extends Control
## Real focusable Godot controls above a hand-drawn field-journal HUD.

var game: Node2D
var font: SystemFont
var bold: SystemFont
var ui_layer: Control
var content_layer: Control
var modal_layer: Control
var signature := ""
var tick := 0.0
var quick_buttons := {}
const PAPER = Color("eee8d2")
const MUTED = Color("adb49e")
const GOLD = Color("d7b875")
const DARK = Color("20352b")
const LIGHT = Color("35493b")
const GUIDES = [
	{"id":"fire","name":"火，先于黑夜","tag":"生火与保温","body":"游戏中：木材 ×4 + 石块 ×3 可以搭建营火。每次添入 2 份木材，增加 10 小时燃料。\n\n生活常识：干燥引火物比粗木柴更易点燃。火源应远离可燃物，保持通风，离开时彻底熄灭。封闭的棚内不能生火。"},
	{"id":"water","name":"清澈不等于安全","tag":"取水与净水","body":"游戏中：到东侧河岸取生水，回到燃烧的营火旁煮沸。1 份生水与 1 份木材换得 1 份净水。\n\n生活常识：沉淀、沙石过滤只能减少部分杂质，不能可靠杀灭病原体。煮沸可处理常见微生物风险，但不能去除化学污染。"},
	{"id":"shelter","name":"把夜晚挡在外面","tag":"搭建与选址","body":"游戏中：用木材和纤维搭建枝叶庇护所。靠近棚子可避寒，加固后更能抵挡降雨。\n\n生活常识：选择高于水线、排水良好的位置，避开河床、枯枝和落石风险。地面隔潮与挡风同样重要。"},
	{"id":"tools","name":"一块石头的用处","tag":"原始工具","body":"游戏中：石块、木材和纤维可制作石斧。装备后，一次拾木的收获从 3 份增加到 5 份，耗时也更短。\n\n生活常识：工具应握持稳定、连接牢固。劳动时与同伴保持安全距离；急躁和疲劳往往比工具钝更危险。"},
	{"id":"food","name":"认得，才入口","tag":"食物与烹饪","body":"游戏中：红色灌木是已辨认的可食浆果，可以直接食用。野薯需要在营火旁烤熟，恢复更多饱食。\n\n生活常识：不能凭颜色、气味或动物是否食用判断野生植物安全。无法可靠辨认的植物与菌类不要吃。"},
	{"id":"wildlife","name":"给危险留一段距离","tag":"野兽应对","body":"游戏中：狼嚎出现后有 150 分钟准备。回到燃烧的营火旁按 F，或使用火把，可以驱退狼。石矛能减轻防御时的伤害。\n\n现实动物对火的反应并不可靠。保持距离、不接近幼崽、不投喂，并遵循当地野生动物安全指引。"},
	{"id":"weather","name":"读懂风里的消息","tag":"降雨与失温","body":"游戏中：第二天上午会出现降雨预警。加固棚顶、留足干柴，并回到棚子附近，可以减少体温流失。\n\n生活常识：潮湿和风会加速散热。及时避风避雨、换下湿衣、隔离冷地面；持续发抖或意识异常需要尽快求助。"},
	{"id":"care","name":"先照顾好自己","tag":"伤口与休息","body":"游戏中：草药 ×2、纤维 ×2、净水 ×1 可以制作敷料，恢复 25 点生命。营地睡眠恢复体力。\n\n现实中应以清洁水冲洗浅表伤口，使用合适的清洁敷料。不要把不明植物敷进伤口，严重伤口需要专业处理。"}
]
var selected_guide := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC","sans-serif"])
	bold = SystemFont.new()
	bold.font_names = font.font_names
	bold.font_weight = 700
	var theme_resource := Theme.new()
	theme_resource.default_font = font
	theme_resource.default_font_size = 15
	theme = theme_resource
	ui_layer = Control.new()
	ui_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_layer)
	content_layer = Control.new()
	content_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content_layer)
	modal_layer = Control.new()
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_layer)
	build_static()
	refresh(1)

func box(color: Color, radius: int = 8, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	if border.a > 0:
		s.border_color = border
		s.set_border_width_all(1)
	return s

func card(rect: Rect2, color: Color = DARK, border: Color = Color("52624b")) -> void:
	draw_style_box(box(color,9,border),rect)

func txt(text: String, at: Vector2, size: int = 16, color: Color = PAPER, strong: bool = false) -> void:
	draw_string(bold if strong else font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func label(parent: Node, text: String, rect: Rect2, size: int = 15, color: Color = PAPER, wrap: bool = false) -> Label:
	var item := Label.new()
	if wrap: item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.text = text
	item.add_theme_font_size_override("font_size",size)
	item.add_theme_color_override("font_color",color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	item.position = rect.position
	item.size = rect.size
	return item

func button(parent: Node, text: String, rect: Rect2, callback: Callable, primary: bool = false, tip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = tip
	b.add_theme_font_size_override("font_size",14)
	b.add_theme_color_override("font_color",DARK if primary else PAPER)
	b.add_theme_color_override("font_hover_color",DARK if primary else Color.WHITE)
	b.add_theme_color_override("font_pressed_color",DARK if primary else PAPER)
	b.add_theme_color_override("font_disabled_color",Color("87907c"))
	b.add_theme_stylebox_override("normal",box(GOLD if primary else LIGHT,6,Color.TRANSPARENT if primary else Color("5b6b53")))
	b.add_theme_stylebox_override("hover",box(Color("e4c789") if primary else Color("465a46"),6,Color("d7b875")))
	b.add_theme_stylebox_override("pressed",box(Color("bd9f62") if primary else Color("182b22"),6))
	b.add_theme_stylebox_override("disabled",box(Color("2b3e31"),6,Color("46553f")))
	b.add_theme_stylebox_override("focus",box(Color(0,0,0,0),6,GOLD))
	b.pressed.connect(func(): callback.call(); signature = ""; refresh(1))
	parent.add_child(b)
	return b

func blocker(parent: Node, rect: Rect2, color: Color = Color.TRANSPARENT) -> Control:
	var c := ColorRect.new()
	c.position = rect.position
	c.size = rect.size
	c.color = color
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(c)
	return c

func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func build_static() -> void:
	blocker(ui_layer,Rect2(0,0,1440,76))
	blocker(ui_layer,Rect2(24,100,246,416))
	blocker(ui_layer,Rect2(24,536,246,222))
	blocker(ui_layer,Rect2(0,850,1440,50))
	button(ui_layer,"生存手记  J",Rect2(1018,22,126,34),func(): game.modal = "guide")
	button(ui_layer,"操作",Rect2(1154,22,64,34),func(): game.modal = "help")
	button(ui_layer,"声音",Rect2(1228,22,64,34),func(): game.sound.toggle(),false,"开启 / 关闭森林环境音")
	button(ui_layer,"暂停",Rect2(1302,22,104,34),func(): game.pause_game = not game.pause_game)
	quick_buttons.berry = button(ui_layer,"1   浆果",Rect2(437,791,116,44),func(): game.consume("berry"),false,"食用 1 份浆果：饱食 +14，饮水 +3")
	quick_buttons.water = button(ui_layer,"2   饮水",Rect2(563,791,116,44),func(): game.consume("water"),false,"饮用 1 份净水：饮水 +38")
	quick_buttons.torch = button(ui_layer,"3   火把",Rect2(689,791,116,44),func(): game.use_torch(),false,"使用火把，或驱赶附近的狼")
	quick_buttons.meal = button(ui_layer,"4   熟食",Rect2(815,791,116,44),func(): game.consume("meal"),false,"食用烤野薯：饱食 +30，体力 +6")
	button(ui_layer,"E   采集 / 交互",Rect2(609,724,214,44),func(): game.interact(),true)

func refresh(delta: float) -> void:
	tick += delta
	queue_redraw()
	if tick < 0.2: return
	tick = 0
	quick_buttons.berry.text = "1  浆果 ×%d" % game.inventory.berry
	quick_buttons.water.text = "2  饮水 ×%d" % game.inventory.water
	quick_buttons.torch.text = "3  燃烧中" if game.torch_minutes > 0 else "3  火把 ×%d" % game.torches
	quick_buttons.meal.text = "4  熟食 ×%d" % game.inventory.meal
	var next := str([game.panel,game.craft_tab,game.inventory,game.structures,game.equipment,game.torches,game.near_camp(),game.fire_lit(),game.modal,game.pause_game,game.game_over,game.victory,selected_guide,game.learned,game.journal.size(),game.sound.enabled,game.active_event])
	if next != signature:
		signature = next
		build_content()
		build_modal()

func _draw() -> void:
	if not game: return
	# Top rail.
	draw_rect(Rect2(0,0,1440,76),Color("192d25"))
	draw_line(Vector2(0,75),Vector2(1440,75),Color("4b5c46"),1)
	# The mark is a small in-game campfire, not an external icon dependency.
	var p := Vector2(42,40)
	draw_line(p+Vector2(-8,14),p+Vector2(9,5),GOLD,2,true)
	draw_line(p+Vector2(9,14),p+Vector2(-8,5),GOLD,2,true)
	draw_polyline(PackedVector2Array([p+Vector2(-6,3),p+Vector2(-7,-3),p+Vector2(1,-15),p+Vector2(1,-6),p+Vector2(7,-1),p+Vector2(7,4)]),GOLD,2,true)
	txt("余烬",Vector2(64,49),31,PAPER,true)
	draw_line(Vector2(143,25),Vector2(143,52),Color("59644d"),1)
	txt("荒野手记",Vector2(159,37),15,PAPER)
	txt("EMBER",Vector2(160,56),10,MUTED)
	txt("第 %02d 天" % game.day(),Vector2(414,36),18,PAPER,true)
	txt(game.clock_text(),Vector2(415,57),13,MUTED)
	var daylight: float = fmod(game.minutes,1440)/1440.0
	draw_line(Vector2(511,39),Vector2(675,39),Color("5a6850"),2,true)
	for i in range(9): draw_line(Vector2(512+i*20,35),Vector2(512+i*20,43),Color("6c795b"),1)
	draw_circle(Vector2(512+daylight*160,39),5,GOLD)
	txt("晴朗" if not game.raining() else "降雨",Vector2(716,38),16,PAPER)
	txt("%d°C · %s" % [8 if game.is_night() else (12 if game.raining() else 18), "夜间降温" if game.is_night() else "河谷地带"],Vector2(716,58),12,MUTED)
	txt("声音开" if game.sound.enabled else "已静音",Vector2(862,48),12,MUTED)
	# Status notebook.
	card(Rect2(24,100,246,416))
	txt("生存状态",Vector2(44,133),17,PAPER,true)
	txt("状态良好" if minf(game.health,minf(game.thirst,game.warmth)) > 30 else "需要照顾自己",Vector2(44,156),12,MUTED)
	draw_line(Vector2(44,172),Vector2(250,172),Color("495c44"),1)
	var stats := [["生命",game.health,Color("b48372")],["饱食",game.hunger,Color("c8af73")],["饮水",game.thirst,Color("83aaa4")],["体力",game.energy,Color("b1bd82")],["保暖",game.warmth,Color("cd9e6e")]]
	for i in range(stats.size()):
		var y := 202+i*58
		txt(stats[i][0],Vector2(45,y),14,PAPER)
		txt("%d" % int(stats[i][1]),Vector2(210,y),14,PAPER,true)
		draw_style_box(box(Color("435440"),3),Rect2(45,y+12,202,5))
		if stats[i][1] > 0: draw_style_box(box(stats[i][2],3),Rect2(45,y+12,202*stats[i][1]/100.0,5))
	txt("脚步慢一点，活得久一点。",Vector2(44,494),12,MUTED)
	# Survival milestones.
	card(Rect2(24,536,246,222))
	txt("活过三个日夜",Vector2(44,570),17,PAPER,true)
	txt("从零开始，留下生存的痕迹。",Vector2(44,595),12,MUTED)
	var goals := [["收集第一批物资",game.total_gathered>=6],["在营地点起火",game.structures.fire],["搭建枝叶庇护所",game.structures.shelter],["学会煮沸净水","water" in game.learned and game.structures.fire]]
	for i in range(4):
		var y := 622+i*29
		draw_arc(Vector2(51,y-4),6,0,TAU,18,GOLD if goals[i][1] else Color("657253"),1.2,true)
		if goals[i][1]: draw_circle(Vector2(51,y-4),3,GOLD)
		txt(goals[i][0],Vector2(68,y),13,PAPER if goals[i][1] else MUTED)
	# Compass.
	txt("N",Vector2(721,113),13,PAPER,true)
	draw_line(Vector2(726,123),Vector2(726,142),PAPER,1.3,true)
	draw_colored_polygon(PackedVector2Array([Vector2(722,131),Vector2(726,124),Vector2(730,131)]),PAPER)
	draw_line(Vector2(691,145),Vector2(761,145),Color(0.90,0.88,0.74,0.4),1)
	for i in range(7): draw_line(Vector2(696+i*10,142),Vector2(696+i*10,148),Color(0.90,0.88,0.74,0.4),1)
	# Camp location label, attached to the landscape.
	var cp: Vector2 = game.CAMP - game.world.camera
	if cp.x > 300 and cp.x < 1110 and cp.y > 245 and cp.y < 660:
		txt("高 地 营 地",cp+Vector2(-49,-128),13,Color("e3dec0"))
		draw_line(cp+Vector2(-22,-113),cp+Vector2(38,-113),Color(0.87,0.83,0.63,0.45),1)
	# Active event has a visible timer and a real actionable control in content_layer.
	if game.active_event == "wolf":
		card(Rect2(398,171,636,83),Color("4c4030"),Color("b79663"))
		txt("林间有狼出没",Vector2(419,201),16,Color("f1d295"),true)
		txt("约 %d 分钟后靠近。回到营火旁，或举起火把。" % maxi(0,int(game.event_deadline-game.minutes)),Vector2(419,229),13,PAPER)
	elif game.raining():
		card(Rect2(449,171,540,63),Color("2d4440"),Color("688b7c"))
		txt("河谷正在降雨 · 靠近庇护所和营火保暖",Vector2(470,208),14,PAPER)
	elif "rain_warning" in game.event_history and not "rain" in game.event_history:
		card(Rect2(449,171,540,63),Color("3b4838"),Color("7f8b66"))
		txt("乌云渐近 · 中午降雨前加固棚顶、准备干柴",Vector2(470,208),14,PAPER)
	# World location and remaining time.
	var location := "高地营地" if game.near_camp() else ("河岸浅滩" if game.player_pos.x > 1310 else "松针林地")
	txt(location,Vector2(299,123),15,PAPER,true)
	txt("探索 · 采集 · 安顿",Vector2(299,145),11,Color("d1d3b8"))
	var elapsed_hours := maxi(0,int((game.minutes-480)/60))
	txt("已生存  %02d 小时" % elapsed_hours,Vector2(298,812),13,PAPER)
	if game.near_camp() and game.fire_lit():
		txt("营火余量  %d 小时" % int(game.fire_fuel/60),Vector2(968,812),12,PAPER)
	# Context caption above action button.
	var idx: int = game.nearest_node()
	var context := "走近资源，再按 E 采集"
	if idx >= 0:
		context = "采集 " + game.ITEM_NAMES[game.nodes[idx].type]
		if game.nodes[idx].type == "raw_water": context = "取生水 · 需要回营煮沸"
	elif game.near_camp(): context = "营地 · 按 Q 查看营火与休息"
	var width := font.get_string_size(context,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
	draw_style_box(box(Color(0.11,0.20,0.15,0.80),5),Rect2(716-width/2-12,688,width+24,26))
	txt(context,Vector2(716-width/2,707),13,PAPER)
	# Footer and the notification strip never overlap quick slots.
	draw_rect(Rect2(0,850,1440,50),Color("1b2e25"))
	txt("W A S D  移动",Vector2(28,880),12,MUTED)
	txt("鼠标点击寻路",Vector2(163,880),12,MUTED)
	txt("E  采集",Vector2(293,880),12,MUTED)
	txt("B  制作",Vector2(382,880),12,MUTED)
	txt("Q  营地",Vector2(472,880),12,MUTED)
	txt("F  驱赶",Vector2(562,880),12,MUTED)
	txt("F1  操作说明",Vector2(652,880),12,MUTED)
	txt("自动存档 · 失去焦点时暂停",Vector2(1206,880),11,MUTED)
	if game.toast_timer > 0:
		var toast_width := minf(820,font.get_string_size(game.toast_text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+38)
		card(Rect2(720-toast_width/2,636,toast_width,39),Color("283b2d"),Color("89956a"))
		txt(game.toast_text,Vector2(720-toast_width/2+19,661),14,PAPER)

func build_content() -> void:
	clear(content_layer)
	if game.active_event == "wolf":
		button(content_layer,"F  驱赶",Rect2(923,183,93,32),func(): game.repel_wolf(),true)
	if game.panel == "":
		button(content_layer,"展开制作  B",Rect2(1260,104,144,38),func(): game.panel = "craft")
		return
	var panel_bg := Panel.new()
	panel_bg.position = Vector2(1150,100)
	panel_bg.size = Vector2(266,656)
	panel_bg.add_theme_stylebox_override("panel",box(DARK,9,Color("52624b")))
	content_layer.add_child(panel_bg)
	for i in range(3):
		var id: String = ["craft","inventory","camp"][i]
		var title: String = ["制作","背包","营地"][i]
		button(content_layer,title,Rect2(1163+i*80,114,73,34),func(): game.panel = id,game.panel == id)
	match game.panel:
		"craft": build_crafting()
		"inventory": build_inventory()
		"camp": build_camp()
	label(content_layer,"原始的工具，也能撑起一段生活。",Rect2(1169,719,232,27),11,MUTED)

func build_crafting() -> void:
	for i in range(3):
		var title: String = ["营地","工具","补给"][i]
		button(content_layer,title,Rect2(1169+i*78,162,71,29),func(): game.craft_tab = title,game.craft_tab == title)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(1167,204)
	scroll.size = Vector2(234,497)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_layer.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",12)
	scroll.add_child(list)
	for id in game.RECIPES:
		var recipe: Dictionary = game.RECIPES[id]
		if recipe.kind != game.craft_tab: continue
		var row := Panel.new()
		row.custom_minimum_size = Vector2(221,156)
		row.add_theme_stylebox_override("panel",box(Color("2c4032"),6,Color("536048")))
		list.add_child(row)
		label(row,recipe.name,Rect2(13,9,204,28),18,PAPER)
		label(row,recipe.description,Rect2(13,40,197,40),12,MUTED,true)
		var cost_text := ""
		for key in recipe.cost:
			cost_text += "%s %d/%d  " % [game.ITEM_NAMES[key],game.inventory[key],recipe.cost[key]]
		label(row,cost_text,Rect2(13,80,203,35),11,GOLD,true)
		var blocked: String = game.recipe_blocked(id)
		var finished := blocked in ["已经建成","已经制作"]
		var b := button(row,"已完成" if finished else "制作 · %d 分钟" % recipe.time,Rect2(13,118,195,28),func(): game.craft(id),blocked == "",blocked if blocked != "" else recipe.description)
		b.disabled = finished
		if not finished and blocked != "":
			b.text = "缺少材料" if blocked.begins_with("还缺") else blocked

func build_inventory() -> void:
	label(content_layer,"随身背包",Rect2(1170,167,214,28),18,PAPER)
	label(content_layer,"采集来的每一份，都用得上。",Rect2(1170,197,216,26),12,MUTED)
	var i := 0
	for key in game.ITEM_NAMES:
		if key in ["berry","water","meal"]:
			var action := "饮用" if key == "water" else "食用"
			var text := "%s ×%d    %s" % [game.ITEM_NAMES[key],game.inventory[key],action]
			button(content_layer,text,Rect2(1169,237+i*33,226,29),func(): game.consume(key),false,"点击%s一份%s" % [action,game.ITEM_NAMES[key]])
		else:
			label(content_layer,game.ITEM_NAMES[key],Rect2(1171,237+i*33,140,28),14,PAPER)
			label(content_layer,"× %d" % game.inventory[key],Rect2(1337,237+i*33,57,28),14,GOLD)
		i += 1
	label(content_layer,"石斧  %s   石矛  %s" % ["已装备" if game.equipment.axe else "未制作","已装备" if game.equipment.spear else "未制作"],Rect2(1170,553,224,34),12,MUTED)
	label(content_layer,"火把  × %d" % game.torches,Rect2(1170,588,210,28),14,GOLD)
	button(content_layer,"饮用净水",Rect2(1170,635,225,38),func(): game.consume("water"),true)
	button(content_layer,"查看生存手记",Rect2(1170,680,225,28),func(): game.modal = "guide")

func build_camp() -> void:
	label(content_layer,"高地营地",Rect2(1170,168,210,29),20,PAPER)
	label(content_layer,"%s\n%s" % ["营火已点燃" if game.fire_lit() else ("营火已熄灭" if game.structures.fire else "尚未建造营火"),"棚顶已经加固" if game.structures.reinforce else ("枝叶庇护所已建成" if game.structures.shelter else "尚未搭建庇护所")],Rect2(1170,216,224,62),14,MUTED,true)
	button(content_layer,"添柴 / 重新点燃",Rect2(1170,299,226,42),func(): game.fuel_fire(),true,"消耗木材 ×2，增加 10 小时燃料")
	label(content_layer,"木材 ×2 · 增加 10 小时燃料",Rect2(1170,347,224,26),12,MUTED)
	button(content_layer,"短暂休息 · 1 小时",Rect2(1170,394,226,42),func(): game.rest(false))
	label(content_layer,"恢复体力。休息也会消耗饮食。",Rect2(1170,442,225,34),12,MUTED,true)
	button(content_layer,"睡一觉 · 8 小时",Rect2(1170,493,226,42),func(): game.rest(true))
	label(content_layer,"需要庇护所，先吃饱、喝足。\n狼嚎会打断睡眠。",Rect2(1170,541,223,46),12,MUTED,true)
	button(content_layer,"保存旅程",Rect2(1170,622,226,35),func(): game.notify("旅程已经保存。" if game.save_game() else "保存失败，请检查存档目录权限。"))
	button(content_layer,"重新开始",Rect2(1170,668,226,31),func(): game.return_modal = ""; game.modal = "restart")

func build_modal() -> void:
	clear(modal_layer)
	var mode: String = game.modal
	if mode == "" and game.pending_load: mode = "welcome"
	if mode == "" and (game.game_over or game.victory): mode = "ending"
	if mode == "" and game.pause_game: mode = "pause"
	if mode == "": return
	blocker(modal_layer,Rect2(0,0,1440,900),Color(0.055,0.11,0.085,0.76))
	var bg := Panel.new()
	bg.position = Vector2(275,155)
	bg.size = Vector2(890,590)
	bg.add_theme_stylebox_override("panel",box(Color("22392d"),12,Color("89916a")))
	modal_layer.add_child(bg)
	if mode in ["guide","help"]:
		button(modal_layer,"关闭  Esc",Rect2(1039,177,101,33),func(): game.modal = "")
	match mode:
		"guide": build_guide()
		"help": build_help()
		"pause":
			label(modal_layer,"让荒野等一会儿",Rect2(337,239,760,61),36,PAPER)
			label(modal_layer,"游戏已暂停。整理好思路，再出发。",Rect2(340,321,720,39),17,MUTED)
			button(modal_layer,"继续旅程",Rect2(341,405,755,49),func(): game.pause_game = false,true)
			button(modal_layer,"查看操作说明",Rect2(341,475,366,43),func(): game.modal = "help")
			button(modal_layer,"生存手记",Rect2(727,475,369,43),func(): game.modal = "guide")
			button(modal_layer,"保存并继续",Rect2(341,540,755,43),func(): game.notify("旅程已经保存。" if game.save_game() else "存档写入失败。 "); game.pause_game = false)
			label(modal_layer,"离开窗口时会自动暂停；暂停期间生存数值不会下降。",Rect2(340,631,760,35),13,MUTED)
		"welcome":
			label(modal_layer,"河谷，还记得你",Rect2(339,239,770,60),36,PAPER)
			label(modal_layer,"发现一份本地存档。你的营火、物资和旅程都留在这里。",Rect2(341,321,736,60),17,MUTED,true)
			button(modal_layer,"继续上次的旅程",Rect2(341,424,754,49),func(): game.load_game(),true)
			button(modal_layer,"开始新的旅程",Rect2(341,494,754,43),func(): game.return_modal = "welcome"; game.modal = "restart")
			label(modal_layer,"新的旅程会覆盖原来的本地存档。",Rect2(341,615,750,40),13,MUTED)
		"restart":
			label(modal_layer,"重新踏入荒野？",Rect2(339,239,770,60),36,PAPER)
			label(modal_layer,"这会清除当前旅程的本地存档，从第一天清晨重新开始。",Rect2(341,330,736,60),17,MUTED,true)
			button(modal_layer,"保留当前旅程",Rect2(341,457,363,47),func(): game.modal = game.return_modal,true)
			button(modal_layer,"确认重新开始",Rect2(724,457,371,47),func(): game.new_game())
		"ending": build_ending()

func build_help() -> void:
	label(modal_layer,"在荒野，学会过日子",Rect2(312,186,710,47),28,PAPER)
	label(modal_layer,"目标：从第一天 08:00 起，平安生存整整 72 小时。",Rect2(314,241,786,29),15,GOLD)
	var tips := [
		["01  先收集", "WASD / 方向键移动，也可点击地面行走。走近木材、石块和植物，按 E 采集。"],
		["02  安顿下来", "在高地营地附近，按 B 制作营火和庇护所。石斧能提高采集效率。"],
		["03  准备饮食", "在东侧水源处取水，回营火旁煮沸。1 吃浆果，2 喝净水，4 吃烤野薯。"],
		["04  应对危险", "狼嚎后，回到点燃的营火旁按 F，或按 3 使用火把。下雨时靠近庇护所。"],
		["05  照顾自己", "按 Q 查看营地：添柴、短暂休息或睡觉。J 打开手记，Esc 暂停，F1 查看操作。"]
	]
	for i in range(tips.size()):
		label(modal_layer,tips[i][0],Rect2(315,303+i*71,151,30),16,PAPER)
		label(modal_layer,tips[i][1],Rect2(487,299+i*71,622,49),14,MUTED,true)
	label(modal_layer,"手记区分了游戏规则与生活常识，避免把简化玩法当作现实操作指南。",Rect2(314,682,791,35),12,MUTED)

func build_guide() -> void:
	label(modal_layer,"生存手记",Rect2(312,184,700,42),28,PAPER)
	label(modal_layer,"在经历中，把本能变成经验。",Rect2(314,232,700,31),14,MUTED)
	button(modal_layer,"最近的旅程",Rect2(837,181,183,34),func(): selected_guide = 8,selected_guide == 8)
	for i in range(GUIDES.size()):
		var entry: Dictionary = GUIDES[i]
		var text: String = ("● " if entry.id in game.learned else "○ ") + entry.tag
		button(modal_layer,text,Rect2(313,287+i*45,204,35),func(): selected_guide = i,selected_guide == i)
	if selected_guide < GUIDES.size():
		var guide: Dictionary = GUIDES[selected_guide]
		label(modal_layer,guide.name,Rect2(552,287,565,49),24,PAPER)
		label(modal_layer,"已有实践" if guide.id in game.learned else "可以提前阅读，在行动中掌握",Rect2(553,341,560,28),12,GOLD)
		label(modal_layer,guide.body,Rect2(553,388,556,235),17,PAPER,true)
	else:
		var scroll := ScrollContainer.new()
		scroll.position = Vector2(551,286)
		scroll.size = Vector2(565,360)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		modal_layer.add_child(scroll)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation",14)
		scroll.add_child(list)
		for entry in game.journal:
			var item := Label.new()
			item.text = entry.time + "   " + entry.title + "\n" + entry.body
			item.custom_minimum_size = Vector2(530,83)
			item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			item.add_theme_font_size_override("font_size",14)
			item.add_theme_color_override("font_color",PAPER)
			list.add_child(item)
	label(modal_layer,"阅读手记时，时间暂停。",Rect2(552,677,563,30),12,MUTED)

func build_ending() -> void:
	label(modal_layer,"你守住了三个清晨" if game.victory else "这一程，暂时停在这里",Rect2(336,229,772,68),34,PAPER)
	label(modal_layer,"每一堆火、每一口净水、每一次准备，都让你离荒野更近了一点。" if game.victory else "身体没能撑住。这一次积累的经验，会让下一次出发从容一些。",Rect2(339,317,752,71),17,MUTED,true)
	label(modal_layer,"生存  %d 小时     采集  %d 份物资     掌握  %d / 8 项技巧" % [int((game.minutes-480)/60),game.total_gathered,game.learned.size()],Rect2(339,405,757,46),18,GOLD)
	if game.victory:
		button(modal_layer,"继续自由生存",Rect2(340,499,754,48),func(): game.victory = false; game.continued = true; game.modal = ""; game.save_game(),true)
	else:
		button(modal_layer,"再出发一次",Rect2(340,499,754,48),func(): game.new_game(),true)
	button(modal_layer,"查看这次的手记",Rect2(340,570,754,41),func(): selected_guide = 8; game.modal = "guide")
	label(modal_layer,"余烬 · 荒野手记",Rect2(340,661,754,30),13,MUTED)
