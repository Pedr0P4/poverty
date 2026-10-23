class_name InventorySlotData
extends RefCounted

var item: ItemData = null
var quantity: int = 0
var ammo: int = 0


func _init(p_item: ItemData = null, p_quantity: int = 0, p_ammo: int = -1) -> void:
	set_data(p_item, p_quantity, p_ammo)


func is_empty() -> bool:
	return item == null or quantity <= 0


func clear() -> void:
	item = null
	quantity = 0
	ammo = 0


func set_data(p_item: ItemData, p_quantity: int, p_ammo: int = -1) -> void:
	if p_item == null or p_quantity <= 0:
		clear()
	else:
		item = p_item
		if p_item.is_ammo:
			quantity = 1
			if p_ammo >= 0:
				ammo = clampi(p_ammo, 0, p_item.max_ammo)
			elif p_quantity > 1:
				ammo = clampi(p_quantity, 0, p_item.max_ammo)
			else:
				ammo = p_item.max_ammo
		elif p_item.equip_type == ItemData.EquipType.WEAPON:
			quantity = 1
			if p_ammo >= 0:
				ammo = clampi(p_ammo, 0, p_item.max_ammo)
			else:
				ammo = 0
		else:
			quantity = p_quantity
			ammo = max(0, p_ammo)


func copy_from(other: InventorySlotData) -> void:
	if other == null or other.is_empty():
		clear()
	else:
		item = other.item
		quantity = other.quantity
		ammo = other.ammo


func can_stack_with(other_item: ItemData) -> bool:
	if is_empty() or other_item == null:
		return false
	return item == other_item and item.can_stack and quantity < item.get_effective_max_stack()
