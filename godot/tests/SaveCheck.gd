extends Node
## Salvataggio/caricamento: gioca, salva, ricarica e verifica che lo stato sia
## identico e che la partita possa continuare senza errori.
## Uso: godot --headless --path godot res://tests/SaveCheck.tscn

const PATH := "user://saves/test-save.json"


func _ready() -> void:
	Game.autosave_enabled = false
	DirAccess.make_dir_recursive_absolute(SaveGame.SAVE_DIR)
	Game.manual = false
	Game.speed = 30.0
	Game.start_new_game(Flow.AX, 7, 2, Game.Mode.VS_AI, 4242)
	var helper := Bot.new(Game.flow, 2, 99)
	var steps := 0
	while steps < 60 and not Game.flow.over:
		var p := Game.pending()
		if p.is_empty():
			await get_tree().create_timer(0.02).timeout
			continue
		Game.choose(helper.pick())
		steps += 1
		await get_tree().create_timer(0.02).timeout
	var expected := SaveGame._state_to_dict(Game.flow.s)
	expected.erase("log")
	var decisions := Game.flow.history.size()

	if not SaveGame.save_game(Game.flow, Game.mode, Game.difficulty, PATH):
		return _fail("Save failed")
	if not Game.load_game(PATH):
		return _fail("Load failed")
	if Game.flow.history.size() != decisions:
		return _fail("History size changed: %d != %d" % [Game.flow.history.size(), decisions])
	var actual := SaveGame._state_to_dict(Game.flow.s)
	actual.erase("log")
	if not _deep_equal(expected, actual):
		for key in expected:
			if not _deep_equal(expected[key], actual[key]):
				printerr("State differs at key: ", key)
				break
		return _fail("Loaded state differs")
	# Continua un'altra decisione dopo il caricamento.
	var helper2 := Bot.new(Game.flow, 2, 77)
	var before := Game.flow.history.size()
	for _i in 20:
		var p := Game.pending()
		if not p.is_empty():
			Game.choose(helper2.pick())
			break
		await get_tree().create_timer(0.05).timeout
	if Game.flow.history.size() <= before:
		return _fail("Game did not continue after load")
	DirAccess.remove_absolute(PATH)
	Game.speed = 1.0
	print("SAVE_RESULT: PASS (%d decisioni salvate)" % decisions)
	get_tree().quit()


func _deep_equal(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not _deep_equal(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _deep_equal(a[i], b[i]):
				return false
		return true
	return is_same(a, b)


func _fail(detail: String) -> void:
	Game.speed = 1.0
	printerr(detail)
	get_tree().quit(1)
