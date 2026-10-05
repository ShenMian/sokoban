extends Slider
class_name SliderBar

@export var disabled: bool = false:
	set(value):
		disabled = value
		if disabled:
			editable = false
			modulate = Color.GRAY * 0.8
		else:
			editable = true
			modulate = Color.WHITE

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var label: Label = $ProgressBar/Label


func _ready() -> void:
	value_changed.connect(_on_value_changed)
	progress_bar.min_value = min_value
	progress_bar.max_value = max_value
	progress_bar.step = step
	progress_bar.value = value
	label.text = str(int(round(progress_bar.value)))


func _on_value_changed(new_value: float) -> void:
	progress_bar.value = new_value
	label.text = str(int(round(new_value)))
