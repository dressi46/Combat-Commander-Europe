## Effetti di setup data-driven delle regole speciali (SSR) applicabili al via:
## gettoni Obiettivo esclusi dal sacchetto e carte garantite in mano a inizio
## partita. Letti da scenario_effects.json; assenti = nessun effetto.
class_name ScenarioEffects
extends RefCounted

const PATH := "res://assets/scenarios/scenario_effects.json"

static var _data: Dictionary = {}
static var _loaded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if d is Dictionary:
		_data = d


static func entry(num: int) -> Dictionary:
	_ensure()
	var e: Variant = _data.get(str(num), {})
	return e if e is Dictionary else {}


## Lettere dei gettoni Obiettivo da NON mettere nel sacchetto (7.3.2 / SSR).
static func exclude_chits(num: int) -> Array:
	var x: Variant = entry(num).get("exclude_chits", [])
	return x if x is Array else []


## Codici carta (es. "G-65") garantiti in mano al lato indicato ("axis"/"allies").
static func opening_cards(num: int, side: String) -> Array:
	var oc: Variant = entry(num).get("opening_cards", {})
	if not (oc is Dictionary):
		return []
	var c: Variant = oc.get(side, [])
	return c if c is Array else []


# ─── Modificatori di terreno/mappa (terrain_mods.json) ────────────────────────

const TERRAIN_PATH := "res://assets/scenarios/terrain_mods.json"
static var _terrain: Dictionary = {}
static var _terrain_loaded := false


static func _ensure_terrain() -> void:
	if _terrain_loaded:
		return
	_terrain_loaded = true
	var f := FileAccess.open(TERRAIN_PATH, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if d is Dictionary:
		_terrain = d


static func terrain_mods(num: int) -> Dictionary:
	_ensure_terrain()
	var t: Variant = _terrain.get(str(num), {})
	return t if t is Dictionary else {}


## Ostacolo (Hindrance) aggiuntivo in OGNI esagono (nebbia, ecc.). 0 se assente.
static func global_hindrance(num: int) -> int:
	return int(terrain_mods(num).get("global_hindrance", 0))


# ─── Rinforzi (Tabella del Tempo, reinforcements.json) ────────────────────────

const REINF_PATH := "res://assets/scenarios/reinforcements.json"
static var _reinf: Dictionary = {}
static var _reinf_loaded := false


static func _ensure_reinf() -> void:
	if _reinf_loaded:
		return
	_reinf_loaded = true
	var f := FileAccess.open(REINF_PATH, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if d is Dictionary:
		_reinf = d


## Grupos di rinforzo del lato ("axis"/"allies") per lo scenario: lista di
## { "space": int, "units": [ {tipo, n} ] }. Vuoto se assenti.
static func reinforcements(num: int, side: String) -> Array:
	_ensure_reinf()
	var s: Variant = _reinf.get(str(num), {})
	if not (s is Dictionary):
		return []
	var r: Variant = s.get(side, [])
	return r if r is Array else []


# ─── Effetti meccanici delle SSR (scenario_effects.json) ─────────────────────

static func _side_key(f: int) -> String:
	return "axis" if f == Domain.Faction.GERMAN else "allies"


static func _side_value(num: int, key: String, f: int, fallback: Variant) -> Variant:
	var d: Variant = entry(num).get(key, {})
	if d is Dictionary:
		return d.get(_side_key(f), fallback)
	return fallback


## Bocage (scenario 2): +1 PM extra oltre al normale +1 della siepe.
static func hedge_move_extra(num: int) -> int:
	return int(entry(num).get("hedge_move_extra", 0))


## Limite di scarto imposto dallo scenario; -1 = usa quello della nazione.
static func discard_limit(num: int, f: int) -> int:
	return int(_side_value(num, "discard_limit", f, -1))


## Azione notturna (scenario 8): i totali di fuoco calano della distanza.
static func night_fire(num: int) -> bool:
	return bool(entry(num).get("night_fire", false))


## Bonus al corpo a corpo (scenario 10: Alleati +1).
static func melee_bonus(num: int, f: int) -> int:
	return int(_side_value(num, "melee_bonus", f, 0))


## Raggio del cecchino (scenario 12: Asse 2 esagoni invece di 1).
static func sniper_range(num: int, f: int) -> int:
	return int(_side_value(num, "sniper_range", f, 1))


## Unità soppresse all'inizio (scenario 22: squadre britanniche).
static func initial_suppressed(num: int, f: int) -> bool:
	return bool(_side_value(num, "initial_suppressed", f, false))


## Crepuscolo (scenario 22): ostacolo pari allo spazio del Tempo.
static func twilight(num: int) -> bool:
	return bool(entry(num).get("twilight", false))


## Forza delle mine (scenario 23: 7 invece di 6).
static func mine_strength(num: int) -> int:
	return int(entry(num).get("mine_strength", 6))


## Unità che escono dalla mappa vengono eliminate (nessun PV di Uscita).
static func exit_eliminates(num: int, f: int) -> bool:
	return bool(_side_value(num, "exit_eliminates", f, false))


## Incursione (scenario 20): l'Asse non può uscire mentre l'Alleato ha un'Arma.
static func exit_blocked(state: GameState, f: int) -> bool:
	if not bool(entry(state.scenario_number).get("exit_block_allies_weapon", false)):
		return false
	if f != Domain.Faction.GERMAN:
		return false
	for u in state.units.values():
		if u.faction == Domain.Faction.RUSSIAN and (u.is_weapon() or state.weapon_carried_by(u.id) != null):
			return true
	return false


## Gelo profondo (scenario 5): nessuna nuova fortificazione dopo l'inizio.
static func fortifications_locked(num: int) -> bool:
	return bool(entry(num).get("fortifications_locked", false))


## Applica gli effetti di stato iniziale dopo che le forze sono piazzate.
static func apply_initial_state(state: GameState) -> void:
	var n := state.scenario_number
	for u in state.units.values():
		if u.type == Domain.UnitType.SQUAD and initial_suppressed(n, u.faction):
			u.suppressed = true
