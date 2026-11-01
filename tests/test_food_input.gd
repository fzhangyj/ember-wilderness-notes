extends SceneTree
## Real GUI/key event regression for eating when food is in the inventory.
const Game = preload("res://scripts/game.gd")
var game: Node2D
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func expect(ok: bool, description: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ")+description)
	if not ok: failures += 1

func reset_food() -> void:
	game.hunger = 0
	game.thirst = 50
	game.energy = 50
	game.inventory.berry = 29
	game.inventory.meal = 6
	game.inventory.water = 4
	game.modal = ""
	game.pause_game = false
	game.pending_load = false
	game.game_over = false
	game.victory = false
	game.hud.refresh(1)

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion,true)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	root.push_input(event,true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	event.button_mask = 0
	root.push_input(event,true)
	await process_frame
	game.hud.refresh(1)
	await process_frame

func press_key(physical: Key, logical: Key = KEY_NONE) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.keycode = logical if logical != KEY_NONE else physical
	event.pressed = true
	root.push_input(event,true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await process_frame
	game.hud.refresh(1)

func run() -> void:
	game = Game.new()
	root.add_child(game)
	game.set_process(false)
	game.testing = true
	if FileAccess.file_exists(game.save_path):
		game.load_game()
	reset_food()
	await process_frame
	await click(Vector2(495,812))
	expect(game.hunger == 14 and game.inventory.berry == 28,"bottom berry button eats exactly one berry")
	reset_food()
	await click(Vector2(872,812))
	expect(game.hunger == 30 and game.inventory.meal == 5,"bottom meal button eats exactly one cooked meal")
	reset_food()
	await press_key(KEY_1)
	expect(game.hunger == 14 and game.inventory.berry == 28,"number-row 1 eats after a button has keyboard focus")
	reset_food()
	await press_key(KEY_4)
	expect(game.hunger == 30 and game.inventory.meal == 5,"number-row 4 eats after a button has keyboard focus")
	reset_food()
	await press_key(KEY_KP_1)
	expect(game.hunger == 14 and game.inventory.berry == 28,"numpad 1 eats a berry")
	reset_food()
	await press_key(KEY_KP_4)
	expect(game.hunger == 30 and game.inventory.meal == 5,"numpad 4 eats a cooked meal")
	reset_food()
	await press_key(KEY_NONE,KEY_1)
	expect(game.hunger == 14,"logical number key works when physical code is unavailable")
	reset_food()
	game.panel = "inventory"
	game.hud.refresh(1)
	await process_frame
	await click(Vector2(1260,350))
	expect(game.hunger == 14 and game.inventory.berry == 28,"clicking berries in the backpack eats a berry")
	reset_food()
	await click(Vector2(1260,515))
	expect(game.hunger == 30 and game.inventory.meal == 5,"clicking cooked food in the backpack eats a meal")
	reset_food()
	await press_key(KEY_KP_2)
	expect(game.thirst == 88 and game.inventory.water == 3,"numpad 2 also supports drinking")
	reset_food()
	game.inventory.berry = 0
	await press_key(KEY_KP_1)
	expect(game.hunger == 0 and game.inventory.berry == 0 and game.toast_text.contains("没有浆果"),"empty food gives feedback without creating or consuming items")
	reset_food()
	game.pause_game = true
	await press_key(KEY_KP_4)
	expect(game.hunger == 0 and game.inventory.meal == 6,"numpad food actions respect pause")
	print("FOOD INPUT: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
