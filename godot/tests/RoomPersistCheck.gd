extends Node
## Persistenza delle sale online: salva una stanza con la partita, simula il
## riavvio del server e verifica che la partita venga ricostruita identica.
## Uso: godot --headless --path godot res://tests/RoomPersistCheck.tscn

const CODE := "persist-test"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://rooms")
	var flow := Flow.new_game(3, Flow.AX)
	flow.start()
	for _i in 12:
		if flow.pending.is_empty():
			break
		flow.answer(0)
	var history_size := flow.history.size()
	var expected := SaveGame._state_to_dict(flow.s)
	expected.erase("log")
	var server = preload("res://online/Server.gd").new()
	var room := {
		"code": CODE, "scenario": 3, "host_side": Flow.AX, "open": false,
		"ids": [0, 0], "tokens": ["tok-a", "tok-b"], "flow": flow,
		"revision": 7, "expires_at": 0,
	}
	server._save_room(room)
	# Nuovo server: legge solo da disco.
	server.rooms.clear()
	server._load_rooms()
	if not server.rooms.has(CODE):
		return _fail("Room not restored")
	var restored: Dictionary = server.rooms[CODE]
	if restored.flow == null:
		return _fail("Flow not replayed")
	if int(restored.revision) != 7 or restored.tokens != ["tok-a", "tok-b"]:
		return _fail("Room metadata lost")
	if restored.flow.history.size() != history_size:
		return _fail("History size changed")
	var actual := SaveGame._state_to_dict(restored.flow.s)
	actual.erase("log")
	if not _deep_equal(expected, actual):
		return _fail("Restored state differs")
	DirAccess.remove_absolute(server._room_path(CODE))
	print("ROOM_PERSIST_RESULT: PASS (%d decisioni)" % history_size)
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
	printerr(detail)
	get_tree().quit(1)
