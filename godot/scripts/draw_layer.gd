# A Node2D whose drawing is delegated to a callable (the game draws its layers this way).
extends Node2D

var fn: Callable

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	if fn.is_valid(): fn.call(self)
