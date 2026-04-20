class_name Item
extends Resource

enum Type {NONE, HEALTH, BUFF}

var item_name: String = ""
var item_type: Type = Type.NONE
var icon: Texture2D = null
var quantity: int = 1
var max_stack: int = 99
