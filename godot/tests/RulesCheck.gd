extends Node
## Controlli mirati sulle regole di terreno e sulle Tabelle di Supporto.

var fails := 0
var total := 0

func ok(cond: bool, what: String) -> void:
	total += 1
	if not cond:
		fails += 1
		print("  FALLITO: ", what)


## Striscia di esagoni lungo la colonna 0 (tutti adiacenti in verticale).
func strip(elev: Array, terr: Array) -> GameState:
	var s := GameState.new()
	s.map_cols = 1
	s.map_rows = elev.size()
	for r in elev.size():
		var hd := GameState.HexData.new(terr[r], elev[r])
		s.hexes["0,%d" % r] = hd
	return s


func _ready() -> void:
	var O := Domain.TerrainType.OPEN
	var W := Domain.TerrainType.WOODS
	var B := Domain.TerrainType.BRUSH
	# Stessa quota: il bosco blocca, il terreno aperto no.
	ok(HexGrid.has_los(0, 0, 0, 2, strip([0, 0, 0], [O, O, O])), "aperto in piano: si vede")
	ok(not HexGrid.has_los(0, 0, 0, 2, strip([0, 0, 0], [O, W, O])), "bosco in piano: blocca")
	# Collina in mezzo più alta dei due estremi: blocca.
	ok(not HexGrid.has_los(0, 0, 0, 2, strip([0, 1, 0], [O, O, O])), "collina fra due esagoni bassi: blocca")
	# Dal bordo dell'altura si vede giù; da dentro l'altopiano no (cresta).
	ok(HexGrid.has_los(0, 0, 0, 2, strip([1, 0, 0], [O, O, O])), "dal bordo dell'altura verso il basso: si vede")
	ok(not HexGrid.has_los(0, 0, 0, 3, strip([1, 1, 0, 0], [O, O, O, O])), "da dentro l'altopiano verso il basso: cresta, non si vede")
	ok(not HexGrid.has_los(0, 3, 0, 0, strip([1, 1, 0, 0], [O, O, O, O])), "dal basso oltre il primo esagono dell'altura: non si vede")
	ok(HexGrid.has_los(0, 3, 0, 1, strip([1, 1, 0, 0], [O, O, O, O])), "dal basso al primo esagono dell'altura: si vede")
	# Ostacolo più basso: non blocca, ma crea un esagono cieco subito dietro.
	ok(HexGrid.has_los(0, 0, 0, 3, strip([1, 0, 0, 0], [O, W, O, O])), "dall'altura oltre un bosco in basso (2 esagoni dopo): si vede")
	ok(not HexGrid.has_los(0, 0, 0, 2, strip([1, 0, 0], [O, W, O])), "dall'altura subito dietro un bosco in basso: esagono cieco")
	# Due alture alla stessa quota con bosco nella valle: si vedono.
	ok(HexGrid.has_los(0, 0, 0, 2, strip([1, 0, 1], [O, W, O])), "fra due alture sopra un bosco di valle: si vede")
	# Hindrance: conta solo se non sta più in basso.
	ok(HexGrid.los_hindrance(0, 0, 0, 2, strip([0, 0, 0], [O, B, O])) > 0, "macchia in piano: ostacola")
	ok(HexGrid.los_hindrance(0, 0, 0, 2, strip([1, 0, 0], [O, B, O])) == 0, "macchia più in basso dell'osservatore: non ostacola")
	# Copertura lungo strada.
	var sr := strip([0], [W])
	var c0 := Rules.cover_at(sr, 0, 0, false)
	sr.hexes["0,0"].has_road = true
	ok(Rules.cover_at(sr, 0, 0, false) == c0 - 1, "strada: copertura −1")
	# Vantaggio d'altura e Tabelle di Supporto su una partita vera.
	var fl := Flow.new_game(1, Flow.AX, 7)
	var g: Unit = fl.men(Flow.AX)[0]
	var base := fl.height_mod([g], Vector2i(g.q, g.r))
	ok(base == 0, "stessa quota: nessun vantaggio d'altura")
	fl.s.hex_at(g.q, g.r).elevation = 1
	var other := Vector2i(g.q, g.r - 1)
	ok(fl.height_mod([g], other) == 1, "tiro verso il basso: +1 FP")
	fl.s.hex_at(g.q, g.r).elevation = 0
	fl.s.hex_at(other.x, other.y).elevation = 1
	ok(fl.height_mod([g], other) == -1, "tiro verso l'alto: −1 FP")
	ok(fl.scenario_year() == 1941, "anno dello scenario 1")
	var names: Array = fl.support_items(Flow.AX, 7, true).map(func(i: Dictionary) -> String: return String(i["nome"]))
	ok(names.has("Squadra Fucilieri") and names.has("Radio 81mm") and not names.has("Team armi con mortaio medio"),
		"Tabella tedesca, colonna 7 nel 1941: %s" % ", ".join(names))
	ok(fl.support_items(Flow.AX, 7, false).all(func(i: Dictionary) -> bool: return String(i["tipo"]) != "radio"), "senza Radio quando non ammesse")
	for nat in ["DE", "RU", "US", "GB", "FR", "IT"]:
		ok((Flow.support_data().get(nat, []) as Array).size() >= 20, "tabella %s presente" % nat)
	var u := fl._spawn_support(Flow.AX, fl.support_items(Flow.AX, 6, false).filter(func(i: Dictionary) -> bool: return String(i["tipo"]) == "team")[0], Vector2i(7, 9))
	ok(u != null and fl.s.weapon_carried_by(u.id) != null and u.has_sides, "il Team di supporto arriva con la sua arma e il lato rotto")
	# O21.1.1: traspaso de arma entre unidades amigas en el mismo hexágono.
	var st := GameState.new()
	var a := Unit.new("a", Flow.AX, Domain.UnitType.SQUAD, Domain.UnitClass.RIFLE, "A")
	var b := Unit.new("b", Flow.AX, Domain.UnitType.SQUAD, Domain.UnitClass.RIFLE, "B")
	var w := Unit.new("w", Flow.AX, Domain.UnitType.WEAPON, Domain.UnitClass.MG, "MG")
	a.q = 0; a.r = 0; b.q = 0; b.r = 0; w.q = 0; w.r = 0; w.carrier_id = "a"
	st.units = { "a": a, "b": b, "w": w }
	ok(st.transfer_weapon("a", "b"), "traspaso de arma permitido")
	ok(st.weapon_carried_by("b") == w and st.weapon_carried_by("a") == null, "arma transferida al receptor")
	ok(not st.transfer_weapon("a", "b"), "no se puede transferir un arma que ya no se lleva")
	# 11.4: Fix/Elim de armas averiadas al comprobar un Hexágono Aleatorio.
	var stf := GameState.new()
	var wf := Unit.new("wf", Flow.AX, Domain.UnitType.WEAPON, Domain.UnitClass.MG, "Light MG")
	wf.efficient = false
	stf.units = { "wf": wf }
	Rules.check_broken_weapons(stf, 2)
	ok(wf.efficient, "11.4: Fix 2 repara la Light MG")
	var ste := GameState.new()
	var we := Unit.new("we", Flow.AX, Domain.UnitType.WEAPON, Domain.UnitClass.MG, "Light MG")
	we.efficient = false
	ste.units = { "we": we }
	Rules.check_broken_weapons(ste, 8)
	ok(not ste.units.has("we"), "11.4: Elim 8 elimina la Light MG")
	var stn := GameState.new()
	var wn := Unit.new("wn", Flow.AX, Domain.UnitType.WEAPON, Domain.UnitClass.MG, "Medium MG")
	wn.efficient = false
	stn.units = { "wn": wn }
	Rules.check_broken_weapons(stn, 5)
	ok(not wn.efficient and stn.units.has("wn"), "11.4: un número fuera de rango no cambia el arma")
	print("RULES_RESULT: %s (%d controlli, %d falliti)" % ["PASS" if fails == 0 else "FAIL", total, fails])
	get_tree().quit(0 if fails == 0 else 1)
