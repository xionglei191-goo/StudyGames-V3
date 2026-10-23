# 全套二维学习素材：定向验证方案

本方案对应新增的 [test_learning_art_all.gd](../../../game/tests/test_learning_art_all.gd)。旧 `test_art_refresh.gd` 及 `art-refresh-v1` 报告保留历史用途。脚本已完成静态复核，Godot `--headless --check-only` 解析检查通过；尚未运行实际回归，须等待 26 字母、10 道具、manifest 与相关代码冻结后统一调度。

验证范围集中在本次图片替换及其共享调用路径：

| 路径 | 定向证据 |
|---|---|
| 26 字母 PNG | manifest、保留原图与运行时文件 SHA 一致；独立源图解码与实际 `Content.icon` 原生尺寸 RGBA 字节相同；1/2/3 倍缩放与独立缩放像素相同；实际 source metadata 正确。B/O/K 继续复用 v1。 |
| 缺图与缓存 | 每个字母先预热 PNG 缓存，再只改内存中的配置路径为不存在的路径，取得该字母的原 SVG；恢复路径后取回 PNG。不改动资源文件。 |
| 通用故事 | 6 个真实词共 52 个字母位置覆盖 A–Z 和现有 13 类通用动作。逐页检查实际舞台纹理；每个动作类别只选一个代表进行实际播放和暂停采样。 |
| 重点故事与10个道具 | 包含 hello、nose、book、football、dog、wood，共28个源动作。逐动作取实际绘制的中间姿态，读取 `prop_diagnostics()`，核对资源像素、源区域、实际四边形与UV；额外记录nose早/晚姿态和book封面/翻页前后四边形，检查翻页跨越书脊。另在测试实例中注入一层书图缓存失败，检查整本书回退旧几何后可恢复。这里的重点故事采样为seek姿态，不能称为完整连续Tween录像。 |
| 提示与存档 | 固定旧学习修订的响应历史、草稿、已揭示格及动画相位恢复；真实 `State` / 事件保存层写入并重新加载 PID 专属存档；H3 不加载未揭示角色或道具，H0/H1 不请求字母图，H4 实际候选选择只前进一步。正式存档及备份前后哈希不变。 |
| 共享序章 | 26 个实际 `PrologueActivity.TextureRect` 均使用对应 PNG 并保持比例；代表图记录原生截图。 |
| 全套图鉴 | 在 1440×900 原生回归场景里用 7 列、4 行真实 `TextureRect` 绘制 A–Z 和中文标签，输出 `00-alphabet-gallery.png`。这是验证场景截图，不加入产品 UI，也不拼接或修改源图。 |

## 真实词集合

| 词 | entry_id | 字母位置数 |
|---|---|---:|
| Tian'anmen Square | `occ-47f1d225c68d` | 15 |
| amazing | `occ-76c657a2a492` | 7 |
| job | `occ-69213f605c59` | 3 |
| expensive | `occ-b5fc541d39f7` | 9 |
| difficulty | `occ-f728e192d2e7` | 10 |
| homework | `occ-2558defff075` | 8 |

这是一组紧凑的覆盖集合，不声称数学上唯一最小，也不展开 1314 条课程的全量回归。覆盖类别为 light、open、roll、fly、tap、catch、lift、transport、mark、greet、place、travel、present。

## 运行顺序与输出

确认素材及代码冻结后，先做脚本检查，再运行 headless；通过后由一个进程顺序完成 1440×900 和 960×640 原生采集。使用 `--fixed-fps 60` 的结果属于功能和离散画面验证，不作为实际性能结论。

输出目录：`docs/verification/art-refresh-all/` 与 `docs/screenshots/art-refresh-all/<window-size>/`。不导出 EXE、不生成 ZIP。原生运行仍须人工查看图鉴及关键动作截图；统计通过不替代视觉核查，也不证明儿童学习效果或所有设备兼容性。
