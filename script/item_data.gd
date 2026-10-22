class_name ItemData
extends Resource

enum EquipType {
	NONE,
	WEAPON,
	HEAD,
	BUST,
	LEGS,
	FEET,
	BAG
}

@export var id: String = ""
@export var item_name: String = "Item"
@export var icon: Texture2D
@export var icon_modulate: Color = Color.WHITE
@export var can_stack: bool = true
@export var max_stack: int = 20
@export var is_rifle: bool = false
@export var is_ammo: bool = false
@export var max_ammo: int = 0
@export var ammo_item_id: String = ""
@export var equip_type: EquipType = EquipType.NONE


func get_effective_max_stack() -> int:
	return max_stack if can_stack else 1
