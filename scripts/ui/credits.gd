extends Control

signal closed

@onready var rich_text_label: RichTextLabel = $RichTextLabel
@onready var version_label: Label = $VersionLabel
@onready var close_button: ButtonFx = $CloseButton


## Shows the credits.
func open():
	show()


## Hides the credits.
func close():
	hide()
	closed.emit()


func _ready():
	rich_text_label.meta_clicked.connect(_on_meta_clicked)
	close_button.pressed.connect(close)

	var project_version: String = ProjectSettings.get_setting("application/config/version")
	var engine_version: Dictionary = Engine.get_version_info()
	version_label.text = "Version: %s\nEngine: %d.%d.%d" % [
		project_version,
		engine_version["major"],
		engine_version["minor"],
		engine_version["patch"]
	]


func _on_meta_clicked(meta: Variant):
	assert(meta is String)
	OS.shell_open(str(meta))
