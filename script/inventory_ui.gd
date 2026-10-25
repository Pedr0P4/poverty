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
const ITEM_PISTOL: ItemData = preload("res://resources/items/pistol_item.tres")
const ITEM_SMG: ItemData = preload("res://resources/items/smg_item.tres")
const ITEM_SHOTGUN: ItemData = preload("res://resources/items/shotgun_item.tres")
const ITEM_SNIPER: ItemData = preload("res://resources/items/sniper_item.tres")
const ITEM_LMG: ItemData = preload("res://resources/items/lmg_item.tres")

const ITEM_AMMO_SMALL: ItemData = preload("res://resources/items/ammo_small_item.tres")
const ITEM_AMMO_MEDIUM: ItemData = preload("res://resources/items/ammo_medium_item.tres")
const ITEM_AMMO_LARGE: ItemData = preload("res://resources/items/ammo_large_item.tres")
const ITEM_AMMO: ItemData = preload("res://resources/items/ammo_medium_item.tres")

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
var _is_using_medkit: bool = false

var _style_reload_fill: StyleBoxFlat
var _style_medkit_fill: StyleBoxFlat
var _style_stamina_fill: StyleBoxFlat

var _loot_toast_timer: float = 0.0
var _loot_toast_fade_duration: float = 0.6

@onready var hud_top_timer_panel: PanelContainer = $HUDTopTimerPanel
@onready var timer_label: Label = $HUDTopTimerPanel/MarginContainer/VBoxContainer/TimerLabel
@onready var phase_label: Label = $HUDTopTimerPanel/MarginContainer/VBoxContainer/PhaseLabel
@onready var interaction_label: Label = $InteractionLabel
@onready var loot_toast_label: Label = $LootToastLabel
@onready var hud_stamina_container: Control = $HUDStaminaContainer
@onready var stamina_progress_bar: ProgressBar = $HUDStaminaContainer/StaminaProgressBar
@onready var hud_hotbar_panel: PanelContainer = $HUDHotbarPanel
@onready var hud_hotbar_grid: HBoxContainer = $HUDHotbarPanel/MarginContainer/HUDHotbarGrid
@onready var hud_ammo_panel: PanelContainer = $HUDAmmoPanel
@onready var ammo_title_label: Label = $HUDAmmoPanel/MarginContainer/VBoxContainer/TitleLabel
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

var is_game_over: bool = false
@onready var game_over_modal: Control = get_node_or_null("GameOverModal") as Control
@onready var go_run_time_label: Label = get_node_or_null("GameOverModal/CenterPanel/MarginContainer/VBoxContainer/StatsContainer/RunTimeLabel") as Label
@onready var go_run_kills_label: Label = get_node_or_null("GameOverModal/CenterPanel/MarginContainer/VBoxContainer/StatsContainer/RunKillsLabel") as Label
@onready var go_record_badge_label: Label = get_node_or_null("GameOverModal/CenterPanel/MarginContainer/VBoxContainer/RecordBadgeLabel") as Label
@onready var go_best_time_label: Label = get_node_or_null("GameOverModal/CenterPanel/MarginContainer/VBoxContainer/BestStatsContainer/BestTimeLabel") as Label
@onready var go_best_kills_label: Label = get_node_or_null("GameOverModal/CenterPanel/MarginContainer/VBoxContainer/BestStatsContainer/BestKillsLabel") as Label
@onready var btn_go_restart: Button = get_node_or_null("GameOverModal/CenterPanel/MarginContainer/VBoxContainer/ButtonContainer/BtnRestart") as Button
@onready var btn_go_main_menu: Button = get_node_or_null("GameOverModal/CenterPanel/MarginContainer/VBoxContainer/ButtonContainer/BtnMainMenu") as Button


func _ready() -> void:
	_ensure_inventory_and_interact_actions()
	_setup_indicator_styles()
	_init_data()
	_build_ui_slots()
	_populate_starter_items()
	_set_open_state(false)
	
	if btn_go_restart != null:
		btn_go_restart.pressed.connect(_on_go_restart_pressed)
	if btn_go_main_menu != null:
		btn_go_main_menu.pressed.connect(_on_go_main_menu_pressed)



func _ensure_inventory_and_interact_actions() -> void:
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var ev_e := InputEventKey.new()
		ev_e.physical_keycode = KEY_E
		InputMap.action_add_event("interact", ev_e)

	if InputMap.has_action("inventory"):
		var has_tab := false
		var has_i := false
		for ev in InputMap.action_get_events("inventory"):
			if ev is InputEventKey:
				var kev := ev as InputEventKey
				if kev.physical_keycode == KEY_TAB or kev.keycode == KEY_TAB:
					has_tab = true
				elif kev.physical_keycode == KEY_I or kev.keycode == KEY_I:
					has_i = true
		if not has_tab:
			var ev_tab := InputEventKey.new()
			ev_tab.physical_keycode = KEY_TAB
			InputMap.action_add_event("inventory", ev_tab)
		if not has_i:
			var ev_i := InputEventKey.new()
			ev_i.physical_keycode = KEY_I
			InputMap.action_add_event("inventory", ev_i)


func _setup_indicator_styles() -> void:
	_style_reload_fill = StyleBoxFlat.new()
	_style_reload_fill.bg_color = Color(0.95, 0.78, 0.22, 1.0)
	_style_reload_fill.set_corner_radius_all(3)

	_style_medkit_fill = StyleBoxFlat.new()
	_style_medkit_fill.bg_color = Color(0.25, 0.9, 0.42, 1.0)
	_style_medkit_fill.set_corner_radius_all(3)

	_style_stamina_fill = StyleBoxFlat.new()
	_style_stamina_fill.bg_color = Color(0.28, 0.85, 0.95, 1.0)
	_style_stamina_fill.set_corner_radius_all(3)
	if stamina_progress_bar != null:
		stamina_progress_bar.add_theme_stylebox_override("fill", _style_stamina_fill)


func _process(delta: float) -> void:
	if cursor_item.visible:
		cursor_item.global_position = get_global_mouse_position() - (cursor_item.size * 0.5)
	if not is_open:
		_update_ammo_hud()

	if _loot_toast_timer > 0.0 and loot_toast_label != null:
		_loot_toast_timer = maxf(0.0, _loot_toast_timer - delta)
		if _loot_toast_timer <= 0.0:
			loot_toast_label.visible = false
		elif _loot_toast_timer < _loot_toast_fade_duration:
			loot_toast_label.modulate.a = clampf(_loot_toast_timer / _loot_toast_fade_duration, 0.0, 1.0)
		else:
			loot_toast_label.modulate.a = 1.0


func _input(event: InputEvent) -> void:
	if is_game_over:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if not is_open and event.is_action_pressed("interact"):
			var player := Player.get_instance()
			if player != null and player.has_method("try_interact") and player.try_interact():
				get_viewport().set_input_as_handled()
				return

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
	# Kit inicial básico de sobrevivência: Pistola equipada, pouca munição pequena e 1 Kit Médico
	equipment_slots[EquipSlot.WEAPON_1].set_data(ITEM_PISTOL, 1, 12)
	selected_hotbar_index = HOTBAR_WEAPON_1_INDEX

	hotbar_slots[0].set_data(ITEM_AMMO_SMALL, 1, 24)
	hotbar_slots[1].set_data(ITEM_MEDKIT, 1)


func add_loot_item(item: ItemData, quantity: int = 1, ammo: int = 0) -> int:
	if item == null:
		return 0

	# 1. Caixas de munição: completa primeiro caixas parciais do mesmo calibre, depois ocupa slots vazios
	if item.is_ammo:
		var remaining_bullets: int = maxi(1, ammo)
		var added_bullets: int = 0
		var max_box: int = maxi(1, item.max_ammo)

		for slot: InventorySlotData in hotbar_slots:
			if not slot.is_empty() and slot.item == item and slot.ammo < max_box:
				var space: int = max_box - slot.ammo
				var take: int = mini(space, remaining_bullets)
				slot.ammo += take
				remaining_bullets -= take
				added_bullets += take
				if remaining_bullets <= 0:
					_refresh_all_ui()
					return added_bullets

		for slot: InventorySlotData in inventory_slots:
			if not slot.is_empty() and slot.item == item and slot.ammo < max_box:
				var space: int = max_box - slot.ammo
				var take: int = mini(space, remaining_bullets)
				slot.ammo += take
				remaining_bullets -= take
				added_bullets += take
				if remaining_bullets <= 0:
					_refresh_all_ui()
					return added_bullets

		for slot: InventorySlotData in hotbar_slots:
			if slot.is_empty():
				var take: int = mini(max_box, remaining_bullets)
				slot.set_data(item, 1, take)
				remaining_bullets -= take
				added_bullets += take
				if remaining_bullets <= 0:
					_refresh_all_ui()
					return added_bullets

		for slot: InventorySlotData in inventory_slots:
			if slot.is_empty():
				var take: int = mini(max_box, remaining_bullets)
				slot.set_data(item, 1, take)
				remaining_bullets -= take
				added_bullets += take
				if remaining_bullets <= 0:
					_refresh_all_ui()
					return added_bullets

		if added_bullets > 0:
			_refresh_all_ui()
		return added_bullets

	# 2. Armas: se houver um slot de arma equipado vazio (Arma 1 ou Arma 2), equipa automaticamente
	if item.equip_type == ItemData.EquipType.WEAPON:
		for w_slot_idx: int in [EquipSlot.WEAPON_1, EquipSlot.WEAPON_2]:
			if equipment_slots[w_slot_idx].is_empty():
				equipment_slots[w_slot_idx].set_data(item, 1, ammo)
				_refresh_all_ui()
				return 1

	# 3. Itens empilháveis (ex: Kit Médico)
	var remaining_qty: int = maxi(1, quantity)
	var added_qty: int = 0
	if item.can_stack:
		var max_s: int = item.get_effective_max_stack()
		for slot: InventorySlotData in hotbar_slots:
			if not slot.is_empty() and slot.item == item and slot.quantity < max_s:
				var space: int = max_s - slot.quantity
				var take: int = mini(space, remaining_qty)
				slot.quantity += take
				remaining_qty -= take
				added_qty += take
				if remaining_qty <= 0:
					_refresh_all_ui()
					return added_qty

		for slot: InventorySlotData in inventory_slots:
			if not slot.is_empty() and slot.item == item and slot.quantity < max_s:
				var space: int = max_s - slot.quantity
				var take: int = mini(space, remaining_qty)
				slot.quantity += take
				remaining_qty -= take
				added_qty += take
				if remaining_qty <= 0:
					_refresh_all_ui()
					return added_qty

	# 4. Slots vazios no inventário ou hotbar
	var first_slots: Array[InventorySlotData] = hotbar_slots if item.can_stack else inventory_slots
	var second_slots: Array[InventorySlotData] = inventory_slots if item.can_stack else hotbar_slots

	for slot: InventorySlotData in first_slots:
		if slot.is_empty():
			var max_s: int = item.get_effective_max_stack()
			var take: int = mini(max_s, remaining_qty)
			slot.set_data(item, take, ammo)
			remaining_qty -= take
			added_qty += take
			if remaining_qty <= 0:
				_refresh_all_ui()
				return added_qty

	for slot: InventorySlotData in second_slots:
		if slot.is_empty():
			var max_s: int = item.get_effective_max_stack()
			var take: int = mini(max_s, remaining_qty)
			slot.set_data(item, take, ammo)
			remaining_qty -= take
			added_qty += take
			if remaining_qty <= 0:
				_refresh_all_ui()
				return added_qty

	if added_qty > 0:
		_refresh_all_ui()
	return added_qty


static func generate_survival_chest_loot(rng: RandomNumberGenerator, tier: int = 0) -> Array[Dictionary]:
	var loot: Array[Dictionary] = []

	# 1. Sempre contém pelo menos 1 caixa de munição para sobrevivência
	var ammo_pool: Array[ItemData] = [ITEM_AMMO_SMALL, ITEM_AMMO_MEDIUM, ITEM_AMMO_LARGE]
	var chosen_ammo: ItemData = ammo_pool[rng.randi_range(0, ammo_pool.size() - 1)]
	var bullets: int = rng.randi_range(int(chosen_ammo.max_ammo * 0.45), chosen_ammo.max_ammo)
	loot.append({"item": chosen_ammo, "quantity": 1, "ammo": bullets})

	# 2. Alta chance de Kit Médico ou 2ª caixa de munição
	var roll_med := rng.randf()
	var med_chance := 0.72 if tier > 0 else 0.62
	if roll_med <= med_chance:
		var med_qty := 2 if (rng.randf() < (0.38 if tier > 0 else 0.25)) else 1
		loot.append({"item": ITEM_MEDKIT, "quantity": med_qty, "ammo": 0})
	elif roll_med <= 0.90:
		var extra_ammo: ItemData = ammo_pool[rng.randi_range(0, ammo_pool.size() - 1)]
		var extra_bullets: int = rng.randi_range(10, int(extra_ammo.max_ammo * 0.75))
		loot.append({"item": extra_ammo, "quantity": 1, "ammo": extra_bullets})

	# 3. Chance de encontrar uma Arma ou Equipamento/Roupa
	var roll_special := rng.randf()
	var weapon_chance := 0.50 if tier > 0 else 0.36
	if roll_special <= weapon_chance:
		var weapon_pool: Array[ItemData] = [ITEM_PISTOL, ITEM_SMG, ITEM_SHOTGUN, ITEM_RIFLE, ITEM_SNIPER, ITEM_LMG]
		var chosen_w: ItemData = weapon_pool[rng.randi_range(0, weapon_pool.size() - 1)]
		var start_ammo: int = rng.randi_range(maxi(1, int(chosen_w.max_ammo * 0.4)), chosen_w.max_ammo)
		loot.append({"item": chosen_w, "quantity": 1, "ammo": start_ammo})
	elif roll_special <= (weapon_chance + 0.26):
		var gear_pool: Array[ItemData] = [ITEM_HAT, ITEM_SHIRT, ITEM_JACKET, ITEM_PANTS, ITEM_SHOES, ITEM_BAG]
		var chosen_g: ItemData = gear_pool[rng.randi_range(0, gear_pool.size() - 1)]
		loot.append({"item": chosen_g, "quantity": 1, "ammo": 0})

	return loot


func update_survival_timer_hud(elapsed_seconds: float, is_night: bool, day_phase: float, difficulty_level: int, day_number: int = 1) -> void:
	if timer_label != null:
		var total_secs := maxi(0, int(floor(elapsed_seconds)))
		var mins := total_secs / 60
		var secs := total_secs % 60
		timer_label.text = "%02d:%02d" % [mins, secs]

	if phase_label != null:
		var hora_24 := int(floor(fposmod(day_phase, 1.0) * 24.0))
		if is_night:
			phase_label.text = "NOITE %d (%02dh) • AMEAÇA NV. %d" % [day_number, hora_24, difficulty_level]
			phase_label.add_theme_color_override("font_color", Color(0.62, 0.78, 1.0, 1.0))
		else:
			phase_label.text = "DIA %d (%02dh) • AMEAÇA NV. %d" % [day_number, hora_24, difficulty_level]
			phase_label.add_theme_color_override("font_color", Color(0.98, 0.85, 0.38, 1.0))


func set_interaction_prompt(prompt_text: String) -> void:
	if interaction_label == null:
		return
	if is_open or prompt_text.is_empty():
		interaction_label.visible = false
	else:
		interaction_label.text = prompt_text
		interaction_label.visible = true


func show_loot_toast(message: String, color: Color = Color(0.98, 0.88, 0.35, 1.0)) -> void:
	if loot_toast_label == null:
		return
	loot_toast_label.text = message
	loot_toast_label.add_theme_color_override("font_color", color)
	loot_toast_label.modulate.a = 1.0
	loot_toast_label.visible = true
	_loot_toast_timer = 2.8


func show_game_over(survival_time: float, kills: int) -> void:
	is_game_over = true
	var res := GameStats.register_run(survival_time, kills)

	if is_open:
		_set_open_state(false)

	hud_hotbar_panel.visible = false
	if hud_ammo_panel:
		hud_ammo_panel.visible = false
	if hud_stamina_container:
		hud_stamina_container.visible = false
	if interaction_label:
		interaction_label.visible = false
	if reload_indicator:
		reload_indicator.visible = false
	if hud_top_timer_panel:
		hud_top_timer_panel.visible = false
	if loot_toast_label:
		loot_toast_label.visible = false

	if go_run_time_label != null:
		go_run_time_label.text = "Tempo Sobrevivido: %s" % GameStats.format_time(survival_time)
	if go_run_kills_label != null:
		go_run_kills_label.text = "Inimigos Eliminados: %d" % kills

	var is_new_time: bool = bool(res.get("is_new_best_time", false))
	var is_new_kills: bool = bool(res.get("is_new_best_kills", false))
	if go_record_badge_label != null:
		if is_new_time or is_new_kills:
			var badges: Array[String] = []
			if is_new_time:
				badges.append("TEMPO")
			if is_new_kills:
				badges.append("ABATES")
			go_record_badge_label.text = "★ NOVO RECORDE DE %s! ★" % " E ".join(badges)
			go_record_badge_label.visible = true
		else:
			go_record_badge_label.visible = false

	if go_best_time_label != null:
		go_best_time_label.text = "Recorde Tempo: %s" % GameStats.format_time(float(res.get("best_time", 0.0)))
	if go_best_kills_label != null:
		go_best_kills_label.text = "Recorde Abates: %d" % int(res.get("best_kills", 0))

	if game_over_modal != null:
		game_over_modal.visible = true

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_go_restart_pressed() -> void:
	if is_inside_tree() and get_tree() != null:
		get_tree().reload_current_scene()


func _on_go_main_menu_pressed() -> void:
	if is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file("res://scene/main_menu.tscn")



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
	if is_open and hud_stamina_container:
		hud_stamina_container.visible = false
	if is_open and interaction_label:
		interaction_label.visible = false
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


func update_stamina_hud(ratio: float, alpha: float, exhausted: bool) -> void:
	if hud_stamina_container == null or stamina_progress_bar == null:
		return
	if is_open or alpha <= 0.005:
		hud_stamina_container.visible = false
		hud_stamina_container.modulate.a = 0.0
		return

	hud_stamina_container.visible = true
	hud_stamina_container.modulate.a = clampf(alpha, 0.0, 1.0)
	stamina_progress_bar.value = clampf(ratio, 0.0, 1.0)

	if _style_stamina_fill != null:
		if exhausted:
			_style_stamina_fill.bg_color = Color(0.95, 0.32, 0.25, 1.0)
		else:
			var low_color := Color(0.95, 0.72, 0.22, 1.0)
			var full_color := Color(0.28, 0.85, 0.95, 1.0)
			_style_stamina_fill.bg_color = low_color.lerp(full_color, clampf(ratio, 0.0, 1.0))


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
	if weapon_slot != null:
		return weapon_slot.item
	var normal_slot := get_selected_normal_hotbar_slot()
	if normal_slot != null and not normal_slot.item.is_weapon():
		return normal_slot.item
	return null


func get_selected_normal_hotbar_slot() -> InventorySlotData:
	if selected_hotbar_index >= 0 and selected_hotbar_index < hotbar_slots.size():
		var slot := hotbar_slots[selected_hotbar_index]
		return slot if not slot.is_empty() else null
	return null


func has_selected_medkit() -> bool:
	var slot := get_selected_normal_hotbar_slot()
	return slot != null and not slot.is_empty() and slot.item.id == "medkit" and slot.quantity > 0


func get_selected_medkit_item() -> ItemData:
	var slot := get_selected_normal_hotbar_slot()
	if slot != null and not slot.is_empty() and slot.item.id == "medkit":
		return slot.item
	return null


func consume_selected_medkit(amount: int = 1) -> bool:
	var slot := get_selected_normal_hotbar_slot()
	if slot == null or slot.is_empty() or slot.item.id != "medkit":
		return false
	if slot.quantity < amount:
		return false
	slot.quantity -= amount
	if slot.quantity <= 0:
		slot.clear()
	_refresh_all_ui()
	return true


func get_selected_weapon_slot() -> InventorySlotData:
	if selected_hotbar_index == HOTBAR_WEAPON_1_INDEX:
		var w1 := equipment_slots[EquipSlot.WEAPON_1]
		return w1 if not w1.is_empty() else null
	elif selected_hotbar_index == HOTBAR_WEAPON_2_INDEX:
		var w2 := equipment_slots[EquipSlot.WEAPON_2]
		return w2 if not w2.is_empty() else null
	return null


func get_total_ammo_for_item(ammo_id: String = "ammo_medium") -> int:
	var total: int = 0
	for slot in inventory_slots:
		if not slot.is_empty() and slot.item.is_ammo and slot.item.id == ammo_id:
			total += slot.ammo
	for slot in hotbar_slots:
		if not slot.is_empty() and slot.item.is_ammo and slot.item.id == ammo_id:
			total += slot.ammo
	return total


func find_best_ammo_slot(ammo_id: String = "ammo_medium") -> InventorySlotData:
	var best_slot: InventorySlotData = null
	var best_ammo: int = 999999

	# Prioriza consumir primeiro de caixas parciais do mesmo calibre para liberar espaço
	for slot in inventory_slots:
		if not slot.is_empty() and slot.item.is_ammo and slot.item.id == ammo_id and slot.ammo > 0 and slot.ammo < best_ammo:
			best_ammo = slot.ammo
			best_slot = slot

	for slot in hotbar_slots:
		if not slot.is_empty() and slot.item.is_ammo and slot.item.id == ammo_id and slot.ammo > 0 and slot.ammo < best_ammo:
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

	var ammo_id := weapon_slot.item.ammo_item_id
	if ammo_id.is_empty():
		return false

	var needed: int = weapon_slot.item.max_ammo - weapon_slot.ammo
	var loaded_any := false

	while needed > 0:
		var ammo_slot := find_best_ammo_slot(ammo_id)
		if ammo_slot == null or ammo_slot.ammo <= 0:
			break
		var take := mini(needed, ammo_slot.ammo)
		weapon_slot.ammo += take
		ammo_slot.ammo -= take
		needed -= take
		loaded_any = true
		if ammo_slot.ammo <= 0:
			ammo_slot.clear()

	if loaded_any:
		_refresh_all_ui()
	return loaded_any


func set_reload_visual_state(reloading: bool, progress: float = 0.0, remaining_sec: float = 0.0) -> void:
	_is_weapon_reloading = reloading
	if reload_indicator:
		reload_indicator.visible = (reloading or _is_using_medkit) and not is_open
	if reloading:
		if reload_progress_bar:
			if _style_reload_fill:
				reload_progress_bar.add_theme_stylebox_override("fill", _style_reload_fill)
			reload_progress_bar.value = progress
		if reload_label:
			reload_label.text = "RECARREGANDO... %.1fs" % remaining_sec
			reload_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3, 1.0))
	_update_ammo_hud()


func set_medkit_visual_state(using: bool, progress: float = 0.0, remaining_sec: float = 0.0) -> void:
	_is_using_medkit = using
	if reload_indicator:
		reload_indicator.visible = (using or _is_weapon_reloading) and not is_open
	if using:
		if reload_progress_bar:
			if _style_medkit_fill:
				reload_progress_bar.add_theme_stylebox_override("fill", _style_medkit_fill)
			reload_progress_bar.value = progress
		if reload_label:
			reload_label.text = "USANDO KIT MÉDICO... %.1fs" % remaining_sec
			reload_label.add_theme_color_override("font_color", Color(0.35, 0.95, 0.48, 1.0))
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

	# Mesma caixa de munição parcial: junta as balas até o max_ammo da caixa
	if target_slot.item == held_slot.item and held_slot.item.is_ammo:
		var max_a: int = held_slot.item.max_ammo
		var space_a: int = max_a - target_slot.ammo
		if space_a > 0 and held_slot.ammo > 0:
			var transfer_a: int = mini(space_a, held_slot.ammo)
			target_slot.ammo += transfer_a
			held_slot.ammo -= transfer_a
			if held_slot.ammo <= 0:
				held_slot.clear()
			return

	# Mesmo item e agrupável
	if target_slot.item == held_slot.item and held_slot.item.can_stack:
		var max_s: int = held_slot.item.get_effective_max_stack()
		var space: int = max_s - target_slot.quantity
		if space > 0:
			var to_transfer: int = mini(space, held_slot.quantity)
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
			var max_s: int = held_slot.item.get_effective_max_stack()
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
		var max_s: int = source_slot.item.get_effective_max_stack()
		for dest_slot in destination_array:
			if not dest_slot.is_empty() and dest_slot.item == source_slot.item and dest_slot.quantity < max_s:
				var space: int = max_s - dest_slot.quantity
				var to_move: int = mini(space, source_slot.quantity)
				dest_slot.quantity += to_move
				source_slot.quantity -= to_move
				if source_slot.quantity <= 0:
					source_slot.clear()
					return

	# 2º passo: procura o primeiro slot totalmente livre em ordem
	for dest_slot in destination_array:
		if dest_slot.is_empty():
			var max_s: int = source_slot.item.get_effective_max_stack()
			var to_move: int = mini(max_s, source_slot.quantity)
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


func _get_ammo_label_for_id(ammo_id: String) -> String:
	match ammo_id:
		"ammo_small":
			return "Mun. Pequena"
		"ammo_medium":
			return "Mun. Média"
		"ammo_large":
			return "Mun. Grande"
	return "Munição"


func _update_ammo_hud() -> void:
	if not weapon_ammo_label or not inventory_ammo_label or not ammo_status_label:
		return

	var weapon_slot := get_selected_weapon_slot()
	if weapon_slot != null and not weapon_slot.is_empty():
		var ammo_id := weapon_slot.item.ammo_item_id
		var ammo_type_name := _get_ammo_label_for_id(ammo_id)
		var total_inv_ammo := get_total_ammo_for_item(ammo_id)

		if ammo_title_label:
			ammo_title_label.text = "%s (%s)" % [weapon_slot.item.item_name.to_upper(), ammo_type_name]
		inventory_ammo_label.text = "%s: %d" % [ammo_type_name, total_inv_ammo]
		weapon_ammo_label.text = "Arma: %d / %d" % [weapon_slot.ammo, weapon_slot.item.max_ammo]

		if weapon_slot.ammo <= 0:
			weapon_ammo_label.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38, 1.0))
		else:
			weapon_ammo_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98, 1.0))

		var player := Player.get_instance()
		var hint := player.get_active_weapon_hint() if player != null else ""

		if _is_weapon_reloading:
			ammo_status_label.text = "RECARREGANDO..."
			ammo_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
		elif weapon_slot.ammo == 0:
			if total_inv_ammo > 0:
				ammo_status_label.text = "[R] Recarregar"
				ammo_status_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.3, 1.0))
			else:
				ammo_status_label.text = "Sem %s" % ammo_type_name
				ammo_status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1.0))
		elif not hint.is_empty():
			if weapon_slot.ammo < weapon_slot.item.max_ammo and total_inv_ammo > 0:
				ammo_status_label.text = "%s | [R] Recarregar" % hint
			else:
				ammo_status_label.text = hint
			ammo_status_label.add_theme_color_override("font_color", Color(0.68, 0.88, 0.96, 1.0))
		elif weapon_slot.ammo < weapon_slot.item.max_ammo and total_inv_ammo > 0:
			ammo_status_label.text = "[R] Recarregar"
			ammo_status_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85, 1.0))
		else:
			ammo_status_label.text = "Carregada"
			ammo_status_label.add_theme_color_override("font_color", Color(0.55, 0.88, 0.6, 1.0))
	else:
		if ammo_title_label:
			ammo_title_label.text = "MUNIÇÕES NO INV."
		var s_total := get_total_ammo_for_item("ammo_small")
		var m_total := get_total_ammo_for_item("ammo_medium")
		var l_total := get_total_ammo_for_item("ammo_large")
		weapon_ammo_label.text = "Arma: -- / --"
		weapon_ammo_label.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75, 1.0))
		inventory_ammo_label.text = "P:%d | M:%d | G:%d" % [s_total, m_total, l_total]
		if has_selected_medkit():
			var player := Player.get_instance()
			if _is_using_medkit:
				ammo_status_label.text = "Aplicando Kit Médico..."
				ammo_status_label.add_theme_color_override("font_color", Color(0.35, 0.95, 0.48, 1.0))
			elif player != null and player.health >= player.max_health:
				ammo_status_label.text = "Kit Médico (Vida Cheia)"
				ammo_status_label.add_theme_color_override("font_color", Color(0.65, 0.85, 0.7, 1.0))
			else:
				ammo_status_label.text = "[Segure Botão Esq]: Usar Kit Médico"
				ammo_status_label.add_theme_color_override("font_color", Color(0.35, 0.95, 0.48, 1.0))
		else:
			ammo_status_label.text = "Sem arma em mãos"
			ammo_status_label.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7, 1.0))
