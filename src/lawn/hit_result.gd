class_name HitResult
extends RefCounted

var object: Variant = null
var object_type := PvZ.OBJECT_TYPE_NONE

func clear() -> void:
	object = null
	object_type = PvZ.OBJECT_TYPE_NONE
