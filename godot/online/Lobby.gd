extends ScrollContainer

var column := VBoxContainer.new()
var address: LineEdit
var invitation: LineEdit
var scenarios: OptionButton
var sides: OptionButton
var public_room: CheckBox
var room_list := VBoxContainer.new()
var message := Label.new()
var last_page := ""
var bookings: Array


func _ready() -> void:
	theme = Tema.get_theme()
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(center)
	column.custom_minimum_size.x = 530
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)
	bookings = JSON.parse_string(FileAccess.get_file_as_string("res://assets/scenari.json"))
	Online.changed.connect(_refresh)
	_refresh()


func _label(key: String) -> void:
	var label := Label.new()
	label.text = L10n.t(key)
	column.add_child(label)


func _button(parent: Control, caption: String, action: Callable) -> void:
	var b := Button.new()
	b.text = caption
	b.pressed.connect(action)
	parent.add_child(b)


func _refresh() -> void:
	var page := "connect" if not Online.lobby_ready else ("waiting" if Online.code != "" else "rooms")
	if page != last_page:
		last_page = page
		for child in column.get_children():
			column.remove_child(child)
			if child != message and child != room_list:
				child.queue_free()
		_label("Online lobby")
		match page:
			"connect": _connect_form()
			"rooms": _room_form()
			"waiting": _waiting()
		column.add_child(message)
		_button(column, L10n.t("Back"), Online.exit_lobby)
	message.text = L10n.t(Online.status)
	if page == "rooms":
		for item in room_list.get_children():
			room_list.remove_child(item)
			item.queue_free()
		for room in Online.listed:
			var title := L10n.t(bookings[int(room.scenario)-1].titolo)
			_button(room_list, L10n.t("Join · %s") % title, _join.bind(room.code))
		if Online.listed.is_empty():
			var empty := Label.new()
			empty.text = L10n.t("No open rooms")
			room_list.add_child(empty)


func _exit_tree() -> void:
	if room_list.get_parent() == null:
		room_list.free()
	if message.get_parent() == null:
		message.free()


func _connect_form() -> void:
	_label("Server address")
	address = LineEdit.new()
	address.text = Online.endpoint
	column.add_child(address)
	_button(column, L10n.t("Connect"), func(): Online.connect_lobby(address.text.strip_edges()))
	_button(column, L10n.t("Local server"), func():
		address.text = "ws://127.0.0.1:8790"
		Online.connect_lobby(address.text))


func _room_form() -> void:
	_label("Create a match")
	scenarios = OptionButton.new()
	for s in bookings:
		scenarios.add_item("%d · %s" % [s.numero, L10n.t(s.titolo)], s.numero)
	column.add_child(scenarios)
	sides = OptionButton.new()
	for side in ["Asse", "Alleati"]:
		sides.add_item(L10n.t(side))
	column.add_child(sides)
	public_room = CheckBox.new()
	public_room.text = L10n.t("List this room publicly")
	column.add_child(public_room)
	_button(column, L10n.t("Create room"), func(): Online.send({"op": "create",
		"scenario": scenarios.get_selected_id(), "side": sides.selected, "open": public_room.button_pressed}))
	_label("Invitation code")
	invitation = LineEdit.new()
	column.add_child(invitation)
	_button(column, L10n.t("Join by code"), func(): _join(invitation.text))
	_label("Open rooms")
	column.add_child(room_list)


func _waiting() -> void:
	_label("Share this invitation code")
	var field := LineEdit.new()
	field.text = Online.code
	field.editable = false
	column.add_child(field)
	_button(column, L10n.t("Copy code"), func(): DisplayServer.clipboard_set(Online.code))
	_button(column, L10n.t("Leave room"), Online.leave)


func _join(value: String) -> void:
	Online.send({"op": "join", "code": value.strip_edges().to_lower()})
