extends GutTest


func test_physics_engine_is_jolt() -> void:
	assert_eq(ProjectSettings.get_setting("physics/3d/physics_engine"), "Jolt Physics")


func test_physics_tick_is_120hz() -> void:
	assert_eq(Engine.physics_ticks_per_second, 120)
