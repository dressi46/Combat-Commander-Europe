extends Node
## Determinismo: la misma semilla + las mismas decisiones deben reproducir el
## mismo estado. Es la base del guardado por replay.
## Uso: godot --headless --path godot res://tests/ReplayCheck.tscn

func _ready() -> void:
	for scenario in [1, 7, 13]:
		for seed_value in [123, 98765]:
			if not _check(scenario, seed_value):
				return
	print("REPLAY_RESULT: PASS")
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


func _check(scenario: int, seed_value: int) -> bool:
	var a := Flow.new_game(scenario, Flow.AX, seed_value)
	var bot := Bot.new(a, 2, seed_value + 1)
	a.start()
	var steps := 0
	while not a.over and steps < 4000:
		if a.pending.is_empty():
			return _fail("BLOCCO scenario %d" % scenario)
		a.answer(bot.pick())
		a.events.clear()
		steps += 1
	if not a.over:
		return _fail("NON FINITA scenario %d" % scenario)
	var history := a.history.duplicate(true)
	var expected := SaveGame._state_to_dict(a.s)
	expected.erase("log")

	var b := Flow.new_game(scenario, Flow.AX, seed_value)
	b.start()
	for entry in history:
		if b.pending.is_empty():
			return _fail("Replay bloccato allo scenario %d, passo %s" % [scenario, entry])
		if int(b.pending["who"]) != int(entry["who"]) or String(b.pending["kind"]) != String(entry["kind"]):
			return _fail("Replay divergente allo scenario %d: atteso %s/%s, trovato %s/%s" % [
				scenario, entry["who"], entry["kind"], b.pending["who"], b.pending["kind"]])
		b.answer(int(entry["index"]))
		b.events.clear()
	var actual := SaveGame._state_to_dict(b.s)
	actual.erase("log")
	if not _deep_equal(expected, actual):
		return _fail("Stato divergente allo scenario %d (seed %d)" % [scenario, seed_value])
	print("  scenario %2d seed %d: %d decisioni riprodotte" % [scenario, seed_value, history.size()])
	return true


func _fail(detail: String) -> bool:
	printerr(detail)
	get_tree().quit(1)
	return false
