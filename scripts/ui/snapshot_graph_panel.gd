extends DraggablePanel
class_name SnapshotGraphPanel
## Snapshot graph panel.

@onready var _graph: SnapshotGraph = %SnapshotGraph
@onready var _save_button: Button = %SaveButton
@onready var _delete_button: Button = %DeleteButton
@onready var _close_button: ButtonFx = %CloseButton

var _level_map: LevelMap
var _open := false
var _live_actions := ""
var _selected_id := -1


func _ready() -> void:
	super()
	_save_button.pressed.connect(_on_save_pressed)
	_delete_button.pressed.connect(_on_delete_pressed)
	_close_button.pressed.connect(close)
	_graph.node_clicked.connect(_on_node_clicked)
	set_process(false)


func open(map: LevelMap) -> void:
	_level_map = map
	_open = true
	_select_snapshot(-1)
	refresh()
	set_process(true)
	show()


func close() -> void:
	_open = false
	set_process(false)
	hide()


func suspend() -> void:
	hide()


func resume() -> void:
	if _open:
		refresh()
		show()


func toggle(map: LevelMap) -> void:
	if _open:
		close()
	else:
		open(map)


## Rebuilds the graph from snapshots and the live state.
func refresh() -> void:
	assert(is_instance_valid(_level_map))

	var level_id: int = SceneTransition.get_level_id()
	var live_actions: String = _level_map.get_actions_lurd()
	_live_actions = live_actions

	var nodes := {}
	nodes[""] = {
		"key": "",
		"kind": "start",
		"actions": "",
		"id": -1,
		"order": 0,
		"solved": false,
		"is_live": false,
	}

	var snapshots: Array = Database.get_snapshots(level_id)
	for i in range(snapshots.size()):
		var row: Dictionary = snapshots[i]
		var actions := str(row["actions_lurd"])
		if actions.is_empty() or nodes.has(actions):
			continue
		nodes[actions] = {
			"key": actions,
			"kind": "snapshot",
			"actions": actions,
			"id": int(row["id"]),
			"order": i + 1,
			"solved": false,
			"is_live": false,
		}

	# Check if the selected snapshot still exists, otherwise deselect it
	if _selected_id >= 0 and not snapshots.any(func(s: Dictionary) -> bool: return int(s["id"]) == _selected_id):
		_select_snapshot(-1)

	if nodes.has(live_actions):
		nodes[live_actions]["is_live"] = true
	else:
		nodes[live_actions] = {
			"key": live_actions,
			"kind": "live",
			"actions": live_actions,
			"id": -1,
			"order": 0x7FFFFFFF,
			"solved": false,
			"is_live": true,
		}

	var keys: Array = nodes.keys()
	var edges := {}
	for key in keys:
		var actions := str(key)
		if actions.is_empty():
			continue
		var predecessor := ""
		for candidate in keys:
			var candidate_actions := str(candidate)
			if candidate_actions == actions:
				continue
			if actions.begins_with(candidate_actions) and candidate_actions.length() > predecessor.length():
				predecessor = candidate_actions
		edges[predecessor + "\n" + actions] = {
			"from": predecessor,
			"to": actions,
		}

	_graph.set_graph(nodes.values(), edges.values())
	_graph.set_selected_id(_selected_id)


func _on_save_pressed() -> void:
	var level_id: int = SceneTransition.get_level_id()
	var actions: String = _level_map.get_actions_lurd()
	if actions.is_empty():
		return
	for row: Dictionary in Database.get_snapshots(level_id):
		if str(row["actions_lurd"]) == actions:
			_select_snapshot(int(row["id"]))
			return
	Database.add_snapshot(level_id, actions, false)
	refresh()
	for row: Dictionary in Database.get_snapshots(level_id):
		if str(row["actions_lurd"]) == actions:
			_select_snapshot(int(row["id"]))
			break


func _on_node_clicked(node: Dictionary) -> void:
	if node.is_empty():
		_select_snapshot(-1)
		return
	var id := int(node["id"])
	if str(node["kind"]) == "snapshot" and id >= 0:
		_select_snapshot(id)
	else:
		_select_snapshot(-1)


func _on_delete_pressed() -> void:
	if _selected_id < 0:
		return
	Database.delete_snapshot(_selected_id)
	_select_snapshot(-1)
	refresh()


func _select_snapshot(id: int) -> void:
	_selected_id = id
	_delete_button.disabled = id < 0
	_graph.set_selected_id(id)


func _process(_delta: float) -> void:
	if not visible:
		return
	assert(is_instance_valid(_level_map))
	if _level_map.get_actions_lurd() != _live_actions:
		refresh()
