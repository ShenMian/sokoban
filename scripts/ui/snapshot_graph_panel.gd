extends DraggablePanel
class_name SnapshotGraphPanel
## Snapshot graph panel.

@onready var _graph: SnapshotGraph = %SnapshotGraph
@onready var _close_button: ButtonFx = %CloseButton

var _level_map: LevelMap
var _open := false
var _live_actions := ""


func _ready() -> void:
	super()
	_close_button.pressed.connect(close)
	set_process(false)


func open(map: LevelMap) -> void:
	_level_map = map
	_open = true
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
	if not is_instance_valid(_level_map):
		return

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

	var histories: Array[String] = []
	var autosave := Database.get_snapshot(level_id, true)
	if not autosave.is_empty():
		histories.append(autosave)
	var manual := Database.get_snapshot(level_id, false)
	if not manual.is_empty() and manual != autosave:
		histories.append(manual)

	for i in range(histories.size()):
		var actions := histories[i]
		if nodes.has(actions):
			continue
		nodes[actions] = {
			"key": actions,
			"kind": "snapshot",
			"actions": actions,
			"id": i,
			"order": i + 1,
			"solved": false,
			"is_live": false,
		}

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

	var keys := nodes.keys()
	var edges := {}
	for from_key in keys:
		for to_key in keys:
			if from_key == to_key:
				continue
			if str(to_key).begins_with(str(from_key)):
				edges[str(from_key) + "\n" + str(to_key)] = {
					"from": from_key,
					"to": to_key,
				}

	_graph.set_graph(nodes.values(), edges.values())


func _process(_delta: float) -> void:
	if not visible or not is_instance_valid(_level_map):
		return
	if _level_map.get_actions_lurd() != _live_actions:
		refresh()
