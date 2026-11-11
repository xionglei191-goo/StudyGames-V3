"""Run the desktop game while holding the same profile lock as the web service.

The Windows child starts suspended and joins a kill-on-close Job Object before
it can touch a save. If this supervisor crashes, Windows stops the child before
releasing this process's profile lock. No web service is needed for desktop play.
"""
from __future__ import annotations

import argparse
import contextlib
import ctypes
import json
import os
import secrets
import subprocess
import sys
from pathlib import Path

from shared_profiles import DEFAULT_ROOT, ProfileError, ProfileStore

ROOT = Path(__file__).resolve().parents[1]


def write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2), "utf-8")
    os.replace(temporary, path)


class WindowsChild:
    """One suspended child, atomically attached to a private lifetime job."""

    def __init__(self, command: list[str], cwd: Path, environment: dict[str, str] | None = None):
        from ctypes import wintypes as wt

        self.kernel = ctypes.WinDLL("kernel32", use_last_error=True)

        class StartupInfo(ctypes.Structure):
            _fields_ = [("cb", wt.DWORD), ("lpReserved", wt.LPWSTR),
                        ("lpDesktop", wt.LPWSTR), ("lpTitle", wt.LPWSTR),
                        ("dwX", wt.DWORD), ("dwY", wt.DWORD),
                        ("dwXSize", wt.DWORD), ("dwYSize", wt.DWORD),
                        ("dwXCountChars", wt.DWORD), ("dwYCountChars", wt.DWORD),
                        ("dwFillAttribute", wt.DWORD), ("dwFlags", wt.DWORD),
                        ("wShowWindow", wt.WORD), ("cbReserved2", wt.WORD),
                        ("lpReserved2", ctypes.POINTER(ctypes.c_byte)),
                        ("hStdInput", wt.HANDLE), ("hStdOutput", wt.HANDLE),
                        ("hStdError", wt.HANDLE)]

        class ProcessInfo(ctypes.Structure):
            _fields_ = [("hProcess", wt.HANDLE), ("hThread", wt.HANDLE),
                        ("dwProcessId", wt.DWORD), ("dwThreadId", wt.DWORD)]

        class BasicLimit(ctypes.Structure):
            _fields_ = [("PerProcessUserTimeLimit", ctypes.c_int64),
                        ("PerJobUserTimeLimit", ctypes.c_int64),
                        ("LimitFlags", wt.DWORD),
                        ("MinimumWorkingSetSize", ctypes.c_size_t),
                        ("MaximumWorkingSetSize", ctypes.c_size_t),
                        ("ActiveProcessLimit", wt.DWORD),
                        ("Affinity", ctypes.c_size_t), ("PriorityClass", wt.DWORD),
                        ("SchedulingClass", wt.DWORD)]

        class IoCounters(ctypes.Structure):
            _fields_ = [(name, ctypes.c_uint64) for name in (
                "ReadOperationCount", "WriteOperationCount", "OtherOperationCount",
                "ReadTransferCount", "WriteTransferCount", "OtherTransferCount")]

        class ExtendedLimit(ctypes.Structure):
            _fields_ = [("BasicLimitInformation", BasicLimit), ("IoInfo", IoCounters),
                        ("ProcessMemoryLimit", ctypes.c_size_t),
                        ("JobMemoryLimit", ctypes.c_size_t),
                        ("PeakProcessMemoryUsed", ctypes.c_size_t),
                        ("PeakJobMemoryUsed", ctypes.c_size_t)]

        kernel = self.kernel
        kernel.CreateJobObjectW.argtypes = [ctypes.c_void_p, wt.LPCWSTR]
        kernel.CreateJobObjectW.restype = wt.HANDLE
        kernel.SetInformationJobObject.argtypes = [wt.HANDLE, ctypes.c_int, ctypes.c_void_p, wt.DWORD]
        kernel.SetInformationJobObject.restype = wt.BOOL
        kernel.CreateProcessW.argtypes = [wt.LPCWSTR, wt.LPWSTR, ctypes.c_void_p,
                                         ctypes.c_void_p, wt.BOOL, wt.DWORD,
                                         ctypes.c_void_p, wt.LPCWSTR,
                                         ctypes.POINTER(StartupInfo), ctypes.POINTER(ProcessInfo)]
        kernel.CreateProcessW.restype = wt.BOOL
        kernel.AssignProcessToJobObject.argtypes = [wt.HANDLE, wt.HANDLE]
        kernel.AssignProcessToJobObject.restype = wt.BOOL
        kernel.ResumeThread.argtypes = [wt.HANDLE]
        kernel.ResumeThread.restype = wt.DWORD
        kernel.TerminateProcess.argtypes = [wt.HANDLE, wt.UINT]
        kernel.TerminateProcess.restype = wt.BOOL
        kernel.CloseHandle.argtypes = [wt.HANDLE]
        kernel.CloseHandle.restype = wt.BOOL
        kernel.WaitForSingleObject.argtypes = [wt.HANDLE, wt.DWORD]
        kernel.WaitForSingleObject.restype = wt.DWORD
        kernel.GetExitCodeProcess.argtypes = [wt.HANDLE, ctypes.POINTER(wt.DWORD)]
        kernel.GetExitCodeProcess.restype = wt.BOOL
        self.process = self.job = None
        self.pid = 0
        self.job = kernel.CreateJobObjectW(None, None)
        if not self.job:
            raise ctypes.WinError(ctypes.get_last_error())
        limits = ExtendedLimit()
        limits.BasicLimitInformation.LimitFlags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        try:
            if not kernel.SetInformationJobObject(self.job, 9, ctypes.byref(limits), ctypes.sizeof(limits)):
                raise ctypes.WinError(ctypes.get_last_error())
            startup, info = StartupInfo(), ProcessInfo()
            startup.cb = ctypes.sizeof(startup)
            startup.dwFlags = 0x00000001  # STARTF_USESHOWWINDOW
            startup.wShowWindow = 1       # SW_SHOWNORMAL
            # Only pass CREATE_NO_WINDOW for *_console.exe builds; GUI Godot opens a visible window.
            no_win_flag = 0x08000000 if str(command[0]).lower().endswith("_console.exe") else 0
            flags = 0x00000004 | no_win_flag | 0x00000400  # SUSPENDED | UNICODE_ENVIRONMENT
            command_line = ctypes.create_unicode_buffer(subprocess.list2cmdline(command))
            environment_block = None
            if environment is not None:
                environment_block = ctypes.create_unicode_buffer("\0".join(
                    key + "=" + value for key, value in sorted(environment.items(), key=lambda item: item[0].upper())) + "\0")
            if not kernel.CreateProcessW(command[0], command_line, None, None, False,
                                         flags, environment_block, str(cwd), ctypes.byref(startup), ctypes.byref(info)):
                raise ctypes.WinError(ctypes.get_last_error())
            self.process, self.pid = info.hProcess, int(info.dwProcessId)
            try:
                if not kernel.AssignProcessToJobObject(self.job, self.process):
                    raise ctypes.WinError(ctypes.get_last_error())
                if kernel.ResumeThread(info.hThread) == 0xFFFFFFFF:
                    raise ctypes.WinError(ctypes.get_last_error())
            except BaseException:
                kernel.TerminateProcess(self.process, 1)
                kernel.WaitForSingleObject(self.process, 10000)
                raise
            finally:
                kernel.CloseHandle(info.hThread)
        except BaseException:
            self.close()
            raise

    def wait(self) -> int:
        from ctypes import wintypes as wt
        result = self.kernel.WaitForSingleObject(self.process, 0xFFFFFFFF)
        if result != 0:
            raise ctypes.WinError(ctypes.get_last_error())
        code = wt.DWORD()
        if not self.kernel.GetExitCodeProcess(self.process, ctypes.byref(code)):
            raise ctypes.WinError(ctypes.get_last_error())
        return int(code.value)

    def close(self) -> None:
        if self.job:
            self.kernel.CloseHandle(self.job)
            self.job = None
        if self.process:
            self.kernel.WaitForSingleObject(self.process, 10000)
            self.kernel.CloseHandle(self.process)
            self.process = None


def run(args: argparse.Namespace) -> int:
    profile_root = args.profile_root.resolve()
    store = ProfileStore(root=profile_root, legacy_path=args.legacy_path)
    profile_id = args.profile_id or store.ensure_default()
    profile = store.get_profile(profile_id)
    if profile.get("pending_browser_import"):
        raise ProfileError("请先在原浏览器完成旧角色导入并保存，再使用电脑端。", 409, "browser_import_pending")
    status_file = args.status_file or profile_root / "native-launch-status.json"
    session_file = profile_root / profile_id / ("native-session-" + secrets.token_hex(8) + ".json")
    nonce = secrets.token_hex(24)
    child = None
    with store.lock_profile(profile_id):
        store.snapshot(profile_id, repair=True)
        save_path = store.save_path(profile_id).resolve()
        write_json(session_file, {"profile_id": profile_id, "save_path": str(save_path),
                                 "supervisor_pid": os.getpid(), "nonce": nonce,
                                 "nickname": profile["nickname"], "outfit": profile.get("outfit", "yellow")})
        arguments = [str(args.godot.resolve()), "--path", str(ROOT / "game"),
                     "--log-file", str(profile_root / profile_id / "native-game.log")]
        arguments += args.engine_arg
        arguments += ["--", "--shared-profile-path=" + str(save_path),
                      "--shared-profile-id=" + profile_id,
                      "--shared-profile-session=" + str(session_file),
                      "--shared-profile-nonce=" + nonce]
        environment = {**os.environ, "ALPHABET_SHARED_NONCE": nonce,
                       "ALPHABET_SHARED_SUPERVISOR": str(os.getpid())}
        try:
            if os.name == "nt":
                child = WindowsChild(arguments, ROOT, environment)
            else:
                child = subprocess.Popen(arguments, cwd=ROOT, env=environment)
            write_json(status_file, {"ok": True, "status": "started", "profile_id": profile_id,
                                     "nickname": profile["nickname"], "pid": child.pid,
                                     "supervisor_pid": os.getpid()})
            code = child.wait()
            write_json(status_file, {"ok": code == 0, "status": "stopped", "profile_id": profile_id,
                                     "pid": child.pid, "exit_code": code,
                                     "error": "" if code == 0 else "游戏未能正常运行，请查看该角色的 native-game.log。"})
            return code
        finally:
            # Child lifetime ends before the canonical file lock can be released.
            if isinstance(child, WindowsChild):
                child.close()
            elif child is not None and child.poll() is None:
                child.terminate()
                child.wait(timeout=10)
            with contextlib.suppress(OSError):
                session_file.unlink()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--profile-id")
    parser.add_argument("--profile-root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--legacy-path", type=Path)
    parser.add_argument("--status-file", type=Path)
    parser.add_argument("--engine-arg", action="append", default=[])
    parser.add_argument("--no-dialog", action="store_true")
    args = parser.parse_args()
    try:
        return run(args)
    except (ProfileError, OSError, ValueError) as error:
        message = getattr(error, "message", str(error))
        status_file = args.status_file or args.profile_root / "native-launch-status.json"
        write_json(status_file, {"ok": False, "status": "error", "error": message,
                                 "code": getattr(error, "code", "native_start_failed")})
        if os.name == "nt" and not args.no_dialog:
            ctypes.windll.user32.MessageBoxW(None, message, "字母岛 · 暂时无法进入", 0x30)
        print(message, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
