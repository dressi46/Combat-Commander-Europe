extends ColorRect
## Pannello delle ranure di salvataggio (auto + 1..3). Usato dal menu iniziale
## e dalla partita. Emette `done(path)` con il file scelto ("" = annulla).
signal done(path: String)

const PANEL_W := 520.0

var mode := "load"
var column := VBoxContainer.new()
var status := Label.new()
var panel := PanelContainer.new()


func setup(p_mode: String) -> void:
	mode = p_mode
	color = Color(0.04, 0.05, 0.03, 0.74)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	panel.add_theme_stylebox_override("panel", Tema.paper_box(Tema.PANEL, Tema.BRASS, 3, 1, 16))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	var title := Tema.title(L10n.t("Save game" if mode == "save" else "Load game"), 24, Tema.BRASS)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	column.add_child(HSeparator.new())
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Tema.BRASS)
	column.add_child(status)
	_rebuild()
	var close := Button.new()
	close.text = L10n.t("Annulla")
	close.custom_minimum_size.y = 48
	close.pressed.connect(func() -> void: done.emit(""))
	column.add_child(close)
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	var extent := Vector2(minf(PANEL_W, size.x - 20), minf(520, size.y - 20))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -extent.x * 0.5
	panel.offset_right = extent.x * 0.5
	panel.offset_top = -extent.y * 0.5
	panel.offset_bottom = extent.y * 0.5
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH


func _rebuild() -> void:
	for child in column.get_children():
		if child is Button and child.has_meta("slot"):
			column.remove_child(child)
			child.queue_free()
	var games := SaveGame.list_games()
	var insert := 3  # dopo titolo, separatore e stato
	for slot in range(1, 4):
		var found := _find(games, slot)
		var b := Button.new()
		b.set_meta("slot", slot)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.y = 52
		b.text = L10n.t("Slot %d — %s") % [slot, _describe(found)]
		b.pressed.connect(_choose.bind(slot))
		column.add_child(b)
		column.move_child(b, insert)
		insert += 1
	var auto := _find(games, 0)
	var a := Button.new()
	a.set_meta("slot", 0)
	a.alignment = HORIZONTAL_ALIGNMENT_LEFT
	a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	a.custom_minimum_size.y = 52
	a.text = L10n.t("Autosave — %s") % _describe(auto)
	if bool(auto.is_empty()):
		a.disabled = true
	a.pressed.connect(_choose.bind(0))
	column.add_child(a)
	column.move_child(a, insert)


func _find(games: Array, slot: int) -> Dictionary:
	for g in games:
		if int(g.get("slot", -1)) == slot:
			return g
	return {}


func _describe(game: Dictionary) -> String:
	if game.is_empty():
		return L10n.t("Empty slot")
	var when := Time.get_datetime_string_from_unix_time(int(game.get("saved_at", 0)))
	return L10n.t("Scenario %d · %s · %s") % [int(game.get("scenario", 0)),
		String(game.get("scenario_name", "")), when.replace("T", " ").left(16)]


func _choose(slot: int) -> void:
	var path := SaveGame.auto_path() if slot == 0 else SaveGame.slot_path(slot)
	if mode == "save":
		if Game.flow == null or Game.flow.s == null:
			status.text = L10n.t("No game in progress")
			return
		if slot == 0:
			status.text = L10n.t("The autosave slot is updated automatically")
			return
		if SaveGame.save_game(Game.flow, Game.mode, Game.difficulty, path):
			status.text = L10n.t("Saved to slot %d") % slot
			_rebuild()
		else:
			status.text = L10n.t("Could not save the game")
		return
	if not FileAccess.file_exists(path):
		status.text = L10n.t("Empty slot")
		return
	done.emit(path)
