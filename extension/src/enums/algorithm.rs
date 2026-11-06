use godot::prelude::*;
use soukoban::solver;

/// Solver search algorithms.
///
/// This is a mirror of [`soukoban::solver::Algorithm`].
#[derive(GodotConvert, Var, Export, Default, Clone, Copy, PartialEq, Eq, Debug)]
#[godot(via = i32)]
pub enum Algorithm {
    /// A* search.
    #[default]
    AStar,
    /// Iterative-deepening A* search.
    IdaStar,
    /// Breadth-first search.
    Bfs,
}

impl From<Algorithm> for solver::Algorithm {
    fn from(algorithm: Algorithm) -> Self {
        match algorithm {
            Algorithm::AStar => solver::Algorithm::AStar,
            Algorithm::IdaStar => solver::Algorithm::IdaStar,
            Algorithm::Bfs => solver::Algorithm::Bfs,
        }
    }
}
