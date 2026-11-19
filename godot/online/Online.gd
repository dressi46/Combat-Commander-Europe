extends Node

signal changed
const LOBBY := "res://online/Lobby.tscn"
const BOARD := "res://scenes/Partita.tscn"
const PUBLIC_URL := "wss://lobby.dressi.es"
var nickname := ""
var proof := ""
var profile_id := ""
var endpoint := PUBLIC_URL
var socket: WebSocketPeer
var lobby_ready := false
var greeted := false
var listed: Array = []
var code := ""
var token := ""
var status := ""
var revision := -1
var counts := {}
var waiting := false
var in_match := false
var disconnected_player := false
var recent: Array = []
var started := 0


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load("user://lobby.cfg") == OK:
		endpoint = config.get_value("network", "endpoint", PUBLIC_URL)
	if OS.has_feature("web") and endpoint == PUBLIC_URL:
		var loc = JavaScriptBridge.get_interface("window").location
		if loc.protocol == "https:":
			endpoint = "wss://%s" % str(loc.host) if loc.hostname == "lobby.dressi.es" else PUBLIC_URL
		elif loc.protocol == "http:":
			endpoint = "ws://%s:%d" % [str(loc.hostname), 8791 if str(loc.port) == "8781" else 8790]


func _load_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://players.cfg")
	nickname = cfg.get_value(endpoint, "name", "")
	proof = cfg.get_value(endpoint, "proof", "")


func connect_lobby(url: String, name_value: String = "") -> void:
	if socket != null:
		return
	if url != endpoint:
		_clear_seat()
	endpoint = url
	_load_profile()
	nickname = name_value.strip_edges()
	if proof.is_empty():
		proof = Crypto.new().generate_random_bytes(32).hex_encode()
	var profile := ConfigFile.new()
	profile.load("user://players.cfg")
	profile.set_value(endpoint, "name", nickname)
	profile.set_value(endpoint, "proof", proof)
	if profile.save("user://players.cfg") != OK:
		status = "Cannot save profile"
		changed.emit()
		return
	var cfg := ConfigFile.new()
	cfg.set_value("network", "endpoint", endpoint)
	cfg.save("user://lobby.cfg")
	greeted = false
	lobby_ready = false
	status = "Connecting…"
	started = Time.get_ticks_msec()
	socket = WebSocketPeer.new()
	socket.inbound_buffer_size = 1048576
	if socket.connect_to_url(url) != OK:
		_lost()
	changed.emit()


func _process(_delta: float) -> void:
	if socket == null:
		return
	socket.poll()
	match socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not greeted:
				greeted = true
				send({"op": "hello", "version": 1, "locale": L10n.locale, "name": nickname, "proof": proof})
			while socket != null and socket.get_available_packet_count() > 0:
				var msg: Variant = bytes_to_var(socket.get_packet())
				if msg is Dictionary:
					_receive(msg)
		WebSocketPeer.STATE_CLOSED:
			_lost()
	if socket != null and not lobby_ready and Time.get_ticks_msec() - started > 12000:
		_lost()


func send(msg: Dictionary) -> void:
	if socket != null and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(msg))


func _receive(msg: Dictionary) -> void:
	match msg.get("type"):
		"profile":
			profile_id = msg.id
		"rooms":
			var first := not lobby_ready
			lobby_ready = true
			listed = msg.rooms
			if first:
				status = ""
				if token != "":
					send({"op": "resume", "code": code, "token": token})
		"seat":
			code = msg.code
			token = msg.token
			status = "Waiting for another player"
		"state":
			var first := not in_match
			in_match = true
			disconnected_player = msg.paused
			waiting = false
			revision = msg.revision
			counts = msg.counts
			recent = msg.events
			for ev in recent:
				if ev.has("card"):
					ev.card = SaveGame._card_from_dict(ev.card)
			Game.receive_match(msg)
			if first:
				get_tree().change_scene_to_file(BOARD)
			else:
				show_events()
		"error":
			status = msg.key
			if not lobby_ready:
				_close()
			if status == "Session unavailable":
				_clear_seat()
			waiting = false
			if in_match:
				Game.decision_changed.emit()
		"ended":
			_clear_seat()
			status = msg.key
			_go_lobby()
	changed.emit()


func show_events() -> void:
	for ev in recent:
		Game._play_event(ev)
	recent = []
	if Game.flow != null and Game.flow.over:
		Game.game_over.emit(Game.flow.winner)


func choose(index: int) -> void:
	if waiting or disconnected_player:
		return
	waiting = true
	send({"op": "choose", "revision": revision, "index": index})
	Game.decision_changed.emit()


func _lost() -> void:
	_close()
	status = "Disconnected. Reconnect to resume." if token != "" else "Cannot reach lobby"
	_go_lobby()
	changed.emit()


func _go_lobby() -> void:
	if Game.mode == Game.Mode.ONLINE:
		Game.flow = null
		Game.mode = Game.Mode.VS_AI
		get_tree().change_scene_to_file(LOBBY)
	in_match = false


func _close() -> void:
	if socket != null:
		socket.close()
	socket = null
	lobby_ready = false
	greeted = false
	listed = []


func leave() -> void:
	if lobby_ready and code != "":
		send({"op": "leave"})
	_clear_seat()
	_go_lobby()
	changed.emit()


func exit_lobby() -> void:
	leave()
	_close()
	status = ""
	get_tree().change_scene_to_file("res://scenes/Home.tscn")


func _clear_seat() -> void:
	code = ""
	token = ""
	revision = -1
	waiting = false
	recent = []
