extends CharacterBody2D
## 처용: 8-direction movement, 4-facing sprite animation built from the art/out sheet.

const SPEED := 72.0
const FRAME := Vector2i(32, 48)
const FEET_ROW := 45 # feet row inside the 48px cell; the node origin sits on it

# Sheet order written by art/build.py (art/src/cheoyong.py FRAMES).
const SHEET := {
	"down_idle": [0], "up_idle": [1], "right_idle": [2],
	"down_walk": [3, 4, 5, 6], "up_walk": [7, 8, 9, 10], "right_walk": [11, 12, 13, 14],
}

@onready var sprite: AnimatedSprite2D = $Sprite
var facing := "down"


func _ready() -> void:
	var tex: Texture2D = load("res://assets/sprites/cheoyong.png")
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim in SHEET:
		frames.add_animation(anim)
		frames.set_animation_loop(anim, true)
		frames.set_animation_speed(anim, 8.0)
		for i in SHEET[anim]:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * FRAME.x, 0, FRAME.x, FRAME.y)
			frames.add_frame(anim, at)
	sprite.sprite_frames = frames
	sprite.offset = Vector2(0, FRAME.y / 2.0 - FEET_ROW)
	sprite.play("down_idle")


func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * SPEED
	move_and_slide()
	if dir != Vector2.ZERO:
		if absf(dir.x) > absf(dir.y) + 0.1:
			facing = "right" if dir.x > 0 else "left"
		else:
			facing = "down" if dir.y > 0 else "up"
	var row := "right" if facing == "left" else facing
	sprite.flip_h = facing == "left"
	var anim := row + ("_walk" if dir != Vector2.ZERO else "_idle")
	if sprite.animation != anim:
		sprite.play(anim)
