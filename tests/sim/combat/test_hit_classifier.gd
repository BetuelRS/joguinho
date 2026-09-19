extends GutTest

const AXIS := Vector3.UP        # lâmina aponta para +Y
const EDGE := Vector3.RIGHT     # fio aponta para +X
var tuning := CombatTuning.new()


func _classify(zone: int, v: Vector3) -> int:
	return HitClassifier.classify(zone, v, AXIS, EDGE, tuning)


func test_edge_moving_edge_first_is_cut() -> void:
	assert_eq(_classify(WeaponZone.Kind.EDGE, Vector3(10, 0, 0)), HitType.Kind.CUT)


func test_edge_moving_sideways_is_blunt() -> void:
	# Movendo pela chapa (Z): não corta.
	assert_eq(_classify(WeaponZone.Kind.EDGE, Vector3(0, 0, 10)), HitType.Kind.BLUNT)


func test_edge_within_cut_angle_is_cut() -> void:
	var v := Vector3(cos(deg_to_rad(30.0)), 0, sin(deg_to_rad(30.0))) * 10.0
	assert_eq(_classify(WeaponZone.Kind.EDGE, v), HitType.Kind.CUT)


func test_edge_beyond_cut_angle_is_blunt() -> void:
	var v := Vector3(cos(deg_to_rad(40.0)), 0, sin(deg_to_rad(40.0))) * 10.0
	assert_eq(_classify(WeaponZone.Kind.EDGE, v), HitType.Kind.BLUNT)


func test_tip_moving_along_axis_is_thrust() -> void:
	assert_eq(_classify(WeaponZone.Kind.TIP, Vector3(0, 8, 0)), HitType.Kind.THRUST)


func test_tip_moving_edge_first_is_cut() -> void:
	assert_eq(_classify(WeaponZone.Kind.TIP, Vector3(8, 0, 0)), HitType.Kind.CUT)


func test_flat_is_blunt() -> void:
	assert_eq(_classify(WeaponZone.Kind.FLAT, Vector3(10, 0, 0)), HitType.Kind.BLUNT)


func test_head_is_blunt() -> void:
	assert_eq(_classify(WeaponZone.Kind.HEAD, Vector3(0, 8, 0)), HitType.Kind.BLUNT)


func test_zero_velocity_is_blunt() -> void:
	assert_eq(_classify(WeaponZone.Kind.EDGE, Vector3.ZERO), HitType.Kind.BLUNT)
