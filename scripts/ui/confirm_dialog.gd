extends Control
class_name ConfirmDialog

signal canceled
signal confirmed

## Override the dialog title.
@export var title: String
## Override the confirm button text.
@export var confirm_text: String
## Override the cancel button text.
@export var cancel_text: String

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var message_label: Label = $Panel/VBox/MessageLabel

@onready var cancel_button: ButtonFx = $Panel/VBox/Buttons/CancelButton
@onready var confirm_button: ButtonFx = $Panel/VBox/Buttons/ConfirmButton


## Opens the dialog with the given message. The message is used as is, pass an
## already translated string.
func open(message: String) -> void:
	message_label.text = message
	show()


## Hides the dialog.
func close() -> void:
	hide()


func _ready():
	if not title.is_empty():
		title_label.text = title
	if not confirm_text.is_empty():
		confirm_button.text = confirm_text
	if not cancel_text.is_empty():
		cancel_button.text = cancel_text

	cancel_button.pressed.connect(_on_cancel_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)


func _on_cancel_pressed():
	close()
	canceled.emit()


func _on_confirm_pressed():
	close()
	confirmed.emit()
