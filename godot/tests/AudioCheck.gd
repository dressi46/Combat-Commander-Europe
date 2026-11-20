extends Node
## Audio: buses separati, volumi indipendenti, musica in loop e suoni di fase.
## Uso: godot --headless --path godot res://tests/AudioCheck.tscn

func _ready() -> void:
	var was_music := Game.music_percent
	var was_sound := Game.sound_percent
	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if music_bus < 0 or sfx_bus < 0:
		return _fail("Missing audio buses", was_music, was_sound)
	Game.set_music_percent(50)
	Game.set_sound_percent(80)
	if not is_equal_approx(AudioServer.get_bus_volume_db(music_bus), linear_to_db(0.5)):
		return _fail("Music volume not applied", was_music, was_sound)
	if not is_equal_approx(AudioServer.get_bus_volume_db(sfx_bus), linear_to_db(0.8)):
		return _fail("SFX volume not applied", was_music, was_sound)
	Audio.play("click")
	Audio.play_music("menu")
	await get_tree().create_timer(0.25).timeout
	if not Audio._music_a.playing and not Audio._music_b.playing:
		return _fail("Music did not start", was_music, was_sound)
	for kind in ["turn", "order", "fire", "roll", "move", "melee", "kill", "bad", "good", "time", "fate", "init", "miss"]:
		Game.chronicle.emit({"kind": kind, "text": "test", "fx": "fire", "pieces": []})
	Audio.stop_music()
	Game.music_percent = was_music
	Game.sound_percent = was_sound
	Audio.apply_volumes()
	Game.save_settings()
	print("AUDIO_RESULT: PASS")
	get_tree().quit()


func _fail(detail: String, was_music: int, was_sound: int) -> void:
	Game.music_percent = was_music
	Game.sound_percent = was_sound
	Audio.apply_volumes()
	Game.save_settings()
	printerr(detail)
	get_tree().quit(1)
