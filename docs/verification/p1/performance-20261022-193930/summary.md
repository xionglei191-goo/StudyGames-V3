# P1 原生性能记录

正式记录有效：是
限制原因：无

CPU：AMD Ryzen 5 3600 6-Core Processor；GPU：NVIDIA GeForce RTX 4070；图形接口：3.3.0 NVIDIA 610.88。
引擎：4.7.2-stable (official)；系统：Windows 10.0.26200。
GPU 驱动及完整硬件信息见 hardware-preflight.json；源文件清单、原生窗口/内容分辨率和样本均保存在 JSON/CSV 中。

| 场景 | 动态 | 帧耗时 p50/p95/p99 ms | GPU 根视口 p50/p95 ms | Draw calls p50 | 进程 RSS p50 MiB |
|---|---|---:|---:|---:|---:|
| 01-landmark_A-r1-off | 关 | 2.666/3.400/3.850 | 0.907/0.934 | 1428.000 | 625.859 |
| 02-landmark_A-r1-on | 开 | 2.745/3.493/3.931 | 0.933/0.960 | 1429.000 | 627.504 |
| 03-landmark_A-r2-on | 开 | 2.716/3.473/3.902 | 0.937/0.962 | 1429.000 | 488.199 |
| 04-landmark_A-r2-off | 关 | 2.727/3.664/4.614 | 0.917/0.984 | 1428.000 | 488.227 |
| 05-village-r1-off | 关 | 4.252/5.269/6.043 | 1.461/1.525 | 2323.000 | 923.514 |
| 06-village-r1-on | 开 | 4.702/5.748/6.406 | 1.577/1.690 | 2326.000 | 959.766 |
| 07-village-r2-on | 开 | 4.697/5.819/6.706 | 1.572/1.710 | 2326.000 | 966.836 |
| 08-village-r2-off | 关 | 4.256/5.153/5.639 | 1.477/1.600 | 2323.000 | 972.352 |
| 09-school-r1-off | 关 | 4.021/4.919/5.508 | 1.414/1.998 | 1892.000 | 545.949 |
| 10-school-r1-on | 开 | 4.094/4.937/5.428 | 1.471/2.039 | 1892.000 | 546.391 |
| 11-school-r2-on | 开 | 4.139/5.035/5.619 | 1.459/2.045 | 1892.000 | 546.949 |
| 12-school-r2-off | 关 | 4.007/4.902/5.466 | 1.415/2.004 | 1892.000 | 547.039 |

| 场景 | process 峰值监视器 p50/p95 ms（诊断） | 根视口渲染 CPU p50/p95 ms | Windows 进程 CPU 整机 p50/p95 % | 三角形（可见场景树） | Windows 实际前台/后台样本 |
|---|---:|---:|---:|---:|---:|
| 01-landmark_A-r1-off | 3.954/6.171 | 1.991/2.431 | 8.333/8.854 | 188581 | 239/0 |
| 02-landmark_A-r1-on | 4.001/6.744 | 2.003/2.448 | 8.333/8.854 | 188581 | 239/0 |
| 03-landmark_A-r2-on | 3.947/5.532 | 1.995/2.442 | 8.333/8.854 | 188581 | 239/0 |
| 04-landmark_A-r2-off | 4.245/6.387 | 2.023/2.568 | 8.333/8.854 | 188581 | 239/0 |
| 05-village-r1-off | 5.800/7.794 | 3.120/3.838 | 8.333/13.542 | 1998902 | 240/0 |
| 06-village-r1-on | 6.393/8.033 | 3.194/3.912 | 8.333/13.542 | 1998902 | 239/0 |
| 07-village-r2-on | 6.219/8.694 | 3.187/3.942 | 8.333/13.542 | 1998902 | 239/0 |
| 08-village-r2-off | 5.551/6.812 | 3.123/3.754 | 8.333/13.021 | 1998902 | 239/0 |
| 09-school-r1-off | 5.567/7.666 | 2.870/3.501 | 8.333/12.500 | 255024 | 240/0 |
| 10-school-r1-on | 5.430/7.592 | 2.860/3.460 | 8.333/13.021 | 255024 | 239/0 |
| 11-school-r2-on | 5.614/7.103 | 2.886/3.519 | 8.333/11.979 | 255024 | 240/0 |
| 12-school-r2-off | 5.413/7.113 | 2.871/3.502 | 8.333/13.542 | 255024 | 239/0 |

| 同场景配对 | 可比 | 开启−关闭帧时 p50/p95 ms | 开启−关闭根视口 GPU p50/p95 ms | 开启−关闭 draw calls p50 |
|---|---|---:|---:|---:|
| landmark_A r1 | 是 | +0.079/+0.093 | +0.026/+0.026 | +1.000 |
| landmark_A r2 | 是 | -0.011/-0.191 | +0.020/-0.022 | +1.000 |
| school r1 | 是 | +0.073/+0.018 | +0.057/+0.041 | +0.000 |
| school r2 | 是 | +0.132/+0.133 | +0.044/+0.041 | +0.000 |
| village r1 | 是 | +0.450/+0.479 | +0.116/+0.165 | +3.000 |
| village r2 | 是 | +0.441/+0.666 | +0.095/+0.110 | +3.000 |

## 测量边界

- One actual machine and current GL Compatibility settings; no low/standard/high preset acceptance.
- Static camera and stationary player. Does not measure gameplay travel or word-story animation.
- Environment off disables foliage deformation, water overlay and rain display while retaining actors, weather lighting/fog and resident resources. The delta is not total weather cost or asset-unloading memory savings.
- Viewport GPU/CPU timers cover the root viewport only; they are not whole-process GPU time.
- Rendered primitives monitor counts vertices/indices across passes, not triangles.
- scene_mesh_triangles counts visible-in-tree mesh geometry, including off-camera meshes; excludes MultiMesh and repeated render passes.
- Godot monitor updates can lag. Recorder overhead is present in both modes.
- TIME_PROCESS and TIME_PHYSICS_PROCESS are cached one-second maxima in this engine. Their sampled quantiles are diagnostics, not per-frame CPU distributions or CPU budget acceptance; screenshot/setup spikes may remain cached.
- GPU timer all-zero values are reported unavailable; CPU timings are not substituted for GPU.
- Working set is resident process memory; private commit and engine static memory are separate metrics.
- If background fixture is enabled, it overrides focus-pause only inside the profiler; this is not foreground user experience or normal game background behavior.
- Requested NO_FOCUS does not prove background operation. Per-stage Windows foreground PID observations report actual foreground/background samples separately from Godot's focus flag.
- Windows compositor occlusion is not separately measured. Do not minimize the capture window or overlap competing render tests.
- This records performance; device-class budgets require designated target hardware and acceptance thresholds.
