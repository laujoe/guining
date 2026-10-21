extends Control
## Bird's-eye diagram uses the collision grid, never a separately authored map.
var core
var show_route = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if core == null: return
	var cell = size / Vector2(core.MAZE[0].length(), core.MAZE.size())
	draw_rect(Rect2(Vector2.ZERO, size), Color("283638"))
	for y in range(core.MAZE.size()):
		for x in range(core.MAZE[y].length()):
			if core.maze_wall(Vector2i(x, y)): continue
			var rect = Rect2(Vector2(x, y) * cell + Vector2.ONE, cell - Vector2(2, 2))
			draw_rect(rect, Color("d5c6a5"))
	for marker in [Vector2i(1, 1), core.MAZE_EXIT]:
		draw_rect(Rect2(Vector2(marker) * cell + Vector2(5, 5), cell - Vector2(10, 10)), Color("71988a") if marker.x == 1 else Color("ab5344"))
	if show_route:
		var points = PackedVector2Array()
		for point in core.maze_exit_path(): points.append((Vector2(point) + Vector2(0.5, 0.5)) * cell)
		if points.size() > 1: draw_polyline(points, Color("9b6338"), 5, true)
	var m: Dictionary = core.state.lantern_maze
	var p = Vector2(m.x, m.z) / core.MAZE_CELL * cell
	var forward = Vector2(sin(m.yaw), -cos(m.yaw))
	draw_circle(p, 15, Color("25393b"))
	draw_colored_polygon(PackedVector2Array([p + forward * 20, p - forward * 10 + forward.orthogonal() * 10, p - forward * 10 - forward.orthogonal() * 10]), Color("f5ce72"))
