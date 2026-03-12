extends Node

enum AnimState {
	IDLE,
	WALK,
	RUN,
	CHARGE,
	JUMP,
	FALL,
	DRIFTL,
	DRIFTR,
	CROUCH,
	DROPKICK,
	TURNL,
	TURNR
}

@export var player_path: NodePath = ^".."
@export var animation_tree_path: NodePath = ^"../AnimationTree"

var player: CharacterBody3D
var animation_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback

var current_state: AnimState = AnimState.IDLE


func _ready():

	player = get_node(player_path)
	animation_tree = get_node(animation_tree_path)

	playback = animation_tree["parameters/playback"]

	animation_tree.active = true

	_set_state(AnimState.IDLE)


func _physics_process(_delta):

	var speed: float = player.get_speed()
	var vertical_velocity: float = player.velocity.y
	var on_floor: bool = player.is_on_floor()

	var forward: bool = Input.is_action_pressed("move_forward")
	var crouch: bool = Input.is_action_pressed("crouch")
	var sprint: bool = Input.is_action_pressed("sprint")
	var turn: float = Input.get_axis("turn_left","turn_right")

	var moving: bool = abs(speed) > 0.05
	var drifting: bool = crouch and speed > 0.0
	var sprinting: bool = sprint and forward and player.stamina > 0.0


	# --- AIR ---
	if not on_floor:

		if crouch:
			_set_state(AnimState.DROPKICK)
			return

		if vertical_velocity > 0:
			_set_state(AnimState.JUMP)
		else:
			_set_state(AnimState.FALL)

		return


	# --- CROUCH ---
	if crouch:

		if forward:

			if drifting and turn < 0 and speed > 0.5:
				_set_state(AnimState.DRIFTL)
				return

			elif drifting and turn > 0 and speed > 0.5:
				_set_state(AnimState.DRIFTR)
				return

			else:
				_set_state(AnimState.DROPKICK)
				return

		else:
			_set_state(AnimState.CROUCH)
			return


	# --- TURNING ---
	if turn < -0.1 and not sprinting and speed > 0.5:
		_set_state(AnimState.TURNL)
		return

	elif turn > 0.1 and not sprinting and speed > 0.5:
		_set_state(AnimState.TURNR)
		return


	# --- CHARGE ---
	if sprinting and speed > 0:
		_set_state(AnimState.CHARGE)
		return


	# --- LOCOMOTION ---
	if speed >= 10:
		_set_state(AnimState.RUN)

	elif moving:
		_set_state(AnimState.WALK)

	else:
		_set_state(AnimState.IDLE)


func _set_state(new_state: AnimState):

	if new_state == current_state:
		return

	current_state = new_state

	match new_state:

		AnimState.IDLE:
			playback.travel("Idle")

		AnimState.WALK:
			playback.travel("Walk")

		AnimState.RUN:
			playback.travel("Run")

		AnimState.CHARGE:
			playback.travel("Charge")

		AnimState.JUMP:
			playback.travel("Jump")

		AnimState.FALL:
			playback.travel("Fall")

		AnimState.DRIFTL:
			playback.travel("DriftL")

		AnimState.DRIFTR:
			playback.travel("DriftR")

		AnimState.CROUCH:
			playback.travel("Crouch")

		AnimState.DROPKICK:
			playback.travel("Drop Kick")

		AnimState.TURNL:
			playback.travel("TurnL")

		AnimState.TURNR:
			playback.travel("TurnR")
