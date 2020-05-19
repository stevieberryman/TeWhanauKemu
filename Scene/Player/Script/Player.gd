extends KinematicBody2D

const up = Vector2(0, -1)
export (int) var speed
export (int) var gravity
export (int) var jumpHeight
var motion = Vector2() # moving in 2d space

func _physics_process(delta):
	motion.y += gravity
	
	if Input.is_action_pressed("ui_right"):
		motion.x = speed
	elif Input.is_action_pressed("ui_left"):
		motion.x = -speed
	else:
		motion.x = 0
	
	if is_on_floor():
		if Input.is_action_pressed("ui_up"):
			motion.y = jumpHeight
	else:
		#$AnimatedSprite.play("Jump")
		pass
		
	motion = move_and_slide(motion, up)
#end of _physics_process

