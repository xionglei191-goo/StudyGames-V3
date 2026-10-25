# 场景精修 · 第二轮

基准：`d30c4f57ee4713444e25067ef7c07ddaf973d4c1`。本轮对 18 个第一轮 `.blend` 进行真实 Blender 编辑，另存新版本并更新游戏实际加载资源。原始 5.2 文件及第一轮资产均保留。

主岛 v09、校园与客厅 v06、院落 v05，其余房间 v04；版本后缀均为 `_cloud`。

## 具体修改

- 主岛：完整山墙门廊、圆窗阁楼、加深窗框与窗台、分层树冠、地形坡面材质和贴合地形的浅岸线。靠近字母入口的树冠高度不超过第一轮。
- 校园：音乐阁楼、美术屋顶采光间、科学观察亭、入口雨棚、路径边缘和中央花园层次。
- 生活与教学空间：圆角桌板/座面、圆润柜体和家具边缘、床头弧形轮廓、窗帘与织物、打包木纹贴图，以及放在现有家具上的茶具、绘画/书写用品、面包、毛巾和育苗盆。
- 运动空间：器材架与挂环、圆润长凳、既有球队长凳上的弧形遮阳棚，保留原有水瓶，避免重复堆叠。
- 复审修正：面包移离果篮；香草盆移出水槽；排烟罩后改用收起的窗帘；教室悬空装饰窗安装到后墙；客厅保留既有窗帘，避免叠加；主岛瓦片改成有厚度的错层搭接，消除原有重面条纹。

## 真实对照与验证

`comparisons/` 有 18 场景总览、3 个固定近景、主岛入口对照及 4 组原生游戏代表画面。`native/before/round2/` 与 `native/after/round2/` 各含 36 张 1440×900 原始截图及相机/光照状态记录。Blender 对照同机位同光照，不用后期调色掩盖几何差异。

- 1,738 个受保护节点：名字、层级、属性、变换和三角形位置校验保持一致（几何比较精度 1e-5）。
- 456 个原有可见网格重塑；18 个保存文件重新打开并检查修改网格和打包贴图。
- 总三角形：5,243,248 → 5,466,060（+4.25%）。
- 18 个 GLB 总大小：305,828,504 → 307,647,376 字节（+0.59%）。源资源与运行时副本内容相同，不重复计算。

普通导出、同步、实际物理路线、当前存档测试的命令、退出码和原始报告见 `export-checks.json`、`runtime-checks.json`。不得把已知失败的存档测试记为 PASS。

![主岛住宅固定近景](comparisons/island-detail.jpg)

![厨房实际游戏相机](comparisons/native-home_kitchen.jpg)

| 检查 | 实际结果 |
|---|---|
| world-conventional | PASS；退出码 0 |
| conventional-export | PASS；退出码 0 |
| sync-interiors | PASS；退出码 0 |
| sync-world | PASS；退出码 0 |
| godot-import | PASS；退出码 0 |
| campus | PASS；退出码 0 |
| household | PASS；退出码 0 |
| letters | PASS；退出码 0 |
| state-after | FAIL：与首轮相同的 reviews 存档断言；退出码 1 |
| 原生游戏截图 | 前后各 36 张；相同相机检查与固定白昼晴天通过 |

实际路线检查与截图检查分别记录。直接载入房间截图不冒充实际步行验证。

常规同步脚本也已更新：版本化房间的面数、预览、版本及源路径会随同步保留并校验；主岛普通导出保留现有预览和来源字段，并重新计算实际实例化三角形数量。不是仅靠本轮专用脚本维持清单。

复验中发现并修复一处 U→V 导航回归：地形材质重新分组改变了导入后的地面处理，虽三角形坐标集合相同，实际路线仍失败。已改为独立、无碰撞的坡面表层，保留原地形材质分组与精确面顺序。`route-baseline-UV-report.json`、`route-initial-UV-report.json`、`route-corrected-UV-report.json` 分别保留首轮通过、中间失败和修正通过；最终全字母结果见 `letters-report.json`。

| 场景 | 三角形：首轮 → 本轮 | 材质：首轮 → 本轮 | GLB 字节：首轮 → 本轮 | 对照 |
|---|---:|---:|---:|---|
| 字母岛 | 2,250,152 → 2,389,466 | 162 → 171 | 160,741,644 → 160,680,168 | [island](comparisons/island.jpg) |
| 山丘学园 | 332,480 → 393,506 | 74 → 81 | 19,439,844 → 19,892,672 | [school](comparisons/school.jpg) |
| 教室 | 205,464 → 203,728 | 35 → 39 | 7,787,196 → 7,769,404 | [classroom](comparisons/classroom.jpg) |
| 音乐教室 | 183,308 → 184,816 | 41 → 45 | 8,236,120 → 8,394,268 | [music_room](comparisons/music_room.jpg) |
| 美术教室 | 159,564 → 160,708 | 43 → 50 | 6,604,996 → 6,785,144 | [art_room](comparisons/art_room.jpg) |
| 科学教室 | 222,916 → 225,664 | 36 → 44 | 8,157,000 → 8,312,892 | [science_room](comparisons/science_room.jpg) |
| 食堂 | 181,584 → 181,792 | 35 → 37 | 7,759,928 → 7,748,712 | [canteen](comparisons/canteen.jpg) |
| 操场 | 126,804 → 131,172 | 22 → 26 | 4,606,980 → 4,655,692 | [playground](comparisons/playground.jpg) |
| 校园足球场 | 182,580 → 183,532 | 27 → 30 | 6,785,608 → 6,875,908 | [football_field](comparisons/football_field.jpg) |
| 客厅 | 169,160 → 167,536 | 43 → 46 | 7,325,652 → 7,301,932 | [home](comparisons/home.jpg) |
| 家务阳台 | 103,116 → 105,844 | 34 → 39 | 3,854,832 → 4,094,744 | [home_balcony](comparisons/home_balcony.jpg) |
| 清爽浴室 | 110,360 → 111,288 | 32 → 35 | 6,320,328 → 6,192,016 | [home_bathroom](comparisons/home_bathroom.jpg) |
| 温暖卧室 | 70,600 → 70,880 | 31 → 32 | 4,341,760 → 4,222,004 | [home_bedroom](comparisons/home_bedroom.jpg) |
| 家庭餐厅 | 99,692 → 100,996 | 41 → 46 | 5,275,056 → 5,472,548 | [home_dining](comparisons/home_dining.jpg) |
| 家园院落 | 464,280 → 465,452 | 51 → 55 | 26,330,972 → 26,439,488 | [home_estate](comparisons/home_estate.jpg) |
| 家里 · 门厅与走廊 | 182,436 → 182,424 | 45 → 49 | 10,966,532 → 11,066,604 | [home_hall](comparisons/home_hall.jpg) |
| 明亮厨房 | 125,400 → 133,564 | 38 → 49 | 6,692,892 → 7,365,428 | [home_kitchen](comparisons/home_kitchen.jpg) |
| 窗边书房 | 73,352 → 73,692 | 40 → 41 | 4,601,164 → 4,377,752 | [home_study](comparisons/home_study.jpg) |

## 保真边界与质量判断

18 个场景第一轮均从当时实际加载的 GLB 导入，因已安装 Blender 4.3.2 无法打开原 Blender 5.2 作者文件。第二轮直接编辑第一轮保存的 `.blend`，未再次用 GLB 重建。原始修改器、曲线与作者操作历史无法由 GLB 还原；第一轮 GLB 的动画/骨骼数均为 0，家务状态仍由原 HOME_TASK 分组驱动。

当前版本、统计、预览和加载路径以更新后的四份源/运行时清单及 `cloud_refinement_revision` 为准。GLB 继承的早期场景自定义注释（例如旧 `output_version`、`sg_game_export_version` 与旧检查说明）属于历史来源记录，不作为本轮版本或验收依据。

本轮有意替换部分装饰网格与材质。原贴图保留/替换数量逐场景记录在 `asset_validation.json`，不宣称全部材质逐字节不变。碰撞代理、导航相关地形和交互节点按受保护集合比较；道路薄边、墙面装饰及屋顶细节不增加地面障碍。

以《动物森友会》的完成度作为审查方向，而非复制其素材或声称已等同商业成品。轮廓厚度、家具曲线、植被层次和生活细节本轮有实际模型改善；原有角色、房间尺度、教学标识和玩法保留。通过真实游戏截图检查可见效果，不把 Blender 渲染当作游戏画面。

| 审查维度 | 本轮达到的可核验结果 / 边界 |
|---|---|
| 建筑与家具轮廓 | 门廊、阁楼、窗框深度、桌椅圆角和床头弧线已经进入实际资源；屋瓦共面条纹已修复。 |
| 材质与色板 | 木纹、织物、叶面贴图打包入 GLB，金属/陶器粗糙度分开；保留原游戏对家务状态道具的着色，因此 Blender 与游戏的任务道具颜色可能不同。 |
| 地形与植被 | 树冠高低和体块重新组织，岸线与坡面层次可见；碰撞地形的精确面顺序保留。 |
| 生活布景与通路 | 道具依附现有家具，已排除发现的桌面重叠；300 条实际路线、88 次转换通过。 |
| 实际镜头 | 18 场景均有原生游戏远景/生产相机，代表性样板补充固定 Blender 近景。 |
| 商业成品等同 | 未把一次迭代、面数或自动检查当作等同商业团队成品的证据；角色动画、完整演出及目标硬件性能不属于本轮已验收结论。 |

已运行的原生画面使用 Godot 4.6.3、X11 和 llvmpipe 软件渲染。项目声明的 Godot 4.7、目标设备 GPU 帧时、人工长时间游玩验收未运行；当前证据不证明这些验收通过。

存档基准测试在首轮 d30c4f57 上重新失败：`_test_life_compatibility_and_transactions` → `Legacy save preserves field: reviews`（`test_state.gd:178` 的断言，汇总打印于第 26 行）。本轮后结果见 `state-after.log`；没有修改学习或存档逻辑。

## 复现

```bash
python3 scripts/cloud_round2_runner.py --evidence /tmp/studygames-round2 --workers 2
python3 scripts/cloud_round2_validate.py --evidence /tmp/studygames-round2
blender --python-exit-code 1 -b -P scripts/cloud_round2_saved.py -- "$PWD" /tmp/studygames-round2
python3 scripts/cloud_round2_integrate.py --evidence /tmp/studygames-round2
python3 scripts/cloud_round2_checks.py --phase export --evidence /tmp/studygames-round2
python3 scripts/cloud_round2_checks.py --phase runtime --evidence /tmp/studygames-round2
```

原生截图需可用图形显示，使用 `game/tests/capture_cloud_round2.gd`。先在 d30c4f57 上录制 `before`，再在新资源上录制 `after`；后者读取前者相机记录并进行比较。仅修改了测试截图入口，未修改游戏核心逻辑。

远程只提交到既有独立分支；不合并、不部署，不重试此前被拒绝的 PR 创建。
