extends Control
## Object-specific observation toys. All coordinates are normalized to this canvas.
signal operation_requested(choice: int, placement: Vector2)
const Content = preload("res://ui/memory_story_content.gd")
const FONT = preload("res://assets/fonts/IslandSans.otf")
var letter := "A"
var step := 0
var choice := 0
var placement := Vector2(0.5,0.5)
var reduced := false
var enabled := true
var clock := 0.0
var dragging := false
var drag_point := Vector2.ZERO
var textures: Dictionary = {}
var semantic_state := ""
var suspended := false
var view_angle := 0.0
var drag_start := Vector2.ZERO
var complete_drag := false
const PICK_AREAS := {
	"C":Rect2(15,155,105,110),"I":Rect2(40,45,120,130),"K":Rect2(35,70,100,170),
	"Q":Rect2(25,80,135,140),"S":Rect2(10,80,145,150),"T":Rect2(410,10,180,150),
	"Y":Rect2(20,190,100,100),"Z":Rect2(25,55,165,170)
}
const DROP_AREAS := {
	"C":Rect2(125,20,350,270),"I":Rect2(220,90,160,200),"K":Rect2(240,130,140,160),
	"Q":Rect2(275,135,135,135),"S":Rect2(230,35,240,240),"T":Rect2(310,80,220,190),
	"Y":Rect2(350,50,220,220),"Z":Rect2(200,55,360,230)
}

func _ready() -> void:
	custom_minimum_size = Vector2(260,225)
	size_flags_vertical = SIZE_EXPAND_FILL
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	clip_contents = true

func _process(delta: float) -> void:
	if suspended or not is_visible_in_tree(): return
	clock += delta
	queue_redraw()

func _texture(key: String) -> Texture2D:
	if not textures.has(key):
		textures[key] = Content.icon(key,2.0) if key.length()==1 else load("res://assets/learning/story_props_v3/"+key+".png")
	return textures[key]

func _art(key: String, rect: Rect2, tint: Color = Color.WHITE, region: Rect2 = Rect2()) -> void:
	var tex := _texture(key)
	if not tex: return
	if region.size==Vector2.ZERO:
		var ratio: float = minf(rect.size.x/tex.get_width(),rect.size.y/tex.get_height())
		var extent := tex.get_size()*ratio
		draw_texture_rect(tex,Rect2(rect.get_center()-extent/2,extent),false,tint)
	else:
		draw_texture_rect_region(tex,rect,Rect2(region.position*tex.get_size(),region.size*tex.get_size()),tint)

func _label(value: String, point: Vector2, font_size: int = 21, color: Color = Color("31463e")) -> void:
	draw_string(FONT,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _box(rect: Rect2, color: Color, border: Color = Color("9eaf97")) -> void:
	draw_style_box(_style(color,border),rect)

func _style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	return style

func _draw() -> void:
	if size.x<=0 or size.y<=0: return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(600,320))
	_box(Rect2(0,0,600,320),Color("edf0e2"))
	semantic_state = letter+":"+str(step)+":"+str(choice)
	var main := Rect2(130,25,340,260)
	match letter:
		"A":
			_art("A",Rect2(20,20,250,260))
			_box(Rect2(340,180,190,100),Color("d5ac78"))
			draw_arc(Vector2(435,180),65,PI,TAU,40,Color("a87c4f"),8)
			if step>=2: _art("A",Rect2(385,160,100,100))
		"B","M":
			var crop := Rect2(0,0,0.55,1) if letter=="B" else Rect2(0,0,1,0.57)
			if step==2: crop = Rect2(0.45,0,0.55,1) if letter=="B" else Rect2(0,0.48,1,0.52)
			_art(letter,main,Color.WHITE,crop if step in [1,2] else Rect2())
			_label(("船头" if step==1 else "船尾") if letter=="B" else ("菌盖" if step==1 else "菌柄"),Vector2(25,45)) if step in [1,2] else _label("完整的伙伴",Vector2(25,45))
		"C":
			_art("C",main)
			_art("strawberry",Rect2((Vector2(135,65)+placement*Vector2(310,130)) if step>=2 else Vector2(25,170),Vector2(66,66)))
			if step==1: _label("选好了莓果 · 点蛋糕任意位置",Vector2(25,305),18)
		"D":
			_art("D",main)
			if step>0:
				for ring: int in 3: draw_arc(Vector2(300,125),50+ring*24+(0 if reduced else sin(clock*3)*5),0,TAU,64,Color("d59b46"),3)
		"E":
			if step==0:
				_box(Rect2(140,35,320,250),Color("b5c8bd")); _label("点这里揭开观察遮片",Vector2(185,170))
			else:
				_art("E",main)
				_label("完整蛋壳 · 光滑的弧面",Vector2(185,300),19)
		"F":
			_art("F",main,Color("ffb8c9") if choice==0 else Color("fff0a9"))
			_label("粉色花瓣" if choice==0 else "金色花瓣",Vector2(225,305))
		"G":
			var key := "globe-angle" if step>0 or view_angle>0.5 else "globe-front"
			if not textures.has(key): textures[key]=load("res://assets/learning/landmark_views/G-"+("angle" if key=="globe-angle" else "front")+".png")
			draw_texture_rect(textures[key],Rect2(50,10,500,270),false)
			if step>0:
				draw_arc(Vector2(300,150),105,-PI*0.7,PI*0.6,64,Color("497f8e"),4)
				_label("转到另一侧，找到了陆地",Vector2(160,305),19)
		"H":
			draw_circle(Vector2(300,175),60,Color("f1d0ac")); draw_circle(Vector2(280,170),4,Color("31463e")); draw_circle(Vector2(320,170),4,Color("31463e"))
			_box(Rect2(230,235,140,72),Color("d9ad5f"))
			_art("cap" if choice==1 else "H",Rect2(215,35,170,130))
			_label("小岛朋友的帽子预览",Vector2(185,30),19)
		"I":
			if step>=2: _art("I",main)
			else:
				_art("I",Rect2(170,140,260,145.6),Color.WHITE,Rect2(0,0.44,1,0.56))
				_art("I",Rect2(10,45,180,86.4),Color.WHITE,Rect2(0,0,1,0.48))
			if step==1: _label("把冰淇淋球放到蛋筒上",Vector2(160,35),20)
		"J":
			_art("J",Rect2(170,113.4,260,171.6),Color.WHITE,Rect2(0,0.34,1,0.66))
			_art("strawberry",Rect2(267,165,66,66))
			_art("J",Rect2(350,8,260,88.4) if step==1 else Rect2(170,25,260,88.4),Color.WHITE,Rect2(0,0,1,0.34))
			_label("看见罐里的莓果" if step==1 else "盖子已经盖好" if step>=2 else "点罐子打开盖子",Vector2(200,315),18)
		"K":
			_art("K",Rect2(170,25,260,166.4),Color.WHITE,Rect2(0,0,1,0.64))
			_art("K",Rect2(170,191.4,260,93.6) if step>=2 else Rect2(-65,85,260,93.6),Color.WHITE,Rect2(0,0.64,1,0.36))
			if step<2: _label("风筝的长尾巴",Vector2(20,45),19)
		"L":
			if step>0: draw_circle(Vector2(300,145),130,Color("f9e9a6"))
			_art("L",main,Color.WHITE if step>0 else Color("85918e"))
		"N":
			_art("N",main)
			if step>0:
				var frame_center := Vector2(220,100)+placement*Vector2(160,100)
				draw_rect(Rect2(frame_center-Vector2(120,75),Vector2(240,150)),Color("c29443"),false,5)
			_label("只观察，不移动鸟巢",Vector2(190,305),19)
		"O","W":
			_art(letter,Rect2(25,40,250,220)); _art("fish",Rect2(325,40,250,220))
			if step>0: _box(Rect2(35,275,230,32),Color("d3e5bb")); _label("找到今天的伙伴了",Vector2(52,299),19)
		"P":
			_art("P",Rect2(100,20,400,280) if choice==0 else Rect2(200,85,200,180))
			_label("大南瓜" if choice==0 else "小南瓜",Vector2(255,305))
		"Q":
			for y: int in 2:
				for x: int in 3: _box(Rect2(210+x*90,70+y*90,84,84),Color("d9c3d3") if (x+y)%2==0 else Color("d5ddaf"))
			_box(Rect2(300,160,84,84),Color("f4efdf"))
			_art("tablecloth",Rect2(300,160,84,84) if step>=2 else Rect2(40,100,100,100))
			_label("花纹布片把空格补好了" if step>=2 else "把布片补进拼布被的空格",Vector2(155,305),20)
		"R":
			if step>0 and choice==1:
				draw_set_transform(size*Vector2(0.5,0.48),0,size/Vector2(600,320)*Vector2(-0.75,1))
				_art("R",Rect2(-170,-130,340,260))
				draw_set_transform(Vector2.ZERO,0,size/Vector2(600,320))
			elif step>0 and choice==0:
				# A shoulder-shaped mask keeps the body intact while its illustrated arm turns.
				var arm := PackedVector2Array([Vector2(0.60,0.52),Vector2(0.70,0.52),Vector2(0.80,0.68),Vector2(0.80,0.78),Vector2(0.66,0.78),Vector2(0.65,0.65),Vector2(0.61,0.62)])
				var body := PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,0.52),arm[0],arm[6],arm[5],arm[4],Vector2(1,0.78),Vector2(1,1),Vector2(0,1)])
				_texture_polygon("R",body,Vector2(170,25),260)
				var shoulder := Vector2(336.4,168)
				var angle := -1.6 if reduced else -1.6+sin(clock*4)*0.22
				draw_set_transform(shoulder*size/Vector2(600,320),angle,size/Vector2(600,320))
				_texture_polygon("R",arm,Vector2(170,25)-shoulder,260)
				draw_set_transform(Vector2.ZERO,0,size/Vector2(600,320))
			else: _art("R",main)
			if step>0:
				if choice==0:
					_label("机器人挥手：Hello!",Vector2(170,305),20)
				else:
					draw_arc(Vector2(300,260),100,0,PI,40,Color("6998a1"),4); _label("转一转，看看侧面",Vector2(200,35),19)
		"S":
			var points := PackedVector2Array()
			var center := Vector2(350,155)
			for i: int in 10: points.append(center+Vector2(sin(i*PI/5),-cos(i*PI/5))*(95 if i%2==0 else 43))
			points.append(points[0]); draw_polyline(points,Color("c5b888"),3)
			_art("S",Rect2(250,55,200,200) if step>=2 else Rect2(20,95,120,120))
		"T":
			_art("T",Rect2(35,10,310,270))
			_carriage(Vector2(345,150) if step>=2 else Vector2(430,65))
			if step>=2: draw_line(Vector2(320,220),Vector2(350,220),Color("6d6964"),5)
			draw_line(Vector2(45,265),Vector2(555,265),Color("9e947e"),4)
		"U":
			if step>0:
				for i: int in 15: draw_line(Vector2(30+i*38,35+(i%3)*40),Vector2(23+i*38,65+(i%3)*40),Color("7aabc3"),3)
				_art("U",main)
			else:
				draw_texture_rect(_texture("U"),Rect2(278,35,44,250),false)
				_label("晴天收起 · 雨天撑开",Vector2(175,305),20)
		"V":
			if not textures.has("dormant"): textures.dormant = load("res://assets/learning/landmark_views/V-front.png")
			draw_texture_rect(textures.dormant,Rect2(40,20,520,270),false)
			if step>0:
				draw_arc(Vector2(300,92),54,0,TAU,60,Color("e2bc62"),4)
				draw_texture_rect_region(textures.dormant,Rect2(435,45,145,120),Rect2(textures.dormant.get_size()*Vector2(0.35,0.18),textures.dormant.get_size()*Vector2(0.30,0.22)))
			_label("静静的火山口 · 观察，不喷发",Vector2(145,310),19)
		"X":
			for i: int in 7:
				var length := 210-i*20
				_box(Rect2(115+i*50,165-length/2,38,length),Color.from_hsv(float(i)/9,0.35,0.83))
			if step>0: draw_arc(Vector2(134 if step==1 else 434,165),35,0,TAU,50,Color("c29342"),4)
			_label("长音条" if step==1 else "短音条" if step>=2 else "先点最长，再点最短",Vector2(200,305),21)
		"Y":
			_art("Y",Rect2(375,75,170,170))
			var path := PackedVector2Array([Vector2(65,235),Vector2(145,210),Vector2(205,250),Vector2(285,180),Vector2(380,200),Vector2(440,170)])
			draw_polyline(path,Color("ccb7c0"),5)
			if step>=2: draw_polyline(path,Color("be6f94"),8)
			draw_circle(path[0],14,Color("be6f94")); _label("沿线找到毛线团",Vector2(195,40),20)
		"Z":
			_box(Rect2(220,75,320,195),Color("fff6de")); _label("Hello, my friend!",Vector2(250,170),22)
			_art("Z",Rect2(440,90,80,80) if step>=2 else Rect2(40,75,135,135))
			if step>=2: draw_arc(Vector2(465,165),37,0,TAU,48,Color("be7569"),3)
		_:
			_art(letter,main)
	if step==1 and PICK_AREAS.has(letter):
		draw_rect(PICK_AREAS[letter],Color("b78d4e"),false,3)
		draw_rect(DROP_AREAS[letter],Color("91ad83"),false,3)
	if dragging and PICK_AREAS.has(letter) and drag_point.distance_to(drag_start)>0.03:
		var center := drag_point*Vector2(600,320)
		match letter:
			"C": _art("strawberry",Rect2(center-Vector2(40,40),Vector2(80,80)))
			"I": _art("I",Rect2(center-Vector2(80,38.4),Vector2(160,76.8)),Color.WHITE,Rect2(0,0,1,0.48))
			"K","Y": draw_line(center-Vector2(20,50),center+Vector2(20,50),Color("be6f94"),6)
			"Q": _art("tablecloth",Rect2(center-Vector2(45,45),Vector2(90,90)))
			"T": _carriage(center-Vector2(60,40))
			_: _art(letter,Rect2(center-Vector2(50,50),Vector2(100,100)))

func _carriage(origin: Vector2) -> void:
	_box(Rect2(origin,Vector2(125,72)),Color("cfa579"),Color("a57d55"))
	_box(Rect2(origin+Vector2(10,8),Vector2(105,40)),Color("9cb9af"))
	for x: int in [25,100]:
		draw_circle(origin+Vector2(x,78),18,Color("6d817b"))
		draw_circle(origin+Vector2(x,78),7,Color("d9b37f"))

func _texture_polygon(key: String, uv: PackedVector2Array, origin: Vector2, extent: float) -> void:
	var vertices := PackedVector2Array()
	for point: Vector2 in uv: vertices.append(origin+point*extent)
	draw_polygon(vertices,PackedColorArray([Color.WHITE]),uv,_texture(key))

func _gui_input(event: InputEvent) -> void:
	if not enabled or suspended: return
	if event is InputEventMouseMotion and dragging:
		drag_point = event.position/size
		queue_redraw()
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			if step==0 and PICK_AREAS.has(letter) and not (PICK_AREAS[letter] as Rect2).has_point(event.position/size*Vector2(600,320)): return
			dragging = true
			drag_point = event.position/size
			drag_start = drag_point
		else:
			if not dragging: return
			dragging = false
			var point: Vector2 = (event.position/size).clamp(Vector2.ZERO,Vector2.ONE)
			complete_drag = drag_start.distance_to(point)>0.12 and DROP_AREAS.has(letter) and (DROP_AREAS[letter] as Rect2).has_point(point*Vector2(600,320))
			if step==1 and DROP_AREAS.has(letter) and not (DROP_AREAS[letter] as Rect2).has_point(point*Vector2(600,320)): return
			var selected := 1 if point.x>0.5 else 0
			if letter in ["O","W"] and selected!=0: operation_requested.emit(1,point)
			elif letter=="U": operation_requested.emit(1,point)
			elif letter=="X" and not (Rect2(100,45,75,235) if step==0 else Rect2(400,105,75,125)).has_point(point*Vector2(600,320)): return
			else: operation_requested.emit(selected if letter in ["F","H","P","R"] else 0,point)
		accept_event()
