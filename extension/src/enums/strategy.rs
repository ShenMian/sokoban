use godot::prelude::*;
use soukoban::solver;

/// Solver and box pathfinding strategies.
#[derive(GodotConvert, Var, Export, Default, Clone, Copy, PartialEq, Eq, Debug)]
#[godot(via = i32)]
pub enum Strategy {
    /// Search for any solution as quickly as possible.
    ///
    /// Using this strategy, A* search degrades into greedy best-first search.
    #[default]
    Quick,
    /// Find the push optimal solution.
    PushOptimal,
    /// Find the move optimal solution.
    MoveOptimal,
}

impl From<Strategy> for solver::Strategy {
    fn from(strategy: Strategy) -> Self {
        match strategy {
            Strategy::Quick => solver::Strategy::Quick,
            Strategy::PushOptimal => solver::Strategy::PushOptimal,
            Strategy::MoveOptimal => solver::Strategy::MoveOptimal,
        }
    }
}
