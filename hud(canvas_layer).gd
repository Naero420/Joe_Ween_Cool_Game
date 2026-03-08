extends CanvasLayer

@onready var stamina_bar: ProgressBar = $StaminaBar
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

	var max_stam: float = float(player.get("max_stamina"))
	var stam: float = float(player.get("stamina"))

	stamina_bar.max_value = max_stam
	stamina_bar.value = stam
	
	stamina_bar.visible = stamina_bar.value < stamina_bar.max_value
