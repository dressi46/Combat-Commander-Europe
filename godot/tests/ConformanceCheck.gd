extends Node
## Fase 3: matriz de conformidad del reglamento. Por defecto informa; con
## `--strict` falla si queda alguna fila PARTIAL o MISSING (puerta de calidad).
## Uso: godot --headless --path godot res://tests/ConformanceCheck.tscn [--strict]

func _ready() -> void:
	var path := "res://assets/docs/conformance.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("No se encontró la matriz de conformidad: ", path)
		get_tree().quit(1)
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (data is Array):
		printerr("Matriz de conformidad inválida")
		get_tree().quit(1)
		return
	var counts := {"IMPLEMENTED": 0, "PARTIAL": 0, "MISSING": 0}
	for row in data:
		if not (row is Dictionary):
			printerr("Fila inválida en la matriz")
			get_tree().quit(1)
			return
		var status := String(row.get("status", ""))
		if not counts.has(status):
			printerr("Estado desconocido: ", status)
			get_tree().quit(1)
			return
		counts[status] += 1
		print("%-12s %s — %s" % [status, String(row.get("area", "")), String(row.get("evidence", ""))])
	print("CONFORMANCE_RESULT: %d implemented, %d partial, %d missing" % [
		counts["IMPLEMENTED"], counts["PARTIAL"], counts["MISSING"]])
	if "--strict" in OS.get_cmdline_user_args() and (counts["PARTIAL"] > 0 or counts["MISSING"] > 0):
		printerr("STRICT FAIL: la matriz aún tiene %d parciales y %d ausentes" % [counts["PARTIAL"], counts["MISSING"]])
		get_tree().quit(1)
		return
	get_tree().quit()
