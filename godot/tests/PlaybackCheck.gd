extends Node
const BattleReport = preload("res://scenes/BattleReport.gd")
## Exercise the visible report, its pause boundary, and the movement preview.
func _ready() -> void:
	Game.flow = Flow.new_game(1, Flow.AX, 123)
	Game.flow.explain_events = true
	var board = preload("res://scenes/Partita.tscn").instantiate()
	add_child(board)
	var f := Game.flow
	var event_card := Card.new()
	event_card.event_name = "NEBBIA DI GUERRA"
	f.deck(Flow.AX).append(event_card)
	await f._event(Flow.AX)
	var report: Dictionary = f.events.back()
	if report.get("kind") != "event_report" or report.outcomes.is_empty():
		return _fail("Event report lost the resolved effect")
	Game._queue.assign([report, {"kind": "move", "text": "next"}])
	Game.skip()
	if not Game.paused or Game._queue.size() != 1:
		return _fail("Skipping passed the event dialog")
	var dialog: BattleReport = null
	for child in board.get_children():
		if child is BattleReport:
			dialog = child
	if dialog == null or not dialog.visible:
		return _fail("Missing event dialog")
	dialog.confirmed.emit()
	if Game.paused:
		return _fail("Acknowledgement did not resume playback")
	var movement := Flow.new_game(1, Flow.AX, 123)
	var unit: Unit = movement.men(Flow.AX)[0]
	for h in HexGrid.neighbors(unit.q, unit.r):
		if movement.in_map(h):
			movement.s.hex_at(h.x, h.y).has_road = true
	movement._move_stack(Flow.AX, [unit])
	var steps := 0
	for option in movement.pending.get("options", []):
		if option.id == "step":
			steps += 1
			if option.road_gain != 1 or option.remaining != movement.pending.left - option.cost + 1:
				return _fail("Wrong road movement preview")
	if steps == 0:
		return _fail("No previewed step")
	movement.answer(movement.pending.options.size() - 1)
	print("PLAYBACK_RESULT: PASS")
	get_tree().quit()


func _fail(detail: String) -> void:
	printerr(detail)
	get_tree().quit(1)
