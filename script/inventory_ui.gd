class_name InventoryUI
extends Control

signal equipped_item_changed(item: ItemData)
signal inventory_toggled(is_open: bool)

enum EquipSlot {
	WEAPON_1 = 0,
	WEAPON_2 = 1,
	HEAD = 2,
	BUST_1 = 3,
	BUST_2 = 4,
	LEGS = 5,
	FEET = 6,
	BAG = 7
}

const INV_COLUMNS: int = 6
const INV_ROWS: int = 3
const INV_SIZE: int = INV_COLUMNS * INV_ROWS # 18 slots
const HOTBAR_SIZE: int = 6
const EQUIP_SIZE: int = 8

const HOTBAR_WEAPON_1_INDEX: int = -2
const HOTBAR_WEAPON_2_INDEX: int = -1

const EQUIP_SLOT_TYPES: Array[int] = [
	ItemData.EquipType.WEAPON, # WEAPON_1
	ItemData.EquipType.WEAPON, # WEAPON_2
	ItemData.EquipType.HEAD,   # HEAD
	ItemData.EquipType.BUST,   # BUST_1
	ItemData.EquipType.BUST,   # BUST_2
	ItemData.EquipType.LEGS,   # LEGS
	ItemData.EquipType.FEET,   # FEET
	ItemData.EquipType.BAG     # BAG
]

const EQUIP_SLOT_PLACEHOLDERS: Array[String] = [
	"Arma 1",
	"Arma 2",
	"Cabeça",
	"Busto 1",
	"Busto 2",
	"Pernas",
	"Sapatos",
	"Bolsa"
]

const SLOT_SCENE: PackedScene = preload("res://scene/inventory_slot.tscn")

const ITEM_RIFLE: ItemData = preload("res://resources/items/rifle_item.tres")
const ITEM_AMMO: ItemData = preload("res://resources/items/ammo_item.tres")
const ITEM_MEDKIT: ItemData = preload("res://resources/items/medkit_item.tres")
const ITEM_KEY: ItemData = preload("res://resources/items/key_item.tres")
const ITEM_HAT: ItemData = preload("res://resources/items/hat_item.tres")
const ITEM_SHIRT: ItemData = preload("res://resources/items/shirt_item.tres")
const ITEM_JACKET: ItemData = preload("res://resources/items/jacket_item.tres")
const ITEM_PANTS: ItemData = preload("res://resources/items/pants_item.tres")
const ITEM_SHOES: ItemData = preload("res://resources/items/shoes_item.tres")
const ITEM_BAG: ItemData = preload("res://resources/items/bag_item.tres")

var inventory_slots: Array[InventorySlotData] = []
var hotbar_slots: Array[InventorySlotData] = []
var equipment_slots: Array[InventorySlotData] = []
var held_slot: InventorySlotData = InventorySlotData.new()

var selected_hotbar_index: int = 0
var is_open: bool = false

var _inv_slot_nodes: Array[InventorySlotUI] = []
var _modal_hotbar_nodes: Array[InventorySlotUI] = []
var _hud_hotbar_nodes: Array[InventorySlotUI] = []
var _hud_weapon_nodes: Array[InventorySlotUI] = []
var _equip_slot_nodes: Array[InventorySlotUI] = []
var _hud_weapon_separator: VSeparator = null

var _is_dragging_left: bool = false
var _drag_source_index: int = -1
var _drag_source_container: int = InventorySlotUI.ContainerType.INVENTORY
var _is_weapon_reloading: bool = false

@onready var hud_hotbar_panel: PanelContainer = $HUDHotbarPanel
@onready var hud_hotbar_grid: HBoxContainer = $HUDHotbarPanel/MarginContainer/HUDHotbarGrid
@onready var hud_ammo_panel: PanelContainer = $HUDAmmoPanel
@onready var weapon_ammo_label: Label = $HUDAmmoPanel/MarginContainer/VBoxContainer/WeaponAmmoLabel
@onready var inventory_ammo_label: Label = $HUDAmmoPanel/MarginContainer/VBoxContainer/InventoryAmmoLabel
@onready var ammo_status_label: Label = $HUDAmmoPanel/MarginContainer/VBoxContainer/AmmoStatusLabel
@onready var reload_indicator: VBoxContainer = $ReloadIndicator
@onready var reload_label: Label = $ReloadIndicator/ReloadLabel
@onready var reload_progress_bar: ProgressBar = $ReloadIndicator/ReloadProgressBar
@onready var equipment_modal: PanelContainer = $EquipmentModal
@onready var weapons_slot_box: VBoxContainer = $EquipmentModal/MarginContainer/VBoxContainer/ColumnsHBox/WeaponsColumn/WeaponsSlotBox
@onready var head_slot_box: HBoxContainer = $EquipmentModal/MarginContainer/VBoxContainer/ColumnsHBox/ClothesColumn/HeadSlotBox
@onready var bust_slots_box: HBoxContainer = $EquipmentModal/MarginContainer/VBoxContainer/ColumnsHBox/ClothesColumn/BustSlotsBox
@onready var legs_slot_box: HBoxContainer = $EquipmentModal/MarginContainer/VBoxContainer/ColumnsHBox/ClothesColumn/LegsSlotBox
@onready var feet_slot_box: HBoxContainer = $EquipmentModal/MarginContainer/VBoxContainer/ColumnsHBox/ClothesColumn/FeetSlotBox
@onready var bag_slot_box: VBoxContainer = $EquipmentModal/MarginContainer/VBoxContainer/ColumnsHBox/BagColumn/BagSlotBox
@onready var inventory_modal: PanelContainer = $InventoryModal
@onready var inventory_grid: GridContainer = $InventoryModal/MarginContainer/VBoxContainer/InventoryGrid
@onready var modal_hotbar_grid: GridContainer = $InventoryModal/MarginContainer/VBoxContainer/ModalHotbarGrid
@onready var cursor_item: Control = $CursorItem
@onready var cursor_icon: TextureRect = $CursorItem/Icon
@onready var cursor_quantity: Label = $CursorItem/QuantityLabel


func _ready() -> void:
	_init_data()
	_build_ui_slots()
	_populate_starter_items()
	_set_open_state(false)


func _process(_delta: float) -> void:
	if cursor_item.visible:
		cursor_item.global_position = get_global_mouse_position() - (cursor_item.size * 0.5)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("inventory"):
			toggle_inventory()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_change_hotbar_focus(1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_change_hotbar_focus(-1)
		else:
			if event.button_index == MOUSE_BUTTON_LEFT and _is_dragging_left:
				_handle_mouse_left_release()


func _init_data() -> void:
	inventory_slots.clear()
	for i in range(INV_SIZE):
		inventory_slots.append(InventorySlotData.new())

	hotbar_slots.clear()
	for i in range(HOTBAR_SIZE):
		hotbar_slots.append(InventorySlotData.new())

	equipment_slots.clear()
	for i in range(EQUIP_SIZE):
		equipment_slots.append(InventorySlotData.new())


func _build_ui_slots() -> void:
	inventory_grid.columns = INV_COLUMNS
	modal_hotbar_grid.columns = HOTBAR_SIZE

	# Slots do Inventário (18)
	for i in range(INV_SIZE):
		var slot_ui: InventorySlotUI = SLOT_SCENE.instantiate()
		slot_ui.slot_index = i
		slot_ui.container_type = InventorySlotUI.ContainerType.INVENTORY
		slot_ui.slot_pressed.connect(_on_slot_pressed)
		inventory_grid.add_child(slot_ui)
		_inv_slot_nodes.append(slot_ui)

	# Slots de Equipamento (8) na área à esquerda
	var equip_parents: Array[BoxContainer] = []
	equip_parents.append(weapons_slot_box) # WEAPON_1
	equip_parents.append(weapons_slot_box) # WEAPON_2
	equip_parents.append(head_slot_box)    # HEAD
	equip_parents.append(bust_slots_box)   # BUST_1
	equip_parents.append(bust_slots_box)   # BUST_2
	equip_parents.append(legs_slot_box)    # LEGS
	equip_parents.append(feet_slot_box)    # FEET
	equip_parents.append(bag_slot_box)     # BAG

	for i in range(EQUIP_SIZE):
		var equip_ui: InventorySlotUI = SLOT_SCENE.instantiate()
		equip_ui.slot_index = i
		equip_ui.container_type = InventorySlotUI.ContainerType.EQUIPMENT
		equip_ui.set_placeholder(EQUIP_SLOT_PLACEHOLDERS[i])
		equip_ui.slot_pressed.connect(_on_slot_pressed)
		equip_parents[i].add_child(equip_ui)
		_equip_slot_nodes.append(equip_ui)

	# 2 Slots fixos de Arma à esquerda na Hotbar do HUD (não aparecem no modal do inventário)
	for i in range(2):
		var hud_weapon_ui: InventorySlotUI = SLOT_SCENE.instantiate()
		hud_weapon_ui.slot_index = i
		hud_weapon_ui.container_type = InventorySlotUI.ContainerType.HUD_WEAPON
		hud_weapon_ui.visible = false
		hud_hotbar_grid.add_child(hud_weapon_ui)
		_hud_weapon_nodes.append(hud_weapon_ui)

	_hud_weapon_separator = VSeparator.new()
	_hud_weapon_separator.visible = false
	hud_hotbar_grid.add_child(_hud_weapon_separator)

	# 6 Slots normais da Hotbar (no Modal e no HUD)
	for i in range(HOTBAR_SIZE):
		var modal_slot_ui: InventorySlotUI = SLOT_SCENE.instantiate()
		modal_slot_ui.slot_index = i
		modal_slot_ui.container_type = InventorySlotUI.ContainerType.HOTBAR
		modal_slot_ui.slot_pressed.connect(_on_slot_pressed)
		modal_hotbar_grid.add_child(modal_slot_ui)
		_modal_hotbar_nodes.append(modal_slot_ui)

		var hud_slot_ui: InventorySlotUI = SLOT_SCENE.instantiate()
		hud_slot_ui.slot_index = i
		hud_slot_ui.container_type = InventorySlotUI.ContainerType.HOTBAR
		hud_slot_ui.slot_pressed.connect(_on_slot_pressed)
		hud_hotbar_grid.add_child(hud_slot_ui)
		_hud_hotbar_nodes.append(hud_slot_ui)


func _populate_starter_items() -> void:
	# Hotbar inicial: Munição cheia (30 balas) no slot 0
	hotbar_slots[0].set_data(ITEM_AMMO, 1, 30)

	# Itens no inventário para testar equipamentos, armas (começam com 0 balas) e munições
	inventory_slots[0].set_data(ITEM_RIFLE, 1, 0)
	inventory_slots[1].set_data(ITEM_RIFLE, 1, 0)
	inventory_slots[2].set_data(ITEM_HAT, 1)
	inventory_slots[3].set_data(ITEM_SHIRT, 1)
	inventory_slots[4].set_data(ITEM_JACKET, 1)
	inventory_slots[5].set_data(ITEM_PANTS, 1)
	inventory_slots[6].set_data(ITEM_SHOES, 1)
	inventory_slots[7].set_data(ITEM_BAG, 1)
	inventory_slots[8].set_data(ITEM_AMMO, 1, 30)
	inventory_slots[9].set_data(ITEM_MEDKIT, 6)
	inventory_slots[10].set_data(ITEM_MEDKIT, 18)
	inventory_slots[11].set_data(ITEM_KEY, 1)
	inventory_slots[12].set_data(ITEM_AMMO, 1, 15)


func toggle_inventory() -> void:
	_set_open_state(not is_open)


func _set_open_state(open: bool) -> void:
	is_open = open
	if not is_open and not held_slot.is_empty():
		_return_held_item_on_close()

	# Quando o inventário abre, a hotbar inferior desaparece e abrem o modal do inventário e o painel de equipamentos à esquerda
	hud_hotbar_panel.visible = not is_open
	if hud_ammo_panel:
		hud_ammo_panel.visible = not is_open
	if is_open and reload_indicator:
		reload_indicator.visible = false
	inventory_modal.visible = is_open
	equipment_modal.visible = is_open

	if is_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_refresh_all_ui()
	inventory_toggled.emit(is_open)


func _get_active_hotbar_indices() -> Array[int]:
	var indices: Array[int] = []
	if not equipment_slots[EquipSlot.WEAPON_1].is_empty():
		indices.append(HOTBAR_WEAPON_1_INDEX)
	if not equipment_slots[EquipSlot.WEAPON_2].is_empty():
		indices.append(HOTBAR_WEAPON_2_INDEX)
	for i in range(HOTBAR_SIZE):
		indices.append(i)
	return indices


func _change_hotbar_focus(step: int) -> void:
	var active_indices := _get_active_hotbar_indices()
	var current_pos := active_indices.find(selected_hotbar_index)
	if current_pos == -1:
		selected_hotbar_index = active_indices[0]
	else:
		var next_pos := posmod(current_pos + step, active_indices.size())
		selected_hotbar_index = active_indices[next_pos]
	_refresh_all_ui()


func get_selected_hotbar_item() -> ItemData:
	# A arma só aparece na mão caso esteja equipada no slot de arma e seu slot correspondente na hotbar esteja selecionado
	var weapon_slot := get_selected_weapon_slot()
	return weapon_slot.item if weapon_slot != null else null


func get_selected_weapon_slot() -> InventorySlotData:
	if selected_hotbar_index == HOTBAR_WEAPON_1_INDEX:
		var w1 := equipment_slots[EquipSlot.WEAPON_1]
		return w1 if not w1.is_empty() else null
	elif selected_hotbar_index == HOTBAR_WEAPON_2_INDEX:
		var w2 := equipment_slots[EquipSlot.WEAPON_2]
		return w2 if not w2.is_empty() else null
	return null


func get_total_ammo_for_item(ammo_id: String = "ammo") -> int:
	var total: int = 0
	for slot in inventory_slots:
		if not slot.is_empty() and slot.item.is_ammo and slot.item.id == ammo_id:
			total += slot.ammo
	for slot in hotbar_slots:
		if not slot.is_empty() and slot.item.is_ammo and slot.item.id == ammo_id:
			total += slot.ammo
	return total


func find_best_ammo_slot(ammo_id: String = "ammo") -> InventorySlotData:
	var best_slot: InventorySlotData = null
	var best_ammo: int = 0

	for slot in inventory_slots:
		if not slot.is_empty() and slot.item.is_ammo and slot.item.id == ammo_id and slot.ammo > best_ammo:
			best_ammo = slot.ammo
			best_slot = slot

	for slot in hotbar_slots:
		if not slot.is_empty() and slot.item.is_ammo and slot.item.id == ammo_id and slot.ammo > best_ammo:
			best_ammo = slot.ammo
			best_slot = slot

	return best_slot


func can_reload_active_weapon() -> bool:
	var weapon_slot := get_selected_weapon_slot()
	if weapon_slot == null or weapon_slot.is_empty():
		return false
	if weapon_slot.ammo >= weapon_slot.item.max_ammo:
		return false
	var ammo_id := weapon_slot.item.ammo_item_id
	if ammo_id.is_empty():
		return false
	return find_best_ammo_slot(ammo_id) != null


func consume_active_weapon_ammo(amount: int = 1) -> bool:
	var weapon_slot := get_selected_weapon_slot()
	if weapon_slot == null or weapon_slot.is_empty():
		return false
	if weapon_slot.ammo < amount:
		return false
	weapon_slot.ammo -= amount
	_refresh_all_ui()
	return true


func reload_active_weapon() -> bool:
	var weapon_slot := get_selected_weapon_slot()
	if weapon_slot == null or weapon_slot.is_empty():
		return false
	if weapon_slot.ammo >= weapon_slot.item.max_ammo:
		return false

	var best_ammo_slot := find_best_ammo_slot(weapon_slot.item.ammo_item_id)
	if best_ammo_slot == null:
		return false

	var old_ammo: int = weapon_slot.ammo
	var new_ammo: int = best_ammo_slot.ammo
	var ammo_item: ItemData = best_ammo_slot.item

	weapon_slot.ammo = new_ammo
	if old_ammo > 0:
		# Armazena a munição com balas a menos no inventário (no lugar da munição usada)
		best_ammo_slot.set_data(ammo_item, 1, old_ammo)
	else:
		# Munição zerada é descartada
		best_ammo_slot.clear()

	_refresh_all_ui()
	return true


func set_reload_visual_state(reloading: bool, progress: float = 0.0, remaining_sec: float = 0.0) -> void:
	_is_weapon_reloading = reloading
	if reload_indicator:
		reload_indicator.visible = reloading and not is_open
	if reloading:
		if reload_progress_bar:
			reload_progress_bar.value = progress
		if reload_label:
			reload_label.text = "RECARREGANDO... %.1fs" % remaining_sec
	_update_ammo_hud()


func _get_slot_data(container_type: int, slot_index: int) -> InventorySlotData:
	match container_type:
		InventorySlotUI.ContainerType.INVENTORY:
			return inventory_slots[slot_index]
		InventorySlotUI.ContainerType.HOTBAR:
			return hotbar_slots[slot_index]
		InventorySlotUI.ContainerType.EQUIPMENT:
			return equipment_slots[slot_index]
	return null


func _can_accept_item(item: ItemData, container_type: int, slot_index: int) -> bool:
	if item == null:
		return false
	if container_type == InventorySlotUI.ContainerType.EQUIPMENT:
		if slot_index < 0 or slot_index >= EQUIP_SIZE:
			return false
		return item.equip_type == EQUIP_SLOT_TYPES[slot_index]
	if container_type == InventorySlotUI.ContainerType.HUD_WEAPON:
		return false
	return true


func _on_slot_pressed(slot_index: int, container_type: int, button_index: int, shift_pressed: bool) -> void:
	if not is_open:
		return
	if container_type == InventorySlotUI.ContainerType.HUD_WEAPON:
		return

	var target_slot := _get_slot_data(container_type, slot_index)
	if target_slot == null:
		return

	if shift_pressed:
		_handle_shift_click(target_slot, container_type)
		_refresh_all_ui()
		return

	if button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click(target_slot, slot_index, container_type)
	elif button_index == MOUSE_BUTTON_RIGHT:
		_handle_right_click(target_slot, slot_index, container_type)

	_refresh_all_ui()


func _handle_left_click(target_slot: InventorySlotData, slot_index: int, container_type: int) -> void:
	if held_slot.is_empty():
		if not target_slot.is_empty():
			held_slot.copy_from(target_slot)
			target_slot.clear()
			_is_dragging_left = true
			_drag_source_index = slot_index
			_drag_source_container = container_type
	else:
		if not _can_accept_item(held_slot.item, container_type, slot_index):
			return
		_place_or_swap_held_into_slot(target_slot)
		_is_dragging_left = false
		_drag_source_index = -1


func _handle_mouse_left_release() -> void:
	_is_dragging_left = false
	if not is_open or held_slot.is_empty():
		return

	var mouse_pos := get_global_mouse_position()

	# Verifica se o usuário soltou sobre algum slot do inventário
	for i in range(_inv_slot_nodes.size()):
		var node := _inv_slot_nodes[i]
		if node.get_global_rect().has_point(mouse_pos):
			if not (_drag_source_container == InventorySlotUI.ContainerType.INVENTORY and _drag_source_index == i):
				if _can_accept_item(held_slot.item, InventorySlotUI.ContainerType.INVENTORY, i):
					_place_or_swap_held_into_slot(inventory_slots[i])
					_drag_source_index = -1
					_refresh_all_ui()
			return

	# Verifica se o usuário soltou sobre algum slot da hotbar abaixo do inventário
	for i in range(_modal_hotbar_nodes.size()):
		var node := _modal_hotbar_nodes[i]
		if node.get_global_rect().has_point(mouse_pos):
			if not (_drag_source_container == InventorySlotUI.ContainerType.HOTBAR and _drag_source_index == i):
				if _can_accept_item(held_slot.item, InventorySlotUI.ContainerType.HOTBAR, i):
					_place_or_swap_held_into_slot(hotbar_slots[i])
					_drag_source_index = -1
					_refresh_all_ui()
			return

	# Verifica se o usuário soltou sobre algum slot de equipamento à esquerda
	for i in range(_equip_slot_nodes.size()):
		var node := _equip_slot_nodes[i]
		if node.get_global_rect().has_point(mouse_pos):
			if not (_drag_source_container == InventorySlotUI.ContainerType.EQUIPMENT and _drag_source_index == i):
				if _can_accept_item(held_slot.item, InventorySlotUI.ContainerType.EQUIPMENT, i):
					_place_or_swap_held_into_slot(equipment_slots[i])
					_drag_source_index = -1
					_refresh_all_ui()
			return


func _place_or_swap_held_into_slot(target_slot: InventorySlotData) -> void:
	if held_slot.is_empty():
		return

	if target_slot.is_empty():
		target_slot.copy_from(held_slot)
		held_slot.clear()
		return

	# Mesmo item e agrupável
	if target_slot.item == held_slot.item and held_slot.item.can_stack:
		var max_s := held_slot.item.get_effective_max_stack()
		var space := max_s - target_slot.quantity
		if space > 0:
			var to_transfer := mini(space, held_slot.quantity)
			target_slot.quantity += to_transfer
			held_slot.quantity -= to_transfer
			if held_slot.quantity <= 0:
				held_slot.clear()
		else:
			var temp_qty := target_slot.quantity
			target_slot.quantity = held_slot.quantity
			held_slot.quantity = temp_qty
		return

	# Itens diferentes ou não agrupáveis: faz swap
	var temp := InventorySlotData.new()
	temp.copy_from(target_slot)
	target_slot.copy_from(held_slot)
	held_slot.copy_from(temp)


func _handle_right_click(target_slot: InventorySlotData, slot_index: int, container_type: int) -> void:
	_is_dragging_left = false

	if not target_slot.is_empty():
		if held_slot.is_empty():
			held_slot.set_data(target_slot.item, 1, target_slot.ammo)
			target_slot.quantity -= 1
			if target_slot.quantity <= 0:
				target_slot.clear()
		elif held_slot.item == target_slot.item and held_slot.item.can_stack:
			var max_s := held_slot.item.get_effective_max_stack()
			if held_slot.quantity < max_s:
				held_slot.quantity += 1
				target_slot.quantity -= 1
				if target_slot.quantity <= 0:
					target_slot.clear()
	elif not held_slot.is_empty():
		if not _can_accept_item(held_slot.item, container_type, slot_index):
			return
		target_slot.set_data(held_slot.item, 1, held_slot.ammo)
		held_slot.quantity -= 1
		if held_slot.quantity <= 0:
			held_slot.clear()


func _handle_shift_click(source_slot: InventorySlotData, from_container: int) -> void:
	if source_slot.is_empty():
		return

	# Se clicou em um slot de equipamento -> devolve para o inventário (ou hotbar se inventário lotado)
	if from_container == InventorySlotUI.ContainerType.EQUIPMENT:
		_transfer_slot_to_array(source_slot, inventory_slots)
		if not source_slot.is_empty():
			_transfer_slot_to_array(source_slot, hotbar_slots)
		return

	# Se o item é equipável e está no inventário ou hotbar, tenta equipar em um slot de equipamento correspondente vazio
	if source_slot.item.equip_type != ItemData.EquipType.NONE:
		for i in range(EQUIP_SIZE):
			if EQUIP_SLOT_TYPES[i] == source_slot.item.equip_type and equipment_slots[i].is_empty():
				equipment_slots[i].set_data(source_slot.item, 1, source_slot.ammo)
				source_slot.quantity -= 1
				if source_slot.quantity <= 0:
					source_slot.clear()
				return

	# Comportamento padrão entre inventário <-> hotbar
	var destination_array: Array[InventorySlotData] = (
		inventory_slots if from_container == InventorySlotUI.ContainerType.HOTBAR else hotbar_slots
	)
	_transfer_slot_to_array(source_slot, destination_array)


func _transfer_slot_to_array(source_slot: InventorySlotData, destination_array: Array[InventorySlotData]) -> void:
	if source_slot.is_empty():
		return

	# 1º passo: se o item pode agrupar (can_stack), tenta completar pilhas existentes do mesmo item em ordem
	if source_slot.item.can_stack:
		var max_s := source_slot.item.get_effective_max_stack()
		for dest_slot in destination_array:
			if not dest_slot.is_empty() and dest_slot.item == source_slot.item and dest_slot.quantity < max_s:
				var space := max_s - dest_slot.quantity
				var to_move := mini(space, source_slot.quantity)
				dest_slot.quantity += to_move
				source_slot.quantity -= to_move
				if source_slot.quantity <= 0:
					source_slot.clear()
					return

	# 2º passo: procura o primeiro slot totalmente livre em ordem
	for dest_slot in destination_array:
		if dest_slot.is_empty():
			var max_s := source_slot.item.get_effective_max_stack()
			var to_move := mini(max_s, source_slot.quantity)
			dest_slot.set_data(source_slot.item, to_move, source_slot.ammo)
			source_slot.quantity -= to_move
			if source_slot.quantity <= 0:
				source_slot.clear()
				return


func _return_held_item_on_close() -> void:
	if held_slot.is_empty():
		return

	# Tenta devolver para o slot de origem se estiver vazio e aceitar o item
	if _drag_source_index >= 0:
		var origin_slot := _get_slot_data(_drag_source_container, _drag_source_index)
		if origin_slot != null and origin_slot.is_empty() and _can_accept_item(held_slot.item, _drag_source_container, _drag_source_index):
			origin_slot.copy_from(held_slot)
			held_slot.clear()
			return

	# Caso contrário, tenta transferir para o inventário ou hotbar
	_transfer_slot_to_array(held_slot, inventory_slots)
	if not held_slot.is_empty():
		_transfer_slot_to_array(held_slot, hotbar_slots)
	held_slot.clear()


func _refresh_all_ui() -> void:
	var active_indices := _get_active_hotbar_indices()
	if not active_indices.has(selected_hotbar_index):
		selected_hotbar_index = 0

	for i in range(INV_SIZE):
		_inv_slot_nodes[i].update_slot(inventory_slots[i], false)

	for i in range(EQUIP_SIZE):
		_equip_slot_nodes[i].update_slot(equipment_slots[i], false)

	# Atualiza os 2 slots de arma à esquerda na Hotbar do HUD
	var w1_slot := equipment_slots[EquipSlot.WEAPON_1]
	var w2_slot := equipment_slots[EquipSlot.WEAPON_2]

	_hud_weapon_nodes[0].visible = not w1_slot.is_empty()
	_hud_weapon_nodes[0].update_slot(w1_slot, selected_hotbar_index == HOTBAR_WEAPON_1_INDEX)

	_hud_weapon_nodes[1].visible = not w2_slot.is_empty()
	_hud_weapon_nodes[1].update_slot(w2_slot, selected_hotbar_index == HOTBAR_WEAPON_2_INDEX)

	if _hud_weapon_separator:
		_hud_weapon_separator.visible = (not w1_slot.is_empty() or not w2_slot.is_empty())

	for i in range(HOTBAR_SIZE):
		var is_sel := (i == selected_hotbar_index)
		_modal_hotbar_nodes[i].update_slot(hotbar_slots[i], is_sel)
		_hud_hotbar_nodes[i].update_slot(hotbar_slots[i], is_sel)

	# Reajusta a largura do painel da Hotbar do HUD para manter centralizado conforme armas são equipadas/desequipadas
	hud_hotbar_panel.reset_size()
	var half_width := hud_hotbar_panel.get_combined_minimum_size().x * 0.5
	hud_hotbar_panel.offset_left = -half_width
	hud_hotbar_panel.offset_right = half_width

	if held_slot.is_empty():
		cursor_item.visible = false
	else:
		cursor_item.visible = true
		cursor_icon.texture = held_slot.item.icon
		cursor_icon.modulate = held_slot.item.icon_modulate
		if held_slot.item.is_ammo or held_slot.item.equip_type == ItemData.EquipType.WEAPON:
			cursor_quantity.text = "%d/%d" % [held_slot.ammo, held_slot.item.max_ammo]
			cursor_quantity.visible = true
		elif held_slot.item.can_stack and held_slot.quantity > 1:
			cursor_quantity.text = str(held_slot.quantity)
			cursor_quantity.visible = true
		else:
			cursor_quantity.text = ""
			cursor_quantity.visible = false
		cursor_item.global_position = get_global_mouse_position() - (cursor_item.size * 0.5)

	_update_ammo_hud()
	equipped_item_changed.emit(get_selected_hotbar_item())


func _update_ammo_hud() -> void:
	if not weapon_ammo_label or not inventory_ammo_label or not ammo_status_label:
		return

	var weapon_slot := get_selected_weapon_slot()
	var ammo_id := "ammo"
	if weapon_slot != null and not weapon_slot.is_empty() and not weapon_slot.item.ammo_item_id.is_empty():
		ammo_id = weapon_slot.item.ammo_item_id

	var total_inv_ammo := get_total_ammo_for_item(ammo_id)
	inventory_ammo_label.text = "Inventário: %d" % total_inv_ammo

	if weapon_slot != null and not weapon_slot.is_empty():
		weapon_ammo_label.text = "Arma: %d / %d" % [weapon_slot.ammo, weapon_slot.item.max_ammo]
		if weapon_slot.ammo <= 0:
			weapon_ammo_label.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38, 1.0))
		else:
			weapon_ammo_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98, 1.0))

		if _is_weapon_reloading:
			ammo_status_label.text = "RECARREGANDO..."
			ammo_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
		elif weapon_slot.ammo < weapon_slot.item.max_ammo:
			if total_inv_ammo > 0:
				ammo_status_label.text = "[R] Recarregar"
				ammo_status_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85, 1.0))
			elif weapon_slot.ammo == 0:
				ammo_status_label.text = "Sem munição"
				ammo_status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1.0))
			else:
				ammo_status_label.text = ""
		else:
			ammo_status_label.text = "Carregada"
			ammo_status_label.add_theme_color_override("font_color", Color(0.55, 0.88, 0.6, 1.0))
	else:
		weapon_ammo_label.text = "Arma: -- / --"
		weapon_ammo_label.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75, 1.0))
		ammo_status_label.text = "Sem arma em mãos"
		ammo_status_label.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7, 1.0))
