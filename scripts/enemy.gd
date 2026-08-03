extends CharacterBody2D

var health = 5

func _ready():
	add_to_group("enemy")

func take_damage():
	health -= 1
	
	if health <= 0:
		queue_free() # این دستور دشمن را کاملاً حذف می‌کند
