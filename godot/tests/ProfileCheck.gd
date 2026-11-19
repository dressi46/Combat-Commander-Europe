extends Node

func _ready() -> void:
	var server := preload("res://online/Server.gd").new()
	var ws := WebSocketPeer.new()
	server.peers[1] = {"socket": ws}
	var proof := Crypto.new().generate_random_bytes(32).hex_encode()
	var nickname := "Player_" + proof.left(12)
	var hello := {"name": nickname, "proof": proof}
	var accepted: bool = server._profile(1, hello) and server._profile(1, hello)
	hello.name = nickname.to_upper()
	hello.proof = "a".repeat(64)
	var duplicate: bool = server._profile(1, hello)
	hello.name = "!"
	var invalid: bool = server._profile(1, hello)
	DirAccess.remove_absolute("user://players/" + nickname.to_lower().sha256_text())
	server.free()
	if not accepted or duplicate or invalid:
		printerr("PROFILE_FAIL")
		get_tree().quit(1)
	else:
		print("PROFILE_OK")
		get_tree().quit()
