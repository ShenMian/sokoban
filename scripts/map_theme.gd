extends Node

@export_group("Materials")
## Material of the box outer frame.
@export var box_outer_frame_material: StandardMaterial3D
## Material of the box diagonal bars.
@export var box_diagonal_bar_material: StandardMaterial3D
## Material of the box inner fill.
@export var box_inner_fill_material: StandardMaterial3D
## Material of the player's body.
@export var box_body_material: StandardMaterial3D
## Material of the player's hat.
@export var box_hat_material: StandardMaterial3D
## Material of the selection and hover indicators.
@export var indicator_material: StandardMaterial3D
## Material of an idle waypoint marker.
@export var waypoint_normal_material: StandardMaterial3D
## Material of a hovered waypoint marker.
@export var waypoint_hover_material: StandardMaterial3D
## Material of the path preview ribbon.
@export var path_preview_material: StandardMaterial3D

@export_group("", "")
## Opacity of waypoint markers.
@export var waypoint_alpha := 0.5
## How much a hovered waypoint is lightened.
@export var waypoint_hover_lighten := 0.7

var floor_color: Color
var wall_color: Color
var goal_color: Color

const DESERT_OASIS := {
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

const ARCTIC_LAB := {
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
	"path_preview_color": Color("#FF4D4D"),
}

const OCEAN_DEPTHS := {
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
	"path_preview_color": Color("#00F5D4"),
}

const THEMES := [DESERT_OASIS, ARCTIC_LAB, OCEAN_DEPTHS]


func _ready() -> void:
	Settings.setting_changed.connect(_on_setting_changed)
	_on_setting_changed("gameplay", "theme", Settings.get_value("gameplay", "theme"))


## Applies the given theme colors to the scene materials.
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


## Returns a 1×1 texture filled with the given color.
func _create_texture_from_color(color: Color) -> Texture2D:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _on_setting_changed(section: String, key: String, value: Variant):
	if section == "gameplay" and key == "theme":
		assert(0 <= value && value < THEMES.size())
		apply(THEMES[value])


## Ensures the tinted MeshLibrary variants used by LevelMap exist with current colors.
## Variant meshes are duplicated once; later calls only re-tint the existing
## materials in place, so live GridMap cells keep referencing a stable mesh.
func ensure_all(map: LevelMap) -> void:
	if not map.is_inside_tree():
		return
	var library: MeshLibrary = map.mesh_library
	assert(library != null)
	var floor_color: Color = MapTheme.get("floor_color")
	map.floor_item_id = _ensure_variant(library, map.base_floor_item_id, "theme_floor", floor_color)
	map.wall_item_id = _ensure_variant(library, map.base_wall_item_id, "theme_wall", MapTheme.get("wall_color"))
	map.goal_item_id = _ensure_variant(library, map.base_goal_item_id, "theme_goal", MapTheme.get("goal_color"))
	map.floor_dark_item_id = _ensure_variant(library, map.floor_item_id, "floor_dark", floor_color.darkened(0.15))
	map.deadlock_item_id = _ensure_variant(library, map.floor_item_id, "floor_deadlock", floor_color * map.deadlock_tint)
	map.deadlock_dark_item_id = _ensure_variant(library, map.floor_item_id, "floor_deadlock_dark", floor_color.darkened(0.15) * map.deadlock_tint)


## Re-tints the existing variant material, duplicating the base mesh only on first use.
func _ensure_variant(library: MeshLibrary, base_item_id: int, variant_name: String, color: Color) -> int:
	var item_id := library.find_item_by_name(variant_name)
	if item_id == -1:
		return _create_variant(library, base_item_id, variant_name, color)
	var existing_mesh := library.get_item_mesh(item_id) as ArrayMesh
	var themed := existing_mesh.surface_get_material(0) as StandardMaterial3D
	_apply_variant_color(themed, color)
	return item_id
	

## Duplicates the base item mesh once and stores it under `variant_name`.
func _create_variant(library: MeshLibrary, base_item_id: int, variant_name: String, color: Color) -> int:
	assert(base_item_id != GridMap.INVALID_CELL_ITEM)
	var base_mesh := library.get_item_mesh(base_item_id) as ArrayMesh
	var base_material := base_mesh.surface_get_material(0) as StandardMaterial3D
	var item_id := library.find_item_by_name(variant_name)
	item_id = library.get_last_unused_item_id()
	library.create_item(item_id)
	library.set_item_name(item_id, variant_name)
	var new_material := base_material.duplicate() as StandardMaterial3D
	_apply_variant_color(new_material, color)
	var new_mesh := base_mesh.duplicate() as ArrayMesh
	new_mesh.surface_set_material(0, new_material)
	library.set_item_mesh(item_id, new_mesh)
	library.set_item_mesh_transform(item_id, library.get_item_mesh_transform(base_item_id))
	return item_id


## Applies the final themed color to a variant material.
func _apply_variant_color(material: StandardMaterial3D, color: Color) -> void:
	material.albedo_color = color
	material.albedo_texture = null
	material.vertex_color_use_as_albedo = false
