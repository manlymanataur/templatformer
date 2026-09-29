class_name ColossusShin
extends AnimatableBody3D
## A colossus's front shin, banded in bronze. A bomb blast shatters it (Bomb.explode calls blast on group
## blastable); nothing else can.

var colossus: Colossus

func _ready() -> void:
	add_to_group("blastable")

func blast(_from: Vector3) -> void:
	colossus.shin_broken(self)
