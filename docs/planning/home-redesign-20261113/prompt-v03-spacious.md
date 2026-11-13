# 第三稿：按人物活动重新分配空间

用户反馈：第二稿太拥挤，人物无法活动。

当前玩家碰撞体：半径 0.34、高 1.5，来自 game/scripts/player.gd。概念设计净宽目标：主通道约 2.4，次通道至少 1.4，门洞约 1.6，客厅独立活动区约 4 × 4。数值用于后续建模约束，生成图不视为精确测量结果。

原则：扩大房屋可用地面、减少家具密度、保持人物与家具正常比例。只修改设计图；用户确认前不修改 Blender 或运行资源。

生成方式：内置 image_gen，以 home-concept-v02.png 为编辑参考。

## 完整提示词

Use case: precise-object-edit, 3D game environment layout redesign.
INPUT: the attached warm family-home concept is the rejected crowded draft. REBUILD its spatial proportions into a MUCH MORE SPACIOUS PLAYABLE HOME. Keep the same cozy stylized art, warm oak/ivory/sage palette, complete connected house and seven functions, but substantially increase the architectural footprint and reduce furnishing density. This is a level-design concept where characters must walk, turn, meet and play, not a tightly furnished interior-design dollhouse.

MOST IMPORTANT: create clearly visible LARGE, CONNECTED EMPTY FLOOR AREAS and wide routes through ALL spaces. About half of the usable interior floor should be unobstructed walking/activity floor. Keep normal-size furnishings and normal-size characters; enlarge the house itself, NEVER shrink people to fake clearance. The living room must feel approximately twice as spacious as the reference. Give every bedroom/study/bathroom visible standing and turning floor.

SPATIAL ORGANIZATION:
- Front-left is a generous entrance foyer with only ONE narrow wall-mounted shoe cabinet, ONE small shoe bench and simple hooks; leave a broad empty floor around the entry and a WIDE opening into the living room.
- Center/front is a large, welcoming living room. Put a modest three-seat sage sofa against the left side of this living zone, with ONE small coffee table and ONE compact rug contained in the seating corner. Leave a LARGE CONTINUOUS OPEN PLAY/ACTIVITY AREA in the center, at least about 4 by 4 meters in design intent. The seating cluster does NOT fill the living room. Remove the armchair, ottoman, cabinet behind the sofa, tall floor plants on circulation paths and excess baskets. Retain only one low storage shelf against a perimeter wall, a family photo and a few books.
- Right side: dining table and four chairs in its OWN generous bay, with at least 1.4 m clear circulation even behind pulled-out chairs. Open kitchen directly behind with counters only along exterior walls, a very broad unobstructed work floor, no island obstructing routes. Don't use a giant dining table.
- Rear/left: actual bedroom, study and bathroom, each a larger properly enclosed room with connected continuous full-height partitions. The bedroom has a normal 1.6 by 2 m bed, a slim wall wardrobe and clear walking space around bed and entrance. The study has just a wall desk and narrow bookcase leaving a large clear floor. Bathroom has shower, WC and sink around the perimeter with a generous central standing area.
- A WIDE short recessed private vestibule connects the three private rooms: bedroom door on the left return wall, study door at the recessed back, bathroom door on the right return wall, on DIFFERENT WALL PLANES. Widen this vestibule substantially. Doors are embedded in connected full-height walls with actual solid wall above the lintel. No freestanding doors, no detached wall fragments, no row of three door props. Door openings approximately 1.6 m clear in design intent and open into rooms without blocking the passage.
- Right-front balcony is a generous usable sunny room extension with wide sliding access, a compact wall-side laundry rack and only two small pots along the outer edge; keep most of its floor clear.
- The whole route ENTRY -> LIVING -> DINING/KITCHEN and LIVING -> PRIVATE ROOMS is obvious, direct and unobstructed, minimum approximately 2.4 m wide in the main route, approximately 1.4 m at secondary furniture clearances. Corners and door approaches must have room to turn. Do not depict these as colored paths.

SCALE EVIDENCE: add exactly TWO appealing stylized child game avatars at NORMAL GAME SCALE, about 1.5 m tall compared with roughly 2.6 m wall height and ordinary furniture. One girl with a ponytail and yellow top and one child in a blue top. They stand/walk comfortably SIDE BY SIDE in the central open circulation area with ample empty floor on BOTH outer sides. They must be large enough relative to the sofa and doors to honestly communicate walkability, not tiny decorative miniatures. No additional people.

VIEW: wide landscape orthographic/isometric 3D cutaway, approximately 50 degrees downward, showing the complete larger home on a thin slab. All rooms visible with understandable furniture placement. Roof removed, only front exterior walls cut low; private room partitions remain continuous and above door height. Keep full-house framing with comfortable margins.
STYLE: polished stylized life-simulation game render, soft rounded bevels, controlled visible wood grain and textile weave, warm daylight, grounded contact shadows and quiet domestic warmth. Clear functional silhouettes at game scale. Moderately furnished and cozy but unmistakably spacious. Light neutral studio background.
No words, numbers, dimension lines, arrows, colored navigation overlays, HUD, labels, logos, watermark, panel borders or collage. ONE finished full-frame concept image.
