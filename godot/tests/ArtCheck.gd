extends Node
## Comprueba qué unidades tienen una ficha de arte existente y qué marcadores
## de terreno faltan. Uso: godot --headless --path godot res://tests/ArtCheck.tscn

func _ready() -> void:
	var fails := 0
	var missing := {}
	var empty := {}
	for n in range(1, 25):
		var f := Flow.new_game(n, Flow.AX, 1)
		for u in f.s.units.values():
			if u.art_name == "":
				var key := "%s/%s" % [u.nation_art, u.display_name]
				empty[key] = int(empty.get(key, 0)) + 1
				continue
			var folder: String = u.nation_art if u.nation_art != "" else String(Domain.FACTION_ART_DIR.get(u.faction, ""))
			var path := "res://assets/counters/%s/%s.png" % [folder, u.art_name]
			if not ResourceLoader.exists(path):
				var key := "%s/%s" % [folder, u.art_name]
				missing[key] = int(missing.get(key, 0)) + 1
	print("MISSING_UNIT_ART: ", missing.size())
	if not missing.is_empty():
		fails += 1
		for key in missing:
			print("  ", key, " (x", missing[key], ")")
	print("EMPTY_ART: ", empty.size())
	if not empty.is_empty():
		fails += 1
		for key in empty:
			print("  ", key, " (x", empty[key], ")")
	for marker in ["Mines", "Wire", "Bunker", "Pillbox", "Foxholes", "Trench", "Blaze", "Smoke"]:
		var exists := ResourceLoader.exists("res://assets/markers/%s.png" % marker)
		print("MARKER ", marker, ": ", exists)
		if not exists:
			fails += 1
	print("ART_RESULT: %s" % ("PASS" if fails == 0 else "FAIL"))
	get_tree().quit(0 if fails == 0 else 1)

