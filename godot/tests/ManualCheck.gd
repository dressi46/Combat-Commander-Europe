extends Node
## Modalità manuale e layout mobile: l'IA si ferma a ogni decisione, il pulsante
## avanza di un solo passo, e i riquadri dadi/carta non si sovrappongono su mobile.
## Uso: godot --headless --path godot res://tests/ManualCheck.tscn

var answers := 0


func _ready() -> void:
	var was_manual := Game.manual
	var was_speed := Game.speed
	get_window().size = Vector2i(1280, 800)
	Game.speed = 30.0
	Game.manual = true
	Game.start_new_game(Flow.AX, 1, 1, Game.Mode.DEMO, 4242)
	Game.flow._answered.connect(func(): answers += 1)
	var board = preload("res://scenes/Partita.tscn").instantiate()
	add_child(board)
	# 1 · L'IA si ferma da sola alla prima decisione.
	if not await _wait_for(func(): return Game.manual_waiting(), 10.0):
		return _fail("Manual mode did not stop the AI", was_manual, was_speed)
	var stopped: Dictionary = Game.flow.pending
	if not board.step_btn.visible:
		return _fail("Next-step button not visible while waiting", was_manual, was_speed)
	board._fill_controls()
	if board.controls.get_popup().get_item_index(7) < 0:
		return _fail("Manual toggle missing from board controls", was_manual, was_speed)
	# 2 · Senza input non avanza.
	await get_tree().create_timer(0.4).timeout
	if not is_same(stopped, Game.flow.pending) or not Game.manual_waiting():
		return _fail("Manual mode advanced without input", was_manual, was_speed)
	# 3 · Un passo = una sola decisione dell'IA.
	var before := answers
	Game.manual_step()
	if not await _wait_for(func(): return Game.manual_waiting() or Game.flow.over, 10.0):
		return _fail("Manual step never reached the next stop", was_manual, was_speed)
	if answers != before + 1:
		return _fail("Manual step answered %d decisions instead of 1" % (answers - before), was_manual, was_speed)
	# 4 · «Mostra subito» non oltrepassa la sosta manuale.
	before = answers
	Game.manual_step()
	Game.skip()
	if not Game.manual_waiting():
		return _fail("Skip passed the manual stop", was_manual, was_speed)
	if answers != before + 1:
		return _fail("Skip answered more than one decision", was_manual, was_speed)
	# 5 · Disattivando la modalità manuale l'IA riprende da sola.
	Game.speed = was_speed
	before = answers
	Game.set_manual(false)
	if not await _wait_for(func(): return answers > before, 10.0):
		return _fail("Disabling manual mode did not resume the AI", was_manual, was_speed)
	# 6 · Layout mobile: testo sotto i dadi, niente sovrapposizioni, cronaca nascosta.
	get_window().size = Vector2i(420, 800)
	board._layout_for_screen()
	if not board.mobile or not board.mobile_tabs.visible or board.log_box.visible:
		return _fail("Mobile layout not applied", was_manual, was_speed)
	if board.dice_lbl.get_parent() != board.dice_col:
		return _fail("Mobile dice text not stacked", was_manual, was_speed)
	board._on_event({ "kind": "roll", "text": "test 3+4 = 7", "dice": [3, 4], "who": Flow.AX })
	var card := Card.new()
	board._on_event({ "kind": "order", "text": "test card", "card": card, "who": Flow.AX })
	await get_tree().process_frame
	await get_tree().process_frame
	var dice_rect := Rect2(board.dice_box.global_position, board.dice_box.size)
	var played_rect := Rect2(board.played_box.global_position, board.played_box.size)
	if dice_rect.intersects(played_rect):
		return _fail("Dice and played card overlap on mobile", was_manual, was_speed)
	if dice_rect.size.x > board.board_holder.size.x:
		return _fail("Dice panel wider than the mobile board", was_manual, was_speed)
	# 7 · Ritorno al desktop: tutto come prima.
	get_window().size = Vector2i(1280, 800)
	board._layout_for_screen()
	if board.mobile or board.dice_lbl.get_parent() != board.dice_row or not board.log_box.visible:
		return _fail("Desktop layout not restored", was_manual, was_speed)
	Game.manual = was_manual
	Game.speed = was_speed
	Game.save_settings()
	print("MANUAL_RESULT: PASS")
	get_tree().quit()


func _wait_for(cond: Callable, timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await get_tree().create_timer(0.03).timeout
	return cond.call()


func _fail(detail: String, was_manual: bool, was_speed: float) -> void:
	Game.manual = was_manual
	Game.speed = was_speed
	Game.save_settings()
	printerr(detail)
	get_tree().quit(1)
