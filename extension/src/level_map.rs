use std::{
    io::{BufReader, Cursor},
    str::FromStr,
};

use godot::{
    classes::{FileAccess, GridMap, IGridMap, file_access::ModeFlags},
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
    deadlock_tint: Color,

    #[export]
    pathfinding_strategy: Strategy,

    #[export]
    floor_item_id: i32,
    #[export]
    wall_item_id: i32,
    #[export]
    goal_item_id: i32,
    #[export]
    floor_dark_item_id: i32,
    #[export]
    deadlock_item_id: i32,
    #[export]
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

    /// Emitted when the background solver proves the level has no solution.
    #[signal]
    fn solve_no_solution();

    /// Emitted when a running solve is cancelled.
    #[signal]
    fn solve_cancelled();

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

        let start = std::time::Instant::now();
        let box_path = path_finding::construct_box_path(waypoint, &self.waypoints);
        let player_path = path_finding::construct_player_path(
            self.map(),
            self.map().player_position(),
            &box_path,
        );
        godot_print!("Computing player path ({:?})", start.elapsed());

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
        let start = std::time::Instant::now();
        let (mut waypoints, costs) = path_finding::compute_box_waypoints(
            self.map(),
            box_position.to_point(),
            self.pathfinding_strategy.into(),
        );
        let waypoints_duration = start.elapsed();
        godot_print!("Computing box waypoints ({waypoints_duration:?})");

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
    #[func(rename = start_solver_inner)]
    pub fn start_solver(&mut self, algorithm: Algorithm, strategy: Strategy) {
        self.solver_worker
            .start(self.map().clone(), algorithm, strategy);
    }

    /// Polls for the solver result.
    ///
    /// Returns `true` while the solver is still
    /// running. When the solver finishes, emits `solve_completed`,
    /// `solve_no_solution` or `solve_cancelled` and returns `false`.
    #[func]
    pub fn poll_solver(&mut self) -> bool {
        match self.solver_worker.poll() {
            Some(Ok(actions)) => {
                let directions: Vec<_> = actions
                    .iter()
                    .map(|action| action.direction() as i32)
                    .collect();
                self.signals().solve_completed().emit(directions);
                false
            }
            Some(Err(SearchError::NoSolution)) => {
                self.signals().solve_no_solution().emit();
                false
            }
            Some(Err(SearchError::Interrupted)) => {
                self.signals().solve_cancelled().emit();
                false
            }
            None => true,
        }
    }

    /// Returns the number of nodes expanded by the running solver.
    #[func]
    pub fn get_solver_expanded_count(&self) -> i64 {
        self.solver_worker.stats().expanded() as i64
    }

    /// Returns the number of successors generated by the running solver
    /// (before duplicate filtering).
    #[func]
    pub fn get_solver_generated_count(&self) -> i64 {
        self.solver_worker.stats().generated() as i64
    }

    /// Returns the best state observed by the running solver as a dictionary
    /// with the `player` position and sorted `boxes` positions, or an empty
    /// dictionary if nothing has been expanded yet.
    #[func]
    pub fn get_solver_best_state(&self) -> VarDictionary {
        let mut state = VarDictionary::new();
        let Some(best) = self.solver_worker.best() else {
            return state;
        };
        let mut boxes: Vec<Vector2i> = best
            .state
            .box_positions
            .iter()
            .copied()
            .map(ToGodot::to_gd)
            .collect();
        boxes.sort_by_key(|position| (position.x, position.y));
        state.set("player", best.state.player_position.to_gd());
        state.set("boxes", boxes);
        state
    }

    /// Cancels the running solve, blocking until it stops. The result is
    /// reported by `poll_solver`.
    #[func(rename = stop_solver_inner)]
    pub fn stop_solver(&mut self) {
        self.solver_worker.cancel();
    }

    /// Moves the player in the given direction.
    #[func]
    pub fn move_player(&mut self, direction: Direction) {
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
    #[func(rename = undo_inner)]
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
    #[func(rename = redo_inner)]
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
    #[func(rename = undo_all_inner)]
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

    /// Returns solver-detected tunnels as `(position, push direction)`
    /// pairs, with directions as `E.Direction`.
    #[func]
    pub fn get_tunnels(&self) -> VarArray {
        let solver = Solver::new(self.map().clone(), Strategy::Quick.into());
        solver
            .context()
            .tunnels()
            .iter()
            .map(|tunnel| {
                varray![tunnel.position.to_gd(), Direction::from(tunnel.direction)].to_variant()
            })
            .collect()
    }

    /// Rebuilds the `GridMap`.
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
}
