extends "res://scripts/main.gd"
func _init() -> void:
	preload("res://tests/memory_fixture.gd").new().configure(self)

func _ready() -> void:
	super._ready()
	show_memory_atlas()
