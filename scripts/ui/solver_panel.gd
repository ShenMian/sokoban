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

## Font colors of the status label per solve state.
const STATUS_COLORS := {
	"SEARCHING": Color(0.62, 0.88, 1.0),
	"SOLVED": Color(0.55, 0.9, 0.6),
	"NO_SOLUTION": Color(0.95, 0.45, 0.45),
	"IDLE": Color(0.65, 0.65, 0.65),
}

## Level map whose solve state this panel displays.
var level_map: LevelMap

@onready var _algorithm_value: Label = %AlgorithmValue
@onready var _strategy_value: Label = %StrategyValue
@onready var _status_label: Label = %StatusLabel
@onready var _nodes_value: Label = %NodesValue
@onready var _generated_value: Label = %GeneratedValue
@onready var _speed_value: Label = %SpeedValue
@onready var _time_value: Label = %TimeValue

@onready var _lower_bounds_switch: CheckButton = %LowerBoundsSwitch
@onready var _tunnels_switch: CheckButton = %TunnelsSwitch
@onready var _best_state_switch: CheckButton = %BestStateSwitch
@onready var _close_button: ButtonFx = %CloseButton

var _solve_started_at := 0.0
var _solver_running := false
# Whether the panel is meant to be on screen. Kept apart from `visible` so it
# survives a temporary `suspend()`.
var _open := false


func _ready():
	super()

	assert(ALGORITHM_LABELS.size() == E.Algorithm.size())
	assert(STRATEGY_LABELS.size() == E.Strategy.size())

	_lower_bounds_switch.toggled.connect(_on_lower_bounds_toggled)
	_tunnels_switch.toggled.connect(_on_tunnels_toggled)
	_best_state_switch.toggled.connect(_on_best_state_toggled)
	_close_button.pressed.connect(close)

	Settings.setting_changed.connect(_on_setting_changed)

	_apply_switch_settings()


## Shows the panel for `map` and starts the elapsed-time counter.
func open(map: LevelMap) -> void:
	level_map = map
	if not _open:
		_bind_level_map_signals()

	_algorithm_value.text = ALGORITHM_LABELS[level_map.solver_algorithm]
	_strategy_value.text = tr(STRATEGY_LABELS[level_map.solver_strategy])
	_solve_started_at = Time.get_ticks_msec() / 1000.0
	_solver_running = true
	_nodes_value.text = "0"
	_generated_value.text = "0"
	_speed_value.text = "—"
	_time_value.text = format_duration(0.0)
	_set_status("SEARCHING")

	_open = true
	show()


## Hides the panel and stops listening to the level map.
func close() -> void:
	_unbind_level_map_signals()

	_open = false
	_solver_running = false
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
	level_map.solve_no_solution.connect(_on_solve_no_solution)
	level_map.solve_cancelled.connect(_on_solve_cancelled)


func _unbind_level_map_signals() -> void:
	level_map.solve_completed.disconnect(_on_solve_completed)
	level_map.solve_no_solution.disconnect(_on_solve_no_solution)
	level_map.solve_cancelled.disconnect(_on_solve_cancelled)


func _apply_switch_settings() -> void:
	_lower_bounds_switch.set_pressed_no_signal(Settings.get_value(SECTION_NAME, "lower_bounds"))
	_tunnels_switch.set_pressed_no_signal(Settings.get_value(SECTION_NAME, "tunnels"))
	_best_state_switch.set_pressed_no_signal(Settings.get_value(SECTION_NAME, "best_state"))


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
	elif key == "best_state":
		_best_state_switch.set_pressed_no_signal(value)


func _on_lower_bounds_toggled(toggled_on: bool) -> void:
	Settings.set_and_save_value(SECTION_NAME, "lower_bounds", toggled_on)


func _on_tunnels_toggled(toggled_on: bool) -> void:
	Settings.set_and_save_value(SECTION_NAME, "tunnels", toggled_on)


func _on_best_state_toggled(toggled_on: bool) -> void:
	Settings.set_and_save_value(SECTION_NAME, "best_state", toggled_on)


func _process(_delta: float) -> void:
	if not visible or not _solver_running:
		return

	_update_stats()


func _on_solve_completed(_lurd: String) -> void:
	_finish_with("SOLVED")


func _on_solve_no_solution() -> void:
	_finish_with("NO_SOLUTION")


func _on_solve_cancelled() -> void:
	_finish_with("IDLE")


## Ends the display: pauses the clock and shows the final status.
func _finish_with(status: String) -> void:
	_solver_running = false
	_update_stats()
	_set_status(status)


## Shows the given solve state with its color.
func _set_status(status: String) -> void:
	_status_label.text = tr(status)
	_status_label.add_theme_color_override("font_color", STATUS_COLORS[status])


## Polls the solver counters and refreshes the stats rows.
func _update_stats() -> void:
	var expanded := level_map.get_solver_expanded_count()
	var generated := level_map.get_solver_generated_count()
	var elapsed := _elapsed_seconds()
	_speed_value.text = "—" if elapsed <= 0.0 else format_count(int(expanded / elapsed)) + "/s"
	_time_value.text = format_duration(elapsed)
	_nodes_value.text = format_count(expanded)
	_generated_value.text = format_count(generated)


## Seconds elapsed since the current solve started.
func _elapsed_seconds() -> float:
	if _solve_started_at <= 0.0:
		return 0.0
	return Time.get_ticks_msec() / 1000.0 - _solve_started_at


func format_duration(seconds: float) -> String:
	assert(seconds >= 0.0)

	if seconds < 1.0:
		return "%dms" % int(round(seconds * 1000.0))

	var value := seconds
	var unit := "s"
	for step in [["m", 60.0], ["h", 60.0], ["d", 24.0]]:
		var factor: float = step[1]
		if value < factor:
			break
		value /= factor
		unit = str(step[0])
	return _format_unit(value, unit)


func format_count(count: int) -> String:
	assert(count >= 0)

	if count < 1000:
		return str(count)

	var value := float(count)
	var unit := ""
	for u in ["k", "M", "B", "T"]:
		value /= 1000.0
		unit = u
		if value < 1000.0:
			break
	return _format_unit(value, unit)


func _format_unit(value: float, unit: String) -> String:
	if value >= 100.0 or value == floor(value):
		return "%d%s" % [int(value), unit]
	return "%.1f%s" % [value, unit]
