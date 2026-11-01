extends SceneTree
## Runs the real game methods against isolated state and an isolated save path.
const Game = preload("res://scripts/game.gd")
var game: Node2D
var checks := 0
var failures := 0
const TEST_SAVE = "user://ember_automated_test.json"

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",description)
	else:
		print("PASS: ",description)

func fresh() -> void:
	if is_instance_valid(game):
		root.remove_child(game)
		game.free()
	game = Game.new()
	game.testing = true
	game.save_path = TEST_SAVE
	root.add_child(game)
	game.set_process(false)
	game.testing = true
	game.modal = ""
	game.pause_game = false

func resource(kind: String) -> int:
	for i in range(game.nodes.size()):
		if game.nodes[i].type == kind: return i
	return -1

func supplies() -> void:
	for key in game.inventory: game.inventory[key] = 30
	game.player_pos = game.CAMP

func run() -> void:
	fresh()
	expect(game.minutes == 480 and game.health == 100,"new journey starts at 08:00 with full health")
	expect(game.nodes.size() >= 45,"world contains all resource families")
	var all_reachable := true
	for n in game.nodes:
		if n.pos.x > game.river_x(n.pos.y)-65: all_reachable = false
	expect(all_reachable,"every resource is on the accessible bank of the river")
	var start_time: float = game.minutes
	game.craft("fire")
	expect(not game.structures.fire and game.minutes == start_time,"missing materials cannot build or consume time")
	var wood := resource("wood")
	game.player_pos = game.nodes[wood].pos
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	game._unhandled_input(key)
	expect(game.inventory.wood == 3 and game.nodes[wood].amount == 2,"E gathers nearby wood and depletes one charge")
	expect(game.minutes == start_time+18 and game.energy < 94,"gathering consumes time and energy")
	var destination: Vector2 = game.player_pos + Vector2(65,0)
	game.walking = true
	game.target = destination
	game.process_movement(0.1)
	expect(game.player_pos.x > game.nodes[wood].pos.x,"click destination drives character movement")
	game.target = game.player_pos + Vector2(10,0)
	game.walking = true
	game.process_movement(0.5)
	expect(game.player_pos.distance_to(game.target) < 0.01,"slow frames cannot overshoot click destinations")
	game.player_pos = Vector2(game.river_x(800)-66,800)
	game.target = Vector2(1900,800)
	game.walking = true
	game.process_movement(0.2)
	expect(game.player_pos.x <= game.river_x(game.player_pos.y)-65,"movement cannot walk into river")
	supplies()
	game.player_pos = Vector2(500,500)
	game.craft("fire")
	expect(not game.structures.fire and game.inventory.wood == 30,"building requires proximity to camp")
	game.player_pos = game.CAMP
	game.craft("fire")
	expect(game.fire_lit() and game.inventory.wood == 26 and game.inventory.stone == 27,"campfire consumes its actual recipe")
	var wood_after: int = game.inventory.wood
	game.craft("fire")
	expect(game.inventory.wood == wood_after,"unique structures cannot consume materials twice")
	game.craft("axe")
	game.player_pos = game.nodes[wood].pos
	wood_after = game.inventory.wood
	game.interact()
	expect(game.inventory.wood == wood_after+5,"equipped stone axe increases wood yield")
	game.interact()
	expect(game.nodes[wood].amount == 0 and game.nearest_node() != wood,"empty resources cannot be gathered again immediately")
	game.nodes[wood].depleted_at = game.minutes-1441
	game.advance_time(0.1)
	expect(game.nodes[wood].amount == 3,"depleted resources regrow after a full day")

	fresh()
	supplies()
	game.inventory.water = 0
	game.craft("water")
	expect(game.inventory.water == 0,"raw water cannot be purified without a lit fire")
	var raw_before: int = game.inventory.raw_water
	game.consume("raw_water")
	expect(game.inventory.raw_water == raw_before,"raw water cannot be consumed as safe water")
	game.craft("fire")
	game.craft("water")
	expect(game.inventory.water == 1 and "water" in game.learned,"boiling produces safe water and records the skill")
	game.thirst = 40
	game.consume("water")
	expect(game.thirst == 78 and game.inventory.water == 0,"safe drinking restores thirst and spends one unit")
	game.player_pos = Vector2(500,500)
	wood_after = game.inventory.wood
	game.fuel_fire()
	expect(game.inventory.wood == wood_after,"fire cannot be refueled remotely")
	game.player_pos = game.CAMP
	var fuel_before: float = game.fire_fuel
	game.fuel_fire()
	expect(game.fire_fuel == fuel_before+595 and game.inventory.wood == wood_after-2,"refueling accounts for time and fuel cost")
	game.craft("shelter")
	game.craft("reinforce")
	expect(game.structures.shelter and game.structures.reinforce,"shelter and roof upgrade can be constructed")
	game.craft("meal")
	game.hunger = 50
	game.energy = 50
	game.consume("meal")
	expect(game.hunger == 80 and game.energy == 56,"cooked tuber restores food and energy")
	game.inventory.water = 1
	game.health = 60
	game.craft("bandage")
	expect(game.health == 85 and game.inventory.water == 0,"wound care consumes clean water and heals")

	fresh()
	supplies()
	game.minutes = 1079
	game.advance_time(1)
	expect(game.active_event == "wolf" and game.event_deadline == 1230,"wolf is preceded by a 150 minute warning")
	game.craft("fire")
	game.repel_wolf()
	expect(game.active_event == "" and game.health == 100 and game.wolf_encounters == 1,"campfire safely resolves wolf encounter")
	game.advance_time(160)
	expect(game.active_event == "","same night cannot trigger duplicate wolves")
	game.active_event = "wolf"
	game.event_deadline = game.minutes+5
	game.player_pos = Vector2(500,500)
	game.advance_time(5)
	expect(game.health == 75 and game.active_event == "","ignoring warning causes bounded damage then retreat")
	game.active_event = "wolf"
	game.equipment.spear = true
	game.repel_wolf()
	expect(game.health == 67 and game.active_event == "","stone spear resolves attack at a smaller health cost")
	game.active_event = "wolf"
	game.torches = 1
	game.use_torch()
	expect(game.active_event == "" and game.torches == 0 and game.torch_minutes == 240,"torch can immediately repel a wolf away from camp")

	fresh()
	supplies()
	game.structures.shelter = true
	game.structures.fire = true
	game.fire_fuel = 700
	game.minutes = 1070
	game.energy = 40
	game.rest(true)
	expect(game.minutes == 1080 and game.active_event == "wolf","sleep stops when wolf warning begins")
	expect(game.in_shelter() and game.energy > 40,"sleep moves to shelter and restores energy")
	game.repel_wolf()
	game.hunger = 10
	start_time = game.minutes
	game.rest(true)
	expect(game.minutes == start_time,"sleep refuses insufficient food before committing time")
	game.pause_game = true
	wood_after = game.inventory.wood
	game.craft("axe")
	game.consume("berry")
	expect(game.inventory.wood == wood_after and game.minutes == start_time,"pause blocks survival actions")

	fresh()
	game.minutes = 2039
	game.advance_time(1)
	expect("rain_warning" in game.event_history and not game.raining(),"rain warning arrives two hours before rain")
	game.advance_time(120)
	expect(game.raining() and "weather" in game.learned,"second-day rain starts at noon")
	game.active_event = ""
	game.player_pos = Vector2(700,700)
	game.warmth = 80
	game.advance_time(60)
	var exposed_warmth: float = game.warmth
	game.player_pos = game.CAMP + Vector2(-70,-45)
	game.structures.shelter = true
	game.structures.reinforce = true
	game.warmth = 80
	game.advance_time(60)
	expect(game.warmth > exposed_warmth,"reinforced shelter reduces rain exposure")

	fresh()
	game.minutes = 4799
	game.advance_time(1)
	expect(game.victory and game.modal == "ending","72 hours opens victory screen")
	game.victory = false
	game.continued = true
	game.modal = ""
	game.advance_time(1)
	expect(not game.victory and game.minutes == 4801,"continuing after victory enables free survival")
	fresh()
	game.health = 0.01
	game.thirst = 0
	game.advance_time(30)
	expect(game.game_over and game.health == 0 and game.modal == "ending","critical survival failure opens the end screen")
	start_time = game.minutes
	game.advance_time(100)
	expect(game.minutes == start_time,"dead characters do not keep simulating")
	fresh()
	game.pending_load = true
	game.modal = "welcome"
	key.physical_keycode = KEY_F1
	game._unhandled_input(key)
	key.physical_keycode = KEY_ESCAPE
	game._unhandled_input(key)
	expect(not game.is_playing() and game.pending_load,"help cannot bypass the saved journey selection")
	expect(not game.save_game(),"pending saved journey cannot be overwritten before choosing continue or new")

	fresh()
	supplies()
	game.testing = false
	game.craft("fire")
	game.inventory.wood = 41
	expect(game.save_game(),"isolated save can be written")
	game.inventory.wood = 42
	expect(game.save_game(),"atomic save can replace an existing file on Windows")
	var saved_time: float = game.minutes
	game.inventory.wood = 0
	game.minutes = 0
	expect(game.load_game() and game.inventory.wood == 42 and game.minutes == saved_time and game.fire_lit(),"save restores supplies, time and burning campfire")
	var file := FileAccess.open(TEST_SAVE,FileAccess.WRITE)
	file.store_string('{"version":1,"pos":[0,"invalid"]}')
	file.close()
	wood_after = game.inventory.wood
	expect(not game.load_game() and game.inventory.wood == wood_after,"malformed save is rejected without partial state mutation")
	game.testing = true
	if FileAccess.file_exists(TEST_SAVE): DirAccess.remove_absolute(TEST_SAVE)
	if FileAccess.file_exists(TEST_SAVE+".tmp"): DirAccess.remove_absolute(TEST_SAVE+".tmp")
	root.remove_child(game)
	game.free()
	print("SURVIVAL TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
