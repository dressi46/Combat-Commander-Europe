class_name BattleStatus
extends HFlowContainer

signal inspected(heading: String, content: String, key: String)
const NATIONS := {"german":"DE", "italian":"IT", "russian":"SU", "american":"US", "british":"GB",
	"french":"FR", "romanian":"RO", "brazilian":"BR", "canadian":"CA", "anzac":"ANZAC",
	"polish":"PL", "yugoslav":"YU"}
var fields := {}
var compact := false


func _ready() -> void:
	add_theme_constant_override("h_separation", 4)
	add_theme_constant_override("v_separation", 2)
	for key in ["Clock", "Score", "Initiative", "Axis losses", "Allied losses", "Objectives"]:
		var b := Button.new()
		var icon_name: String = {"Clock":"time", "Initiative":"initiative", "Axis losses":"loss",
			"Allied losses":"loss", "Objectives":"objective"}.get(key, "")
		if icon_name != "":
			b.icon = load("res://assets/track/" + icon_name + ".svg")
			b.add_theme_constant_override("icon_max_width", 18)
		b.add_theme_stylebox_override("normal", Tema.box(Tema.PANEL, Tema.EDGE, 1, 2, 5))
		b.custom_minimum_size.y = 40
		b.pressed.connect(_inspect.bind(key))
		fields[key] = b
		add_child(b)
	refresh()


func _country(side: int) -> String:
	return NATIONS.get(Game.flow.nation(side), Game.flow.side_name(side))


func _field(key: String, value: String, heading: String) -> void:
	var b: Button = fields[key]
	b.text = value
	b.tooltip_text = heading
	b.accessibility_name = heading + " · " + value


func refresh() -> void:
	var s := Game.state
	if s == null or fields.is_empty():
		return
	var time_label := "" if compact else L10n.t("TEMPO") + " "
	_field("Clock", time_label + "%d / %d" % [s.time_marker, s.sudden_death_space], L10n.t("Time / sudden death"))
	_field("Score", _score(s.vp_tracker, true), L10n.t("Victory point breakdown"))
	var holder := _country(s.initiative_holder) if compact else L10n.t("Iniziativa: %s") % Game.flow.side_name(s.initiative_holder)
	_field("Initiative", holder, L10n.t("Iniziativa: %s") % Game.flow.side_name(s.initiative_holder))
	for side in [Flow.AX, Flow.AL]:
		var key := "Axis losses" if side == Flow.AX else "Allied losses"
		var limit := int(s.surrender_threshold.get(side, 0))
		var name_label := _country(side) if compact else Game.flow.side_name(side)
		_field(key, "%s %d/%s" % [name_label, int(s.casualties.get(side, 0)), str(limit) if limit > 0 else "-"],
			L10n.t("Casualty record · %s") % Game.flow.side_name(side))
	_field("Objectives", L10n.t("Objectives"), L10n.t("Objective chits"))


func _score(points: int, compact: bool = false) -> String:
	if points == 0:
		return L10n.t("PV 0 (parità)")
	var side := Flow.AX if points > 0 else Flow.AL
	return L10n.t("PV %d %s") % [absi(points), _country(side) if compact else Game.flow.side_name(side)]


func _inspect(key: String) -> void:
	var s := Game.state
	var lines := PackedStringArray()
	match key:
		"Clock":
			lines.append(L10n.t("Time marker %d. Sudden death checks begin at %d.") % [s.time_marker, s.sudden_death_space])
		"Initiative":
			lines.append(L10n.t("Iniziativa: %s") % Game.flow.side_name(s.initiative_holder))
			lines.append(L10n.t("The holder can request a reroll and pass initiative to the opponent. Initiative breaks a final VP tie."))
		"Score":
			lines = _score_lines(s)
		"Axis losses", "Allied losses":
			var side := Flow.AX if key == "Axis losses" else Flow.AL
			lines.append(L10n.t("Losses %d · surrender threshold %s") % [s.casualties[side],
				str(s.surrender_threshold[side]) if s.surrender_threshold[side] > 0 else "-"])
			for weapons in [false, true]:
				var names := PackedStringArray()
				for u: Unit in s.graves:
					if u.faction == side and u.is_weapon() == weapons:
						names.append(L10n.unit_label(u.display_name))
				if not names.is_empty():
					lines.append("\n" + L10n.t("Equipment lost" if weapons else "Eliminated units"))
					lines.append_array(names)
			if lines.size() == 1:
				lines.append(L10n.t("No eliminated counters on record."))
		"Objectives":
			lines = _objective_lines(s)
	inspected.emit(fields[key].tooltip_text, "\n".join(lines), key)


func _score_lines(s: GameState) -> PackedStringArray:
	var lines := PackedStringArray()
	var accounted := 0
	for key in s.vp_sources:
		var sides: Array = s.vp_sources[key]
		accounted += int(sides[Flow.AX]) - int(sides[Flow.AL])
		var awards := PackedStringArray()
		for side in [Flow.AX, Flow.AL]:
			if int(sides[side]) != 0:
				awards.append("%s %+d" % [Game.flow.side_name(side), int(sides[side])])
		lines.append("%s · %s" % [L10n.t(key), " / ".join(awards) if not awards.is_empty() else "0"])
	for obj in s.objectives:
		if obj.controller < 0 or obj.vp == 0:
			continue
		var amount: int = obj.vp if obj.controller == Flow.AX else -obj.vp
		accounted += amount
		lines.append("%s %d (%s) · %s" % [L10n.t("Objective"), obj.id, Game.flow.lbl(Vector2i(obj.q, obj.r)), _score(amount)])
	if accounted != s.vp_tracker:
		lines.append("%s · %s" % [L10n.t("Unitemized balance"), _score(s.vp_tracker - accounted)])
	lines.append("\n%s · %s" % [L10n.t("Net score"), _score(s.vp_tracker)])
	return lines


func _objective_lines(s: GameState) -> PackedStringArray:
	var lines := PackedStringArray()
	for token in s.objective_chits:
		if token.revealed:
			if lines.is_empty():
				lines.append(L10n.t("Public objectives"))
			lines.append(ObjectiveChits._describe(ObjectiveChits._find(token.letter)))
	for obj in s.objectives:
		var owner := L10n.t("Uncontrolled") if obj.controller < 0 else Game.flow.side_name(obj.controller)
		lines.append("%s %d · %s · %s · %d %s" % [L10n.t("Objective"), obj.id, Game.flow.lbl(Vector2i(obj.q, obj.r)), owner, obj.vp, L10n.t("VP")])
	return lines
