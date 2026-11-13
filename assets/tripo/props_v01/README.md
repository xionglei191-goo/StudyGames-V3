# 字母岛 · 道具、家具与配饰 · 24 件

14 件互动道具、6 件家具、4 件穿戴配饰。与现有游戏目录中的名称一一对应，保留独立白底单物体图片。

由内置 `image_gen` 生成，原始 PNG 按字节复制并校验，未裁切或重新编码。

打开 [可搜索总览](index.html) 选图；每次向 Tripo 上传一张独立 PNG。生成的模型可按下表命名，返回后再处理骨架、尺寸、碰撞和游戏接入。

[总览图片](preview/overview.jpg) · [完整提示词](generation-plan.json) · [生成记录](generation-records.json) · [检查结果](delivery-checks.json)

## 素材索引

| 编号 | 名称 | 类别 | 图片 | 建议 GLB 文件名 | 外观依据 |
|---|---|---|---|---|---|
| 001 | 积木探险机器人 | 互动道具 | [01_robot.png](01_robot.png) | `prop_robot.glb` | 原创游戏道具 |
| 002 | 红色蒸汽小火车 | 互动道具 | [02_train.png](02_train.png) | `prop_train.glb` | 原创游戏道具 |
| 003 | 海蓝旋纹贝壳 | 互动道具 | [03_whale_shell.png](03_whale_shell.png) | `prop_whale_shell.glb` | 原创游戏道具 |
| 004 | 暖枝小鸟巢 | 互动道具 | [04_nest.png](04_nest.png) | `prop_nest.glb` | 原创游戏道具 |
| 005 | 蓝海小地球仪 | 互动道具 | [05_globe.png](05_globe.png) | `prop_globe.glb` | 原创游戏道具 |
| 006 | 暖光纸灯笼 | 互动道具 | [06_lantern.png](06_lantern.png) | `prop_lantern.glb` | 原创游戏道具 |
| 007 | 蜜桃毛线球 | 互动道具 | [07_yarn.png](07_yarn.png) | `prop_yarn.glb` | 原创游戏道具 |
| 008 | 秋日小南瓜 | 互动道具 | [08_pumpkin.png](08_pumpkin.png) | `prop_pumpkin.glb` | 原创游戏道具 |
| 009 | 草莓冰淇淋 | 互动道具 | [09_ice_cream.png](09_ice_cream.png) | `prop_ice_cream.glb` | 原创游戏道具 |
| 010 | 蜜桃小花 | 互动道具 | [10_flower.png](10_flower.png) | `prop_flower.glb` | 原创游戏道具 |
| 011 | 麦香乡村面包 | 互动道具 | [11_bread.png](11_bread.png) | `prop_bread.glb` | 原创游戏道具 |
| 012 | 蓝盖牛奶瓶 | 互动道具 | [12_milk.png](12_milk.png) | `prop_milk.glb` | 原创游戏道具 |
| 013 | 晴空蓝雨伞 | 互动道具 | [13_umbrella.png](13_umbrella.png) | `prop_umbrella.glb` | 原创游戏道具 |
| 014 | 彩色燕尾风筝 | 互动道具 | [14_kite.png](14_kite.png) | `prop_kite.glb` | 原创游戏道具 |
| 015 | 云朵双人沙发 | 家具 | [15_reading_sofa.png](15_reading_sofa.png) | `prop_reading_sofa.glb` | 原创游戏道具 |
| 016 | 童话绘本架 | 家具 | [16_walnut_bookshelf.png](16_walnut_bookshelf.png) | `prop_walnut_bookshelf.glb` | 原创游戏道具 |
| 017 | 黄铜留声机 | 家具 | [17_music_gramophone.png](17_music_gramophone.png) | `prop_music_gramophone.glb` | 原创游戏道具 |
| 018 | 森系木秋千 | 家具 | [18_courtyard_swing.png](18_courtyard_swing.png) | `prop_courtyard_swing.glb` | 原创游戏道具 |
| 019 | 晴空小喷泉 | 家具 | [19_garden_fountain.png](19_garden_fountain.png) | `prop_garden_fountain.glb` | 原创游戏道具 |
| 020 | 兔兔绿雕 | 家具 | [20_bunny_topiary.png](20_bunny_topiary.png) | `prop_bunny_topiary.glb` | 原创游戏道具 |
| 021 | 田园丝带草帽 | 穿戴配饰 | [21_straw_hat.png](21_straw_hat.png) | `prop_straw_hat.glb` | 原创游戏道具 |
| 022 | 摘星画家贝雷帽 | 穿戴配饰 | [22_star_beret.png](22_star_beret.png) | `prop_star_beret.glb` | 原创游戏道具 |
| 023 | 元气向日葵书包 | 穿戴配饰 | [23_school_pack.png](23_school_pack.png) | `prop_school_pack.glb` | 原创游戏道具 |
| 024 | 藤编野餐花篮 | 穿戴配饰 | [24_picnic_basket.png](24_picnic_basket.png) | `prop_picnic_basket.glb` | 原创游戏道具 |

## 使用边界

图片内的组件关系供建模参考。秋千座板与支架、留声机唱片与机身、柜门/抽屉等活动组件，生成模型后仍需分件及设置轴心；水面动态留待引擎实现。帽子与背包需结合人物模型校正佩戴位置。

道具由项目玩法名称和现有材质方向重新设计。尺寸、轴心和碰撞记录是后续导入建议，尚未写入游戏。地球仪上的陆地轮廓为装饰性简化，不用于地理知识教学。
