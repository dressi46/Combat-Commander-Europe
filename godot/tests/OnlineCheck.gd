extends Node
## Run against a disposable lobby listening on localhost (see online/README.md).
var url := "ws://127.0.0.1:18790"
var clients: Array[WebSocketPeer] = []
var inbox: Array = []
var deadline: int
var failed := false


func _ready() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		url = OS.get_cmdline_user_args()[0]
	deadline = Time.get_ticks_msec() + 20000
	_run()


func _check(ok: bool, detail: String) -> void:
	if not ok and not failed:
		failed = true
		printerr("ONLINE_FAIL: ", detail)
		get_tree().quit(1)


func _process(_delta: float) -> void:
	for i in clients.size():
		var ws := clients[i]
		ws.poll()
		while ws.get_available_packet_count():
			inbox[i].append(bytes_to_var(ws.get_packet()))
	if Time.get_ticks_msec() > deadline:
		_check(false, "Timed out waiting for the lobby")


func _client(locale: String) -> int:
	var socket := WebSocketPeer.new()
	socket.inbound_buffer_size = 1048576
	var i := clients.size()
	clients.append(socket)
	inbox.append([])
	socket.connect_to_url(url)
	while socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		await get_tree().process_frame
	_send(i, {"op": "hello", "version": 1, "locale": locale})
	return i


func _send(i: int, data: Dictionary) -> void:
	clients[i].send_text(JSON.stringify(data))


func _next(i: int, type: String) -> Dictionary:
	while true:
		for j in inbox[i].size():
			if inbox[i][j].type == type:
				return inbox[i].pop_at(j)
		await get_tree().process_frame
	return {}


func _run() -> void:
	var a := await _client("es")
	var b := await _client("en")
	await _next(a, "rooms")
	await _next(b, "rooms")
	_send(a, {"op": "create", "open": true, "scenario": 3, "side": 1})
	var public_seat := await _next(a, "seat")
	var listings := await _next(b, "rooms")
	_check(listings.rooms.any(func(r): return r.code == public_seat.code), "Open room missing")
	_send(a, {"op": "leave"})
	await _next(a, "ended")
	await _next(b, "rooms")
	_send(a, {"op": "create", "open": false, "scenario": 1, "side": 0})
	var host := await _next(a, "seat")
	listings = await _next(b, "rooms")
	_check(not listings.rooms.any(func(r): return r.code == host.code), "Private room listed")
	_send(b, {"op": "join", "code": host.code})
	await _next(b, "seat")
	var av := await _next(a, "state")
	var bv := await _next(b, "state")
	_check(not av.board.has("russian_hand") and not bv.board.has("german_hand"), "Opponent hand exposed")
	_check(not av.board.has("german_deck") and [av,bv].all(func(view): return view.board.objective_chits.all(func(c): return c.revealed or int(c.owner) == int(view.seat))), "Hidden draw data exposed")
	_check(av.events[0].text.contains("Escenario") and bv.events[0].text.contains("Scenario"), "Locale mismatch")
	var active: int = av.pending.who
	var seats := [a,b]
	_check(not [av,bv][1-active].pending.has("options"), "Opponent choices exposed")
	_send(seats[1-active], {"op": "choose", "revision": 0, "index": 0})
	await _next(seats[1-active], "error")
	_send(seats[active], {"op": "choose", "revision": 0, "index": 99999})
	await _next(seats[active], "error")
	clients[a].close()
	var paused := await _next(b, "state")
	_check(paused.paused, "Disconnection did not pause")
	a = await _client("es")
	await _next(a, "rooms")
	_send(a, {"op":"resume", "code":host.code, "token":host.token})
	await _next(a, "seat")
	av = await _next(a, "state")
	bv = await _next(b, "state")
	_check(not av.paused and av.revision == 0, "Resume lost the decision")
	seats = [a,b]
	for turn in 20:
		active = av.pending.who
		var options: Array = [av,bv][active].pending.options
		_check(not options.is_empty(), "No legal options")
		_send(seats[active], {"op":"choose", "revision":av.revision, "index":0})
		av = await _next(a, "state")
		bv = await _next(b, "state")
		_check(av.revision == turn+1 and av.revision == bv.revision, "Revision mismatch")
		if turn == 0:
			_send(seats[av.pending.who], {"op":"choose", "revision":0, "index":0})
			await _next(seats[av.pending.who], "error")
		if av.over:
			break
	_send(b, {"op":"leave"})
	await _next(a, "ended")
	if not failed:
		print("ONLINE_RESULT: PASS")
	get_tree().quit(int(failed))
