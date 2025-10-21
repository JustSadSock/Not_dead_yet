extends RigidBody3D
@export var lifetime := 2.0

func _ready():
    contact_monitor = true
    contacts_reported = 8
    body_entered.connect(_on_body_entered)

func _physics_process(delta):
    lifetime -= delta
    if lifetime <= 0:
        queue_free()

func _on_body_entered(body):
    queue_free()
