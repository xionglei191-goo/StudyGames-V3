# Drive own16 同步前保护基线

建立时间：2026-10-27T19:28:24.192090+08:00。仅创建本目录的 baseline.json、before.zip、baseline-notes.md；未修改生产文件，未启动 Godot。

ZIP 含 196 个文件，原始合计 716,092,334 字节；压缩后 478,016,666 字节（455.87 MiB）。创建前确认磁盘剩余 716,027,420,672 字节，容量充足。

## 保护范围

- `runtime_glb`：44 个文件。
- `import_sidecar`：44 个文件。
- `import_cache_scene`：44 个文件。
- `import_cache_checksum`：44 个文件。
- `manifest`：3 个文件。
- `dirty_code`：6 个文件。
- `shared_profile`：7 个文件。
- `appdata_persistent`：4 个文件。

另记录 assets/blender 下 206 个既有 .blend/.blend备份/.glb 源文件的 SHA-256 与大小（共 2,887,571,332 字节），不重复打包，不删除源文件。

AppData 只纳入本游戏的持久化存档/备份及现有照片；排除 validation-* 测试存档、日志、shader cache。.local/shared-profiles 下现有文件全部纳入。存档内容未在说明或工具输出中披露。

## 验证

- 每个 ZIP 文件均完整流式回读，SHA-256 与归档时原文件字节一致。
- 归档完成后重新计算全部备份源文件 SHA-256，未发现变化。
- ZIP SHA-256：`4f240cbebfa41a39b182eeec3b57eacec8aa4d12a2089b066bda7eabd932ed81`。

## 恢复规则

先停止游戏及共享存档写入进程，并将当前状态另存到新的临时位置。解压 before.zip 到独立临时目录，根据 baseline.json 的 files[].path 与 files[].zip_entry 逐文件恢复；不要直接将两个顶层目录覆盖到同一个根目录。

- `workspace/` 对应 `F:\LoveStudy\`。
- `appdata_godot/<游戏名称>/` 对应 baseline.json 中 appdata_root。
- 如仅回滚模型，恢复 runtime_glb、import_sidecar、import_cache_scene、import_cache_checksum 和 manifest 五类。
- dirty_code、shared_profile、appdata_persistent 是保护副本；未发生修改时不需回滚，以免覆盖同步后产生的新进度或代码。
- 恢复后按 baseline.json 的逐文件 SHA-256 验证。未包含的既有 Blender 源模型应原位保留，可按 source_files 清单确认。
