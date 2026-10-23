# 世界近景美术 v3

六款独立 Blender 道具和六组中性细节材质，延续暖奶油、鼠尾草绿、柔红与蜂蜜木色的儿童绘本方向。原地图、碰撞、地标、场景导航和存档不在本资产生成或接入脚本的写入范围内。

## 可编辑来源与造型

- `world_props_v3.blend`：原创建模来源。苹果有五瓣轮廓、凹顶、弯果梗和立体叶脉；篮子为真正交替编织的开口结构，含底编织、口沿、双侧提手；蛋糕含海绵夹层、果酱、起伏滴落奶油、草莓、籽点和陶盘；书含封皮、圆书脊、纸边、压印叶形、书角和书签。
- 邀请函与姓名牌：32×23cm厚纸卡，中心原点、正面+Z。邀请函带三角折盖、折线和蜡封；姓名牌带圆角框、细金边、缝点和叶饰。中央不烘焙文字，沿用运行时文本。
- `props-review.png`：800×600、12 samples、CPU Cycles 小图。已人工查看造型；它不替代引擎画面验收。
- `textures/`：wood、bark、foliage、cloth、paper、plaster 共六组256×256可平铺中性明度细节和OpenGL法线。由确定性函数生成，不含外部图片或烘焙照明。
- `manifest.json`：来源、坐标、原点、顶点/三角、字节、SHA256与限制，包含可编辑源、12张纹理及最终引擎报告的SHA256。原始脚本：`scripts/build_world_art_v3.py`，固定种子3217。

本批内容为项目原创程序化DCC建模及解析纹理，不引入第三方素材授权义务。

## 接入边界

`game/scripts/world_art.gd` 提供 `create_prop(kind)`。Y向上、单位米；苹果原点在果身中心，篮/蛋糕/书在底面中心，邀请函/姓名牌为卡片中心。6个GLB由PackedScene缓存加载，重复实例共享Mesh和Material资源。精细篮子约2.3万三角，苹果/蛋糕/书约0.2万/1.2万/0.2万，邀请函1472、姓名牌940三角；没有单独LOD网格。

`BlenderMaterials.restore_vertex_colors()`恢复原顶点色后应用本层。仅对明确命名的水果、篮子、蛋糕和桌面书本增加视觉子节点。旧Mesh保留在原位置，`layers=0`抑制旧几何绘制，原节点AABB、transform、visible及碰撞/SG标记不变。新视觉继承旧节点的显示状态，家居装饰开关仍有效。分离果梗/叶片、旧篮编织和旧蛋糕附件单独抑制绘制。采苹果活动和拾取反馈使用同一新资产。

材质仅处理未含albedo/normal贴图且不透明的原材质；原颜色及已有贴图保持。桌椅、门框、窗框和其他木作获得木纹，树干为树皮，植被为柔和叶斑，纸页/织物/浅色墙面分别使用对应细节。大树、建筑、家具主体沿用原轮廓；本批不声称重做所有场景几何。

## 验证

- `python -X utf8 scripts/check_world_art_v3.py`：6模型、12贴图及35房间资源清单；GLB有限数值、单位法线、UV、非退化三角、资源hash检查。结果在`static-qa.json`。
- `python -X utf8 scripts/sync_blender_world.py --verify-only`及`python -X utf8 scripts/sync_blender_interiors.py --verify-only --require-all`已通过：原主岛和35房间仍符合原导出清单。
- `game/tests/test_world_art_v3.gd`：引擎专项夹具。必须带`-- --test-harness`。默认覆盖主岛+35房；可用`--room=landmark_A,landmark_C,classroom,home`限定范围，`--capture`需实际渲染器。它比较所有原节点变换/AABB/显示、碰撞shape/layer，确认无新增碰撞、视觉是真实Mesh、统计匹配、重复应用幂等和正式存档hash不变。主任务已运行36场景，PASS/0失败，报告`docs/verification/art-finish-v3/world-headless.json`。`--art-width`/`--art-height`/`--capture-dir`控制双尺寸近景，记录实际尺寸和PNG SHA256。

实机首轮近景暴露了木纹过于均匀的问题；已改为低频弯曲纹路，将明暗调制从0.22收敛为0.08、木纹法线强度从0.32改为0.085，纸/布微表面也同步减弱。最终近景以主任务重拍结果为准。

最终专项结果：36场景（主岛+35房）结构检查PASS，共81处道具替换、6197处表面细节；正式存档hash未变。6种已创作道具中，苹果/篮子/蛋糕/书4种替换已有场景物件，邀请函/姓名牌由角色手持展示调用。

`docs/verification/art-finish-v3/world-native-1440x900.json`与`world-native-960x640.json`均PASS，各含5张近景：果园苹果与篮子、蛋糕、教室书本、家中日记。截图位于`docs/screenshots/art-finish-v3/1440x900/world/`和`960x640/world/`。前者窗口及图像为1440×900；后者实际窗口960×640，按项目固定比例得到960×600视口。最终画面已检查，木纹细节保持低对比、不遮挡原配色；邀请函/姓名牌纳入角色手持道具画面验收。

导出构建与小图渲染均通过隐藏后台Blender进程运行。正式引擎验收由主任务统一调度；证据以以上结构报告和双尺寸截图为准。静态验证、DCC预览和抽样近景不能替代整套游戏体验、低端设备性能或35房间完整导航回归。
