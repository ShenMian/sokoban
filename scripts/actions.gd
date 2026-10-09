class_name Actions
extends RefCounted

var lurd: String = ""


func _init(s := ""):
	lurd = s


## Returns true when no actions have been recorded.
func is_empty() -> bool:
	return lurd.is_empty()


## Returns the number of moves made.
func moves() -> int:
	return lurd.length()


## Returns the number of pushes made.
func pushes() -> int:
	return _count_uppercase(lurd)


## Rotates every action 90° clockwise.
func rotate_cw():
	var map = {
		"U": "R", "R": "D", "D": "L", "L": "U",
		"u": "r", "r": "d", "d": "l", "l": "u",
	}
	var new_lurd := ""
	for c in lurd:
		new_lurd += map.get(c, c)
	lurd = new_lurd


## Mirrors every action horizontally.
func flip_horizontal():
	var map = {
		"L": "R", "R": "L",
		"l": "r", "r": "l",
	}
	var new_lurd := ""
	for c in lurd:
		new_lurd += map.get(c, c)
	lurd = new_lurd


## Mirrors every action vertically.
func flip_vertical():
	var map = {
		"U": "D", "D": "U",
		"u": "d", "d": "u",
	}
	var new_lurd := ""
	for c in lurd:
		new_lurd += map.get(c, c)
	lurd = new_lurd


func _to_string() -> String:
	return lurd


## Returns the number of uppercase letters in the given text.
func _count_uppercase(text: String) -> int:
	var count := 0
	for i in range(text.length()):
		if text[i] >= "A" and text[i] <= "Z":
			count += 1
	return count
