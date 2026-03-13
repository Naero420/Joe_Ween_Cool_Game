extends CanvasLayer

@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var speedometer: Label = $Speedometer
@onready var fps_counter: Label = $FPSMeter
@onready var speedometer_forward: Label = $Speedometer_Forward

@export var player_path: NodePath

var player: Node = null

func _ready() -> void:
	print("HUD ready:", self)
	set_process(true)

	player = get_node_or_null(player_path)
	print("HUD player:", player)

func _process(_delta: float) -> void:
	if player == null:
		return

	stamina_process()
	speed_process()
	fps_process()

# Updates the stamina bar UI element
func stamina_process() -> void:
	var max_stam: float = float(player.get("max_stamina"))
	var stam: float = float(player.get("stamina"))

	stamina_bar.max_value = max_stam
	stamina_bar.value = stam
	
	stamina_bar.visible = stamina_bar.value < stamina_bar.max_value

# Updates the speedometer UI element
func speed_process() -> void:
	var player_speed: Vector3 = player.get("velocity")
	var horizontal_speed = Vector2(player_speed[0],player_speed[2])
	speedometer.text = str(horizontal_speed.length()) + " m/s"

	speedometer_forward.text = "Forward Speed: " + str(player.call("get_forward_speed")) + " m/s"

func fps_process() -> void:
	fps_counter.text = str(Engine.get_frames_per_second()) + " fps"

