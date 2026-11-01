extends SceneTree
## Full 72-hour playthrough using only starting supplies and real action costs.
const Game = preload("res://scripts/game.gd")
var game: Node2D
var failures := 0
var checks := 0
var log_lines: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	var line := ("PASS: " if condition else "FAIL: ") + message
	print(line)
	log_lines.append(line)
	if not condition: failures += 1

func travel(point: Vector2) -> void:
	game.target = point
	game.walking = true
	var steps := 0
	while game.walking and not game.game_over and not game.victory and steps < 300:
		game.process_movement(0.25)
		game.advance_time(0.4)
		steps += 1

func gather_until(kind: String, quantity: int) -> void:
	var limit := 0
	while game.inventory[kind] < quantity and limit < 25 and not game.game_over and not game.victory:
		var closest := -1
		var distance := INF
		for i in range(game.nodes.size()):
			var n: Dictionary = game.nodes[i]
			if n.type != kind or n.amount <= 0 or n.pos.x > game.river_x(n.pos.y)-65: continue
			var d: float = game.player_pos.distance_to(n.pos)
			if d < distance: closest = i; distance = d
		if closest < 0: break
		travel(game.nodes[closest].pos)
		game.interact()
		limit += 1
	if not game.victory and game.inventory[kind] < quantity:
		check(false,"reachable resources sufficient for "+kind)

func make(id: String) -> void:
	for item in game.RECIPES[id].cost:
		gather_until(item,game.RECIPES[id].cost[item])
	travel(game.CAMP)
	game.craft(id)

func click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion,true)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event,true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	event.button_mask = 0
	root.push_input(event,true)
	await process_frame
	game.hud.refresh(1)
	await process_frame

func run() -> void:
	game = Game.new()
	root.add_child(game)
	game.set_process(false)
	game.testing = true
	game.pending_load = false
	game.modal = ""
	game.pause_game = false
	make("fire")
	make("shelter")
	make("axe")
	make("torch")
	make("water")
	make("reinforce")
	check(game.structures.fire and game.structures.shelter and game.structures.reinforce and game.equipment.axe,"starting resources can establish a complete camp")
	check(game.minutes < 1080,"a prepared first camp is achievable before the first wolf warning")
	var camp_time: String = game.clock_text()
	var turns := 0
	while not game.victory and not game.game_over and turns < 150:
		turns += 1
		if game.active_event == "wolf":
			travel(game.CAMP)
			if not game.fire_lit():
				gather_until("wood",2)
				travel(game.CAMP)
				game.fuel_fire()
			game.repel_wolf()
			continue
		if game.thirst < 63:
			if game.inventory.water < 1: make("water")
			game.consume("water")
			continue
		if game.hunger < 65:
			gather_until("berry",1)
			game.consume("berry")
			continue
		if game.fire_fuel < 560:
			gather_until("wood",2)
			travel(game.CAMP)
			game.fuel_fire()
			continue
		travel(game.CAMP)
		game.rest(game.energy < 65)
	check(game.victory and not game.game_over,"actual resource gathering, crafting and camp care reaches 72-hour victory")
	check(game.wolf_encounters >= 3,"all three nightly wolf encounters can be resolved")
	check(game.health > 50 and game.warmth > 50,"prepared playthrough remains healthy through cold and rain")
	check("rain" in game.event_history and "water" in game.learned,"playthrough includes the rain event and water purification")
	log_lines.append("Camp ready at day 1 "+camp_time)
	log_lines.append("End: day %d %s, health %.1f, food %.1f, water %.1f, warmth %.1f, wolves %d, materials %d" % [game.day(),game.clock_text(),game.health,game.hunger,game.thirst,game.warmth,game.wolf_encounters,game.total_gathered])
	# Exercise the actual GUI event route, not just button callbacks.
	game.victory = false
	game.continued = true
	game.modal = ""
	game.pause_game = false
	game.hud.refresh(1)
	await process_frame
	await click(Vector2(1280,130))
	check(game.panel == "inventory","mouse click opens the inventory tab")
	await click(Vector2(1360,130))
	check(game.panel == "camp","mouse click opens the camp tab")
	await click(Vector2(1200,130))
	await click(Vector2(1274,176))
	check(game.panel == "craft" and game.craft_tab == "工具","mouse click switches crafting categories")
	await click(Vector2(1080,39))
	check(game.modal == "guide" and not game.is_playing(),"handbook button opens a paused readable guide")
	await click(Vector2(1100,191))
	check(game.modal == "" and game.is_playing(),"closing the guide restores play")
	await click(Vector2(1340,39))
	check(game.pause_game and not game.is_playing(),"pause button stops survival progression")
	await click(Vector2(700,430))
	check(not game.pause_game,"resume button returns to the game")
	game.modal = "ending"
	game.victory = true
	game.hud.refresh(1)
	await process_frame
	await click(Vector2(690,588))
	check(game.modal == "guide","victory page opens the journey journal")
	await click(Vector2(1100,191))
	check(game.modal == "" and game.victory,"closing the journal preserves the victory state")
	game.hud.refresh(1)
	await process_frame
	await click(Vector2(710,522))
	check(game.continued and not game.victory and game.is_playing(),"victory screen remains usable after returning from journal")
	var file := FileAccess.open("res://artifacts/playthrough.txt",FileAccess.WRITE)
	file.store_string("\n".join(log_lines)+"\n%d checks, %d failures\n" % [checks,failures])
	file.close()
	print("PLAYTHROUGH AND GUI: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
