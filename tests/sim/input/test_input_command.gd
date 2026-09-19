extends GutTest


func _full_command() -> InputCommand:
	var c := InputCommand.new()
	c.tick = 4242
	c.move = Vector2(0.5, -1.0)
	c.sprint = true
	c.crouch = true
	c.hand_target = Vector3(0.25, -0.5, 0.75)
	c.blade_roll = 1.5
	c.tension = true
	c.free_hand_mode = true
	c.free_hand_target = Vector3(-0.25, 0.5, 0.125)
	c.thrust = true
	c.throw = true
	c.look_yaw_delta = -0.5
	return c


func test_roundtrip_preserves_values() -> void:
	var d := InputCommand.from_bytes(_full_command().to_bytes())
	assert_eq(d.tick, 4242)
	assert_eq(d.move, Vector2(0.5, -1.0))
	assert_eq(d.hand_target, Vector3(0.25, -0.5, 0.75))
	assert_eq(d.blade_roll, 1.5)
	assert_eq(d.free_hand_target, Vector3(-0.25, 0.5, 0.125))
	assert_eq(d.look_yaw_delta, -0.5)


func test_roundtrip_preserves_flags() -> void:
	var d := InputCommand.from_bytes(_full_command().to_bytes())
	assert_true(d.sprint)
	assert_true(d.crouch)
	assert_true(d.tension)
	assert_true(d.free_hand_mode)
	assert_true(d.thrust)
	assert_true(d.throw)
	assert_false(d.jump)
	assert_false(d.dodge)
	assert_false(d.kick)
	assert_false(d.grip_toggle)
	assert_false(d.lock_on_toggle)


func test_default_command_roundtrips_to_defaults() -> void:
	var d := InputCommand.from_bytes(InputCommand.new().to_bytes())
	assert_eq(d.tick, 0)
	assert_eq(d.move, Vector2.ZERO)
	assert_false(d.tension)
