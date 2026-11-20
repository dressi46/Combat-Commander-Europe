extends Node

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
	var dialog: AcceptDialog = null
	for node in board.get_children():
		if node is AcceptDialog:
			dialog = node
	if dialog == null or not dialog.visible:
		return _fail("Objective detail did not open")
	print("STATUS_RESULT: PASS")
	get_tree().quit()


func _fail(details: String) -> void:
	printerr(details)
	get_tree().quit(1)
