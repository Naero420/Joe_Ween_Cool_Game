extends CharacterBody3D

@onready var visual_pivot: Node3D = $VisualPivot
@onready var camera_rig: Node3D = $CameraRig
@onready var spring_arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D

# --------------------
# Movement tuning
# --------------------
@export_group("Movement Tuning")
@export var max_speed: float = 6.0
@export var sprint_speed: float = 10.0
@export var reverse_speed: float = 3.0

@export var acceleration: float = 14.0
@export var decceleration: float = 5.0
@export var brake_force: float = 32.0
@export var friction: float = 22.0
@export var rotation_speed: float = 2.5
@export var jump_velocity: float = 4.5

# Turning slows down at higher speed (0.25 = 25% turning at top speed)
@export var min_turn_multiplier_at_top_speed: float = 0.25

# Prevent micro sliding
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

# --------------------
# Runtime
# --------------------
var gravity: float = 9.8
var current_speed: float = 0.0


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

	# --------------------
	# Sprinting state
	# --------------------
	var input_forward: bool = Input.is_action_pressed(&"move_forward")
	var input_back: bool = Input.is_action_pressed(&"move_backward")
	var input_sprint: bool = Input.is_action_pressed(&"sprint")

	var sprinting: bool = input_sprint and input_forward and stamina > 0.0

	# --------------------
	# Turning (disabled while sprinting)
	# Turning slows down as speed increases
	# --------------------
	var turn_input: float = Input.get_axis(&"turn_left", &"turn_right")

	var speed_ratio: float = clampf(abs(current_speed) / sprint_speed, 0.0, 1.0)
	var turn_multiplier: float = lerpf(1.0, min_turn_multiplier_at_top_speed, speed_ratio)

	if not sprinting:
		rotation.y -= turn_input * rotation_speed * turn_multiplier * delta

	# --------------------
	# Camera lag (yaw offset that returns to 0)
	# --------------------
	var player_yaw_delta: float = wrapf(rotation.y - prev_player_yaw, -PI, PI)
	prev_player_yaw = rotation.y

	cam_yaw_offset -= player_yaw_delta
	cam_yaw_offset = lerpf(cam_yaw_offset, 0.0, clampf(camera_lag_return_speed * delta, 0.0, 1.0))
	camera_rig.rotation.y = cam_yaw_offset

	# --------------------
	# Stamina (with recovery delay)
	# --------------------
	if sprinting:
		stamina = max(stamina - stamina_drain * delta, 0.0)
		stamina_recovery_timer = stamina_recovery_delay
	else:
		if stamina_recovery_timer > 0.0:
			stamina_recovery_timer = max(stamina_recovery_timer - delta, 0.0)
		else:
			stamina = min(stamina + stamina_recovery * delta, max_stamina)

	# --------------------
	# Movement (fixed + clean)
	# W: forward (accel), Sprint: instant sprint speed
	# S: brake then reverse
	# No input: friction slow down
	# --------------------
	var current_acceleration : float = 0

	if input_forward:
		if sprinting:
			current_speed = sprint_speed  # bypass acceleration
		else:
			#current_speed = move_toward(current_speed, max_speed, acceleration * delta)
			current_acceleration += acceleration

	elif input_back:
		"""
		# If moving forward, brake to 0 first
		if current_speed > 0.0:
			current_speed = move_toward(current_speed, 0.0, brake_force * delta)
		else:
			current_speed = move_toward(current_speed, -reverse_speed, acceleration * delta)
		"""
		current_acceleration -= brake_force

	# Deceleration when there is no input.
	else:
		#current_speed = move_toward(current_speed, 0.0, friction * delta)
		if (!is_on_floor()):
			current_acceleration = 0
		elif (current_speed > 0) :
			current_acceleration -= decceleration
		elif (current_speed < 0) :
			current_acceleration += decceleration
		
	# Applies the accerlation to velocity
	current_speed += current_acceleration * delta

	# Caps speed at max speed in both directions
	current_speed = clampf(current_speed, -max_speed, max_speed)
	

	# Snap tiny speeds to 0
	if abs(current_speed) < stop_threshold:
		current_speed = 0.0

	# Apply movement in facing direction
	var forward: Vector3 = -transform.basis.z
	velocity.x = forward.x * current_speed
	velocity.z = forward.z * current_speed

	move_and_slide()

	"""
	# --------------------
	# Momentum leaning (visual only)
	# --------------------
	var target_lean: float = turn_input * lerpf(1.0, speed_ratio, lean_from_speed)

	var rate: float = (lean_speed if abs(target_lean) > abs(lean_amount) else lean_return_speed)
	var t: float = clampf(rate * delta, 0.0, 1.0)

	lean_amount = lerpf(lean_amount, target_lean, t)

	var lean_radians: float = deg_to_rad(max_lean_degrees) * lean_amount
	visual_pivot.rotation.z = -lean_radians
	camera_rig.rotation.z = -lean_radians * 0.35

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
