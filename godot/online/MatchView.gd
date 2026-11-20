class_name MatchView
extends RefCounted
## Only these board fields and legal choices are public on the network.
const BOARD := ["map_cols", "map_rows", "map_image", "cal_hex", "cal_ox", "cal_oy",
	"hexes", "side_features", "scenario_number", "scenario_name", "axis_nation",
	"allied_nation", "active_faction", "initiative_holder", "defender_faction",
	"time_marker", "sudden_death_space", "vp_tracker", "casualties",
	"surrender_threshold", "turn_number", "objectives", "units"]


static func make(flow: Flow, seat: int, revision: int, text: MatchText, catalog: Dictionary) -> Dictionary:
	var saved := SaveGame._state_to_dict(flow.s)
	var board := {}
	for key in BOARD:
		board[key] = saved[key]
	board["german_hand" if seat == Flow.AX else "russian_hand"] = SaveGame._cards_to(flow.hand(seat))
	var counts := {}
	for side in [Flow.AX, Flow.AL]:
		counts[side] = [flow.hand(side).size(), flow.deck(side).size(), flow.pile(side).size()]
	var events := []
	for ev in flow.events:
		var visible := {"kind": ev.kind, "text": text.render(ev.text, catalog)}
		for key in ["who", "dice", "hex", "from", "to", "fx", "unit", "order", "rule"]:
			if ev.has(key):
				visible[key] = ev[key]
		if ev.get("card") is Card:
			visible.card = SaveGame._card_to_dict(ev.card)
		events.append(visible)
	return {"type": "state", "seat": seat, "revision": revision, "board": board,
		"pending": _decision(flow.pending, seat, text, catalog), "counts": counts,
		"orders_max": flow.orders_max, "orders_done": flow.orders_done,
		"over": flow.over, "winner": flow.winner, "reason": text.render(flow.end_reason, catalog),
		"events": events}


static func _decision(p: Dictionary, seat: int, text: MatchText, catalog: Dictionary) -> Dictionary:
	if p.is_empty():
		return {}
	if p.who != seat:
		return {"who": p.who}
	var view := {"who": seat, "kind": p.kind, "title": text.render(p.title, catalog), "options": []}
	for key in ["selected", "selected_cards", "unit", "leader", "order"]:
		if p.has(key):
			view[key] = p[key]
	if p.has("blocked"):
		view.blocked = {}
		for i in p.blocked:
			view.blocked[i] = text.render(p.blocked[i], catalog)
	for option in p.options:
		var entry := {"label": text.render(option.get("label", ""), catalog)}
		for key in ["id", "hex", "unit", "card", "on", "cost", "remaining", "road_gain", "melee"]:
			if option.has(key):
				entry[key] = option[key]
		view.options.append(entry)
	return view
