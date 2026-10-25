class_name MainMenu
extends Control

@onready var btn_play: Button = $ContentMargin/MainVBox/ButtonContainer/BtnPlay
@onready var btn_controls: Button = $ContentMargin/MainVBox/ButtonContainer/BtnControls
@onready var btn_quit: Button = $ContentMargin/MainVBox/ButtonContainer/BtnQuit

@onready var lbl_best_time: Label = $ContentMargin/MainVBox/RecordsPanel/MarginContainer/VBoxContainer/BestTimeValue
@onready var lbl_best_kills: Label = $ContentMargin/MainVBox/RecordsPanel/MarginContainer/VBoxContainer/BestKillsValue
@onready var lbl_total_games: Label = $ContentMargin/MainVBox/RecordsPanel/MarginContainer/VBoxContainer/TotalGamesValue

@onready var controls_modal: Control = $ControlsModal
@onready var btn_close_controls: Button = $ControlsModal/CenterContainer/ControlsPanel/MarginContainer/VBoxContainer/BtnCloseControls


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if btn_play != null:
		btn_play.pressed.connect(_on_play_pressed)
	if btn_controls != null:
		btn_controls.pressed.connect(_on_controls_pressed)
	if btn_quit != null:
		btn_quit.pressed.connect(_on_quit_pressed)
	if btn_close_controls != null:
		btn_close_controls.pressed.connect(_on_close_controls_pressed)

	_update_records_display()


func _update_records_display() -> void:
	var stats := GameStats.load_stats()
	var best_time := float(stats.get("best_survival_time", 0.0))
	var best_kills := int(stats.get("best_kills", 0))
	var total_games := int(stats.get("total_games_played", 0))

	if lbl_best_time != null:
		lbl_best_time.text = "Melhor Tempo: %s" % GameStats.format_time(best_time)
	if lbl_best_kills != null:
		lbl_best_kills.text = "Inimigos Eliminados: %d" % best_kills
	if lbl_total_games != null:
		lbl_total_games.text = "Partidas Jogadas: %d" % total_games


func _on_play_pressed() -> void:
	if is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file("res://scene/terreno_teste.tscn")


func _on_controls_pressed() -> void:
	if controls_modal != null:
		controls_modal.visible = true


func _on_close_controls_pressed() -> void:
	if controls_modal != null:
		controls_modal.visible = false


func _on_quit_pressed() -> void:
	if is_inside_tree() and get_tree() != null:
		get_tree().quit()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("ui_cancel") and controls_modal != null and controls_modal.visible:
			controls_modal.visible = false
			get_viewport().set_input_as_handled()
