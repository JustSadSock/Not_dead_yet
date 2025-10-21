extends RigidBody3D
@export var lifetime: float = 2.0

func _ready():
<<<<<<< HEAD
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)
=======
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)
>>>>>>> ecf516509e40efb39cbcc4b4ba2379e27a0fb4bf

func _physics_process(delta):
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

<<<<<<< HEAD
func _on_body_entered(body):
	queue_free()
=======
func _on_body_entered(_body):
	queue_free()
>>>>>>> ecf516509e40efb39cbcc4b4ba2379e27a0fb4bf
