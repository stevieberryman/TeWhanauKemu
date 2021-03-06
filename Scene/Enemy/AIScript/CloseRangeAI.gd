extends KinematicBody2D
class_name CloseRangeEnemy

export var max_speed_normal:int = 100 
export var max_speed_attack:int = 120
export var damage:int = 45
export var hp:int = 10
var direction:int = 1
var max_speed = max_speed_normal
var velocity := Vector2()
var origin_position: Vector2
var target: Vector2	# 目标
var player: Player	# Players in the secen
var state_machine: CloseRangeEnemyStateMachine	# 状态机

onready var GroundCheckLeft = $GroundCheckLeft
onready var GroundCheckRight = $GroundCheckRight
onready var WallCheckLeft = $WallCheckLeft
onready var WallCheckRight = $WallCheckRight
onready var AnimatedSprite = $AnimatedSprite

const TARGET_DIST = 0
const UP = Vector2(0, -1)

func _ready():
	origin_position = global_position
	state_machine = CloseRangeEnemyStateMachine.new(self)
	state_machine.set_state_deferred(CloseRangeEnemyStateMachine.IDLE)
	
func _physics_process(delta):
	state_machine.process(delta)
	
func process_movement(delta):
	velocity = move_and_slide(velocity,Vector2.UP)

func process_velocity(delta):
	"""Apply gravity"""
	velocity.y += 20
	velocity.x = max_speed * direction
	
func _on_HitBox_body_entered(body):
	#AnimatedSprite.play("Slashing")
	if hp <=0:
		state_machine.set_state(CloseRangeEnemyStateMachine.DEAD)
	if body.has_method("take_damage"):
		WallCheckLeft.enabled = false
		WallCheckRight.enabled = false
		body.take_damage(damage) #what to do?
		AnimatedSprite.play("Slashing")
		
func _on_HitBox_body_exited(body):
	if body.has_method("take_damage"):
		WallCheckLeft.enabled = true
		WallCheckRight.enabled = true
		state_machine.set_state(CloseRangeEnemyStateMachine.CHASE)

func _on_DetectingBox_body_entered(body):
	"""Player enters the perception area"""
	if body is Player:
		player = body
		target = body.global_position
		state_machine.set_state(CloseRangeEnemyStateMachine.CHASE)
		
func _on_DetectingBox_body_exited(body):
	"""Player exits the perception area"""
	if body is Player:
		state_machine.set_state(CloseRangeEnemyStateMachine.WALK)
		
func _check_direction():
	"""Determine the current direction"""
	if GroundCheckLeft.is_colliding() or WallCheckLeft.is_colliding():
		return -1
	elif GroundCheckRight.is_colliding() or WallCheckRight.is_colliding():
		return 1
	else:
		return direction
		
func control_ray_cast(condition:bool):
	GroundCheckLeft.enabled = condition
	GroundCheckRight.enabled = condition

func takeDamage(damage):
	hp -= damage
	if hp > 0:
		pass
	else:
		state_machine.set_state(CloseRangeEnemyStateMachine.DEAD)
				
class CloseRangeEnemyStateMachine extends StateMachine:
	enum {IDLE,WALK,ATTACK,DEAD,CHASE,JUMP,FALL}
	var enemy: CloseRangeEnemy
	var idle_state_duration = 0
	var walk_state_duration = 0
	var state_stay = 0

	func _init(tanemahuta: CloseRangeEnemy):
		enemy = tanemahuta
		add_state(IDLE)
		add_state(WALK)
		add_state(ATTACK)
		add_state(DEAD)
		add_state(CHASE)
		add_state(JUMP)
		add_state(FALL)

	func _do_actions(delta):
		match state:
			IDLE:
				idle_state_duration += delta
				enemy.direction = 0;
			WALK:
				enemy.direction = enemy._check_direction()
				if enemy.direction > 0:
					enemy.AnimatedSprite.flip_h = false
				elif enemy.direction < 0:
					enemy.AnimatedSprite.flip_h = true
				walk_state_duration += delta
			CHASE:
				if enemy.player.position.x < enemy.position.x - 60:
					enemy.AnimatedSprite.flip_h = true
					enemy.direction = -1
				elif enemy.player.position.x > enemy.position.x +60:
					enemy.AnimatedSprite.flip_h = false
					enemy.direction = 1
			DEAD:
				enemy.direction = 0
				if enemy.AnimatedSprite.animation == "Dying" and enemy.AnimatedSprite.frame == enemy.AnimatedSprite.frames.get_frame_count("Dying")-1:
					enemy.queue_free()
				
		enemy.process_velocity(delta)
		enemy.process_movement(delta)
		
	func _check_conditions(delta):
		match state:
			IDLE:
				if enemy.hp <=0:
					return DEAD
				if enemy.is_on_floor():
					if idle_state_duration > state_stay:
						return WALK
			WALK:
				if enemy.hp <=0:
					return DEAD
				if walk_state_duration > state_stay: #or enemy.direction != enemy._check_direction() :
					return IDLE
			CHASE:
				if enemy.hp <=0:
					return DEAD
				if enemy.player.position.y < enemy.position.y -32 and enemy.is_on_floor():
					if enemy.player.position.x - enemy.position.x > -128 and enemy.player.position.x - enemy.position.x <=0 :
						return JUMP
					elif enemy.player.position.x - enemy.position.x < 128 and enemy.player.position.x - enemy.position.x >=0:
						return JUMP
				elif enemy.WallCheckLeft.is_colliding() or enemy.WallCheckRight.is_colliding():
					return JUMP
			JUMP: 
				if enemy.hp <=0:
					return DEAD
				if !enemy.is_on_floor() && enemy.velocity.y >= 0:
					return FALL
			FALL:
				if enemy.hp <=0:
					return DEAD
				if enemy.is_on_floor():
					return CHASE
			ATTACK:
				if enemy.hp <=0:
					return DEAD


	func _enter_state(state, old_state):
		"""Enter state"""
		match state:
			IDLE:
				# 静止状态，随机持续时间
				enemy.AnimatedSprite.play("Idle")
				enemy.velocity = Vector2.ZERO
				state_stay = rand_range(1, 4)
			WALK:
				enemy.control_ray_cast(true)
				# 移动状态，在活动范围内移动
				enemy.max_speed = enemy.max_speed_normal
				enemy.AnimatedSprite.play("Walking")
				state_stay = rand_range(1, 5)
			CHASE:
				enemy.control_ray_cast(false)
				enemy.AnimatedSprite.play('Running')

				enemy.max_speed = enemy.max_speed_attack
			JUMP:
				enemy.velocity.y = -700
				enemy.AnimatedSprite.play("Jump")
			DEAD:
				enemy.AnimatedSprite.play("Dying")
				
			FALL:
				enemy.AnimatedSprite.play("Falling")

	func _exit_state(state, new_state):
		match state:
			IDLE:
				idle_state_duration = 0
				if enemy.direction == 0:
					enemy.direction = 1
				else:
					enemy.direction *= -1
				state_stay = 0
			WALK:
				walk_state_duration = 0
				state_stay = 0
			CHASE:
				pass
			JUMP:
				pass
	func set_state(new_state):
		"""Set current status"""
		if state == DEAD: return
		if states.has(new_state):
			previous_state = state
			state = states[new_state]
			if previous_state != null:
				_exit_state(previous_state, state)
			if state != null:
				_enter_state(state, previous_state)
