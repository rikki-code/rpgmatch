## Content scale shared by every top-level scene.
class_name UiScale
extends RefCounted

## Enlarges all 2D UI (text, buttons, cards, HUD) for touch; layout code works in
## the scaled canvas, so the board fit adapts on its own.
const FACTOR := 1.25

## Portrait screens (phones) get the project's base size turned portrait, so
## the UI isn't shrunk to fit a 1920-wide landscape canvas.
static func fit(window: Window) -> void:
	var base := Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	var portrait := window.size.y > window.size.x
	var wanted := Vector2i(mini(base.x, base.y), maxi(base.x, base.y)) if portrait else base
	if window.content_scale_size != wanted:
		window.content_scale_size = wanted
	window.content_scale_factor = FACTOR
