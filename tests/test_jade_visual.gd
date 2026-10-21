extends SceneTree
const Jade = preload("res://scripts/jade_visual.gd")
var failures: Array = []
var checks = 0

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _initialize() -> void:
	var polygons: Array = []
	for id in range(3):
		var shape = Jade.polygon(id)
		polygons.append(shape)
		expect(not Geometry2D.triangulate_polygon(shape).is_empty(), "fragment can be rendered")
		expect(not Geometry2D.is_point_in_polygon(Vector2.ZERO, shape), "hole is not clickable")
		expect(Geometry2D.is_point_in_polygon(Jade.piece_center(id), shape), "fragment center is clickable")
		for point in Jade.fracture(id + 1):
			var found_here = false
			var found_next = false
			for vertex in shape:
				if vertex.distance_to(point) < 0.001: found_here = true
			for vertex in Jade.polygon((id + 1) % 3):
				if vertex.distance_to(point) < 0.001: found_next = true
			expect(found_here and found_next, "adjacent jagged fracture edges match")
	# Sample the annulus away from exact edges: every point belongs to one piece.
	for angle_index in range(360):
		for radius in [50.0, 75.0, 100.0, 125.0, 138.0]:
			var point = Vector2.from_angle(deg_to_rad(angle_index + 0.37)) * radius
			var owners = 0
			for shape in polygons:
				if Geometry2D.is_point_in_polygon(point, shape): owners += 1
			expect(owners == 1, "no gap or overlap in assembled jade")
	for texture in [Jade.FRONT, Jade.BACK]:
		var image = texture.get_image()
		expect(image.get_pixel(0, 0).a < 0.01, "background is transparent")
		expect(image.get_pixel(image.get_width() / 2, image.get_height() / 2).a < 0.01, "central hole is transparent")
	print("JADE VISUAL: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)
