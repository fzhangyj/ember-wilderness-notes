extends Node2D
## Deterministic, layered vector landscape. No downloaded assets are needed.

var game: Node2D
var camera := Vector2.ZERO
var grasses: Array = []
var trees: Array = []
var flowers: Array = []
var terrain: Array = []
var pebbles: Array = []
var font: SystemFont
var elapsed := 0.0
const GREEN = Color("718366")
const INK = Color("263e35")

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 712493
	for i in range(145):
		var p := Vector2(rng.randf_range(60,2350),rng.randf_range(100,1800))
		if p.x > game.river_x(p.y) - 45 and p.x < game.river_x(p.y) + 230: continue
		if p.distance_to(game.CAMP) < 200: continue
		var close := false
		for n in game.nodes:
			if p.distance_to(n.pos) < 60: close = true; break
		if close: continue
		trees.append({"pos":p,"s":rng.randf_range(0.75,1.55),"kind":rng.randi_range(0,3),"tint":rng.randf_range(-0.07,0.07)})
	for i in range(1800):
		var p := Vector2(rng.randf_range(0,2380),rng.randf_range(0,1820))
		grasses.append({"p":p,"s":rng.randf_range(2,6),"color":Color("8b9a71") if i % 3 == 0 else Color("657c5b")})
	for i in range(140):
		flowers.append(Vector2(rng.randf_range(100,2250),rng.randf_range(180,1700)))
	for i in range(100):
		terrain.append({"p":Vector2(rng.randf_range(0,2380),rng.randf_range(0,1820)),"size":Vector2(rng.randf_range(70,210),rng.randf_range(40,100)),"c":Color("6d8060") if i % 2 else Color("778769")})
	for i in range(180):
		pebbles.append({"p":Vector2(rng.randf_range(80,2300),rng.randf_range(100,1790)),"s":rng.randf_range(1.5,4)})

func _process(delta: float) -> void:
	if game.is_playing(): elapsed += delta
	camera = game.player_pos - Vector2(737, 478)
	camera.x = clampf(camera.x, 10, 1100)
	camera.y = clampf(camera.y, 0, 980)

func to_world(p: Vector2) -> Vector2: return p + camera
func on_screen(p: Vector2, margin: float = 150.0) -> bool:
	return Rect2(camera - Vector2.ONE * margin,Vector2(1440,900) + Vector2.ONE * margin * 2).has_point(p)

func ellipse(p: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var angle := TAU * i / 24.0
		points.append(p + Vector2(cos(angle),sin(angle)) * radius)
	draw_colored_polygon(points, color)

func poly(points: Array, color: Color, origin: Vector2 = Vector2.ZERO, scale_factor: float = 1.0) -> void:
	var vertices := PackedVector2Array()
	for p in points: vertices.append(origin + p * scale_factor)
	draw_colored_polygon(vertices,color)

func _draw() -> void:
	if not game: return
	draw_set_transform(-camera)
	draw_rect(Rect2(Vector2.ZERO,game.WORLD_SIZE),GREEN)
	for t in terrain:
		if on_screen(t.p,250): ellipse(t.p,t.size,t.c)
	# The winding river has separate silt, shore, water and reflected-light layers.
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var shore := PackedVector2Array()
	for i in range(47):
		var y := i * 40.0 - 20
		var x: float = game.river_x(y)
		left.append(Vector2(x,y))
		right.insert(0,Vector2(x + 150 + sin(y * 0.008) * 15,y))
		shore.append(Vector2(x-28,y))
	var bank := shore.duplicate()
	bank.append_array(right)
	draw_colored_polygon(bank,Color("a7a283"))
	var water := left.duplicate()
	water.append_array(right)
	draw_colored_polygon(water,Color("689793"))
	draw_polyline(left,Color("acd0b2"),4,true)
	for i in range(82):
		var y := fmod(i * 29.0 + elapsed * 7,1850.0)
		var x: float = game.river_x(y) + 20 + fmod(i * 37.0,110.0)
		if on_screen(Vector2(x,y),20):
			draw_line(Vector2(x,y),Vector2(x+13+sin(i)*9,y-2),Color(0.79,0.89,0.80,0.32),1.3,true)
	# Footpath connects the initial camp, forest and water.
	var path := PackedVector2Array([Vector2(550,1580),Vector2(710,1390),Vector2(940,1100),Vector2(1020,920),Vector2(1150,850),Vector2(1280,830),Vector2(1460,780)])
	draw_polyline(path,Color("83896a"),65,true)
	draw_polyline(path,Color("8e9070"),40,true)
	ellipse(game.CAMP+Vector2(0,35),Vector2(190,135),Color("8c9170"))
	ellipse(game.CAMP+Vector2(15,25),Vector2(143,103),Color("969777"))
	for g in grasses:
		if not on_screen(g.p,5): continue
		if g.p.x > game.river_x(g.p.y) - 23 and g.p.x < game.river_x(g.p.y) + 174: continue
		if g.p.distance_to(game.CAMP) < 110: continue
		var p: Vector2 = g.p
		draw_line(p,p+Vector2(-2,-g.s),g.color,1.0)
		if int(p.x) % 2 == 0: draw_line(p,p+Vector2(3,-g.s * 0.75),g.color,1.0)
	for p in pebbles:
		if on_screen(p.p,5) and p.p.x < game.river_x(p.p.y) - 40:
			ellipse(p.p,Vector2(p.s,p.s * 0.6),Color("91977c"))
	for p in flowers:
		if on_screen(p,5) and p.x < game.river_x(p.y) - 45 and p.distance_to(game.CAMP) > 170:
			draw_line(p,p+Vector2(0,-5),Color("546c50"),1.2)
			draw_circle(p+Vector2(0,-5),1.8,Color("d0c594"))
	# Objects and characters share a Y sort so walking behind a tree feels physical.
	var objects: Array = []
	for t in trees:
		if on_screen(t.pos): objects.append({"y":t.pos.y,"type":"tree","data":t})
	for i in range(game.nodes.size()):
		var n: Dictionary = game.nodes[i]
		if on_screen(n.pos): objects.append({"y":n.pos.y,"type":"resource","data":n,"idx":i})
	objects.append({"y":game.CAMP.y-10,"type":"shelter"})
	objects.append({"y":game.CAMP.y+45,"type":"fire"})
	objects.append({"y":game.player_pos.y,"type":"player"})
	if game.active_event == "wolf": objects.append({"y":game.wolf_pos.y,"type":"wolf"})
	objects.sort_custom(func(a,b): return a.y < b.y)
	for obj in objects:
		match obj.type:
			"tree": draw_tree(obj.data)
			"resource": draw_resource(obj.data,obj.idx)
			"shelter": draw_shelter()
			"fire": draw_fire()
			"player": draw_player()
			"wolf": draw_wolf()
	# Sparse leaves drift with the wind and give the still forest some life.
	for i in range(12):
		var p := Vector2(fmod(elapsed*12+i*183,1500),fmod(elapsed*5+i*97,950)) + camera
		draw_line(p,p+Vector2(4,2),Color(0.83,0.82,0.60,0.35),1.7,true)
	if game.walking:
		draw_arc(game.target,9,0,TAU,32,Color(0.95,0.88,0.65,0.7),1.5,true)
		draw_circle(game.target,2.2,Color("dfcd98"))
	# The compass and HUD stay crisp while the landscape darkens with the day.
	draw_set_transform(Vector2.ZERO)
	var darkness := 0.0
	var h: float = fmod(game.minutes,1440) / 60
	if h >= 18: darkness = clampf((h - 18) / 3,0,1) * 0.48
	elif h < 6: darkness = 0.48 * (1-clampf((h-5)/1,0,1))
	if darkness > 0:
		draw_rect(Rect2(0,0,1440,900),Color(0.045,0.105,0.16,darkness))
		if game.fire_lit(): draw_glow(game.CAMP + Vector2(40,33)-camera,105)
		if game.torch_minutes > 0: draw_glow(game.player_pos+Vector2(23,-37)-camera,70)
	if game.raining():
		draw_rect(Rect2(0,0,1440,900),Color(0.17,0.25,0.26,0.16))
		for i in range(160):
			var x := fmod(i*131.7-elapsed*190+50000,1480)
			var y := fmod(i*53.1+elapsed*510,940)
			draw_line(Vector2(x,y),Vector2(x-6,y+17),Color(0.76,0.86,0.84,0.22),1.1,true)
	# A restrained edge shade anchors the field notebook panels.
	for i in range(12):
		var alpha := 0.007 + i*0.0005
		draw_rect(Rect2(i*3,i*3,1440-i*6,900-i*6),Color(0.07,0.12,0.09,alpha),false,6)

func draw_tree(t: Dictionary) -> void:
	var p: Vector2 = t.pos
	var s: float = t.s
	var alpha := 0.48 if game.player_pos.y < p.y+12 and game.player_pos.distance_to(p+Vector2(0,-45*s)) < 65*s else 1.0
	ellipse(p+Vector2(15,4)*s,Vector2(34,13)*s,Color(0.16,0.25,0.20,0.20*alpha))
	draw_line(p+Vector2(0,4)*s,p+Vector2(0,-40)*s,Color(0.32,0.29,0.21,alpha),7*s)
	if t.kind < 3:
		var shade := Color("344f41").lightened(t.tint)
		shade.a = alpha
		poly([Vector2(-41,-19),Vector2(-28,-45),Vector2(-32,-45),Vector2(-19,-65),Vector2(-22,-65),Vector2(0,-108),Vector2(21,-65),Vector2(17,-64),Vector2(31,-44),Vector2(26,-43),Vector2(40,-18),Vector2(10,-11),Vector2(0,-15),Vector2(-13,-10)],shade,p,s)
		var light := Color("536e4e").lightened(t.tint)
		light.a = alpha
		poly([Vector2(0,-103),Vector2(-21,-62),Vector2(-7,-64),Vector2(-28,-37),Vector2(-9,-40),Vector2(-32,-20),Vector2(0,-23)],light,p,s)
		var mid := Color("405e45").lightened(t.tint)
		mid.a = alpha
		poly([Vector2(1,-77),Vector2(19,-49),Vector2(7,-47),Vector2(27,-23),Vector2(2,-18)],mid,p,s)
	else:
		var dark := Color("496344").lightened(t.tint)
		dark.a = alpha
		ellipse(p+Vector2(0,-46)*s,Vector2(40,36)*s,dark)
		var light := Color("758451").lightened(t.tint)
		light.a = alpha
		ellipse(p+Vector2(-14,-60)*s,Vector2(27,25)*s,light)
		ellipse(p+Vector2(15,-64)*s,Vector2(28,27)*s,Color(0.39+t.tint,0.47+t.tint,0.28,alpha))
		ellipse(p+Vector2(-3,-80)*s,Vector2(23,19)*s,light)

func draw_resource(n: Dictionary, idx: int) -> void:
	var p: Vector2 = n.pos
	if n.amount <= 0:
		ellipse(p,Vector2(12,4),Color(0.28,0.34,0.24,0.30))
		return
	var nearby: bool = idx == game.nearest_node()
	if nearby:
		ellipse(p+Vector2(0,3),Vector2(36,17),Color(0.91,0.83,0.53,0.15))
		draw_arc(p+Vector2(0,-3),32,0,TAU,40,Color(0.93,0.86,0.62,0.65),1.4,true)
	ellipse(p+Vector2(6,3),Vector2(20,8),Color(0.22,0.30,0.22,0.20))
	match n.type:
		"wood":
			for i in range(3):
				var q := p+Vector2(i*4-8,-i*6)
				draw_line(q+Vector2(-16,1),q+Vector2(18,-11),Color("655442"),9,true)
				draw_line(q+Vector2(-16,-2),q+Vector2(18,-13),Color("a0885f"),3,true)
				draw_circle(q+Vector2(-17,0),4.5,Color("c0a779"))
				draw_circle(q+Vector2(-17,0),2.2,Color("8a7150"))
		"stone":
			poly([Vector2(-22,0),Vector2(-25,-14),Vector2(-9,-30),Vector2(9,-28),Vector2(22,-14),Vector2(17,4),Vector2(0,8)],Color("7b827c"),p)
			poly([Vector2(-25,-14),Vector2(-9,-30),Vector2(9,-28),Vector2(5,-11)],Color("b6b7a3"),p)
			poly([Vector2(5,-11),Vector2(9,-28),Vector2(22,-14),Vector2(17,4)],Color("929b8b"),p)
			draw_line(p+Vector2(-20,-10),p+Vector2(-4,-8),Color("a2ac95"),1.5,true)
		"fiber", "herb":
			var shade := Color("b6b87a") if n.type == "fiber" else Color("7ba17b")
			for i in range(7):
				var angle := -PI+float(i)/6.0*PI
				var tip := Vector2(cos(angle)*23,sin(angle)*32-5)
				poly([Vector2(-2,2),tip,tip*0.45+Vector2(5,0)],shade,p)
				draw_line(p,p+tip,Color("506d49"),1.2,true)
				if n.type == "herb" and i % 2:
					draw_circle(p+tip,3.2,Color("c6cca2"))
		"berry":
			for offset in [Vector2(-12,-10),Vector2(10,-13),Vector2(0,-24)]:
				ellipse(p+offset,Vector2(16,13),Color("4b6a47"))
				ellipse(p+offset+Vector2(-3,-4),Vector2(11,8),Color("657d50"))
			for offset in [Vector2(-14,-15),Vector2(7,-7),Vector2(1,-25),Vector2(12,-23),Vector2(-4,-12)]:
				draw_circle(p+offset,3.5,Color("b76654"))
				draw_circle(p+offset+Vector2(-1,-1),1,Color("d9a085"))
		"tuber":
			for i in range(4):
				ellipse(p+Vector2(i*7-12,-3+sin(i)*4),Vector2(7,4),Color("a78a61"))
				poly([Vector2(i*4-8,0),Vector2(i*9-19,-23),Vector2(i*4,-17)],Color("80905a"),p)
		"raw_water":
			for i in range(3):
				draw_arc(p+Vector2(0,-8),12+i*7,0.2,PI-0.2,20,Color(0.79,0.91,0.82,0.8-i*0.2),1.5,true)
	if not nearby:
		draw_circle(p+Vector2(0,-43 if n.type == "stone" else -39),2,Color(0.9,0.86,0.68,0.65))
	else:
		var label: String = "取水" if n.type == "raw_water" else game.ITEM_NAMES[n.type]
		var width := font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
		var box := Rect2(p+Vector2(-width/2-10,-73),Vector2(width+20,28))
		draw_style_box(box_style(Color("253d32"),6),box)
		draw_string(font,p+Vector2(-width/2,-53),label,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("eee9d0"))
		poly([Vector2(-4,-45),Vector2(4,-45),Vector2(0,-40)],Color("253d32"),p)

func box_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style

func draw_shelter() -> void:
	var p: Vector2 = game.CAMP + Vector2(-75,-23)
	if not game.structures.shelter:
		var outline := PackedVector2Array([p+Vector2(-57,5),p+Vector2(-3,-73),p+Vector2(63,-50),p+Vector2(85,15),p+Vector2(-57,5)])
		for i in range(outline.size()-1):
			draw_dashed_line(outline[i],outline[i+1],Color(0.85,0.82,0.61,0.40),1.5,5,true)
		draw_string(font,p+Vector2(-38,30),"庇护所营址",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("d3cfad"))
		return
	ellipse(p+Vector2(25,14),Vector2(85,24),Color(0.22,0.28,0.19,0.25))
	poly([Vector2(-65,8),Vector2(-8,-76),Vector2(44,10)],Color("574e36"),p)
	poly([Vector2(-8,-76),Vector2(68,-57),Vector2(93,21),Vector2(44,10)],Color("87905b") if game.structures.reinforce else Color("7b8555"),p)
	poly([Vector2(-49,6),Vector2(-8,-52),Vector2(27,8)],Color("343e2e"),p)
	for i in range(8):
		var a := p+Vector2(-5+i*10,-74+i*2.5)
		var b := p+Vector2(45+i*6,10+i*1.4)
		draw_line(a,b,Color("a5ab74"),3,true)
	for j in range(4):
		var a := p+Vector2(3+j*10,-58+j*17)
		var b := p+Vector2(73+j*5,-41+j*18)
		draw_line(a,b,Color("636e47"),5,true)
	for edge in [[Vector2(-65,13),Vector2(-8,-78)],[Vector2(-8,-78),Vector2(44,14)],[Vector2(-8,-78),Vector2(68,-59)],[Vector2(68,-59),Vector2(93,23)]]:
		draw_line(p+edge[0],p+edge[1],Color("b49a6a"),5,true)
	if game.structures.reinforce:
		draw_line(p+Vector2(17,-45),p+Vector2(81,-27),Color("c5b887"),3,true)
		draw_line(p+Vector2(32,-19),p+Vector2(86,0),Color("c5b887"),3,true)
	# Bed of leaves under the lean-to.
	ellipse(p+Vector2(-10,5),Vector2(31,8),Color("969363"))

func draw_fire() -> void:
	var p: Vector2 = game.CAMP+Vector2(40,33)
	ellipse(p+Vector2(2,8),Vector2(45,24),Color(0.34,0.34,0.23,0.25))
	if not game.structures.fire:
		for i in range(8):
			var a := TAU*i/8.0
			draw_arc(p,27,a,a+0.35,6,Color(0.89,0.84,0.66,0.5),1.5,true)
		# A stone marker shows where a campfire will be built.
		draw_line(p+Vector2(-11,4),p+Vector2(11,-6),Color("71694c"),5,true)
		draw_line(p+Vector2(12,4),p+Vector2(-10,-6),Color("71694c"),5,true)
		return
	if game.fire_lit():
		for i in range(4): ellipse(p,Vector2(62-i*10,39-i*6),Color(1,0.68,0.29,0.018+i*0.012))
	ellipse(p,Vector2(26,15),Color("514b37"))
	for i in range(9):
		var a := TAU*i/9.0
		var r := p+Vector2(cos(a)*28,sin(a)*17)
		ellipse(r,Vector2(7,5),Color("9ba08c") if i<5 else Color("777e6c"))
	draw_line(p+Vector2(-17,5),p+Vector2(14,-5),Color("655239"),7,true)
	draw_line(p+Vector2(16,6),p+Vector2(-14,-7),Color("987146"),7,true)
	if game.fire_lit():
		var flicker := sin(elapsed*9)*3
		poly([Vector2(-13,0),Vector2(-12,-17),Vector2(-5,-12),Vector2(-1,-39-flicker),Vector2(7,-25),Vector2(11,-12),Vector2(15,-18),Vector2(14,1),Vector2(0,6)],Color("e5a155"),p)
		poly([Vector2(-6,0),Vector2(-5,-13),Vector2(2,-24+flicker),Vector2(7,-8),Vector2(6,2)],Color("f3d389"),p)
		for i in range(7):
			var up := fmod(elapsed*20+i*14,100.0)
			var at := p+Vector2(sin(up*0.08+i)*9,-30-up)
			draw_circle(at,1.4,Color(0.91,0.72,0.43,(1-up/100)*0.6))
		for i in range(4):
			var up := fmod(elapsed*12+i*22,95.0)
			ellipse(p+Vector2(sin(up*0.027)*17,-45-up),Vector2(7+up*0.10,5+up*0.1),Color(0.85,0.84,0.71,(1-up/95)*0.06))

func draw_player() -> void:
	var p: Vector2 = game.player_pos
	var bob := sin(game.walk_phase)*1.6
	ellipse(p+Vector2(3,4),Vector2(17,7),Color(0.16,0.24,0.19,0.30))
	if game.interaction_flash > 0: draw_arc(p,28+(1-game.interaction_flash)*15,0,TAU,36,Color(0.91,0.83,0.55,game.interaction_flash),2,true)
	var step := sin(game.walk_phase)*4
	draw_line(p+Vector2(-5,-12),p+Vector2(-6+step,0),Color("39453c"),7,true)
	draw_line(p+Vector2(5,-12),p+Vector2(6-step,0),Color("39453c"),7,true)
	poly([Vector2(-10,-32+bob),Vector2(8,-33+bob),Vector2(14,-12),Vector2(0,-8),Vector2(-14,-12)],Color("c3a572"),p)
	poly([Vector2(-10,-32+bob),Vector2(-1,-30+bob),Vector2(0,-8),Vector2(-14,-12)],Color("a0845b"),p)
	draw_line(p+Vector2(-9,-28+bob),p+Vector2(-15,-16+bob),Color("d0ac7e"),5,true)
	draw_line(p+Vector2(9,-28+bob),p+Vector2(17,-20+bob),Color("d0ac7e"),5,true)
	# The bedroll and strap make the tiny wanderer legible on the meadow.
	draw_style_box(box_style(Color("5a6450"),3),Rect2(p+Vector2(-8,-29+bob),Vector2(13,18)))
	draw_line(p+Vector2(-5,-31+bob),p+Vector2(7,-10),Color("554d39"),2,true)
	draw_circle(p+Vector2(0,-39+bob),9,Color("dab990"))
	poly([Vector2(-9,-39+bob),Vector2(-7,-49+bob),Vector2(3,-51+bob),Vector2(9,-43+bob),Vector2(5,-39+bob),Vector2(0,-43+bob)],Color("3c4034"),p)
	if game.facing.y > 0:
		draw_circle(p+Vector2(4,-39+bob),1,Color("394338"))
	draw_line(p+Vector2(19,-34+bob),p+Vector2(16,1),Color("766449"),2.5,true)
	if game.equipment.spear:
		poly([Vector2(18,-34+bob),Vector2(17,-50+bob),Vector2(24,-40+bob)],Color("b0b7a1"),p)
	if game.torch_minutes > 0:
		draw_line(p+Vector2(17,-20+bob),p+Vector2(23,-43+bob),Color("8b6b43"),4,true)
		poly([Vector2(18,-43+bob),Vector2(20,-59+sin(elapsed*8)*3),Vector2(27,-47),Vector2(24,-40)],Color("edb166"),p)
		poly([Vector2(21,-44),Vector2(22,-52),Vector2(25,-44)],Color("f9d890"),p)
	# Player locator ring, kept subtle rather than a large floating marker.
	draw_arc(p+Vector2(0,4),20,0.2,PI-0.2,24,Color(0.91,0.85,0.65,0.6),1.2,true)

func draw_wolf() -> void:
	var p: Vector2 = game.wolf_pos
	if not on_screen(p): return
	ellipse(p+Vector2(5,4),Vector2(30,9),Color(0.16,0.23,0.19,0.3))
	poly([Vector2(-21,-17),Vector2(-14,-26),Vector2(12,-26),Vector2(28,-14),Vector2(16,-10),Vector2(-14,-11)],Color("878d81"),p)
	poly([Vector2(-27,-18),Vector2(-28,-35),Vector2(-21,-29),Vector2(-15,-34),Vector2(-9,-22),Vector2(-16,-15),Vector2(-32,-14)],Color("a0a496"),p)
	for x in [-17,-9,10,18]: draw_line(p+Vector2(x,-14),p+Vector2(x-3,2),Color("707b70"),4,true)
	draw_line(p+Vector2(24,-19),p+Vector2(36,-11),Color("899082"),6,true)
	draw_circle(p+Vector2(-23,-23),1.8,Color("e4ba6c"))
	draw_string(font,p+Vector2(-20,-48),"野狼",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("e9cc99"))

func draw_glow(p: Vector2, size: float) -> void:
	for i in range(10):
		draw_circle(p,size*(1-i*0.085),Color(0.99,0.65,0.26,0.015))
