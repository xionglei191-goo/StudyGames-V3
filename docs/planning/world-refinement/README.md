# 全场景精修范围

以已完成的小院/客厅样板为标准，对现有主岛、26 个字母场所、校园及功能区、家园及室内空间做完整美术精修，共 44 处。

`baseline.json` 固定修改前 131 份源文件和预览的 SHA256；`inventory.json` 记录当时的节点与材质。两份 before manifest 保存当时有效路径。此基线不可覆盖。

执行保持版本化源文件，保留已有贴图、固定记忆点、门口和碰撞几何；新纹理、树冠和装饰在 Blender 内生成并保存。修改后分别验证导出资产、实际通行和 Godot 原生画面，三者互不替代。

当前结果见 [专项验收](../../verification/world-refinement/README.md) 和 [44 场景对照](../../world-refinement.html)。
