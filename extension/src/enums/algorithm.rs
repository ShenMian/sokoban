use godot::prelude::*;
use soukoban::solver;

/// Solver search algorithms.
///
/// This is a mirror of [`soukoban::solver::Algorithm`] with `GodotConvert`
#[derive(GodotConvert, Var, Export, Default, Clone, Copy, PartialEq, Eq, Debug)]
#[godot(via = i32)]
pub enum Algorithm {
    /// A* search algorithm.
    #[default]
    AStar,
    /// IDA* search algorithm.
    IDAStar,
    /// BFS search algorithm.
    Bfs,
}

impl From<Algorithm> for solver::Algorithm {
    fn from(algorithm: Algorithm) -> Self {
        match algorithm {
            Algorithm::AStar => solver::Algorithm::AStar,
            Algorithm::IDAStar => solver::Algorithm::IDAStar,
            Algorithm::Bfs => solver::Algorithm::Bfs,
        }
    }
}
