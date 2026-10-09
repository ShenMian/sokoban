//! Conversions between Godot and `soukoban` types.

use godot::prelude::*;
use soukoban::prelude::*;

/// A trait for converting a `soukoban` value to its Godot representation.
pub trait ToGodot {
    /// The resulting Godot type.
    type Out;

    /// Converts the given value to the corresponding Godot value.
    fn to_gd(self) -> Self::Out;
}

impl ToGodot for Point {
    type Out = Vector2i;

    fn to_gd(self) -> Self::Out {
        Vector2i::new(self.x, self.y)
    }
}

/// A trait for converting a Godot value to its `soukoban` representation.
pub trait ToSoukoban {
    /// The resulting `soukoban` type.
    type Out;

    /// Converts the given value to the corresponding `soukoban` value.
    fn to_point(self) -> Self::Out;
}

impl ToSoukoban for Vector2i {
    type Out = Point;

    fn to_point(self) -> Self::Out {
        Point::new(self.x, self.y)
    }
}
