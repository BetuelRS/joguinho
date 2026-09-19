class_name BodyPart
extends RefCounted

enum Kind { HEAD, TORSO, ARM_L, ARM_R, LEG_L, LEG_R }

const ALL: Array[int] = [Kind.HEAD, Kind.TORSO, Kind.ARM_L, Kind.ARM_R, Kind.LEG_L, Kind.LEG_R]


static func is_arm(part: int) -> bool:
	return part == Kind.ARM_L or part == Kind.ARM_R


static func is_leg(part: int) -> bool:
	return part == Kind.LEG_L or part == Kind.LEG_R


static func is_limb(part: int) -> bool:
	return is_arm(part) or is_leg(part)


static func is_vital(part: int) -> bool:
	return part == Kind.HEAD or part == Kind.TORSO
