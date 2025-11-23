# Wind Waker Style Torches demo by Kobold's Keep Videogames tkeene@kobolds-keep.net
# This one is MIT license.
class_name LightStencilsCharacterController
extends CharacterBody3D

var WALK_SPEED := 6.0
var MOUSE_SENSITIVITY := 0.02
var CAMERA_DISTANCE := 2.5
var CAMERA_MIN_HEIGHT = -5.0
var CAMERA_MAX_HEIGHT = 3.0

static var my_camera:Camera3D = null

var current_camera_offset_direction := Vector3(1.0, 1.0, 1.0)
var current_camera_height := 1.0

func _ready() -> void:
	my_camera = $Camera3D

func _physics_process(_delta:float) -> void:
	var move_input := Vector3.ZERO
	var camera_right := my_camera.global_basis.x
	var camera_forward := camera_right.rotated(Vector3.UP, PI * 0.5)
	move_input += Input.get_axis("left", "right") * camera_right
	move_input += Input.get_axis("down", "up") * camera_forward
	velocity = move_input * WALK_SPEED
	move_and_slide()

func _process(delta:float) -> void:
	# We don't move the camera on _physics_process() beacuse that can happen
	# multiple times per render frame.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var camera_input := Vector2.ZERO
	var mouse_velocity := Input.get_last_mouse_velocity()
	var screen_size := DisplayServer.window_get_size()
	mouse_velocity.x /= screen_size.x * delta
	mouse_velocity.y /= screen_size.y * delta
	camera_input.x += -mouse_velocity.x * MOUSE_SENSITIVITY
	camera_input.y += mouse_velocity.y * MOUSE_SENSITIVITY
	current_camera_offset_direction = current_camera_offset_direction.rotated(Vector3.UP, camera_input.x * delta)
	current_camera_height += camera_input.y * delta
	current_camera_height = clamp(current_camera_height, CAMERA_MIN_HEIGHT, CAMERA_MAX_HEIGHT)
	my_camera.position = current_camera_offset_direction * CAMERA_DISTANCE + Vector3.UP * current_camera_height
	my_camera.look_at(self.global_position, Vector3.UP)
	OrderedMaterials.update_ordered_materials(my_camera, delta)
