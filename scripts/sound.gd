extends Node
## Short original synthesized cues, generated locally. Ambience is deliberately quiet.
var enabled := true
var player: AudioStreamPlayer
var ambient: AudioStreamPlayer

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.volume_db = -17
	add_child(player)
	ambient = AudioStreamPlayer.new()
	ambient.volume_db = -30
	add_child(ambient)
	if DisplayServer.get_name() != "headless":
		ambient.stream = create_ambience()
		ambient.play()

func toggle() -> void:
	enabled = not enabled
	ambient.stream_paused = not enabled

func play_effect(kind: String) -> void:
	if not enabled or DisplayServer.get_name() == "headless": return
	var length := 0.18
	var frequency := 520.0
	match kind:
		"craft": frequency = 660.0; length = 0.35
		"consume": frequency = 390.0; length = 0.24
		"warning": frequency = 180.0; length = 0.65
	var rate := 22050
	var data := PackedByteArray()
	data.resize(int(rate*length)*2)
	for i in range(int(rate*length)):
		var t := float(i)/rate
		var envelope := sin(PI*t/length)*exp(-t*8)
		var f: float = frequency*(1.5 if kind == "craft" and t > 0.13 else 1.0)
		var value := sin(TAU*f*t)*envelope*0.34
		data.encode_s16(i*2,int(value*32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	player.stream = stream
	player.play()

func create_ambience() -> AudioStreamWAV:
	var rate := 22050
	var duration := 12.0
	var data := PackedByteArray()
	data.resize(int(rate*duration)*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var previous := 0.0
	for i in range(int(rate*duration)):
		var t := float(i)/rate
		previous = previous*0.97 + rng.randf_range(-1,1)*0.03
		var value := previous*0.27
		for start in [1.3,1.65,5.7,8.9]:
			var bird: float = t-start
			if bird > 0 and bird < 0.19:
				value += sin(TAU*(1800*bird+1900*bird*bird))*sin(PI*bird/0.19)*0.11
		# Fade the loop boundary so the noise cannot click.
		value *= minf(1,minf(t*8,(duration-t)*8))
		data.encode_s16(i*2,int(clampf(value,-1,1)*32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(rate*duration)
	return stream
