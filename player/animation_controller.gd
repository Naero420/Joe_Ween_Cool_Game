extends Node

@export var player_path: NodePath = ^".."
@export var animation_tree_path: NodePath = ^"../AnimationTree"

@export var idle_state: StringName = &"Idle"
@export var walk_state: StringName = &"Walk"
@export var run_state: StringName = &"Run"
@export var charge_state: StringName = &"Charge"

@export var move_threshold: float = 0.05
@export var run_threshold: float = 10.0

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
	var is_moving: bool = abs(speed) > move_threshold
	var charging: bool = Input.is_action_pressed("sprint") and is_moving

	if charging and speed > 0.0:
		_travel_if_needed(charge_state)
		return

	elif speed >= run_threshold:
		_travel_if_needed(run_state)
	elif abs(speed) > move_threshold:
		_travel_if_needed(walk_state)
	else:
		_travel_if_needed(idle_state)

func _travel_if_needed(state_name: StringName) -> void:
	if current_state == state_name:
		return

	playback.travel(state_name)
	current_state = state_name
