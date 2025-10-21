extends RigidBody3D
@export var lifetime: float = 2.0

func _ready():
    contact_monitor = true
    max_contacts_reported = 8
    body_entered.connect(_on_body_entered)

func _physics_process(delta):
    lifetime -= delta
    if lifetime <= 0:
        queue_free()

func _on_body_entered(_body):
    queue_free()
