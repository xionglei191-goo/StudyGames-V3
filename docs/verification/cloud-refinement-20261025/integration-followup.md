# 清单与常规导出验证补充

首个精修提交 `d007cf1926cdefcd6fad0526d4041f6259473e03` 已更新游戏使用的 18 个 GLB 和运行时清单，但集成脚本漏掉了源清单的 `triangles` 与 `preview`。这是实际整合缺陷：对学校执行仓库原有 `export_existing.py --room school --verify-only --no-render`，退出 1，报 `Roundtrip geometry changed`。学校旧统计为 262,564，新导出实际为 332,480。

本次修复更新 17 个校园/家庭源条目的三角形统计、独立版本预览 PNG 路径和 `model_version`。预览直接使用此前真实 Blender `after.png` 渲染，未改动图像内容。集成脚本在写入前核对源文件哈希、实际三角形数和 PNG 存在性，并通过原 `sync_blender_interiors.inspect_glb` 重建完整运行时验证字段，避免只更新少数计数。

另发现足球场旧元数据仍写纹理数 0，且保留早期版本的 Blender 5.2 制作说明与原生画面验收 PASS。当前纹理数更新为 16；历史制作与验收事实移到 `source_history`，当前条目明确为 Blender 4.3.2 的 GLB 导入精修、尚未进行该版本的原生画面人工验收。设计风格参考图属于历史参考，保持不变。锚点、导航边界及学习逻辑未修改。

## 本次新运行的验证

| 检查 | 实际结果 |
| --- | --- |
| 原 `export_existing.py --verify-only --no-render`，逐一选择 17 个新版场景 | 退出 0，17/17 通过；重新打开 `.blend` 并执行常规导出，节点/变换和三角形数量一致，源文件与已交付 GLB 哈希未变。 |
| 原 `sync_blender_interiors.py --require-all --verify-only` | 退出 0；全部 43 个室内/校园条目同步通过。所需历史 LFS 素材已实际获取。 |
| 原 `sync_blender_world.py --verify-only` | 退出 0；主岛 v08、33 个标记、实际运行时资源与清单同步通过，v05 源哈希校验通过。 |
| 连续第二次运行修复后的集成脚本 | 四份清单字节完全相同，未重复添加历史元数据。 |
| 18 个已交付 `.blend`、源 GLB 与运行时 GLB | 与首次交付记录的哈希完全相同；此次只修正清单、脚本并新增版本预览，不改动游戏几何。 |

命令、17 场景统计和预览哈希见 [integration-followup.json](integration-followup.json)。原导出器的原生报告见 [conventional-export-report.json](conventional-export-report.json)，修复前后完整日志均保留在同目录。

这里没有宣称 26 个未修改字母场景的原始 Blender 5.2 文件在 Blender 4.3.2 中完成重新导出；43 项同步检查与 17 项 Blender 重开导出检查的覆盖范围不同。未重复运行已通过且资源哈希未变的 300 条物理行走路线，也没有新增 GPU/人工视觉验收。

## 存档测试对照

基准 `74fdcf79d39f5ce6d5dfc8723ae96e35a2da8c41` 在替换资产之前运行 `test_state.gd`，退出 1：`Legacy save preserves field: reviews`。失败断言在 `_test_life_compatibility_and_transactions()`，比较加载旧存档前后的 `reviews` 字段；日志中的第 26 行是统一报告错误的位置，实际断言在第 178 行。

首次交付时没有重跑此项。本次补充验证在精修后的工程中重跑，仍以同一错误退出 1，见 [godot_state_after_followup.log](godot_state_after_followup.log)。基准与当前的 `game_state.gd`、`test_state.gd` 字节相同；未修复存档逻辑。不能用通过的路线测试替代此项存档兼容测试。

## 文件快照说明

之前上传 Library 的大报告、源文件包、游戏资源包和原件备份保持不变，它们是首次交付快照；其中清单未包含本次补充修复。最新清单、版本预览、集成脚本与验证记录以 GitHub 同一精修分支的后续提交为准。原始 `.blend`、GLB 和旧预览均保留。
