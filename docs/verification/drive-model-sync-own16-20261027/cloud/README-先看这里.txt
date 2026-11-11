StudyGames own16 — 全图审查与针对性精修（2026-10-27）

【1. 先运行游戏：无需旧包】
下载「01_完整Godot项目」内全部分片、parts-manifest.json、reassemble.py到同一目录，运行 python reassemble.py。
脚本验证每个分片和合并ZIP的SHA256。解压ZIP，用Godot4.6.3打开 StudyGames-V3-own16/game/project.godot，等待标准导入后运行主场景。
这是完整Godot工程，不是Windows EXE。引擎未打包；重组脚本需Python3.10+。不用安装旧版或串联增量补丁。

【2. 可选编辑：完整44套Blender源】
「02_完整44场景可编辑源」同样下载全部文件并运行 python reassemble.py。
该ZIP自包含当前44套 .blend /匹配GLB/预览，共132个索引文件，不依赖旧源包。Blender4.3.2验证，960幅图像已打包。
直接解压即可编辑。也可用根目录 restore_sources.py 精确恢复并验证：
python restore_sources.py --index SOURCE-INDEX44.json --output editable44 StudyGames-V3-own16-complete44-editable-sources-20261027.zip
脚本拒绝路径逃逸及覆盖不同内容的本地文件；重复运行不会重复写入。不会恢复旧版团状树冠或已否决的中间模型。
部分原文件历史上由GLB恢复，可编辑网格不等于恢复全部原始修改器/创作历史。构建链脚本仅作为技术来源；直接使用最终.blend可独立编辑和重新导出。

【3. 本轮到底改了什么】
44个可加载环境资产及室外全图均已审查；20项针对性精修（19个室内/庭院场景及主岛），24项保留已验收版本，并非44项全部重做。
主岛更换473个指定植物网格，保留原142棵可辨叶片树冠、主题建筑、道路、地面和碰撞。室内改善织物、餐具/水槽、植物、船体、南瓜、火山、鲸与伞面等。
SOURCE-INDEX44.json、SCENE-LEDGER44及原生前后图记录精确范围。图像为真实Godot同机位截图排版，不是生成图。

【4. 验证与已知限制】
完整功能及支撑测试未发现新回归；既有旧存档reviews字段迁移断言仍实际失败（exit1），不声称全部测试通过。
Godot4.6.3/Linux/Mesa llvmpipe软件主机的单次60绘制帧配对：学校FPS约-8.1%、庭院-9.0%、棕榈区-2.3%、极远岛景-6.4%；果园+3.8%仅作为单次波动，不承诺加速。未验证Windows或目标独立显卡性能。
既有多边形海岸/沙土边界、风格化帽带及部分食物折痕等仍有局限；不宣称达到商业游戏同等品质。
最终清洁导入、全44实际资源/材质纹理/LOD/阴影等价、源文件恢复及远端下载字节校验，以 PACKAGE-VALIDATION.json 和 DELIVERY-MANIFEST.json 为准。完整功能QA在冻结规范工程执行，不把解压包资源检查冒称全功能重跑。

【5. 取证与隐私】
「03_真实画面对比与验证」提供全范围图库、原图和技术报告；根目录精简对比图可先看。
DELIVERY-MANIFEST.json、SHA256SUMS.txt列出精确归档哈希及验证收据。此前版本保留，Google Drive仍为原私有访问范围。
