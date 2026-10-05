extends Control
class_name VictoryMenu

signal request_next_level
signal request_menu

@onready var moves_label: Label = %MovesValue
@onready var pushes_label: Label = %PushesValue
@onready var optimal_move_label: Label = %OptimalMoveLabel
@onready var optimal_push_label: Label = %OptimalPushLabel

@onready var audio_player: AudioStreamPlayer = $AudioPlayer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var next_button: Button = $Panel/VBox/VBox/NextButton
@onready var menu_button: Button = $Panel/VBox/VBox/MenuButton


func open(actions: Actions):
	get_tree().paused = true

	moves_label.text = str(actions.moves())
	pushes_label.text = str(actions.pushes())

	var level_id: int = SceneTransition.level_id
	var prev_solution := Database.get_best_solution(level_id)
	Database.add_solution(level_id, str(actions))
	var best_solution := Database.get_best_solution(level_id)

	var prev_move := Actions.new(prev_solution["move_optimal"])
	var prev_push := Actions.new(prev_solution["push_optimal"])
	var best_move := Actions.new(best_solution["move_optimal"])
	var best_push := Actions.new(best_solution["push_optimal"])

	if actions.moves() < prev_move.moves():
		moves_label.add_theme_color_override("font_color", Color.GREEN)
		optimal_move_label.text = "(%s %d→%d)" % [tr("BEST"), prev_move.moves(), best_move.moves()]
	else:
		optimal_move_label.text = "(%s %d)" % [tr("BEST"), best_move.moves()]

	if actions.pushes() < prev_push.pushes():
		pushes_label.add_theme_color_override("font_color", Color.GREEN)
		optimal_push_label.text = "(%s %d→%d)" % [tr("BEST"), prev_push.pushes(), best_push.pushes()]
	else:
		optimal_push_label.text = "(%s %d)" % [tr("BEST"), best_push.pushes()]

	next_button.visible = SceneTransition.has_next_level()
	show()
	audio_player.play()
	animation_player.play("show")


func close():
	hide()
	get_tree().paused = false


func _ready():
	next_button.pressed.connect(_on_next_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)


func _on_next_button_pressed():
	close()
	request_next_level.emit()


func _on_menu_button_pressed():
	close()
	request_menu.emit()
