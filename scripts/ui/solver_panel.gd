extends DraggablePanel
class_name SolverPanel
## Read-only display of the running solver. Shown when a solve starts and
## kept on screen afterwards so the result stays readable; close it with the
## button in its title bar.
##
## The algorithm and strategy are snapshotted at solve start, since the solver
## cannot change them mid-solve. Only the visualization switches stay live.

const SECTION_NAME := "assists"

## Algorithm labels, indexed by `E.Algorithm`.
const ALGORITHM_LABELS := ["A*", "IDA*", "BFS"]
## Strategy labels, indexed by `E.Strategy` (index 0 is `QUICK`, shown as
## "FAST" to match the settings menu).
const STRATEGY_LABELS := ["FAST", "PUSH_OPTIMAL", "MOVE_OPTIMAL"]

## Level map whose solve state this panel displays.
var level_map: LevelMap

@onready var _algorithm_value: Label = %AlgorithmValue
@onready var _strategy_value: Label = %StrategyValue
@onready var _status_label: Label = %StatusLabel
@onready var _nodes_value: Label = %NodesValue
@onready var _time_value: Label = %TimeValue

@onready var _lower_bounds_switch: CheckButton = %LowerBoundsSwitch
@onready var _tunnels_switch: CheckButton = %TunnelsSwitch
@onready var _close_button: ButtonFx = %CloseButton

var _solve_started_at := 0.0
# True while the elapsed-time readout should tick.
var _timer_running := false
# Whether the panel is meant to be on screen. Kept apart from `visible` so it
# survives a temporary `suspend()`.
var _open := false


func _ready():
	super()

	assert(ALGORITHM_LABELS.size() == E.Algorithm.size())
	assert(STRATEGY_LABELS.size() == E.Strategy.size())

	_lower_bounds_switch.toggled.connect(_on_lower_bounds_toggled)
	_tunnels_switch.toggled.connect(_on_tunnels_toggled)
	_close_button.pressed.connect(close)

	Settings.setting_changed.connect(_on_setting_changed)

	_apply_switch_settings()


## Shows the panel for `map` and starts the elapsed-time counter.
func open(map: LevelMap) -> void:
	level_map = map
	_bind_level_map_signals()

	_algorithm_value.text = ALGORITHM_LABELS[level_map.solver_algorithm]
	_strategy_value.text = STRATEGY_LABELS[level_map.solver_strategy]

	_solve_started_at = Time.get_ticks_msec() / 1000.0
	_timer_running = true
	_nodes_value.text = "—"
	_time_value.text = "0.00s"
	_status_label.text = "SEARCHING"
	_open = true
	show()


## Hides the panel and stops listening to the level map.
func close() -> void:
	_unbind_level_map_signals()

	_open = false
	_timer_running = false
	hide()


## Hides the panel temporarily, keeping its open state so `resume()` can bring
## it back.
func suspend() -> void:
	hide()


## Restores visibility if the panel is still open.
func resume() -> void:
	if _open:
		show()


func _bind_level_map_signals() -> void:
	level_map.solve_completed.connect(_on_solve_completed)
	level_map.solve_failed.connect(_on_solve_failed)
	level_map.solve_cancelled.connect(_on_solve_cancelled)


func _unbind_level_map_signals() -> void:
	level_map.solve_completed.disconnect(_on_solve_completed)
	level_map.solve_failed.disconnect(_on_solve_failed)
	level_map.solve_cancelled.disconnect(_on_solve_cancelled)


func _apply_switch_settings() -> void:
	_lower_bounds_switch.set_pressed_no_signal(Settings.get_value(SECTION_NAME, "lower_bounds"))
	_tunnels_switch.set_pressed_no_signal(Settings.get_value(SECTION_NAME, "tunnels"))


## Mirrors the visualization switches. The algorithm and strategy labels are
## deliberately left alone: they describe the solve on screen, not the
## current settings.
func _on_setting_changed(section: String, key: String, value: Variant):
	if section != SECTION_NAME:
		return

	if key == "lower_bounds":
		_lower_bounds_switch.set_pressed_no_signal(value)
	elif key == "tunnels":
		_tunnels_switch.set_pressed_no_signal(value)


func _on_lower_bounds_toggled(toggled_on: bool) -> void:
	Settings.set_and_save_value(SECTION_NAME, "lower_bounds", toggled_on)


func _on_tunnels_toggled(toggled_on: bool) -> void:
	Settings.set_and_save_value(SECTION_NAME, "tunnels", toggled_on)


func _process(_delta: float) -> void:
	if _timer_running:
		_time_value.text = "%.2fs" % _elapsed_seconds()


func _on_solve_completed(_directions: Array) -> void:
	_finish_with("SOLVED")


func _on_solve_failed(_error: String) -> void:
	_finish_with("FAILED")


func _on_solve_cancelled() -> void:
	_finish_with("IDLE")


## Ends the display: pauses the clock and shows the final status.
func _finish_with(status: String) -> void:
	_timer_running = false
	_time_value.text = "%.2fs" % _elapsed_seconds()
	_status_label.text = status


## Seconds elapsed since the current solve started.
func _elapsed_seconds() -> float:
	if _solve_started_at <= 0.0:
		return 0.0
	return Time.get_ticks_msec() / 1000.0 - _solve_started_at
