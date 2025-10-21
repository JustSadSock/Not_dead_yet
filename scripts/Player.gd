extends CharacterBody3D

@export var move_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.2
@export var fire_rate: float = 5.0
@export var bullet_speed: float = 40.0

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var pitch: float = 0.0
var yaw: float = 0.0
var _cooldown: float = 0.0
var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")

func _ready():
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    if not has_node("Head/Camera3D"):
        push_error("No camera. Add Node3D 'Head' with daughter Camera3D.")
    _setup_inputs()

func _unhandled_input(event):
    if event is InputEventMouseMotion:
        pitch -= event.relative.y * mouse_sensitivity * 0.01
        yaw -= event.relative.x * mouse_sensitivity * 0.01
        pitch = clamp(pitch, deg_to_rad(-89), deg_to_rad(89))
        $Head.rotation.x = pitch
        rotation.y = yaw
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
    var input_dir = Vector3.ZERO
    var basis = Basis(Vector3.UP, rotation.y)
    if Input.is_action_pressed("move_forward"):
        input_dir -= basis.z
    if Input.is_action_pressed("move_back"):
        input_dir += basis.z
    if Input.is_action_pressed("move_left"):
        input_dir -= basis.x
    if Input.is_action_pressed("move_right"):
        input_dir += basis.x
    input_dir = input_dir.normalized()

    var speed = move_speed
    if Input.is_action_pressed("sprint"):
        speed = sprint_speed

    velocity.x = input_dir.x * speed
    velocity.z = input_dir.z * speed

    if not is_on_floor():
        velocity.y -= gravity * delta
    elif Input.is_action_just_pressed("jump"):
        velocity.y = jump_velocity

    move_and_slide()

    if Input.is_action_pressed("shoot"):
        _try_shoot()

    _cooldown = max(_cooldown - delta, 0)

func _try_shoot():
    if _cooldown > 0:
        return
    _cooldown = 1.0 / fire_rate

    var bullet = bullet_scene.instantiate()
    var dir = -$Head/Camera3D.global_transform.basis.z
    bullet.global_transform.origin = $Head/Camera3D.global_transform.origin + dir * 0.3
    bullet.linear_velocity = dir * bullet_speed
    get_tree().current_scene.add_child(bullet)

func _setup_inputs():
    var keys = {
        "move_forward": KEY_W,
        "move_back": KEY_S,
        "move_left": KEY_A,
        "move_right": KEY_D,
        "jump": KEY_SPACE,
        "sprint": KEY_SHIFT,
    }
    for action in keys:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        var ev = InputEventKey.new()
        ev.physical_keycode = keys[action]
        InputMap.action_add_event(action, ev)
    if not InputMap.has_action("shoot"):
        InputMap.add_action("shoot")
        var btn = InputEventMouseButton.new()
        btn.button_index = MOUSE_BUTTON_LEFT
        InputMap.action_add_event("shoot", btn)
