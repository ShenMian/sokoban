extends Control

signal closed

@onready var rich_text_label: RichTextLabel = $RichTextLabel
@onready var close_button: ButtonFx = $CloseButton


func open():
	show()


func close():
	hide()
	closed.emit()


func _ready():
	rich_text_label.meta_clicked.connect(_on_meta_clicked)
	close_button.pressed.connect(close)


func _on_meta_clicked(meta: Variant):
	OS.shell_open(str(meta))
