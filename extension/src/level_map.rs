use std::{
    io::{BufReader, Cursor},
    str::FromStr,
};

use godot::{
    classes::{
        ArrayMesh, FileAccess, GridMap, IGridMap, MeshLibrary, StandardMaterial3D,
        file_access::ModeFlags,
    },
    meta::ToGodot as _,
    prelude::*,
};
use soukoban::{
    deadlock::compute_static_deadlocks, direction, path_finding, prelude::*, solver::Solver,
};

use crate::{
    convert::{ToGodot, ToSoukoban as _},
    enums::{algorithm::Algorithm, direction::Direction, strategy::Strategy},
    solver_worker::SolverWorker,
};

#[derive(GodotClass)]
#[class(base=GridMap)]
struct LevelMap {
    level: Level,

    #[export]
    checkerboard_shading: bool,

    #[export]
    deadlock_hint: bool,

    #[export]
    #[var(set = set_deadlock_tint)]
    deadlock_tint: Color,

    #[export]
    pathfinding_strategy: Strategy,

    #[export_group(name = "Base Meshes", prefix = "base_")]
    #[export]
    base_floor_item_id: i32,
    #[export]
    base_wall_item_id: i32,
    #[export]
    base_goal_item_id: i32,

    floor_item_id: i32,
    wall_item_id: i32,
    goal_item_id: i32,
    floor_dark_item_id: i32,
    deadlock_item_id: i32,
    deadlock_dark_item_id: i32,

    waypoints: FxHashMap<DirectedPosition, DirectedPosition>,
    costs: FxHashMap<DirectedPosition, i32>,

    solver_worker: SolverWorker,

    base: Base<GridMap>,
}

#[godot_api]
impl IGridMap for LevelMap {
    fn init(base: Base<GridMap>) -> Self {
        let level = Level::from_map(Map::with_actions(&Actions::from_str("R").unwrap()).unwrap());
        Self {
            checkerboard_shading: true,
            deadlock_hint: true,
            deadlock_tint: Color::from_rgb(0.5, 0.5, 0.5),
            pathfinding_strategy: Strategy::default(),
            base_floor_item_id: GridMap::INVALID_CELL_ITEM,
            base_wall_item_id: GridMap::INVALID_CELL_ITEM,
            base_goal_item_id: GridMap::INVALID_CELL_ITEM,
            floor_dark_item_id: GridMap::INVALID_CELL_ITEM,
            deadlock_item_id: GridMap::INVALID_CELL_ITEM,
            deadlock_dark_item_id: GridMap::INVALID_CELL_ITEM,
            floor_item_id: GridMap::INVALID_CELL_ITEM,
            wall_item_id: GridMap::INVALID_CELL_ITEM,
            goal_item_id: GridMap::INVALID_CELL_ITEM,
            waypoints: FxHashMap::default(),
            costs: FxHashMap::default(),
            solver_worker: SolverWorker::new(),
            level,
            base,
        }
    }

    fn ready(&mut self) {
        self.create_theme_variants();
    }
}

#[godot_api]
impl LevelMap {
    /// Emitted when the player moves.
    #[signal]
    fn player_moved(to: Vector2i, pushed: bool);

    /// Emitted when a box moves.
    #[signal]
    fn box_moved(from: Vector2i, to: Vector2i);

    /// Emitted when a box enters a goal.
    #[signal]
    fn box_enter_goal(position: Vector2i);

    /// Emitted when a box leaves a goal.
    #[signal]
    fn box_leave_goal(position: Vector2i);

    /// Emitted when the level becomes solved.
    #[signal]
    fn solved();

    /// Emitted when the background solver completes successfully.
    #[signal]
    fn solve_completed(directions: Vec<i32>);

    /// Emitted when the background solver fails.
    #[signal]
    fn solve_failed(error: String);

    /// Loads and displays a level from an XSB file at the given `index`.
    #[func]
    pub fn load_from_file(&mut self, path: String, index: i32) {
        let Some(mut file) = FileAccess::open(&path, ModeFlags::READ) else {
            godot_error!("failed to open level file '{path}'");
            return;
        };
        let len = file.get_length() as i64;
        let buffer = file.get_buffer(len).to_vec();
        let reader = BufReader::new(Cursor::new(buffer));

        let Ok(level) = Level::load_nth_from_reader(reader, index as usize) else {
            godot_error!("failed to load level #{index} from '{path}'");
            return;
        };
        self.level = level;
        self.rebuild();
    }

    /// Loads a level from an XSB map string or an LURD action string.
    #[func]
    pub fn load_from_string(&mut self, string: String) {
        if let Ok(level) = Level::from_str(&string) {
            self.level = level;
            self.rebuild();
        } else if let Ok(actions) = Actions::from_str(&string) {
            let Ok(map) = Map::with_actions(&actions) else {
                godot_warn!("failed to create map from actions");
                return;
            };
            self.level = Level::from_map(map);
            self.fast_forward(string);
            self.undo_all();
            self.rebuild();
        } else {
            godot_warn!("failed to parse level or actions from string: '{string}'");
        }
    }

    /// Returns the current map in XSB format.
    #[func]
    pub fn get_map_xsb(&self) -> String {
        self.map().to_string()
    }

    /// Returns the action history as an LURD string.
    #[func]
    pub fn get_actions_lurd(&self) -> String {
        self.level.actions().to_string()
    }

    /// Returns the map dimensions as `(width, height)`.
    #[func]
    pub fn get_dimensions(&self) -> Vector2i {
        self.map().dimensions().to_gd()
    }

    /// Returns the player's current grid position.
    #[func]
    pub fn get_player_position(&self) -> Vector2i {
        self.map().player_position().to_gd()
    }

    /// Returns the direction the player is facing, defaults to `Down`.
    #[func]
    pub fn get_player_direction(&self) -> Direction {
        self.level
            .player_direction()
            .unwrap_or(direction::Direction::Down)
            .into()
    }

    /// Returns the positions of all boxes on the map.
    #[func]
    pub fn get_box_positions(&self) -> Vec<Vector2i> {
        self.map()
            .box_positions()
            .iter()
            .copied()
            .map(ToGodot::to_gd)
            .collect()
    }

    /// Returns all goal tile positions.
    #[func]
    pub fn get_goal_positions(&self) -> Vec<Vector2i> {
        self.map()
            .goal_positions()
            .iter()
            .copied()
            .map(ToGodot::to_gd)
            .collect()
    }

    /// Returns `true` if every goal is occupied by a box.
    #[func]
    pub fn is_solved(&self) -> bool {
        self.map().is_solved()
    }

    /// Returns positions of boxes that the player can currently push.
    #[func]
    pub fn get_pushable_box_positions(&self) -> Vec<Vector2i> {
        path_finding::compute_pushable_boxes(self.map())
            .into_iter()
            .map(ToGodot::to_gd)
            .collect()
    }

    /// Returns the sequence of player directions needed to push the nearest box to `to`.
    #[func]
    pub fn get_box_move_path(&self, to: Vector2i) -> Vec<Direction> {
        let waypoint = self.find_best_waypoint(to.to_point()).unwrap();

        let box_path = path_finding::construct_box_path(waypoint, &self.waypoints);
        let player_path = path_finding::construct_player_path(
            self.map(),
            self.map().player_position(),
            &box_path,
        );

        player_path
            .windows(2)
            .map(|positions| {
                direction::Direction::try_from(positions[1] - positions[0])
                    .unwrap()
                    .into()
            })
            .collect()
    }

    /// Returns the sequence of tile positions a box traverses when pushed to `to`.
    #[func]
    pub fn get_box_path(&self, to: Vector2i) -> Vec<Vector2i> {
        let waypoint = self.find_best_waypoint(to.to_point()).unwrap();
        path_finding::construct_box_path(waypoint, &self.waypoints)
            .into_iter()
            .map(ToGodot::to_gd)
            .collect()
    }

    /// Computes all reachable waypoint positions for the box at `box_position`.
    #[func]
    pub fn get_waypoints(&mut self, box_position: Vector2i) -> Vec<Vector2i> {
        let (mut waypoints, costs) = path_finding::compute_box_waypoints(
            self.map(),
            box_position.to_point(),
            self.pathfinding_strategy.into(),
        );

        if self.deadlock_hint {
            let deadlocks = self.dead_positions();
            waypoints.retain(|dp, _| !deadlocks.contains(&dp.position));
        }

        let positions: FxHashSet<Vector2i> =
            waypoints.keys().map(|dp| dp.position.to_gd()).collect();
        self.waypoints = waypoints;
        self.costs = costs;

        Vec::from_iter(positions)
    }

    /// Starts solving in a background thread with a custom stack size.
    #[func]
    pub fn start_solve(&mut self, algorithm: Algorithm, strategy: Strategy) {
        self.solver_worker
            .start(self.map().clone(), algorithm, strategy);
    }

    /// Polls for the solver result. Returns `true` while the solver is still
    /// running. When the solver finishes, emits `solve_completed` or
    /// `solve_failed` and returns `false`.
    #[func]
    pub fn poll_solve(&mut self) -> bool {
        match self.solver_worker.poll() {
            Some(Ok(actions)) => {
                let directions: Vec<_> = actions
                    .iter()
                    .map(|action| action.direction() as i32)
                    .collect();
                self.signals().solve_completed().emit(directions);
                false
            }
            Some(Err(err)) => {
                self.signals().solve_failed().emit(err.to_string());
                false
            }
            None => true,
        }
    }

    /// Cancels a running solve (if any).
    #[func]
    pub fn cancel_solve(&mut self) {
        self.solver_worker.cancel();
    }

    /// Moves the player in the given direction.
    #[func]
    pub fn move_by(&mut self, direction: Direction) {
        let direction: direction::Direction = direction.into();

        let box_positions = self.map().box_positions().clone();
        let _ = self.level.execute(direction);
        let new_box_positions = self.map().box_positions();

        let box_position = box_positions.difference(new_box_positions).next().copied();
        let new_box_position = new_box_positions.difference(&box_positions).next().copied();
        debug_assert!(box_position.is_some() == new_box_position.is_some());

        let player_position = self.map().player_position();
        self.signals()
            .player_moved()
            .emit(player_position.to_gd(), new_box_position.is_some());

        if let (Some(from), Some(to)) = (box_position, new_box_position) {
            self.signals().box_moved().emit(from.to_gd(), to.to_gd());

            match (
                self.map()[from].contains(Tiles::Goal),
                self.map()[to].contains(Tiles::Goal),
            ) {
                (false, true) => self.signals().box_enter_goal().emit(to.to_gd()),
                (true, false) => self.signals().box_leave_goal().emit(to.to_gd()),
                _ => {}
            }
        }

        if self.map().is_solved() {
            self.signals().solved().emit();
        }
    }

    /// Undoes actions until crossing the previous box-change boundary.
    #[func]
    pub fn undo(&mut self) {
        let initial_box_changes = self.level.actions().secondary_values().box_changes;
        while self.level.undo().is_ok() {
            if self.level.actions().secondary_values().box_changes < initial_box_changes {
                break;
            }
        }
        self.rebuild();
    }

    /// Redoes actions until crossing the next box-change boundary.
    #[func]
    pub fn redo(&mut self) {
        let initial_box_changes = self.level.actions().secondary_values().box_changes;
        while self.level.redo().is_ok() {
            if self.level.actions().secondary_values().box_changes > initial_box_changes + 1 {
                let _ = self.level.undo();
                break;
            }
        }
        self.rebuild();

        if self.map().is_solved() {
            self.signals().solved().emit();
        }
    }

    /// Undoes all actions.
    #[func]
    pub fn undo_all(&mut self) {
        while self.level.undo().is_ok() {}
        self.rebuild();
    }

    /// Applies an entire LURD action sequence without emitting per-move signals.
    #[func]
    pub fn fast_forward(&mut self, lurd: String) {
        let actions = Actions::from_str(&lurd).expect("failed to parse actions");
        self.level
            .execute_batch(actions.0.into_iter().map(|action| action.direction()))
            .unwrap();
    }

    /// Returns true if there are actions to undo.
    #[func]
    pub fn can_undo(&self) -> bool {
        !self.level.actions().is_empty()
    }

    /// Returns true if there are undone actions to redo.
    #[func]
    pub fn can_redo(&self) -> bool {
        !self.level.undone_actions().is_empty()
    }

    /// Returns the total number of moves (steps) taken so far.
    #[func]
    pub fn get_move_count(&self) -> i32 {
        self.level.actions().moves() as i32
    }

    /// Returns the total number of pushes (box shifts) so far.
    #[func]
    pub fn get_push_count(&self) -> i32 {
        self.level.actions().shifts() as i32
    }

    /// Rotates the entire level 90° clockwise.
    #[func]
    pub fn rotate_cw(&mut self) {
        self.level.rotate_cw();
        self.rebuild();
    }

    /// Flips the level horizontally.
    #[func]
    pub fn flip_horizontal(&mut self) {
        self.level.flip_horizontal();
        self.rebuild();
    }

    /// Returns a dictionary mapping each position to its heuristic lower-bound cost.
    #[func]
    pub fn get_min_costs(&self, strategy: Strategy) -> VarDictionary {
        let solver = Solver::new(self.map().clone(), strategy.into());
        let mut dict = VarDictionary::new();
        for (position, value) in solver.context().min_costs() {
            dict.set(position.to_gd(), &value.to_variant());
        }
        dict
    }

    /// Returns positions that form solver-detected tunnels (macro moves).
    #[func]
    pub fn get_tunnels(&self) -> Vec<Vector2i> {
        let solver = Solver::new(self.map().clone(), Strategy::Quick.into());
        let mut positions = Vec::new();
        let mut visited = FxHashSet::default();
        for tunnel in solver.context().tunnels() {
            if visited.insert(tunnel.position) {
                positions.push(tunnel.position.to_gd());
            }
        }
        positions
    }

    /// Rebuilds the GridMap.
    #[func]
    pub fn rebuild(&mut self) {
        if !self.base().is_inside_tree() {
            return;
        }

        self.waypoints.clear();
        self.costs.clear();

        let deadlocks = self.dead_positions();
        self.base_mut().clear();
        for x in 0..self.map().dimensions().x {
            for y in 0..self.map().dimensions().y {
                let position = Point::new(x, y);
                let tiles = self.map()[position];

                if tiles.contains(Tiles::Floor) {
                    let is_dark = self.checkerboard_shading && (x + y) % 2 == 1;
                    let is_deadlocked = self.deadlock_hint && deadlocks.contains(&position);
                    let item_id = match (is_deadlocked, is_dark) {
                        (false, false) => self.floor_item_id,
                        (false, true) => self.floor_dark_item_id,
                        (true, false) => self.deadlock_item_id,
                        (true, true) => self.deadlock_dark_item_id,
                    };
                    self.base_mut()
                        .set_cell_item(Vector3i::new(x, -1, y), item_id);
                }
                if tiles.intersects(Tiles::Wall | Tiles::Goal) {
                    let item_id = if tiles.contains(Tiles::Wall) {
                        self.wall_item_id
                    } else if tiles.contains(Tiles::Goal) {
                        self.goal_item_id
                    } else {
                        continue;
                    };
                    self.base_mut()
                        .set_cell_item(Vector3i::new(x, 0, y), item_id);
                }
            }
        }
    }

    /// Updates the deadlock tint color and rebuilds theme variants.
    #[func]
    pub fn set_deadlock_tint(&mut self, color: Color) {
        self.deadlock_tint = color;
        self.create_theme_variants();
        self.rebuild();
    }

    /// Creates tinted MeshLibrary variants for floor, wall, goal, and deadlock tiles.
    #[func]
    pub fn create_theme_variants(&mut self) {
        let mut mesh_library = self.base().get_mesh_library().unwrap();

        let map_theme = self.base().get_node_as::<Node>("/root/MapTheme");
        let floor_color: Color = map_theme.get("floor_color").to();
        let wall_color: Color = map_theme.get("wall_color").to();
        let goal_color: Color = map_theme.get("goal_color").to();

        self.floor_item_id = self.create_colored_variant(
            &mut mesh_library,
            self.base_floor_item_id,
            "theme_floor",
            |_| floor_color,
        );
        self.wall_item_id = self.create_colored_variant(
            &mut mesh_library,
            self.base_wall_item_id,
            "theme_wall",
            |_| wall_color,
        );
        self.goal_item_id = self.create_colored_variant(
            &mut mesh_library,
            self.base_goal_item_id,
            "theme_goal",
            |_| goal_color,
        );

        self.floor_dark_item_id = self.create_colored_variant(
            &mut mesh_library,
            self.floor_item_id,
            "floor_dark",
            |color| color.darkened(0.15),
        );

        let deadlock_tint = self.deadlock_tint;
        self.deadlock_item_id = self.create_colored_variant(
            &mut mesh_library,
            self.floor_item_id,
            "floor_deadlock",
            |color| color * deadlock_tint,
        );
        self.deadlock_dark_item_id = self.create_colored_variant(
            &mut mesh_library,
            self.floor_item_id,
            "floor_deadlock_dark",
            |color| color.darkened(0.15) * deadlock_tint,
        );
    }

    fn map(&self) -> &Map {
        self.level.map()
    }

    fn dead_positions(&self) -> FxHashSet<Point> {
        compute_static_deadlocks(self.map())
    }

    fn find_best_waypoint(&self, target: Point) -> Option<DirectedPosition> {
        let mut best = None;
        let mut min_cost = i32::MAX;
        for (&dp, &cost) in &self.costs {
            if dp.position == target && cost < min_cost {
                min_cost = cost;
                best = Some(dp);
            }
        }
        best
    }

    fn create_colored_variant<F>(
        &self,
        mesh_library: &mut Gd<MeshLibrary>,
        base_item_id: i32,
        name: &str,
        f: F,
    ) -> i32
    where
        F: Fn(Color) -> Color,
    {
        debug_assert_ne!(base_item_id, GridMap::INVALID_CELL_ITEM);

        let mut item_id = mesh_library.find_item_by_name(name);
        if item_id == -1 {
            item_id = mesh_library.get_last_unused_item_id();
            mesh_library.create_item(item_id);
            mesh_library.set_item_name(item_id, name);
        }

        let mesh = mesh_library
            .get_item_mesh(base_item_id)
            .unwrap()
            .cast::<ArrayMesh>();

        let material = mesh.surface_get_material(0).unwrap();
        let mut new_material = material.cast::<StandardMaterial3D>().duplicate_resource();

        let color = new_material.get_albedo();
        new_material.set_albedo(f(color));
        new_material.set("albedo_texture", &Variant::nil());
        new_material.set("vertex_color_use_as_albedo", &false.to_variant());

        let mut new_mesh = mesh.duplicate_resource();
        new_mesh.surface_set_material(0, &new_material);

        mesh_library.set_item_mesh(item_id, &new_mesh);

        let transform = mesh_library.get_item_mesh_transform(base_item_id);
        mesh_library.set_item_mesh_transform(item_id, transform);

        item_id
    }
}
