extends ScrollContainer
class_name SettingsTab

## Reloads the saved settings into the controls.
func apply_settings() -> void:
	push_error("apply_settings() must be overridden.")
	assert(false)


## Restores the default settings and reloads the controls.
func reset_to_defaults() -> void:
	push_error("reset_to_defaults() must be overridden.")
	assert(false)
