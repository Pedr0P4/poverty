class_name InventorySlotData
extends RefCounted

var item: ItemData = null
var quantity: int = 0


func _init(p_item: ItemData = null, p_quantity: int = 0) -> void:
	item = p_item
	quantity = p_quantity


func is_empty() -> bool:
	return item == null or quantity <= 0


func clear() -> void:
	item = null
	quantity = 0


func set_data(p_item: ItemData, p_quantity: int) -> void:
	if p_item == null or p_quantity <= 0:
		clear()
	else:
		item = p_item
		quantity = p_quantity


func copy_from(other: InventorySlotData) -> void:
	if other == null or other.is_empty():
		clear()
	else:
		item = other.item
		quantity = other.quantity


func can_stack_with(other_item: ItemData) -> bool:
	if is_empty() or other_item == null:
		return false
	return item == other_item and item.can_stack and quantity < item.get_effective_max_stack()
