class_name TypingCheck
extends RefCounted
## Port of TypingCheck: matches a phrase against the most recently typed key codes.

var phrase := PackedInt32Array()
var recent_typing := PackedInt32Array()

func _init(the_phrase: String = "") -> void:
	set_phrase(the_phrase)

func set_phrase(the_phrase: String) -> void:
	for ch in the_phrase:
		add_char(ch)

func add_key_code(key: int) -> void:
	phrase.append(key)

## GetKeyCodeFromName for single characters: letters/digits map to their upper-case ASCII code.
func add_char(ch: String) -> void:
	add_key_code(ch.to_upper().unicode_at(0))

func check_phrase() -> bool:
	if recent_typing == phrase:
		recent_typing.clear()
		return true
	return false

func check(key: int) -> bool:
	recent_typing.append(key)
	var n := phrase.size()
	if n == 0:
		return false
	if recent_typing.size() > n:
		recent_typing = recent_typing.slice(recent_typing.size() - n)
	return check_phrase()
