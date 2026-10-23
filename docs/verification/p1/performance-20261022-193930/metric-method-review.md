# 计时口径复核

本次引擎为 `4.7.2-stable.official.ed1daf0bf`。采集完成后对同提交的 [Godot main.cpp](https://github.com/godotengine/godot/blob/ed1daf0bf/main/main.cpp#L4723-L4761)复核，确认 `Performance.TIME_PROCESS` 与 `TIME_PHYSICS_PROCESS` 每秒发布该时间窗内的最大值，随后清零内部峰值；外部读取期间保留已发布值。

因此原始 CSV 的 `engine_process_ms` / `engine_physics_ms` 没有被删除，但其分位数是缓存峰值监视器的取样分布，不能解释为每帧 CPU 时间。预热后的截图也可能在该监视器中留下短暂峰值。它们只供诊断，不用于 CPU 成本或预算结论。

正式结论使用以下独立来源：

- `wall_frame_ms`：连续 `frame_post_draw` 的实时时钟差。
- `viewport_render_cpu_ms` / `viewport_render_gpu_ms`：RenderingServer 的根视口测量，只覆盖这个视口。
- `process_cpu_percent_machine`：Windows 进程内核与用户 CPU 累积时间差，再按墙钟与逻辑处理器数归一化。
- RSS / Private Commit：Windows `GetProcessMemoryInfo`，分别报告驻留与私有提交。

没有把根视口渲染 CPU 写成整个进程的逐帧 CPU；后者本轮未单独采集。原始 CSV、原生日志、截图、样本数量、配对检查与有效性均保持不变。更新仅明确指标解释，`summary.json` 和 `pooled-metrics.json` 中的 `metric_definitions` 对应此复核。

`collector-source/` 保存采集时两份工具源码的逐字节快照，SHA-256 对应 `pooled-metrics.json` 的 `collector_hashes`。当前分析脚本的 SHA-256 单列为 `analysis_script_sha256`；复现应使用仓库中当前的 `scripts/verify_p1.py`，快照保留原采集方法以便追溯。
