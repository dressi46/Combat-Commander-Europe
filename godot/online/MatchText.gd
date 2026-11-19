class_name MatchText
extends RefCounted
## Keep rule messages translatable after Flow interpolates their arguments.
## Markers are internal to the server. Peers receive ordinary localized text.

const BASE := 0xe000
const OPEN := "\uf800"
const SEP := "\uf801"
const CLOSE := "\uf802"
var formats := RegEx.create_from_string("%[-+0-9.]*[sdf]")
var tokens := RegEx.create_from_string("([\ue000-\uf7ff])(?:\uf800([^\ue000-\uf800\uf802]*)\uf802|(?!\uf800))")
var sources: Array[String] = []
var encoded := {}


func template(source: String) -> String:
	if encoded.has(source):
		return encoded[source]
	assert(sources.size() < 0x1800)
	var marker := String.chr(BASE + sources.size())
	sources.append(source)
	var args := PackedStringArray()
	for m in formats.search_all(source):
		args.append(m.get_string())
	if not args.is_empty():
		marker += OPEN + SEP.join(args) + CLOSE
	encoded[source] = marker
	return marker


func render(message: String, catalog: Dictionary) -> String:
	var match_token := tokens.search(message)
	while match_token != null:
		var index := match_token.get_string(1).unicode_at(0) - BASE
		var key := sources[index]
		var translated: String = catalog.get(key, L10n.english.get(key, key))
		if match_token.get_start(2) >= 0:
			var args := match_token.get_string(2).split(SEP)
			var slots := formats.search_all(translated)
			for i in range(slots.size() - 1, -1, -1):
				translated = translated.left(slots[i].get_start()) + args[i] + translated.substr(slots[i].get_end())
		message = message.left(match_token.get_start()) + translated + message.substr(match_token.get_end())
		match_token = tokens.search(message)
	return message
