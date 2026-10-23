# P1 原生性能记录

正式记录有效：是
限制原因：无

CPU：AMD Ryzen 5 3600 6-Core Processor；GPU：NVIDIA GeForce RTX 4070；图形接口：3.3.0 NVIDIA 610.88。
引擎：4.7.2-stable (official)；系统：Windows 10.0.26200。
GPU 驱动及完整硬件信息见 hardware-preflight.json；源文件清单、原生窗口/内容分辨率和样本均保存在 JSON/CSV 中。

| 场景 | 动态 | 帧耗时 p50/p95/p99 ms | GPU 根视口 p50/p95 ms | Draw calls p50 | 进程 RSS p50 MiB |
|---|---|---:|---:|---:|---:|
| 01-landmark_A-r1-off | 关 | 2.339/2.700/3.055 | 0.833/0.851 | 1298.000 | 664.160 |
| 02-landmark_A-r1-on | 开 | 2.410/2.776/3.173 | 0.858/0.880 | 1299.000 | 663.500 |
| 03-landmark_A-r2-on | 开 | 2.408/2.805/3.266 | 0.856/0.884 | 1299.000 | 661.855 |
| 04-landmark_A-r2-off | 关 | 2.355/2.735/3.162 | 0.838/0.860 | 1298.000 | 538.395 |
| 05-village-r1-off | 关 | 3.677/4.378/4.920 | 1.334/1.382 | 2231.000 | 975.016 |
| 06-village-r1-on | 开 | 4.054/4.805/5.343 | 1.473/1.518 | 2234.000 | 1011.578 |
| 07-village-r2-on | 开 | 4.062/4.868/5.462 | 1.479/1.525 | 2234.000 | 1011.840 |
| 08-village-r2-off | 关 | 3.696/4.592/5.217 | 1.345/1.494 | 2231.000 | 1025.203 |
| 09-school-r1-off | 关 | 3.438/4.086/4.603 | 1.272/1.302 | 1587.000 | 731.922 |
| 10-school-r1-on | 开 | 3.555/4.172/4.830 | 1.312/1.351 | 1587.000 | 617.172 |
| 11-school-r2-on | 开 | 3.559/4.205/4.805 | 1.317/1.358 | 1587.000 | 616.742 |
| 12-school-r2-off | 关 | 3.459/4.297/4.973 | 1.284/1.316 | 1587.000 | 617.184 |

| 场景 | process 峰值监视器 p50/p95 ms（诊断） | 根视口渲染 CPU p50/p95 ms | Windows 进程 CPU 整机 p50/p95 % | 三角形（可见场景树） | Windows 实际前台/后台样本 |
|---|---:|---:|---:|---:|---:|
| 01-landmark_A-r1-off | 3.192/4.612 | 1.786/1.959 | 8.333/8.333 | 305229 | 0/239 |
| 02-landmark_A-r1-on | 3.365/5.415 | 1.805/1.979 | 8.333/8.854 | 305229 | 0/239 |
| 03-landmark_A-r2-on | 3.297/5.553 | 1.803/1.994 | 8.333/8.854 | 305229 | 0/239 |
| 04-landmark_A-r2-off | 3.155/4.362 | 1.801/1.993 | 8.333/8.854 | 305229 | 0/239 |
| 05-village-r1-off | 4.948/6.280 | 2.757/3.214 | 8.333/13.542 | 2101374 | 0/239 |
| 06-village-r1-on | 5.465/7.617 | 2.786/3.286 | 8.333/13.594 | 2101374 | 0/239 |
| 07-village-r2-on | 5.369/7.644 | 2.793/3.316 | 8.333/13.594 | 2101374 | 0/239 |
| 08-village-r2-off | 5.049/7.006 | 2.775/3.338 | 8.333/14.062 | 2101374 | 0/239 |
| 09-school-r1-off | 4.686/6.012 | 2.481/2.889 | 8.333/13.542 | 322260 | 0/239 |
| 10-school-r1-on | 4.800/7.658 | 2.481/2.892 | 8.333/13.073 | 322260 | 0/239 |
| 11-school-r2-on | 4.903/5.932 | 2.487/2.900 | 8.333/12.500 | 322260 | 0/239 |
| 12-school-r2-off | 4.991/6.360 | 2.502/2.990 | 8.333/12.514 | 322260 | 0/240 |

| 同场景配对 | 可比 | 开启−关闭帧时 p50/p95 ms | 开启−关闭根视口 GPU p50/p95 ms | 开启−关闭 draw calls p50 |
|---|---|---:|---:|---:|
| landmark_A r1 | 是 | +0.071/+0.076 | +0.025/+0.029 | +1.000 |
| landmark_A r2 | 是 | +0.053/+0.070 | +0.018/+0.024 | +1.000 |
| school r1 | 是 | +0.117/+0.086 | +0.040/+0.049 | +0.000 |
| school r2 | 是 | +0.100/-0.092 | +0.033/+0.042 | +0.000 |
| village r1 | 是 | +0.377/+0.427 | +0.139/+0.136 | +3.000 |
| village r2 | 是 | +0.366/+0.276 | +0.134/+0.031 | +3.000 |

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
