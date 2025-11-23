extends Node3D

@export var cycle_time := 5.0
@export var move_distance := 8.0

var home_position := Vector3.ZERO
var current_time := 0.0

func _ready() -> void:
	home_position = global_position

func _process(delta: float) -> void:
	current_time += delta
	if current_time > cycle_time:
		current_time -= cycle_time
	var current_t = current_time / cycle_time * PI * 2.0
	var current_x = sin(current_t * 2.0) * move_distance * 0.5
	var current_y = sin(current_t) * move_distance
	var right = Vector3.RIGHT
	var forward = Vector3.FORWARD
	global_position = home_position + current_x * right + current_y * forward
