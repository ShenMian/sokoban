//! GDExtension bridge for the Sokoban.
//!
//! This crate exposes the core [soukoban] library to the Godot engine.

use godot::prelude::*;

/// Coordinate conversion traits between `soukoban` and Godot types.
mod convert;
/// SQLite-backed persistent storage for levels, collections, solutions, and snapshots.
mod database;
/// The enums exposed to Godot.
mod enums;
/// The core level map node: rendering, player/box movement, pathfinding, and solver integration.
mod level_map;
/// Background thread worker for the solver.
mod solver_worker;

struct Extension;

#[gdextension]
unsafe impl ExtensionLibrary for Extension {}
