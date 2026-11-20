extends ColorRect
## A field report stays within the board's canvas when a mobile browser resizes.
signal confirmed
var contents := VBoxContainer.new()
var scroll := ScrollContainer.new()
var panel := PanelContainer.new()
var column := VBoxContainer.new()
var close_button := Button.new()


func setup(caption: String) -> void:
	color = Color(0.04, 0.05, 0.03, 0.72)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", Tema.box(Tema.PANEL, Tema.BRASS, 3, 1, 14))
	add_child(panel)
	panel.add_child(column)
	var heading := Tema.title(caption, 23, Tema.BRASS)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	column.add_child(HSeparator.new())
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 8)
	scroll.add_child(contents)
	close_button.text = L10n.t("Continue play")
	close_button.custom_minimum_size.y = 48
	close_button.pressed.connect(func(): confirmed.emit())
	column.add_child(close_button)
	close_button.grab_focus()
	resized.connect(_fit)
	panel.minimum_size_changed.connect(_fit.call_deferred)
	_fit()


func _fit() -> void:
	var extent := Vector2(minf(590, size.x - 20), minf(520, size.y - 20))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -extent.x * 0.5
	panel.offset_right = extent.x * 0.5
	panel.offset_top = -extent.y * 0.5
	panel.offset_bottom = extent.y * 0.5
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
