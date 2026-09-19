class_name InputCommand
extends RefCounted
## Comando de um lutador para um tick de simulação. Serializável para a rede (SP2).

const _FLAG_FIELDS: Array[StringName] = [
	&"sprint", &"jump", &"crouch", &"dodge", &"tension", &"free_hand_mode",
	&"thrust", &"kick", &"grip_toggle", &"throw", &"lock_on_toggle",
]

var tick: int = 0
var move: Vector2 = Vector2.ZERO
var sprint: bool = false
var jump: bool = false
var crouch: bool = false
var dodge: bool = false
## Alvo da mão da arma, no espaço do ombro, dentro da esfera de alcance.
var hand_target: Vector3 = Vector3.ZERO
## Rotação da arma no próprio eixo (radianos).
var blade_roll: float = 0.0
var tension: bool = false
var free_hand_mode: bool = false
var free_hand_target: Vector3 = Vector3.ZERO
var thrust: bool = false
var kick: bool = false
var grip_toggle: bool = false
var throw: bool = false
var lock_on_toggle: bool = false
var look_yaw_delta: float = 0.0


func to_bytes() -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_32(tick)
	buf.put_float(move.x)
	buf.put_float(move.y)
	_put_vec3(buf, hand_target)
	buf.put_float(blade_roll)
	_put_vec3(buf, free_hand_target)
	buf.put_float(look_yaw_delta)
	var flags := 0
	for i in _FLAG_FIELDS.size():
		if get(_FLAG_FIELDS[i]):
			flags |= 1 << i
	buf.put_u16(flags)
	return buf.data_array


static func from_bytes(data: PackedByteArray) -> InputCommand:
	var buf := StreamPeerBuffer.new()
	buf.data_array = data
	var c := InputCommand.new()
	c.tick = buf.get_32()
	var mx := buf.get_float()
	var my := buf.get_float()
	c.move = Vector2(mx, my)
	c.hand_target = _get_vec3(buf)
	c.blade_roll = buf.get_float()
	c.free_hand_target = _get_vec3(buf)
	c.look_yaw_delta = buf.get_float()
	var flags := buf.get_u16()
	for i in _FLAG_FIELDS.size():
		c.set(_FLAG_FIELDS[i], (flags & (1 << i)) != 0)
	return c


static func _put_vec3(buf: StreamPeerBuffer, v: Vector3) -> void:
	buf.put_float(v.x)
	buf.put_float(v.y)
	buf.put_float(v.z)


static func _get_vec3(buf: StreamPeerBuffer) -> Vector3:
	var x := buf.get_float()
	var y := buf.get_float()
	var z := buf.get_float()
	return Vector3(x, y, z)
