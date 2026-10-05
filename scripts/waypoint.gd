extends Node3D

signal clicked
signal hovered
signal unhovered

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var area: Area3D = $MeshInstance3D/Area3D

@export var normal_material: StandardMaterial3D
@export var hover_material: StandardMaterial3D

var _is_hovered: bool = false


func _ready() -> void:
	_apply_effect()

	area.input_event.connect(_on_input_event)
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)


func _on_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
		get_viewport().set_input_as_handled()


func _on_mouse_entered():
	_is_hovered = true
	_apply_effect()
	hovered.emit()


func _on_mouse_exited():
	_is_hovered = false
	_apply_effect()
	unhovered.emit()


func _apply_effect():
	if _is_hovered:
		mesh.material_override = hover_material
	else:
		mesh.material_override = normal_material
