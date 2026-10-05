extends Control
class_name PauseMenu

signal closed
signal request_settings
signal request_credits
signal request_menu

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var settings_button: ButtonFx = $MenuBackground/VBox/SettingsButton
@onready var credits_button: ButtonFx = $MenuBackground/VBox/CreditsButton
@onready var menu_button: ButtonFx = $MenuBackground/VBox/MenuButton
@onready var close_button: ButtonFx = $CloseButton


func open():
	get_tree().paused = true
	show()
	animation_player.play("blur")


func close():
	hide()
	closed.emit()
	get_tree().paused = false


func _ready():
	close_button.pressed.connect(close)
	settings_button.pressed.connect(_on_settings_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	menu_button.pressed.connect(_on_menu_pressed)


func _exit_tree():
	close()


func _on_settings_pressed():
	request_settings.emit()


func _on_credits_pressed():
	request_credits.emit()


func _on_menu_pressed():
	close()
	request_menu.emit()
