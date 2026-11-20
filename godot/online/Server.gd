extends Node
## Dedicated lobby. Each connection owns at most one seat, each room one Flow.
const GRACE_SECONDS := 604800  # 7 giorni: si può riprendere anche dopo molto tempo
const ROOM_DIR := "user://rooms/"
const MAX_CLIENTS := 80
const MAX_ROOMS := 32
var listener := TCPServer.new()
var peers := {}
var rooms := {}
var catalogs := {}
var codec := MatchText.new()
var crypto := Crypto.new()
var serial := 0


func _ready() -> void:
	var port := int(OS.get_environment("PORT")) if OS.has_environment("PORT") else 8790
	var bind_address := OS.get_environment("LOBBY_BIND")
	for code in L10n.builtins:
		catalogs[code] = L10n._read_catalog(code)
	if listener.listen(port, bind_address if bind_address != "" else "*") != OK:
		push_error("Cannot listen on port %d" % port)
		get_tree().quit(1)
		return
	_load_rooms()
	print("Lobby listening on port %d" % port)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	while listener.is_connection_available():
		var tcp := listener.take_connection()
		if peers.size() >= MAX_CLIENTS:
			tcp.disconnect_from_host()
			continue
		var socket := WebSocketPeer.new()
		socket.inbound_buffer_size = 8192
		socket.outbound_buffer_size = 1048576
		if socket.accept_stream(tcp) != OK:
			continue
		serial += 1
		peers[serial] = {"socket": socket, "room": "", "seat": -1, "locale": "",
			"window": now, "requests": 0, "created": now}
	for id in peers.keys():
		var p: Dictionary = peers[id]
		var ws: WebSocketPeer = p.socket
		ws.poll()
		if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_disconnect(id)
			continue
		if p.locale == "" and now - int(p.created) > 10000:
			ws.close()
		if now - int(p.window) >= 1000:
			p.window = now
			p.requests = 0
		while ws.get_available_packet_count() > 0 and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			var packet := ws.get_packet()
			p.requests += 1
			if packet.size() > 2048 or p.requests > 24 or not ws.was_string_packet():
				ws.close(1008)
				break
			var msg: Variant = JSON.parse_string(packet.get_string_from_utf8())
			if msg is Dictionary:
				_request(id, msg)
	for code in rooms.keys():
		var r: Dictionary = rooms[code]
		if int(r.get("expires_at", 0)) > 0 and Time.get_unix_time_from_system() >= int(r.expires_at):
			_end_room(code, "Room expired")


func _room_path(code: String) -> String:
	return ROOM_DIR + code + ".json"


## Salva la stanza e la partita (seme + decisioni) su disco, così il server
## può ripartire senza perdere le partite in corso.
func _save_room(r: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ROOM_DIR)
	var data := {
		"version": 1,
		"code": r.code,
		"scenario": int(r.scenario),
		"host_side": int(r.host_side),
		"open": bool(r.open),
		"revision": int(r.revision),
		"tokens": r.tokens,
		"expires_at": int(r.get("expires_at", 0)),
		"seed": r.flow.seed_value if r.flow != null else 0,
		"history": r.flow.history if r.flow != null else [],
	}
	var file := FileAccess.open(_room_path(String(r.code)), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()


func _load_rooms() -> void:
	DirAccess.make_dir_recursive_absolute(ROOM_DIR)
	var dir := DirAccess.open(ROOM_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var file := FileAccess.open(ROOM_DIR + file_name, FileAccess.READ)
		if file == null:
			continue
		var data: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if not (data is Dictionary):
			continue
		var code := String(data.get("code", ""))
		if code == "":
			continue
		var tokens: Variant = data.get("tokens", ["", ""])
		var r := {
			"code": code,
			"scenario": int(data.get("scenario", 1)),
			"host_side": int(data.get("host_side", 0)),
			"open": bool(data.get("open", false)),
			"ids": [0, 0],
			"tokens": tokens if tokens is Array and (tokens as Array).size() == 2 else ["", ""],
			"flow": null,
			"revision": int(data.get("revision", 0)),
			"expires_at": int(data.get("expires_at", 0)),
		}
		var saved_history: Variant = data.get("history", [])
		if saved_history is Array and not (saved_history as Array).is_empty():
			r.flow = Flow.replay(int(r.scenario), int(r.host_side), int(data.get("seed", 0)), saved_history, false, false)
		rooms[code] = r
	print("Rooms restored: %d" % rooms.size())


func _send(id: int, msg: Dictionary) -> void:
	if peers.has(id):
		var ws: WebSocketPeer = peers[id].socket
		if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			if ws.send(var_to_bytes(msg)) != OK:
				ws.close(1011)


func _error(id: int, key: String) -> void:
	_send(id, {"type": "error", "key": key})


# One file per canonical name. The server serializes requests on the main thread.
func _profile(id: int, msg: Dictionary) -> bool:
	if not msg.has("name"): # v1 clients have guest identities for this connection.
		peers[id].display = "· %08x" % id
		return true
	var name_value: Variant = msg.get("name")
	var key: Variant = msg.get("proof")
	if not name_value is String or not key is String or key.length() != 64 or not key.is_valid_hex_number(false):
		_error(id, "Invalid player profile")
		return false
	var nick: String = name_value.strip_edges()
	if nick.length() < 2 or nick.length() > 24 or not nick.is_valid_ascii_identifier():
		_error(id, "Use 2–24 letters, digits or underscores, starting with a letter or underscore")
		return false
	var path := "user://players/" + nick.to_lower().sha256_text()
	var signature: String = key.sha256_text()
	var uid: String
	if FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary or data.get("signature") != signature:
			_error(id, "Username already registered")
			return false
		uid = data.id
	else:
		DirAccess.make_dir_recursive_absolute("user://players")
		uid = crypto.generate_random_bytes(16).hex_encode()
		var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
		if file == null:
			_error(id, "Cannot save profile")
			return false
		file.store_string(JSON.stringify({"id": uid, "signature": signature}))
		file.close()
		if DirAccess.rename_absolute(path + ".tmp", path) != OK:
			_error(id, "Cannot save profile")
			return false
	peers[id].display = nick
	_send(id, {"type": "profile", "id": uid, "name": nick})
	return true


func _list(id: int) -> void:
	var waiting := []
	for r in rooms.values():
		if r.open and r.flow == null and r.ids[0] != 0:
			waiting.append({"code": r.code, "scenario": r.scenario, "side": r.host_side, "host": peers[r.ids[0]].display})
	_send(id, {"type": "rooms", "rooms": waiting})


func _refresh_lobby() -> void:
	for id in peers:
		if peers[id].room == "" and peers[id].locale != "":
			_list(id)


func _request(id: int, msg: Dictionary) -> void:
	var p: Dictionary = peers[id]
	var op: Variant = msg.get("op")
	if p.locale == "":
		if op == "hello" and msg.get("version") == 1 and catalogs.has(msg.get("locale")):
			if not _profile(id, msg):
				return
			var preferred: Variant = msg.get("preferred_locale")
			p.locale = preferred if catalogs.has(preferred) else msg.locale
			_list(id)
		else:
			_error(id, "Incompatible client")
		return
	if op == "list" and p.room == "":
		_list(id)
	elif op == "create" and p.room == "":
		var n: Variant = msg.get("scenario")
		if not _integer(n, 1, 24) or not _integer(msg.get("side"), 0, 1) or typeof(msg.get("open")) != TYPE_BOOL or rooms.size() >= MAX_ROOMS:
			_error(id, "Cannot create room")
			return
		var code := crypto.generate_random_bytes(12).hex_encode()
		var r := {"code": code, "scenario": int(n), "host_side": int(msg.side), "open": msg.open,
			"ids": [id, 0], "tokens": [_token(), ""], "flow": null, "revision": 0, "expires_at": 0}
		rooms[code] = r
		_seat(id, r, 0)
		_save_room(r)
		_refresh_lobby()
	elif op == "join" and p.room == "":
		var r: Dictionary = rooms.get(msg.get("code"), {})
		if r.is_empty() or r.flow != null or r.ids[0] == 0:
			_error(id, "Room unavailable")
			return
		r.tokens[1] = _token()
		_seat(id, r, 1)
		L10n.match_text = codec
		r.flow = Flow.new_game(r.scenario, r.host_side)
		r.flow.start()
		L10n.match_text = null
		_publish(r)
		_save_room(r)
		_refresh_lobby()
	elif op == "resume" and p.room == "":
		var r: Dictionary = rooms.get(msg.get("code"), {})
		var token: Variant = msg.get("token")
		if r.is_empty() or not token is String or token == "" or not r.tokens.has(token):
			_error(id, "Session unavailable")
			return
		var slot: int = r.tokens.find(token)
		if r.ids[slot] != 0:
			_error(id, "Seat still connected")
			return
		_seat(id, r, slot)
		r.expires_at = 0
		if r.flow != null:
			_publish(r)
		_save_room(r)
		_refresh_lobby()
	elif op == "leave" and p.room != "":
		_end_room(p.room, "Player left the room")
	elif op == "choose" and p.room != "":
		var r: Dictionary = rooms[p.room]
		var f: Flow = r.flow
		if f == null or f.over or r.ids.has(0) or msg.get("revision") != r.revision or f.pending.get("who") != p.seat or not _integer(msg.get("index"), 0, f.pending.options.size()-1):
			_error(id, "Choice is no longer available")
			return
		L10n.match_text = codec
		f.answer(int(msg.index))
		L10n.match_text = null
		r.revision += 1
		_publish(r)


func _integer(value: Variant, lo: int, hi: int) -> bool:
	return (value is int or value is float) and value >= lo and value <= hi and floor(value) == value


func _token() -> String:
	return crypto.generate_random_bytes(32).hex_encode()


func _seat(id: int, r: Dictionary, slot: int) -> void:
	r.ids[slot] = id
	peers[id].room = r.code
	peers[id].seat = r.host_side if slot == 0 else 1 - int(r.host_side)
	_send(id, {"type": "seat", "code": r.code, "token": r.tokens[slot], "scenario": r.scenario})


func _publish(r: Dictionary) -> void:
	for id in r.ids:
		if id != 0:
			var p: Dictionary = peers[id]
			var view := MatchView.make(r.flow, p.seat, r.revision, codec, catalogs[p.locale])
			view.paused = r.ids.has(0)
			_send(id, view)
	r.flow.events.clear()
	_save_room(r)


func _disconnect(id: int) -> void:
	var p: Dictionary = peers[id]
	peers.erase(id)
	if rooms.has(p.room):
		var r: Dictionary = rooms[p.room]
		r.ids[r.ids.find(id)] = 0
		r.expires_at = int(Time.get_unix_time_from_system()) + GRACE_SECONDS
		if r.flow != null:
			_publish(r)
		_save_room(r)
		_refresh_lobby()


func _end_room(code: String, reason: String) -> void:
	var r: Dictionary = rooms[code]
	rooms.erase(code)
	DirAccess.remove_absolute(_room_path(code))
	for id in r.ids:
		if peers.has(id):
			peers[id].room = ""
			peers[id].seat = -1
			_send(id, {"type": "ended", "key": reason})
	_refresh_lobby()
