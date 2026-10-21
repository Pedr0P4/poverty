class_name InventorySlotUI
extends PanelContainer

signal slot_pressed(slot_index: int, is_hotbar: bool, button_index: int, shift_pressed: bool)

var slot_index: int = 0
var is_hotbar: bool = false
var is_focused: bool = false
var is_hovered: bool = false

var _style_normal: StyleBoxFlat
var _style_hover: StyleBoxFlat
var _style_focused: StyleBoxFlat

@onready var icon_rect: TextureRect = $MarginContainer/Icon
@onready var name_label: Label = $NameLabel
@onready var quantity_label: Label = $QuantityLabel


func _ready() -> void:
	_setup_styles()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_update_style()


func _setup_styles() -> void:
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.13, 0.14, 0.17, 0.92)
	_style_normal.border_color = Color(0.32, 0.34, 0.38, 1.0)
	_style_normal.set_border_width_all(2)
	_style_normal.set_corner_radius_all(4)

	_style_hover = _style_normal.duplicate()
	_style_hover.bg_color = Color(0.22, 0.24, 0.29, 0.96)
	_style_hover.border_color = Color(0.6, 0.65, 0.72, 1.0)

	_style_focused = _style_normal.duplicate()
	_style_focused.bg_color = Color(0.25, 0.22, 0.14, 0.96)
	_style_focused.border_color = Color(1.0, 0.82, 0.22, 1.0)
	_style_focused.set_border_width_all(3)


func update_slot(data: InventorySlotData, focused: bool = false) -> void:
	is_focused = focused
	_update_style()

	if data == null or data.is_empty():
		icon_rect.texture = null
		icon_rect.visible = false
		name_label.text = ""
		name_label.visible = false
		quantity_label.text = ""
		quantity_label.visible = false
	else:
		icon_rect.texture = data.item.icon
		icon_rect.modulate = data.item.icon_modulate
		icon_rect.visible = true

		name_label.text = data.item.item_name
		name_label.visible = true

		if data.item.can_stack and data.quantity > 1:
			quantity_label.text = str(data.quantity)
			quantity_label.visible = true
		else:
			quantity_label.text = ""
			quantity_label.visible = false


func _update_style() -> void:
	if not _style_normal:
		return
	if is_focused:
		add_theme_stylebox_override("panel", _style_focused)
	elif is_hovered:
		add_theme_stylebox_override("panel", _style_hover)
	else:
		add_theme_stylebox_override("panel", _style_normal)


func _on_mouse_entered() -> void:
	is_hovered = true
	_update_style()


func _on_mouse_exited() -> void:
	is_hovered = false
	_update_style()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			slot_pressed.emit(slot_index, is_hotbar, event.button_index, event.shift_pressed)
			accept_event()
