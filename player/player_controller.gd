extends CharacterBody3D
@onready var visual_pivot: Node3D = $VisualPivot
@onready var camera_rig: Node3D = $CameraRig
@onready var spring_arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D

# --------------------
# Movement tuning
# --------------------
@export_group("Movement")
## Maximum speed the player can reach when accelerating
@export var max_speed: float = 20.0
@export var sprint_speed: float = 10.0
## Speed when walking
@export var walk_speed: float = 6.0

## Force applied to player when forward input is inputted
@export var acceleration: float = 14.0
## Force applied to player when they are on the ground.
@export var friction: float = 15.0
## Seconds passed before friction can be applied (Used for bunny hopping)
@export var friction_delay: float = 0.15
## Force multiplier applied to player when they are on the ground and drifting (0.25 = 25% of friction is applied)
@export var drift_friction_multiplier: float = 0.2
## Force applied when the backward movement key is held when player is moving forward
@export var brake_force: float = 28.0
## Conserves forward velocity (0 = no forward velocity is conserved when turning; 1 = 100% of forward velocity is conserved while turning)
@export var conserve_velocity_when_turning_multiplier: float = 1.0
@export var converse_velocity_when_drift_turning_multiplier: float = 0.8

@export var jump_velocity: float = 4.5

@export_subgroup("Turning")
## Turning speed in radians
@export var rotation_speed: float = 5
## Turning speed in radians while drifting
@export var drift_rotation_speed: float = 10

## Slows down turning at high speed (0.25 = 25% turning at top speed)
@export var min_turn_multiplier_at_top_speed: float = 0.25
## Slows down turning at high speed when drifting (0.25 = 25% turning at top speed)
@export var min_drift_turn_multiplier_at_top_speed: float = 0.5

## Speed slower than this value is set to 0.
@export var stop_threshold: float = 0.05

# --------------------
# Stamina
# --------------------
@export_group("Stamina")
@export var max_stamina: float = 5.0
@export var stamina_drain: float = 1.5
@export var stamina_recovery: float = 1.0
@export var stamina_recovery_delay: float = 1.5

var stamina: float = 5.0
var stamina_recovery_timer: float = 0.0

# --------------------
# Camera lag (returns behind player)
# CameraRig is a CHILD of Player, so "behind player" == local yaw 0
# --------------------
@export_group("Camera")
@export var camera_lag_return_speed: float = 6.0  # higher = returns faster
var cam_yaw_offset: float = 0.0
var prev_player_yaw: float = 0.0

# --------------------
# Camera effects
# --------------------
@export var normal_fov: float = 75.0
@export var sprint_fov: float = 85.0
@export var fov_speed: float = 5.0

@export var shake_strength: float = 0.05
@export var shake_frequency: float = 20.0
@export var shake_in_speed: float = 10.0

var shake_amount: float = 0.0
var shake_time: float = 0.0
var cam_base_pos: Vector3 = Vector3.ZERO

# --------------------
# Momentum leaning
# --------------------
@export_group("Movement Leaning")
@export var max_lean_degrees: float = 10.0
@export var lean_speed: float = 8.0
@export var lean_return_speed: float = 10.0
@export var lean_from_speed: float = 1.0 # 0 = lean even standing, 1 = lean mostly when moving

var lean_amount: float = 0.0 # [-1..1]

# --------------------
# Mouse gesture attacks
# --------------------
@export_group("Attacking")
@export var attack_cooldown: float = 0.20

# Longer window = easier to register
@export var gesture_window: float = 0.16

# Either of these can trigger an attack:
@export var swipe_min_speed: float = 850.0        # was ~1400
@export var swipe_min_distance: float = 140.0     # pixels moved during the window

@export var heavy_swipe_speed: float = 1700.0     # was ~2600

# How "straight" it must be (0.0 = any direction, 1.0 = perfectly straight)
@export var direction_bias: float = 0.55

var gesture_timer: float = 0.0
var gesture_sum: Vector2 = Vector2.ZERO
var attack_cd_timer: float = 0.0

## @experimental
enum moveState {
	IDLE,
	RUNNING,
	WALKING,
	BRAKING,
	STOPPING,
	DRIFTING,
	CROUCHING,
	SLIDING,
	CHARGING,
}

# --------------------
# Runtime
# --------------------
var gravity: float = 9.8
var friction_time: float = 0

# Player Inputs
var _input_forward: bool
var _input_back: bool
var _turn_input: float
var _input_move: float
var _input_sprint: bool
var _input_crouch: bool
var _input_walk: bool

# Player states
var is_sprinting: bool ## @deprecated
var is_drifting: bool ## @deprecated
var is_falling: bool ## @deprecated
var is_walking: bool ## @deprecated
var is_braking: bool ## @deprecated

var state: moveState = moveState.IDLE ## @experimental


func _ready() -> void:
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))

	stamina = max_stamina
	stamina_recovery_timer = 0.0

	cam_base_pos = camera.position
	camera.fov = normal_fov

	spring_arm.margin = 0.2

	prev_player_yaw = rotation.y


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		gesture_sum += event.relative
		gesture_timer = gesture_window


func _physics_process(delta: float) -> void:
	# Applies gravity and jumping logic
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed(&"jump") and is_on_floor():
		velocity.y = jump_velocity
	
	is_falling = velocity.y < 0

	_input_process()
	_move_process(delta)

	# --------------------
	# Camera lag (yaw offset that returns to 0)
	# --------------------
	var player_yaw_delta: float = wrapf(rotation.y - prev_player_yaw, -PI, PI)
	prev_player_yaw = rotation.y

	cam_yaw_offset -= player_yaw_delta
	cam_yaw_offset = lerpf(cam_yaw_offset, 0.0, clampf(camera_lag_return_speed * delta, 0.0, 1.0))
	camera_rig.rotation.y = cam_yaw_offset

	"""
	# --------------------
	# Camera FOV + Shake (sprinting)
	# --------------------
	var target_fov: float = sprint_fov if sprinting else normal_fov
	camera.fov = lerpf(camera.fov, target_fov, clampf(fov_speed * delta, 0.0, 1.0))

	# Shake amount eases in/out
	if shake_in_speed > 0.0:
		var target_shake: float = 1.0 if sprinting else 0.0
		shake_amount = move_toward(shake_amount, target_shake, shake_in_speed * delta)
	else:
		shake_amount = 1.0 if sprinting else 0.0

	if shake_amount > 0.0:
		shake_time = fmod(shake_time + delta * shake_frequency, TAU)
		var shake_offset: Vector3 = Vector3(
			sin(shake_time) * shake_strength * shake_amount,
			cos(shake_time * 1.3) * shake_strength * shake_amount,
			0.0
		)
		camera.position = cam_base_pos + shake_offset
	else:
		camera.position = cam_base_pos

	# --------------------
	# Gesture attack evaluation (more tolerant)
	# --------------------
	attack_cd_timer = max(attack_cd_timer - delta, 0.0)

	if gesture_timer > 0.0:
		gesture_timer -= delta

		if gesture_timer <= 0.0 and attack_cd_timer <= 0.0:
			var swipe: Vector2 = gesture_sum
			gesture_sum = Vector2.ZERO

			var distance: float = swipe.length()
			var speed: float = distance / max(gesture_window, 0.001)

			# More tolerant: trigger if either speed OR distance is enough
			if speed >= swipe_min_speed or distance >= swipe_min_distance:
				_trigger_mouse_attack_tolerant(swipe, speed)
				attack_cd_timer = attack_cooldown
	"""
func _input_process() -> void:
	# Input Variables
	_input_forward = Input.is_action_pressed(&"move_forward")
	_input_back = Input.is_action_pressed(&"move_backward")
	_turn_input = Input.get_axis(&"turn_left", &"turn_right")
	_input_move = Input.get_axis(&"move_backward", &"move_forward")
	_input_sprint = Input.is_action_pressed(&"sprint")
	_input_crouch = Input.is_action_pressed(&"crouch")
	_input_walk = Input.is_action_pressed(&"walk")

	# TODO: Should these variables be moved to move_process instead of local?
	is_sprinting = _input_sprint and _input_forward and stamina > 0.0
	is_walking = _input_back || (_input_walk && _input_forward)
	is_drifting = _input_crouch and get_speed() > 0.0 and not is_walking

func _move_process(delta: float) -> void:
	var vel : Vector3 = velocity

	# --------------------
	# Turning (disabled while sprinting)
	# Turning slows down as speed increases
	# --------------------

	#TODO: Add a separate variable to adjust the threshold for speed ratio
	var speed_ratio: float = clampf(_vec32(velocity).length() / max_speed, 0.0, 1.0)

	var turn_multiplier: float = lerpf(1.0, min_turn_multiplier_at_top_speed, speed_ratio)
	var drift_turn_multiplier: float = lerpf(1.0, min_drift_turn_multiplier_at_top_speed, speed_ratio)

	var _rotation_delta: float = 0.0
	if not is_sprinting:
		_rotation_delta -= _turn_input * rotation_speed * turn_multiplier * delta
	elif is_drifting:
		_rotation_delta -= _turn_input * drift_rotation_speed * drift_turn_multiplier * delta
	rotation.y += _rotation_delta

	# Stamina recovery with delay
	if is_sprinting:
		stamina = max(stamina - stamina_drain * delta, 0.0)
		stamina_recovery_timer = stamina_recovery_delay
	else:
		if stamina_recovery_timer > 0.0:
			stamina_recovery_timer = max(stamina_recovery_timer - delta, 0.0)
		else:
			stamina = min(stamina + stamina_recovery * delta, max_stamina)


	# Movement
	var accel : Vector3 = Vector3(0,0,0)
	var forward: Vector3 = -transform.basis.z
	var _use_acceleration: bool = true
	## Current speed of the player object.
	var _current_speed: float = 0

	# Calculate friction:
	# Friction is applied in the opposite direction of the object's velocity
	var can_friction_apply: bool = false
	var friction_force: Vector2 = Vector2(0,0)
	# Bunny hop logic: Friction is given a delay before it is applied when the player touches the floor
	
	if is_on_floor():
		if friction_time <= 0:
			can_friction_apply = true
		else:
			friction_time = clampf(friction_time - delta, 0, friction_delay)
	else:
		friction_time = friction_delay
		can_friction_apply = false

	if can_friction_apply:
		friction_force += friction * _vec32(vel).normalized()
		if _input_crouch && _turn_input != 0:
			var _multi: float = 0.8
			var _vel_rot = (vel.rotated(Vector3.UP, _rotation_delta) * converse_velocity_when_drift_turning_multiplier) \
			+ (vel.rotated(Vector3.UP, _rotation_delta) * (1 - converse_velocity_when_drift_turning_multiplier))
			vel = _vel_rot
	# Turning in the air conserves forward momentum
	elif (_turn_input != 0):
		var _vel_rot = (vel.rotated(Vector3.UP, _rotation_delta) * conserve_velocity_when_turning_multiplier) \
			+ (vel.rotated(Vector3.UP, _rotation_delta) * (1 - conserve_velocity_when_turning_multiplier))
		vel = _vel_rot
	
	# Apply friction force

	# Moving forward
	if _input_move > 0:
		if _input_walk: # Walking forward
			if vel.length() >= walk_speed + stop_threshold:
				accel += -_brake(vel, 0)
			else:
				_use_acceleration = false
				_current_speed += walk_speed
		else: # Running (normal movement)
			var forward_accel : Vector3 = Vector3()
			# Negates friction when running forwards on the ground
			if can_friction_apply: 
				forward_accel += forward * (acceleration + friction)
			else:
				forward_accel += forward * acceleration
			
			# Limit Forward acceleration when max speed is achieved
			var _forward_speed : float = get_forward_speed()
			
			# TODO: Rewrite this logic to be more accurate
			var _ratio = clampf(_forward_speed / max_speed, 0.0, 1.0)
			if (_ratio >= 1):
				accel += forward_accel * (lerpf((0), 1, 1 - _ratio))
			else:
				accel += forward_accel
	# Moving back = walking back
	elif _input_move < 0:
		if vel.length() >= walk_speed + stop_threshold:
			accel += -_brake(vel, 0)
		else:
			_use_acceleration = false
			_current_speed += -walk_speed
	# Braking when there's no movement input
	elif _input_walk:
		accel += -_brake(vel, 0)
	
	# Applies velocity to object
	if _use_acceleration:
		# Apply friction force
		accel += -_vec23(friction_force if not _input_crouch else friction_force * drift_friction_multiplier)	
		vel += accel * delta
	else: 
		vel.x = forward.x * _current_speed
		vel.z = forward.z * _current_speed

	if (_vec32(vel).length() < stop_threshold):
		vel.x = 0
		vel.z = 0
		state = moveState.IDLE
	
	velocity.x = vel.x
	velocity.z = vel.z

	move_and_slide()

# Slows down the player faster than friction. Returns the acceleration
# limit: stop braking when speed is lower than limit
# ngl it feels horrible not being to pass by reference
func _brake(vel: Vector3, limit: float) -> Vector3:
	var brake_accel: Vector3 = Vector3()
	var _current_speed: float = get_speed()
	var direction: Vector3 = _vec23(_vec32(vel)).normalized()

	if _current_speed >= limit - stop_threshold:
		var bf: float = brake_force
		if bf > friction:
			bf = bf - friction
		else:
			bf = friction - bf

		brake_accel.x += bf * direction.x
		brake_accel.z += bf * direction.z

	return brake_accel

# Converts vector 3 to vector 2
func _vec32(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)

# Converts vector 3 to vector 2
func _vec23(v: Vector2) -> Vector3:
	return Vector3(v.x, 0, v.y)

func _trigger_mouse_attack(swipe: Vector2, swipe_speed: float) -> void:
	var dir: Vector2 = swipe.normalized()

	# Vertical vs horizontal gesture
	if abs(dir.y) >= abs(dir.x):
		# Up (forward) = punches
		if dir.y < 0.0:
			if swipe_speed >= heavy_swipe_speed:
				heavy_punch()
			else:
				light_punch()
		# Down (back) = kick
		else:
			kick()
	else:
		# Left/Right = jab
		jab()
	
func _trigger_mouse_attack_tolerant(swipe: Vector2, swipe_speed: float) -> void:
	if swipe.length() < 1.0:
		return

	var dir: Vector2 = swipe.normalized()

	var ax: float = abs(dir.x)
	var ay: float = abs(dir.y)

	# How strongly does it favor the dominant axis?
	var dominance: float = abs(ax - ay)

	# If it's too diagonal/noisy, ignore it (lower direction_bias = more tolerant)
	if dominance < direction_bias:
		return

	# Vertical vs horizontal based on dominant axis
	if ay >= ax:
		# Up (forward) punches
		if dir.y < 0.0:
			if swipe_speed >= heavy_swipe_speed:
				heavy_punch()
			else:
				light_punch()
		else:
			kick()
	else:
		jab()
		
# Returns the real horizontal speed of the object. (This can never be a negative number)
func get_speed() -> float :
	return Vector2(velocity.x, velocity.z).length()

func get_forward_speed() -> float :
	return velocity.dot(-global_transform.basis.z)

func get_movement_state() -> moveState :
	return state

# TODO:
func is_slowing_down() -> bool :
	return false

# --------------------
# Attack hooks (replace prints with animations/hitboxes later)
# --------------------
func light_punch() -> void:
	print("Light Punch")

func heavy_punch() -> void:
	print("Heavy Punch")

func kick() -> void:
	print("Kick")

func jab() -> void:
	print("Jab")
