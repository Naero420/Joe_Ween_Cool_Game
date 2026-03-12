extends Node

@export var player_path: NodePath = ^".."
@export var animation_tree_path: NodePath = ^"../AnimationTree"

@export var idle_state: StringName = &"Idle"
@export var walk_state: StringName = &"Walk"
@export var run_state: StringName = &"Run"
@export var charge_state: StringName = &"Charge"

@export var jump_state: StringName = &"Jump"
@export var fall_state: StringName = &"Fall"

@export var drift_left_state: StringName = &"DriftL"
@export var drift_right_state: StringName = &"DriftR"

@export var crouching_state: StringName = &"Crouch"
@export var crouch_walk_state: StringName = &"CrouchWalk"
@export var dropkick_state: StringName = &"Drop Kick"

@export var turn_left_state: StringName = &"TurnL"
@export var turn_right_state: StringName = &"TurnR"

@export var move_threshold: float = 0.05
@export var run_threshold: float = 10.0

@export var jump_velocity_threshold: float = 0.1
@export var fall_velocity_threshold: float = -0.1

@export var turn_threshold: float = 0.1


var player: CharacterBody3D = null
var animation_tree: AnimationTree = null
var playback: AnimationNodeStateMachinePlayback = null
var current_state: StringName = &""


func _ready() -> void:
	player = get_node_or_null(player_path) as CharacterBody3D
	animation_tree = get_node_or_null(animation_tree_path) as AnimationTree

	if player == null:
		push_error("AnimationController: Player not found.")
		return

	if animation_tree == null:
		push_error("AnimationController: AnimationTree not found.")
		return

	playback = animation_tree["parameters/playback"] as AnimationNodeStateMachinePlayback

	if playback == null:
		push_error("AnimationController: Could not access AnimationTree playback.")
		return

	animation_tree.active = true
	_travel_if_needed(idle_state)


func _physics_process(_delta: float) -> void:

	if player == null or playback == null:
		return

	var speed: float = float(player.get("current_speed"))
	var vertical_velocity: float = player.velocity.y
	var is_on_floor_now: bool = player.is_on_floor()

	var input_forward: bool = Input.is_action_pressed(&"move_forward")
	var input_sprint: bool = Input.is_action_pressed(&"sprint")
	var input_crouch: bool = Input.is_action_pressed(&"crouch")

	var turn_input: float = Input.get_axis(&"turn_left", &"turn_right")

	var is_sprinting: bool = input_sprint and input_forward and float(player.get("stamina")) > 0.0
	var is_drifting: bool = input_crouch and speed > 0.5
	var is_moving: bool = abs(speed) > move_threshold


	# --------------------
	# AIR STATES
	# --------------------
	if not is_on_floor_now:

		if input_crouch:
			_travel_if_needed(dropkick_state)
			return

		if vertical_velocity > jump_velocity_threshold:
			_travel_if_needed(jump_state)
		else:
			_travel_if_needed(fall_state)

		return


	# --------------------
	# CROUCH STATES
	# --------------------
	if input_crouch:

		if input_forward:

			if turn_input < -turn_threshold and is_drifting:
				_travel_if_needed(drift_left_state)
				return

			elif turn_input > turn_threshold and is_drifting:
				_travel_if_needed(drift_right_state)
				return

			else:
				_travel_if_needed(crouch_walk_state)
				return

		else:
			_travel_if_needed(crouching_state)
			return


	# --------------------
	# TURNING STATES
	# --------------------
	if not is_drifting and not is_sprinting and is_on_floor_now:

		if turn_input < -turn_threshold and speed >= run_threshold:
			_travel_if_needed(turn_left_state)
			return

		elif turn_input > turn_threshold and speed >= run_threshold:
			_travel_if_needed(turn_right_state)
			return


	# --------------------
	# CHARGE STATE
	# --------------------
	if is_sprinting and speed > 0.0:
		_travel_if_needed(charge_state)
		return


	# --------------------
	# NORMAL LOCOMOTION
	# --------------------
	if speed >= run_threshold:
		_travel_if_needed(run_state)

	elif is_moving:
		_travel_if_needed(walk_state)

	else:
		_travel_if_needed(idle_state)


func _travel_if_needed(state_name: StringName) -> void:

	if current_state == state_name:
		return

	playback.travel(state_name)
	current_state = state_name
