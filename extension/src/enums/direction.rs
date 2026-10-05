use godot::prelude::*;
use soukoban::direction;

/// Direction exposed to Godot.
///
/// This is a mirror of [`soukoban::direction::Direction`] with `GodotConvert`
#[derive(GodotConvert, Var, Export, Clone, Copy, PartialEq, Eq, Debug)]
#[godot(via = i32)]
pub enum Direction {
    Up,
    Right,
    Down,
    Left,
}

impl From<Direction> for direction::Direction {
    fn from(direction: Direction) -> Self {
        match direction {
            Direction::Up => direction::Direction::Up,
            Direction::Right => direction::Direction::Right,
            Direction::Down => direction::Direction::Down,
            Direction::Left => direction::Direction::Left,
        }
    }
}

impl From<direction::Direction> for Direction {
    fn from(direction: direction::Direction) -> Self {
        match direction {
            direction::Direction::Up => Direction::Up,
            direction::Direction::Right => Direction::Right,
            direction::Direction::Down => Direction::Down,
            direction::Direction::Left => Direction::Left,
        }
    }
}
