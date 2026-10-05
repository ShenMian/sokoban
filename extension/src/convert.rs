//! Conversions between Godot and `soukoban` types.

use godot::prelude::*;
use soukoban::prelude::*;

/// Conversion to a Godot type.
pub trait ToGodot {
    /// The target Godot type.
    type Out;

    /// Converts `self` into the corresponding Godot representation.
    fn to_gd(self) -> Self::Out;
}

impl ToGodot for Point {
    type Out = Vector2i;

    fn to_gd(self) -> Self::Out {
        Vector2i::new(self.x, self.y)
    }
}

/// Conversion to a `soukoban`` type.
pub trait ToSoukoban {
    /// The target `soukoban`` type.
    type Out;

    /// Converts `self` into the corresponding `soukoban` representation.
    fn to_point(self) -> Self::Out;
}

impl ToSoukoban for Vector2i {
    type Out = Point;

    fn to_point(self) -> Self::Out {
        Point::new(self.x, self.y)
    }
}
