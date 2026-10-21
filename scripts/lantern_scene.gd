extends Control
## Lens foreground. The maze viewport owns perspective and lighting.
const HAND = preload("res://assets/lantern-hand-v2.png")
var app

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1600, 900)

func _process(_delta: float) -> void:
	visible = app != null and app.mode == "ding_lamp"
	if visible: queue_redraw()

func _draw() -> void:
	if app == null or app.mode != "ding_lamp": return
	var sway: Vector2 = app.stage.lantern_maze.sway
	var bob = Vector2(sway.x * 170, sway.y * 230)
	draw_texture_rect(HAND, Rect2(Vector2(1060, 330) + bob, Vector2(580, 580)), false, Color(0.68, 0.60, 0.48))
