extends SliderBar
class_name PercentSliderBar


func _on_value_changed(new_value: float) -> void:
	progress_bar.value = new_value
	label.text = str(int(round(new_value * 100))) + "%"
