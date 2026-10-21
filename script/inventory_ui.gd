class_name InventoryUI
extends Control

signal equipped_item_changed(item: ItemData)
signal inventory_toggled(is_open: bool)

const INV_COLUMNS: int = 6
const INV_ROWS: int = 3
const INV_SIZE: int = INV_COLUMNS * INV_ROWS # 18 slots
const HOTBAR_SIZE: int = 6

const SLOT_SCENE: PackedScene = preload("res://scene/inventory_slot.tscn")

const ITEM_RIFLE: ItemData = preload("res://resources/items/rifle_item.tres")
const ITEM_AMMO: ItemData = preload("res://resources/items/ammo_item.tres")
const ITEM_MEDKIT: ItemData = preload("res://resources/items/medkit_item.tres")
const ITEM_KEY: ItemData = preload("res://resources/items/key_item.tres")

var inventory_slots: Array[InventorySlotData] = []
var hotbar_slots: Array[InventorySlotData] = []
var held_slot: InventorySlotData = InventorySlotData.new()

var selected_hotbar_index: int = 0
var is_open: bool = false

var _inv_slot_nodes: Array[InventorySlotUI] = []
var _modal_hotbar_nodes: Array[InventorySlotUI] = []
var _hud_hotbar_nodes: Array[InventorySlotUI] = []

var _is_dragging_left: bool = false
var _drag_source_index: int = -1
var _drag_source_is_hotbar: bool = false

@onready var hud_hotbar_panel: PanelContainer = $HUDHotbarPanel
@onready var hud_hotbar_grid: GridContainer = $HUDHotbarPanel/MarginContainer/HUDHotbarGrid
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


func _build_ui_slots() -> void:
	inventory_grid.columns = INV_COLUMNS
	modal_hotbar_grid.columns = HOTBAR_SIZE
	hud_hotbar_grid.columns = HOTBAR_SIZE

	for i in range(INV_SIZE):
		var slot_ui: InventorySlotUI = SLOT_SCENE.instantiate()
		slot_ui.slot_index = i
		slot_ui.is_hotbar = false
		slot_ui.slot_pressed.connect(_on_slot_pressed)
		inventory_grid.add_child(slot_ui)
		_inv_slot_nodes.append(slot_ui)

	for i in range(HOTBAR_SIZE):
		var modal_slot_ui: InventorySlotUI = SLOT_SCENE.instantiate()
		modal_slot_ui.slot_index = i
		modal_slot_ui.is_hotbar = true
		modal_slot_ui.slot_pressed.connect(_on_slot_pressed)
		modal_hotbar_grid.add_child(modal_slot_ui)
		_modal_hotbar_nodes.append(modal_slot_ui)

		var hud_slot_ui: InventorySlotUI = SLOT_SCENE.instantiate()
		hud_slot_ui.slot_index = i
		hud_slot_ui.is_hotbar = true
		hud_slot_ui.slot_pressed.connect(_on_slot_pressed)
		hud_hotbar_grid.add_child(hud_slot_ui)
		_hud_hotbar_nodes.append(hud_slot_ui)


func _populate_starter_items() -> void:
	# Slot 0 da Hotbar: Rifle (não agrupável, equipa na mão)
	hotbar_slots[0].set_data(ITEM_RIFLE, 1)
	# Slot 1 da Hotbar: Munição (agrupável até 20)
	hotbar_slots[1].set_data(ITEM_AMMO, 12)

	# Alguns itens no inventário para testar empilhamento (até 20), botão direito e Shift+Clique
	inventory_slots[0].set_data(ITEM_AMMO, 15)
	inventory_slots[1].set_data(ITEM_MEDKIT, 6)
	inventory_slots[2].set_data(ITEM_MEDKIT, 18)
	inventory_slots[3].set_data(ITEM_KEY, 1)


func toggle_inventory() -> void:
	_set_open_state(not is_open)


func _set_open_state(open: bool) -> void:
	is_open = open
	if not is_open and not held_slot.is_empty():
		_return_held_item_on_close()

	# Quando o inventário abre, a hotbar inferior desaparece e aparece abaixo do inventário
	hud_hotbar_panel.visible = not is_open
	inventory_modal.visible = is_open

	if is_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_refresh_all_ui()
	inventory_toggled.emit(is_open)


func _change_hotbar_focus(step: int) -> void:
	selected_hotbar_index = posmod(selected_hotbar_index + step, HOTBAR_SIZE)
	_refresh_all_ui()


func get_selected_hotbar_item() -> ItemData:
	var slot := hotbar_slots[selected_hotbar_index]
	return slot.item if not slot.is_empty() else null


func _on_slot_pressed(slot_index: int, is_hotbar: bool, button_index: int, shift_pressed: bool) -> void:
	if not is_open:
		return

	var target_slot: InventorySlotData = hotbar_slots[slot_index] if is_hotbar else inventory_slots[slot_index]

	if shift_pressed:
		_handle_shift_click(target_slot, is_hotbar)
		_refresh_all_ui()
		return

	if button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click(target_slot, slot_index, is_hotbar)
	elif button_index == MOUSE_BUTTON_RIGHT:
		_handle_right_click(target_slot)

	_refresh_all_ui()


func _handle_left_click(target_slot: InventorySlotData, slot_index: int, is_hotbar: bool) -> void:
	if held_slot.is_empty():
		if not target_slot.is_empty():
			held_slot.copy_from(target_slot)
			target_slot.clear()
			_is_dragging_left = true
			_drag_source_index = slot_index
			_drag_source_is_hotbar = is_hotbar
	else:
		_place_or_swap_held_into_slot(target_slot)
		_is_dragging_left = false
		_drag_source_index = -1


func _handle_mouse_left_release() -> void:
	_is_dragging_left = false
	if not is_open or held_slot.is_empty():
		return

	var mouse_pos := get_global_mouse_position()

	# Verifica se o usuário arrastou e soltou sobre algum slot do inventário
	for i in range(_inv_slot_nodes.size()):
		var node := _inv_slot_nodes[i]
		if node.get_global_rect().has_point(mouse_pos):
			if not (_drag_source_is_hotbar == false and _drag_source_index == i):
				_place_or_swap_held_into_slot(inventory_slots[i])
				_drag_source_index = -1
				_refresh_all_ui()
			return

	# Verifica se o usuário arrastou e soltou sobre algum slot da hotbar abaixo do inventário
	for i in range(_modal_hotbar_nodes.size()):
		var node := _modal_hotbar_nodes[i]
		if node.get_global_rect().has_point(mouse_pos):
			if not (_drag_source_is_hotbar == true and _drag_source_index == i):
				_place_or_swap_held_into_slot(hotbar_slots[i])
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
			# Se o slot destino já está em 20, troca as quantidades entre cursor e slot
			var temp_qty := target_slot.quantity
			target_slot.quantity = held_slot.quantity
			held_slot.quantity = temp_qty
		return

	# Itens diferentes ou não agrupáveis: faz swap
	var temp := InventorySlotData.new()
	temp.copy_from(target_slot)
	target_slot.copy_from(held_slot)
	held_slot.copy_from(temp)


func _handle_right_click(target_slot: InventorySlotData) -> void:
	_is_dragging_left = false

	# Quando apertar em um item com o botão direito, sai 1 item só do conjunto aglomerado para o cursor
	if not target_slot.is_empty():
		if held_slot.is_empty():
			held_slot.set_data(target_slot.item, 1)
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
		# Se clicar com botão direito em um slot vazio segurando itens, coloca 1 unidade
		target_slot.set_data(held_slot.item, 1)
		held_slot.quantity -= 1
		if held_slot.quantity <= 0:
			held_slot.clear()


func _handle_shift_click(source_slot: InventorySlotData, from_hotbar: bool) -> void:
	if source_slot.is_empty():
		return

	# Se clicou na hotbar -> vai para o inventário; se clicou no inventário -> vai para a hotbar
	var destination_array: Array[InventorySlotData] = inventory_slots if from_hotbar else hotbar_slots

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
			dest_slot.set_data(source_slot.item, to_move)
			source_slot.quantity -= to_move
			if source_slot.quantity <= 0:
				source_slot.clear()
				return


func _return_held_item_on_close() -> void:
	if held_slot.is_empty():
		return

	# Tenta devolver para o slot de origem se estiver vazio
	if _drag_source_index >= 0:
		var origin_slot: InventorySlotData = hotbar_slots[_drag_source_index] if _drag_source_is_hotbar else inventory_slots[_drag_source_index]
		if origin_slot.is_empty():
			origin_slot.copy_from(held_slot)
			held_slot.clear()
			return

	# Caso contrário, tenta transferir para o inventário ou hotbar
	_handle_shift_click(held_slot, true)
	if not held_slot.is_empty():
		_handle_shift_click(held_slot, false)
	held_slot.clear()


func _refresh_all_ui() -> void:
	for i in range(INV_SIZE):
		_inv_slot_nodes[i].update_slot(inventory_slots[i], false)

	for i in range(HOTBAR_SIZE):
		var is_sel := (i == selected_hotbar_index)
		_modal_hotbar_nodes[i].update_slot(hotbar_slots[i], is_sel)
		_hud_hotbar_nodes[i].update_slot(hotbar_slots[i], is_sel)

	if held_slot.is_empty():
		cursor_item.visible = false
	else:
		cursor_item.visible = true
		cursor_icon.texture = held_slot.item.icon
		cursor_icon.modulate = held_slot.item.icon_modulate
		if held_slot.item.can_stack and held_slot.quantity > 1:
			cursor_quantity.text = str(held_slot.quantity)
			cursor_quantity.visible = true
		else:
			cursor_quantity.text = ""
			cursor_quantity.visible = false
		cursor_item.global_position = get_global_mouse_position() - (cursor_item.size * 0.5)

	equipped_item_changed.emit(get_selected_hotbar_item())
