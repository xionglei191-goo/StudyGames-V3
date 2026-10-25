# Blender 场景精修 · 2026-10-25

基于 `main` 的 `74fdcf79d39f5ce6d5dfc8723ae96e35a2da8c41`，实际主岛来源是 **v07**。本次保留原始文件，生成主岛 `v08_cloud` 和 17 个校园/家庭场景的新版本，并更新 `game/` 使用的 GLB 与清单。儿童英语生活模拟的布局、比例和浅色美术方向保持。

这是实际 Blender 网格、材质编辑及 Cycles 渲染。环境为 Blender 4.3.2、Git LFS 3.6.1、Godot 4.6.3。获取的素材经过 LFS SHA-256 校验；没有把指针文本当作模型。

## 查看效果

以下各组均使用相同相机、灯光、渲染器和色彩管理。全部 19 组见 [gallery.json](gallery.json) 与 [comparisons](comparisons/)。这些是 Blender 渲染，不是 Godot 游戏截图。家庭任务的两侧对比均显示 `before` 状态，实际 GLB 保留全部三种状态。

![主岛住宅与湖岸，左原版右精修](comparisons/island-neighborhood.jpg)

![校园，左原版右精修](comparisons/school.jpg)

![厨房，左原版右精修](comparisons/home_kitchen.jpg)

## 修改范围

| 范围 | 实际修改 |
| --- | --- |
| 主岛 | 住宅入口分片雨棚、木撑与百叶窗；建筑墙角石、檐下托木、屋脊盖瓦；花箱和林下植物；叶色层次；现有岸石分层造型。 |
| 校园 | 屋檐、墙角、花箱；仅给装饰道路网格施加小于 1 cm 的高度错层，修复交叉路面重叠黑面，原可行走地面不变。 |
| 教室、音乐、美术、科学、食堂 | 护墙和桌面收边、柜门嵌板及五金、粉笔托和粉笔、吸音板木条、书脊细节。 |
| 操场 | 跑道色带与篮筐网；原路线、场线和碰撞保持。 |
| 客厅、卧室、餐厅、厨房、浴室、书房 | 柜门、木作、床头、护墙、书脊与植物细节；修正被原家具遮住的装饰件。 |
| 足球场、阳台、院落、门厅 | 轻量细节处理：五金、叶形、屋脊盖瓦或坐垫扣；保留既有陈设和任务状态。 |

18 个场景共新增 134 个按材质合批的网格对象，调整 276 处原有装饰细节。完整逐场景记录在 [changes](changes/)。原有 26 个字母室内资源未修改，主岛字母地标布局保持。

## 兼容性与实际验收

原有节点名全部保留。1,738 个受保护的碰撞、地面、交互/任务节点的层级、属性和变换通过比较；碰撞三角形坐标集合在 `1e-5` 精度下相同。新增装饰标记 `sg_collision=none`，不加入导航或阻挡路线。18 个运行时 GLB 与各自源导出哈希完全一致，贴图嵌入、UV 检查通过。

| 本次实际运行 | 结果 |
| --- | --- |
| 保存后重新打开 18 个 `.blend` | 通过；新增网格无非有限坐标/退化三角形，纹理已打包。 |
| GLB 原版/新版结构及保护节点比较 | 18/18 通过；原始 `.blend` 和 GLB 哈希未变。 |
| Godot 4.6.3 `--headless --import` | 退出 0，无 `ERROR` / `SCRIPT ERROR`。 |
| `test_world_refinement.gd --letters=ABCDEFGHIJKLMNOPQRSTUVWXYZ` | 787 项检查，182 条实际物理行走路线，52 次切换；全部通过。 |
| `test_school_hierarchy.gd` | 352 项检查，56 条路线，16 次切换；全部通过。 |
| `test_home_indoor.gd` | 942 项检查，62 条路线，20 次切换；全部通过。 |

上述路线合计 300 条，场景切换 88 次；测试报告显示玩家存档保持。完整结果、命令和对应资源 SHA 见 [validation-summary.json](validation-summary.json)、[asset_validation.json](asset_validation.json)、[saved_blend_validation.json](saved_blend_validation.json)，原生测试报告和日志也随附于此目录。校园/家庭测试退出时有 `ObjectDB instances leaked` 警告，未隐藏该日志。

**基线失败：** 在替换任何游戏资产之前运行 `test_state.gd`，退出 1，错误为 `Legacy save preserves field: reviews`，见 [原始日志](godot_state_before.log)。本次没有修改存档或学习逻辑，也没有宣称该测试通过。

**尚未运行：** 项目声明的 Godot 4.7、交互式人工验收、GPU 帧率/移动端性能验收、远端 CI（远端运行状态以本次 PR 为准）。主岛三角形由 2,026,792 增至 2,250,152（约 +11%），GLB 从 143.4 MB 增至 160.7 MB；18 个场景总三角形从 4,914,052 增至 5,243,248。图像和 headless 路线通过不能替代目标硬件性能验收。

## 源文件限制

原始 `.blend` 的文件头为 Blender 5.2 格式，安装的 Blender 4.3.2 不能直接打开。官方 Blender 5.2 下载访问返回 HTTP 403。本次在真实 Blender 中导入清单所指向的真实 GLB，完成编辑、保存和重新导出；输出 `.blend` 为可编辑网格场景，包含新建几何、材质、评审相机/灯光和打包纹理。原始修改器、曲线等制作历史没有被重建。原始 `.blend` 与 GLB 字节保持不变。

评审灯光/相机以 `REVIEW_` 命名，仅用于同机位对比；GLB 不导出这些对象，游戏原灯光逻辑保持。家庭任务的所有状态仍导出，不能因静态渲染时隐藏其他状态而删除它们。

## 使用与复现

游戏项目仍在 `game/`。先通过 Git LFS 获取真正资产，再用 Godot 打开 `game/project.godot`。版本和源文件位置以资产清单为准，旧 README 的地图版本不是本次来源。

精修源文件路径、原版路径和哈希见 [执行计划](../../planning/cloud-refinement-20261025.json)。本次新增文件均带 `_cloud`，原件保留。回退游戏资源时，应在独立工作副本恢复这 18 个运行时 GLB 及四份清单到上面的基准提交。

可在另一个隔离工作副本使用 Blender 4.3.2 重放网格编辑与渲染：

```bash
git lfs pull
python3 scripts/cloud_refinement_runner.py --overwrite-generated
blender --background --threads 4 --python-exit-code 1 \
  --python scripts/cloud_verify_saved.py -- "$PWD" "$PWD/.local/cloud-refinement/evidence"
python3 scripts/cloud_integrate_assets.py
python3 scripts/cloud_build_review.py .local/cloud-refinement/evidence
```

`--overwrite-generated` 只允许替换本次生成的 `_cloud` 版本，请勿在有未备份编辑的工作副本中重放。脚本先核对原 GLB 哈希，拒绝指针或错误版本；不覆盖原始 v07/v04/v02 等来源。可以用 `--rooms island,school,home` 只重建指定场景；完整结构验证及整批集成要求全部 18 个场景。评审图合成需要 Pillow 与 Noto Sans CJK 字体。Blender 文件保存时间、压缩与导出器环境可导致重放文件哈希变化，应以重新生成的报告和清单为准。

新增对象位于 `Cloud_Refinement_08` 集合；按场景选择对象后继续编辑即可。原始纹理与游戏逻辑无需从外部网站重新获取。
