extends Control

signal closed

@onready var rich_text_label: RichTextLabel = $RichTextLabel
@onready var version_label: Label = $VersionLabel
@onready var close_button: ButtonFx = $CloseButton


func open():
	show()


func close():
	hide()
	closed.emit()


func _ready():
	var project_version: String = ProjectSettings.get_setting(
		"application/config/version",
		"Unknown",
	)
	var engine_info: Dictionary = Engine.get_version_info()
	var engine_version: String = "%d.%d.%d" % [
		engine_info["major"],
		engine_info["minor"],
		engine_info["patch"],
	]
	version_label.text = "Version: %s\nEngine: %s" % [project_version, engine_version]

	rich_text_label.meta_clicked.connect(_on_meta_clicked)
	close_button.pressed.connect(close)


func _on_meta_clicked(meta: Variant):
	OS.shell_open(str(meta))
