extends Node2D
## All survival changes pass through advance_time(), including travel and sleep.
## The scene is dependency free and can be run with F5 in Godot 4.3+.

const WorldView = preload("res://scripts/world.gd")
const HUDView = preload("res://scripts/hud.gd")
const AudioView = preload("res://scripts/sound.gd")
const SAVE_PATH = "user://ember_save.json"
const CAMP = Vector2(1040, 840)
const WORLD_SIZE = Vector2(2380, 1820)
const SPEED = 152.0
const ITEM_NAMES = {"wood":"木材", "stone":"石块", "fiber":"纤维", "berry":"浆果", "raw_water":"生水", "water":"净水", "herb":"草药", "tuber":"野薯", "meal":"烤野薯"}
const RECIPES = {
	"fire": {"name":"营火", "description":"点亮营地，取暖、煮水并震慑野兽。", "cost":{"wood":4,"stone":3}, "time":35, "kind":"营地"},
	"shelter": {"name":"枝叶庇护所", "description":"搭在高地上。抵挡风雨，允许睡眠。", "cost":{"wood":6,"fiber":5}, "time":65, "kind":"营地"},
	"axe": {"name":"石斧", "description":"木材每次采集从 3 增加到 5。", "cost":{"wood":2,"stone":3,"fiber":1}, "time":25, "kind":"工具"},
	"spear": {"name":"石矛", "description":"遭遇野兽时可主动防御，减轻伤害。", "cost":{"wood":3,"stone":2,"fiber":2}, "time":30, "kind":"工具"},
	"torch": {"name":"火把", "description":"需要点燃的营火。携带后可驱退狼。", "cost":{"wood":2,"fiber":2}, "time":15, "kind":"工具"},
	"water": {"name":"煮沸净水", "description":"在营火旁把生水煮沸，补充安全饮水。", "cost":{"raw_water":1,"wood":1}, "time":20, "kind":"补给"},
	"meal": {"name":"烤野薯", "description":"烤熟野薯，恢复 30 点饱食和 6 点体力。", "cost":{"tuber":1,"wood":1}, "time":20, "kind":"补给"},
	"bandage": {"name":"草药敷料", "description":"用清洁净水处理擦伤，恢复 25 点生命。", "cost":{"herb":2,"fiber":2,"water":1}, "time":15, "kind":"补给"},
	"reinforce": {"name":"加固棚顶", "description":"编密枝叶，提升雨中保暖和睡眠效果。", "cost":{"wood":3,"fiber":4}, "time":40, "kind":"营地"}
}

var player_pos := CAMP + Vector2(65, 105)
var facing := Vector2.DOWN
var target := Vector2.ZERO
var walking := false
var walk_phase := 0.0
var minutes := 480.0
var health := 100.0
var hunger := 86.0
var thirst := 82.0
var energy := 94.0
var warmth := 88.0
var inventory := {"wood":0,"stone":0,"fiber":0,"berry":2,"raw_water":0,"water":1,"herb":0,"tuber":0,"meal":0}
var structures := {"fire":false,"shelter":false,"reinforce":false}
var equipment := {"axe":false,"spear":false}
var torches := 0
var fire_fuel := 0.0
var torch_minutes := 0.0
var nodes: Array = []
var learned: Array = []
var journal: Array = []
var event_history: Array = []
var active_event := ""
var event_deadline := 0.0
var wolf_pos := Vector2(1500, 1050)
var wolf_encounters := 0
var rain_until := 0.0
var pause_game := false
var panel := "craft"
var craft_tab := "营地"
var modal := ""
var game_over := false
var victory := false
var continued := false
var save_elapsed := 0.0
var toast_text := ""
var toast_timer := 0.0
var interaction_flash := 0.0
var total_gathered := 0
var world: Node2D
var hud: Control
var sound: Node
var testing := false
var storage_message := ""
var capture_path := ""
var return_modal := ""
var save_path := SAVE_PATH
var pending_load := false

func _ready() -> void:
	setup_nodes()
	world = WorldView.new()
	world.game = self
	add_child(world)
	sound = AudioView.new()
	add_child(sound)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HUDView.new()
	hud.game = self
	layer.add_child(hud)
	var args := OS.get_cmdline_user_args()
	testing = "--test" in args
	if "--capture" in args:
		var idx := args.find("--capture")
		capture_path = args[idx + 1] if idx + 1 < args.size() else "user://ember.png"
	elif FileAccess.file_exists(save_path) and not testing:
		pending_load = true
		modal = "welcome"
	if journal.is_empty():
		log_entry("来到河谷", "你在一片高地醒来。河流在东侧，林地散落着可以利用的材料。")
	if storage_message != "":
		notify(storage_message)
	else:
		notify("先采集木材和石块。天黑前，给自己留一堆火。", 8.0)
	if capture_path != "":
		capture_after_frames()

func capture_after_frames() -> void:
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(capture_path)
	print("CAPTURE_RESULT ", err, " ", capture_path)
	get_tree().quit(err)

func setup_nodes() -> void:
	nodes.clear()
	var positions := {
		"wood":[Vector2(860,960),Vector2(940,640),Vector2(620,710),Vector2(690,1110),Vector2(490,1020),Vector2(1280,600),Vector2(1220,1260),Vector2(1620,640),Vector2(560,400),Vector2(380,1340),Vector2(1750,1370),Vector2(1080,1480)],
		"stone":[Vector2(1210,1010),Vector2(1130,660),Vector2(580,860),Vector2(1390,1150),Vector2(770,480),Vector2(480,1480),Vector2(1480,440),Vector2(1820,900),Vector2(1090,1440)],
		"fiber":[Vector2(890,1120),Vector2(1310,850),Vector2(720,900),Vector2(1150,1190),Vector2(600,1270),Vector2(1440,650),Vector2(1720,1150),Vector2(530,580),Vector2(840,1380)],
		"berry":[Vector2(710,1030),Vector2(1030,560),Vector2(1390,920),Vector2(780,1230),Vector2(1640,960),Vector2(600,520),Vector2(1860,1250)],
		"herb":[Vector2(1200,740),Vector2(550,1130),Vector2(1520,1240),Vector2(740,640)],
		"tuber":[Vector2(1000,1200),Vector2(760,800),Vector2(1560,780),Vector2(420,740)],
		"raw_water":[Vector2(1480,770),Vector2(1550,990),Vector2(1340,480),Vector2(1420,1390)]
	}
	for kind in positions:
		for p in positions[kind]:
			var resource_pos: Vector2 = p
			resource_pos.x = river_x(p.y) - 82 if kind == "raw_water" else minf(p.x,river_x(p.y)-105)
			nodes.append({"type":kind,"pos":resource_pos,"amount":3 if kind != "raw_water" else 999,"depleted_at":-1.0})

func _process(delta: float) -> void:
	toast_timer = maxf(0.0, toast_timer - delta)
	interaction_flash = maxf(0.0, interaction_flash - delta * 2)
	if is_playing():
		process_movement(delta)
		if active_event == "wolf":
			var safety_distance := 195.0 if (near_camp() and fire_lit()) or torch_minutes > 0 else 105.0
			if wolf_pos.distance_to(player_pos) > safety_distance:
				wolf_pos = wolf_pos.move_toward(player_pos, delta * 25.0)
		advance_time(delta * 1.6)
		save_elapsed += delta
		if save_elapsed > 20.0:
			save_game()
			save_elapsed = 0.0
	world.queue_redraw()
	hud.refresh(delta)

func is_playing() -> bool:
	return not pending_load and not pause_game and modal == "" and not game_over and not victory

func process_movement(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): direction.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): direction.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): direction.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): direction.x += 1
	if direction != Vector2.ZERO:
		walking = false
	elif walking:
		var offset := target - player_pos
		if offset.length() < 6:
			walking = false
		else:
			direction = offset.normalized()
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		facing = direction
		var speed := SPEED * (0.7 if energy < 20 else 1.0)
		var travel_distance := minf(speed * delta, player_pos.distance_to(target)) if walking else speed * delta
		var proposed := player_pos + direction * travel_distance
		proposed.x = clampf(proposed.x, 190, WORLD_SIZE.x - 190)
		proposed.y = clampf(proposed.y, 210, WORLD_SIZE.y - 180)
		# The river is a visible world boundary. Its near bank remains walkable.
		proposed.x = minf(proposed.x, river_x(proposed.y) - 65)
		player_pos = proposed
		walk_phase += delta * 10
	else:
		walk_phase = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if code == KEY_ESCAPE:
			if modal == "welcome" or (pending_load and modal == ""): return
			elif modal == "restart": modal = return_modal
			elif modal != "": modal = ""
			else: pause_game = not pause_game
			return
		if code == KEY_F1:
			modal = "" if modal == "help" else "help"
			return
		if not is_playing(): return
		match code:
			KEY_E: interact()
			KEY_B: panel = "" if panel == "craft" else "craft"
			KEY_J: modal = "guide"
			KEY_Q: camp_action()
			KEY_F: repel_wolf()
			KEY_1, KEY_KP_1: consume("berry")
			KEY_2, KEY_KP_2: consume("water")
			KEY_3, KEY_KP_3: use_torch()
			KEY_4, KEY_KP_4: consume("meal")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and is_playing():
		var point: Vector2 = world.to_world(get_viewport().get_mouse_position())
		target = Vector2(clampf(point.x, 190, WORLD_SIZE.x - 190), clampf(point.y, 210, WORLD_SIZE.y - 180))
		target.x = minf(target.x, river_x(target.y) - 68)
		walking = true

func river_x(y: float) -> float:
	return 1500.0 + sin(y * 0.004) * 110.0 - cos(y * 0.0025) * 70.0

func day() -> int: return int(minutes / 1440.0) + 1
func hour() -> int: return int(fmod(minutes, 1440.0) / 60.0)
func clock_text() -> String: return "%02d:%02d" % [hour(), int(fmod(minutes, 60.0))]
func is_night() -> bool: return hour() >= 19 or hour() < 6
func raining() -> bool: return minutes < rain_until
func near_camp() -> bool: return player_pos.distance_to(CAMP) < 170
func fire_lit() -> bool: return structures.fire and fire_fuel > 0
func in_shelter() -> bool: return structures.shelter and player_pos.distance_to(CAMP + Vector2(-70,-45)) < 115

func nearest_node() -> int:
	var best := -1
	var distance := 88.0
	for i in range(nodes.size()):
		if nodes[i].amount <= 0: continue
		var d: float = player_pos.distance_to(nodes[i].pos)
		if d < distance:
			best = i
			distance = d
	return best

func interact() -> void:
	if not is_playing(): return
	var idx := nearest_node()
	if idx == -1:
		if near_camp(): camp_action()
		else: notify("走近发光的资源，再按 E 采集。")
		return
	var n: Dictionary = nodes[idx]
	var kind: String = n.type
	var amount := 1
	var cost := 12.0
	match kind:
		"wood":
			amount = 5 if equipment.axe else 3
			cost = 12.0 if equipment.axe else 18.0
		"stone": amount = 3; cost = 16.0
		"fiber": amount = 3
		"berry": amount = 3; cost = 10.0
		"raw_water": amount = 2; cost = 8.0
		"herb": amount = 2
		"tuber": amount = 2; cost = 14.0
	if energy < 5:
		notify("太疲惫了。在营地休息一会儿。")
		return
	inventory[kind] += amount
	total_gathered += amount
	if kind != "raw_water":
		n.amount -= 1
		if n.amount <= 0: n.depleted_at = minutes
	energy = maxf(0, energy - 2)
	advance_time(cost)
	interaction_flash = 1.0
	walking = false
	sound.play_effect("gather")
	notify("+%d %s  ·  用时 %d 分钟" % [amount, ITEM_NAMES[kind], int(cost)])
	if kind == "fiber": learn("shelter")
	if kind == "berry": learn("food")
	save_game()

func recipe_blocked(id: String) -> String:
	if not RECIPES.has(id): return "配方不存在"
	if id in ["fire","shelter","reinforce"] and structures.get(id, false): return "已经建成"
	if equipment.get(id, false): return "已经制作"
	if not near_camp(): return "请回到营地制作"
	if id in ["water","meal","torch"] and not fire_lit(): return "需要点燃的营火"
	if id == "reinforce" and not structures.shelter: return "先搭建庇护所"
	if torches >= 3 and id == "torch": return "最多携带 3 支火把"
	var missing: Array[String] = []
	for item in RECIPES[id].cost:
		var need: int = RECIPES[id].cost[item] - inventory[item]
		if need > 0: missing.append("%s ×%d" % [ITEM_NAMES[item], need])
	if not missing.is_empty(): return "还缺 " + "、".join(missing)
	return ""

func craft(id: String) -> void:
	if not is_playing(): return
	var blocked := recipe_blocked(id)
	if blocked != "": notify(blocked); return
	for item in RECIPES[id].cost: inventory[item] -= RECIPES[id].cost[item]
	match id:
		"fire": structures.fire = true; fire_fuel = 720.0; learn("fire")
		"shelter": structures.shelter = true; learn("shelter")
		"reinforce": structures.reinforce = true
		"axe": equipment.axe = true; learn("tools")
		"spear": equipment.spear = true; learn("wildlife")
		"torch": torches += 1; learn("wildlife")
		"water": inventory.water += 1; learn("water")
		"meal": inventory.meal += 1; learn("food")
		"bandage": health = minf(100, health + 25); learn("care")
	advance_time(RECIPES[id].time)
	sound.play_effect("craft")
	notify("%s已完成。" % RECIPES[id].name)
	log_entry("制作 · " + RECIPES[id].name, RECIPES[id].description)
	save_game()

func consume(item: String) -> void:
	if not is_playing(): return
	if not item in ["berry","water","meal"]: return
	if inventory[item] <= 0: notify("背包里没有%s。" % ITEM_NAMES[item]); return
	if item == "water" and thirst >= 99: notify("现在还不渴，留着净水吧。 "); return
	if item != "water" and hunger >= 99: notify("已经吃饱了，把食物留到之后吧。 "); return
	inventory[item] -= 1
	match item:
		"berry": hunger = minf(100, hunger + 14); thirst = minf(100, thirst + 3)
		"water": thirst = minf(100, thirst + 38)
		"meal": hunger = minf(100, hunger + 30); energy = minf(100, energy + 6)
	sound.play_effect("consume")
	notify("%s  ·  %s" % [ITEM_NAMES[item], "饮水 +38" if item == "water" else ("饱食 +30" if item == "meal" else "饱食 +14")])
	save_game()

func camp_action() -> void:
	if not is_playing(): return
	if not near_camp(): notify("回到营地才能添柴或休息。 "); return
	panel = "camp"
	walking = false

func fuel_fire() -> void:
	if not is_playing(): return
	if not near_camp(): notify("请先回到营地。 "); return
	if not structures.fire: notify("先建造一堆营火。 "); return
	if inventory.wood < 2: notify("添柴需要 2 份木材。 "); return
	if fire_fuel > 1300: notify("柴火充足，暂时不用添柴。 "); return
	inventory.wood -= 2
	fire_fuel += 600
	advance_time(5)
	notify("添入干柴，营火增加 10 小时燃料。 ")
	sound.play_effect("craft")
	save_game()

func rest(long_sleep: bool) -> void:
	if not is_playing(): return
	if not near_camp(): notify("回到营地再休息。 "); return
	if active_event == "wolf": notify("附近有狼。先处理危险，再安心休息。 "); return
	if long_sleep and not structures.shelter: notify("先搭建庇护所，才能安稳睡觉。 "); return
	if long_sleep and (hunger < 25 or thirst < 30): notify("先吃点东西、喝些净水，再睡觉。 "); return
	var duration := 480.0 if long_sleep else 60.0
	walking = false
	if long_sleep: player_pos = CAMP + Vector2(-70,-45)
	# Advance in small steps: warnings can interrupt sleep before an attack.
	var rested := 0.0
	while rested < duration and not game_over and not victory:
		advance_time(10)
		rested += 10
		energy = minf(100, energy + (1.5 if long_sleep else 2.5))
		if structures.shelter: warmth = minf(100, warmth + 1.2)
		if health < 100 and hunger > 35 and thirst > 35: health = minf(100, health + 0.25)
		if active_event == "wolf": break
	log_entry("营地休息", "在营地休息了 %d 分钟，恢复了体力。" % int(rested))
	notify("休息了 %d 分钟。%s" % [int(rested), "狼嚎把你惊醒，先处理危险。" if active_event == "wolf" else "体力恢复了。 "])
	save_game()

func use_torch() -> void:
	if not is_playing(): return
	if torch_minutes > 0:
		if active_event == "wolf": repel_wolf()
		else: notify("火把正在燃烧，还能使用 %d 分钟。" % int(torch_minutes))
		return
	if torches < 1: notify("先在燃烧的营火旁制作火把。 "); return
	torches -= 1
	torch_minutes = 240.0
	notify("举起火把。四小时内提供照明，可按 F 驱赶狼。 ")
	if active_event == "wolf": repel_wolf()
	save_game()

func repel_wolf() -> void:
	if not is_playing(): return
	if active_event != "wolf": notify("附近暂时没有需要驱赶的野兽。 "); return
	if torch_minutes > 0 or (near_camp() and fire_lit()):
		active_event = ""
		wolf_encounters += 1
		learn("wildlife")
		log_entry("守住了火光", "狼在火光外徘徊了一会儿，退回了树林。")
		notify("火光让狼退回树林。你平安化解了这次遭遇。", 6)
		sound.play_effect("craft")
	elif equipment.spear:
		active_event = ""
		wolf_encounters += 1
		health = maxf(1, health - 8)
		energy = maxf(0, energy - 12)
		learn("wildlife")
		notify("你用石矛守住距离。狼退走了，擦伤损失 8 点生命。", 6)
	else:
		notify("不要空手接近。返回点燃的营火旁按 F，或使用火把。", 6)
	save_game()

func advance_time(amount: float) -> void:
	if game_over or victory: return
	var remaining := amount
	while remaining > 0.001 and not game_over and not victory:
		var step := minf(remaining, 5.0)
		if not continued and minutes < 480 + 3 * 1440:
			step = minf(step, 480 + 3 * 1440 - minutes)
		remaining -= step
		minutes += step
		fire_fuel = maxf(0, fire_fuel - step)
		torch_minutes = maxf(0, torch_minutes - step)
		hunger = maxf(0, hunger - step * 0.030)
		thirst = maxf(0, thirst - step * 0.045)
		energy = maxf(0, energy - step * 0.017)
		var exposed := not in_shelter()
		var warm_rate := 0.035
		if is_night(): warm_rate = -0.045 if exposed else -0.004
		if raining(): warm_rate -= 0.075 if exposed else (0.002 if structures.reinforce else 0.035)
		if near_camp() and fire_lit(): warm_rate += 0.13
		if torch_minutes > 0: warm_rate += 0.04
		warmth = clampf(warmth + step * warm_rate, 0, 100)
		if hunger <= 0: health -= step * 0.065
		if thirst <= 0: health -= step * 0.1
		if warmth < 18: health -= step * 0.07
		if energy <= 0: health -= step * 0.025
		check_events()
		if health <= 0:
			health = 0
			game_over = true
			modal = "ending"
			log_entry("旅程暂时结束", "下一次，记得先准备净水、食物和温暖的落脚点。")
		if minutes >= 480 + 3 * 1440 and not continued and not game_over:
			victory = true
			modal = "ending"
			log_entry("第三个清晨", "你在荒野生存了整整三天。每一份准备，都变成了活下去的底气。")
	for n in nodes:
		if n.amount <= 0 and minutes - n.depleted_at > 1440:
			n.amount = 3
			n.depleted_at = -1.0

func check_events() -> void:
	for d in range(1, day() + 1):
		var event_id := "wolf_%d" % d
		var scheduled := (d - 1) * 1440 + 18 * 60
		if minutes >= scheduled and not event_id in event_history and active_event == "":
			event_history.append(event_id)
			active_event = "wolf"
			event_deadline = minutes + 150
			wolf_pos = player_pos + Vector2(235, -115)
			log_entry("林间传来狼嚎", "你还有约两小时准备。火光可以帮助你守住营地。")
			notify("林间传来狼嚎。准备火把，或回到燃烧的营火旁按 F 驱赶。", 9)
			if sound: sound.play_effect("warning")
	if minutes >= 1440 + 10 * 60 and not "rain_warning" in event_history:
		event_history.append("rain_warning")
		log_entry("乌云正在聚集", "两小时后会下雨。加固棚顶，准备干柴，并靠近营地。")
		notify("风里有潮气。两小时后降雨，最好加固庇护所、储备干柴。", 9)
	if minutes >= 1440 + 12 * 60 and not "rain" in event_history:
		event_history.append("rain")
		rain_until = 1440 + 22 * 60
		learn("weather")
		log_entry("河谷降雨", "待在庇护所里、维持火源可以减轻失温。")
		notify("下雨了。返回庇护所，保持营火燃烧。", 8)
	if active_event == "wolf" and minutes >= event_deadline:
		if (near_camp() and fire_lit()) or torch_minutes > 0:
			active_event = ""
			wolf_encounters += 1
			learn("wildlife")
			notify("狼不愿接近火光，离开了。 ", 6)
		else:
			health -= 12 if equipment.spear else 25
			energy = maxf(0, energy - 10)
			active_event = ""
			log_entry("惊险的遭遇", "狼扑来后退走了。下次提前准备火把，或返回有火的营地。")
			notify("狼突然扑来！损失 %d 点生命。它随后退回了树林。" % (12 if equipment.spear else 25), 8)

func learn(id: String) -> void:
	if id in learned: return
	learned.append(id)

func notify(message: String, duration: float = 4.5) -> void:
	toast_text = message
	toast_timer = duration

func log_entry(title: String, body: String) -> void:
	journal.push_front({"time":"第 %d 天 · %s" % [day(),clock_text()], "title":title,"body":body})
	if journal.size() > 40: journal.resize(40)

func save_game() -> bool:
	if pending_load: return false
	if testing or capture_path != "": return true
	var saved_nodes: Array = []
	for n in nodes: saved_nodes.append({"amount":n.amount,"depleted_at":n.depleted_at})
	var data := {"version":1,"pos":[player_pos.x,player_pos.y],"minutes":minutes,"health":health,"hunger":hunger,"thirst":thirst,"energy":energy,"warmth":warmth,"inventory":inventory,"structures":structures,"equipment":equipment,"torches":torches,"fire_fuel":fire_fuel,"torch_minutes":torch_minutes,"learned":learned,"journal":journal,"event_history":event_history,"active_event":active_event,"event_deadline":event_deadline,"rain_until":rain_until,"wolf_encounters":wolf_encounters,"continued":continued,"game_over":game_over,"victory":victory,"nodes":saved_nodes,"total_gathered":total_gathered}
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		storage_message = "存档暂时无法写入，本次游戏仍可继续。"
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	var err := DirAccess.rename_absolute(save_path + ".tmp", save_path)
	if err != OK:
		storage_message = "存档暂时无法写入，本次游戏仍可继续。"
	return err == OK

func load_game() -> bool:
	if not FileAccess.file_exists(save_path): return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null: notify("无法读取存档，可以开始新的旅程。 "); return false
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or data.get("version", 0) != 1:
		notify("存档无法识别，可以开始新的旅程。 "); return false
	# Validate the full record before assigning any state.
	if not data.get("pos") is Array or data.pos.size() != 2: return corrupt_save()
	for value in data.pos:
		if not (value is float or value is int): return corrupt_save()
	for key in ["minutes","health","hunger","thirst","energy","warmth","fire_fuel","torch_minutes","torches","event_deadline","rain_until","wolf_encounters","total_gathered"]:
		if not (data.get(key) is float or data.get(key) is int): return corrupt_save()
	for key in ["inventory","structures","equipment"]:
		if not data.get(key) is Dictionary: return corrupt_save()
	for key in inventory:
		if not (data.inventory.get(key) is float or data.inventory.get(key) is int): return corrupt_save()
	for key in structures:
		if not data.structures.get(key) is bool: return corrupt_save()
	for key in equipment:
		if not data.equipment.get(key) is bool: return corrupt_save()
	for key in ["continued","game_over","victory"]:
		if not data.get(key) is bool: return corrupt_save()
	for key in ["learned","journal","event_history","nodes"]:
		if not data.get(key) is Array: return corrupt_save()
	if data.nodes.size() != nodes.size(): return corrupt_save()
	for item in data.nodes:
		if not item is Dictionary or not (item.get("amount") is float or item.get("amount") is int) or not (item.get("depleted_at") is float or item.get("depleted_at") is int): return corrupt_save()
	for entry in data.journal:
		if not entry is Dictionary: return corrupt_save()
		for key in ["time","title","body"]:
			if not entry.get(key) is String: return corrupt_save()
	for id in data.learned + data.event_history:
		if not id is String: return corrupt_save()
	if not data.get("active_event") in ["","wolf"]: return corrupt_save()
	player_pos = Vector2(clampf(data.pos[0],190,WORLD_SIZE.x-190), clampf(data.pos[1],210,WORLD_SIZE.y-180))
	player_pos.x = minf(player_pos.x, river_x(player_pos.y) - 65)
	for key in ["minutes","health","hunger","thirst","energy","warmth","fire_fuel","torch_minutes","torches","event_deadline","rain_until","wolf_encounters","total_gathered"]:
		set(key, maxf(0, data[key]))
	for key in ["health","hunger","thirst","energy","warmth"]: set(key, clampf(get(key),0,100))
	for key in inventory: inventory[key] = clampi(int(data.inventory[key]),0,9999)
	structures = data.structures
	equipment = data.equipment
	learned = data.learned
	journal = data.journal
	event_history = data.event_history
	for key in ["continued","game_over","victory","active_event"]: set(key,data[key])
	for i in range(nodes.size()):
		nodes[i].amount = clampi(int(data.nodes[i].amount),0,999)
		nodes[i].depleted_at = float(data.nodes[i].depleted_at)
	wolf_pos = player_pos + Vector2(235,-115)
	modal = "ending" if game_over or victory else ""
	pending_load = false
	pause_game = false
	walking = false
	notify("回到河谷。上次的旅程已经恢复。 ")
	return true

func corrupt_save() -> bool:
	notify("存档内容不完整，可以开始新的旅程。 ", 7)
	return false

func new_game() -> void:
	# Reloading the scene avoids stale input, weather, UI, and audio state.
	if FileAccess.file_exists(save_path):
		var err := DirAccess.remove_absolute(save_path)
		if err != OK: notify("旧存档无法覆盖，请检查存档目录权限。 "); return
	get_tree().reload_current_scene()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not pending_load: save_game()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if modal == "" and not testing and capture_path == "": pause_game = true
