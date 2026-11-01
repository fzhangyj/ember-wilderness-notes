extends SceneTree
## Visual regression fixtures. Never writes a player save.
const Game = preload("res://scripts/game.gd")
var game: Node2D

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = Game.new()
	root.add_child(game)
	game.set_process(false)
	game.testing = true
	game.modal = ""
	game.pause_game = false
	var args := OS.get_cmdline_user_args()
	var fixture := args[0] if args.size() > 0 else "camp"
	var output := args[1] if args.size() > 1 else "res://artifacts/camp.png"
	game.structures = {"fire":true,"shelter":true,"reinforce":true}
	game.equipment = {"axe":true,"spear":true}
	game.fire_fuel = 840
	game.total_gathered = 42
	game.learned = ["fire","shelter","water","tools"]
	game.inventory = {"wood":12,"stone":6,"fiber":8,"berry":5,"raw_water":2,"water":3,"herb":2,"tuber":2,"meal":1}
	game.torches = 2
	game.toast_timer = 0
	game.minutes = 960
	match fixture:
		"night":
			game.minutes = 1210
			game.active_event = "wolf"
			game.event_deadline = 1280
			game.wolf_pos = game.player_pos+Vector2(230,-70)
			game.torch_minutes = 150
		"rain":
			game.minutes = 2270
			game.rain_until = 2760
			game.player_pos = game.CAMP+Vector2(-50,-5)
			game.panel = "camp"
		"guide": game.modal = "guide"; game.hud.selected_guide = 1
		"help": game.modal = "help"
		"inventory": game.panel = "inventory"
		"tools": game.craft_tab = "工具"
		"victory": game.victory = true; game.modal = "ending"; game.minutes = 4800
	game.hud.refresh(1)
	for i in range(8):
		game.world.queue_redraw()
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output)
	print("VISUAL FIXTURE ",fixture," ",result)
	game.queue_free()
	await process_frame
	await process_frame
	quit(result)
