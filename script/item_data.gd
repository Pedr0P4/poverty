class_name ItemData
extends Resource

@export var id: String = ""
@export var item_name: String = "Item"
@export var icon: Texture2D
@export var icon_modulate: Color = Color.WHITE
@export var can_stack: bool = true
@export var max_stack: int = 20
@export var is_rifle: bool = false


func get_effective_max_stack() -> int:
	return max_stack if can_stack else 1
