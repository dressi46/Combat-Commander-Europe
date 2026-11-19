extends CenterContainer

var column := VBoxContainer.new()


func _ready() -> void:
	theme = Tema.get_theme()
	column.custom_minimum_size.x = 330
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	_home()


func _page(title: String) -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 32)
	column.add_child(heading)


func _button(key: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = L10n.t(key)
	button.custom_minimum_size.y = 48
	button.pressed.connect(action)
	column.add_child(button)
	return button


func _home() -> void:
	_page("Combat Commander: Europe")
	_button("Single player", _scenarios.bind(false)).grab_focus()
	_button("Multiplayer", _scenarios.bind(true))
	_button("Settings", _settings)


func _scenarios(local_multiplayer: bool) -> void:
	L10n.local_two_player = local_multiplayer
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")


func _settings() -> void:
	_page(L10n.t("Settings"))
	var label := Label.new()
	label.text = L10n.t("Language")
	column.add_child(label)
	var picker := OptionButton.new()
	var codes := L10n.languages.keys()
	for code in codes:
		picker.add_item(L10n.languages[code])
	picker.select(codes.find(L10n.locale))
	picker.item_selected.connect(func(index: int) -> void:
		L10n.set_language(codes[index])
		_settings())
	column.add_child(picker)
	picker.grab_focus()
	_button("Back", _home)
