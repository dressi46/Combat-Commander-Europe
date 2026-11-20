extends Node
const BattleReport = preload("res://scenes/BattleReport.gd")

func _ready() -> void:
	var flow := Flow.new_game(1, Flow.AX, 123)
	Game.flow = flow
	var s := flow.s
	s.objective_chits = [{"letter":"A", "owner":-1, "revealed":true},
		{"letter":"B","owner":Flow.AX,"revealed":false}, {"letter":"C","owner":Flow.AL,"revealed":false}]
	var victim: Unit = flow.men(Flow.AL)[0]
	var points := GameState.elimination_vp(victim) * (2 if s.chit_double_elim else 1)
	s.eliminate_unit(victim.id)
	flow.update_objectives()
	var board = preload("res://scenes/Partita.tscn").instantiate()
	add_child(board)
	if s.vp_sources.get("Enemy losses") != [points, 0] or s.graves.is_empty():
		return _fail("Unattributed elimination")
	var restored := SaveGame._state_from_dict(SaveGame._state_to_dict(s))
	if restored.vp_sources != s.vp_sources or restored.graves.size() != s.graves.size():
		return _fail("Lost scoring or casualty history")
	for side in [Flow.AX, Flow.AL]:
		var view := MatchView.make(flow, side, 0, MatchText.new(), {})
		var letters: Array = view.board.objective_chits.map(func(c): return c.letter)
		if letters != ["A", "B" if side == Flow.AX else "C"]:
			return _fail("Wrong private objective projection")
	if not Tema.body_font().get_string_size("→").x > 0 or not Tema.body_font().fallbacks[0].has_char(0x2192):
		return _fail("Missing movement symbol")
	board._fill_controls()
	if board.controls.get_popup().get_item_count() < 7:
		return _fail("Missing board controls")
	board.status_strip._inspect("Objectives")
	var dialog: BattleReport = null
	for node in board.get_children():
		if node is BattleReport:
			dialog = node
	if dialog == null or not dialog.visible:
		return _fail("Objective detail did not open")
	var tiles := dialog.contents.get_children().filter(func(c): return c is Button)
	if tiles.size() != 1 or tiles[0].text.contains(" — "):
		return _fail("Private counter should be face down")
	tiles[0].button_pressed = true
	if tiles[0].text != ObjectiveChits._describe(ObjectiveChits._find("B")):
		return _fail("Own counter did not turn over")
	dialog.confirmed.emit()
	s.objective_chits.append({"letter":"D","owner":Flow.AX,"revealed":false})
	board.status_strip._inspect("Objectives")
	if board.active_report.contents.get_children().filter(func(c): return c is Button).size() != 2:
		return _fail("Second private counter missing")
	board.active_report.confirmed.emit()
	s.objective_chits.clear()
	board.status_strip._inspect("Objectives")
	if board.active_report.contents.get_children().any(func(c): return c is Button or c is Label):
		return _fail("Empty private section visible")
	board.active_report.confirmed.emit()
	board.status_strip._inspect("Clock")
	if board.active_report.contents.get_child(0).get_child_count() < 13:
		return _fail("Time track is incomplete")
	print("STATUS_RESULT: PASS")
	get_tree().quit()


func _fail(details: String) -> void:
	printerr(details)
	get_tree().quit(1)
