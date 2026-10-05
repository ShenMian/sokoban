extends Node

@export_group("Materials")
@export var box_outer_frame_material: StandardMaterial3D
@export var box_diagonal_bar_material: StandardMaterial3D
@export var box_inner_fill_material: StandardMaterial3D
@export var box_body_material: StandardMaterial3D
@export var box_hat_material: StandardMaterial3D
@export var indicator_material: StandardMaterial3D
@export var waypoint_normal_material: StandardMaterial3D
@export var waypoint_hover_material: StandardMaterial3D
@export var path_preview_material: StandardMaterial3D

@export_group("", "")
@export var waypoint_alpha := 0.5
@export var waypoint_hover_lighten := 0.7

var floor_color: Color
var wall_color: Color
var goal_color: Color

var DESERT_OASIS := {
	"background_color": Color("#3E2B1D"),
	"floor_color": Color("#F3E9D2"),
	"wall_color": Color("#E0A96D"),
	"goal_color": Color("#1A6C3E"),
	"box_outer_frame_color": Color("#C57B57"),
	"box_diagonal_bar_color": Color("#8C5230"),
	"box_inner_fill_color": Color("#E8D8C4"),
	"player_body_color": Color("#1A508B"),
	"player_hat_color": Color("#C4884B"),
	"indicator_color": Color("#00AFB9"),
	"waypoint_color": Color("#247BA0"),
	"path_preview_color": Color("#00E5F2")
}

var ARCTIC_LAB := {
	"background_color": Color("#AEC3D6"),
	"floor_color": Color("#DDE3EA"),
	"wall_color": Color("#7A96BA"),
	"goal_color": Color("#E66767"),
	"box_outer_frame_color": Color("#565E7A"),
	"box_diagonal_bar_color": Color("#E5BE5E"),
	"box_inner_fill_color": Color("#C2B4B6"),
	"player_body_color": Color("#E5BE5E"),
	"player_hat_color": Color("#2A3546"),
	"indicator_color": Color("#1D8EC4"),
	"waypoint_color": Color("#D97A28"),
	"path_preview_color": Color("#FF4D4D")
}

var OCEAN_DEPTHS := {
	"background_color": Color("#01050F"),
	"floor_color": Color("#014C63"),
	"wall_color": Color("#003B50"),
	"goal_color": Color("#EF835F"),
	"box_outer_frame_color": Color("#CD853F"),
	"box_diagonal_bar_color": Color("#EF835F"),
	"box_inner_fill_color": Color("#001A33"),
	"player_body_color": Color("#01B7A3"),
	"player_hat_color": Color("#001A33"),
	"indicator_color": Color("#FDD017"),
	"waypoint_color": Color("#00979a"),
	"path_preview_color": Color("#00F5D4")
}

var THEMES := [
	DESERT_OASIS,
	ARCTIC_LAB,
	OCEAN_DEPTHS
]


func _ready() -> void:
	Settings.setting_changed.connect(_on_setting_changed)
	_on_setting_changed("gameplay", "theme", Settings.get_value("gameplay", "theme"))


func apply(theme: Dictionary) -> void:
	RenderingServer.set_default_clear_color(theme.get("background_color"))
	floor_color = theme.get("floor_color")
	wall_color = theme.get("wall_color")
	goal_color = theme.get("goal_color")
	box_outer_frame_material.albedo_texture = _create_texture_from_color(theme.get("box_outer_frame_color"))
	box_diagonal_bar_material.albedo_texture = _create_texture_from_color(theme.get("box_diagonal_bar_color"))
	box_inner_fill_material.albedo_texture = _create_texture_from_color(theme.get("box_inner_fill_color"))
	box_body_material.albedo_texture = _create_texture_from_color(theme.get("player_body_color"))
	box_hat_material.albedo_texture = _create_texture_from_color(theme.get("player_hat_color"))
	indicator_material.albedo_texture = _create_texture_from_color(theme.get("indicator_color"))
	var waypoint_color := Color(theme.get("waypoint_color"), waypoint_alpha)
	waypoint_normal_material.albedo_color = waypoint_color
	waypoint_hover_material.albedo_color = waypoint_color.lightened(waypoint_hover_lighten)
	path_preview_material.albedo_color = theme.get("path_preview_color")


func _create_texture_from_color(color: Color) -> Texture2D:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _on_setting_changed(section: String, key: String, value: Variant):
	if section == "gameplay" and key == "theme":
		apply(THEMES[value])
