class_name OrderNotes
extends RefCounted

const DECISIONS := {
	"fire_group": Domain.OrderType.FIRE, "fire_target": Domain.OrderType.FIRE,
	"advance": Domain.OrderType.ADVANCE, "rout_who": Domain.OrderType.ROUT,
	"spotter": Domain.OrderType.ARTY, "arty_target": Domain.OrderType.ARTY, "arty_kind": Domain.OrderType.ARTY,
}

const NOTES := {
	Domain.OrderType.MOVE: ["O21", "Pay the entry cost for each adjacent hex."],
	Domain.OrderType.FIRE: ["O20", "Compare the fire attack total with each target’s defense total."],
	Domain.OrderType.ADVANCE: ["O16", "Each advancing unit may enter one adjacent hex."],
	Domain.OrderType.RECOVER: ["O22", "Attempt to rally broken units and remove suppression."],
	Domain.OrderType.ROUT: ["O23", "Check broken units for retreat."],
	Domain.OrderType.ARTY: ["O18", "Resolve the radio request, spotting and artillery impact."],
	Domain.OrderType.ARTY_DENIED: ["O17", "Check the condition of the opposing radio."],
	Domain.OrderType.PASS: ["O19", "This card has no playable order."],
}

const EVENT_RULES := {
	"SUPPORTO AEREO": ["E43", "The event identifies a hex for air support."],
	"TEMPRATI DALLA GUERRA": ["E44", "A unit can gain veteran status."],
	"SCONTRO SENZA PERDITE": ["E45", "The rule awards victory points based on casualties."],
	"INCENDIO": ["E46", "A blaze can change which hexes units may enter."],
	"TRAPPOLA ESPLOSIVA": ["E47", "A random hex is checked for mine placement."],
	"BREZZA": ["E48", "Wind affects smoke on the map."],
	"COMANDO E CONTROLLO": ["E49", "Scoring depends on controlled objectives."],
	"COMMISSARIO": ["E50", "Compare a roll with the broken unit’s morale."],
	"ACQUATTARSI": ["E51", "Command range determines which squads are exposed."],
	"DIVIDERSI": ["E52", "A squad can split into two teams."],
	"POLVERE": ["E53", "Dust uses a smoke marker."],
	"IMPETO": ["E54", "The surrender marker can move on the casualty track."],
	"TRINCERAMENTO": ["E55", "Check whether a friendly hex can receive foxholes."],
	"PROMOZIONE SUL CAMPO": ["E56", "A field promotion can bring a new leader into play."],
	"NEBBIA DI GUERRA": ["E57", "Each side with cards in hand loses a random card."],
	"EROE": ["E58", "Check whether a hero can enter play."],
	"INFILTRAZIONI": ["E59", "The event checks for infiltration."],
	"INTERDIZIONE": ["E60", "Interdiction affects the players’ hands."],
	"SPIONAGGIO": ["E61", "Inspect the opposing hand and decide whether to discard a card."],
	"UCCISO IN AZIONE": ["E62", "Check for a broken unit to eliminate."],
	"MALFUNZIONAMENTO": ["E63", "Distance from a random hex determines which weapon is affected."],
	"MEDICO": ["E64", "A broken unit can rally, even if it belongs to the opposing side."],
	"OBIETTIVO DELLA MISSIONE": ["E65", "An additional objective chit can change the scoring."],
	"PRIGIONIERI DI GUERRA": ["E66", "Check the drawing side for a broken unit."],
	"RICOGNIZIONE": ["E67", "An opponent’s secret objective can become public."],
	"RINFORZI": ["E68", "Use the support table to determine the reinforcement."],
	"MACERIE": ["E69", "Rubble can change the terrain of a hex."],
	"ZAPPATORI": ["E70", "Check for mines or wire that sappers can remove."],
	"SACCHEGGIO": ["E71", "An eliminated weapon may return with a new carrier."],
	"SHOCK DA COMBATTIMENTO": ["E72", "Check units near the random hex for shell shock."],
	"CRATERI": ["E73", "Check a random hex for foxholes."],
	"OBIETTIVO STRATEGICO": ["E74", "A strategic objective can change the value of controlling the map."],
	"FUOCO DI SOPPRESSIONE": ["E75", "Machine-gun range and line of sight determine exposure."],
	"PROCEDERE FERITI": ["E76", "An eliminated unit may return to the map broken."],
	"White Phosphorus": ["E77", "A squad may place smoke in an adjacent hex and affect units there."],
}


static func describe(order: int) -> String:
	var note: Array = NOTES.get(order, [])
	return "" if note.is_empty() else "%s · %s" % [note[0], L10n.t(note[1])]
