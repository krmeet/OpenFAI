extends Node2D
class_name FloorObject

const SEPARATION = 2

var floor:Floor:
	set(value):
		floor = value
		angle = value.angle
		length = value.length
var actions:Array[Action]

var angle:int = 0:
	get: return angle
	set(value):
		angle = value
		realign()
var length:int = 50:
	get: return length
	set(value):
		length = value
		realign()

var midspin:bool:
	get: return floor.midspin
var midspin_object:FloorObject
var midspins:Array[FloorObject] = []
var midspin_parent:FloorObject

var aligned_to:FloorObject
var next_floor:FloorObject

var passed:bool = false

@onready var line:Line2D = $Line

func _ready():
	line.set_point_position(0,Vector2(-length,0))
	call_deferred("realign")
	call_deferred("update_actions")

func update_actions():
	var types = actions.map(func(action): return action.type)
	$Actions/Twirl.visible = Action.Type.Twirl in types
	$Actions/Speed.visible = false
	$Actions/Speed2.visible = false
	$Actions/Slow.visible = false
	$Actions/Slow2.visible = false
	if Action.Type.SetSpeed in types:
		var index = types.find(Action.Type.SetSpeed)
		var action = actions[index]
		var speed_type = action.data.get("speedType","Multiplier")
		var _speed = action.data.get("bpmMultiplier",1)
		if speed_type == "Multiplier":
			if _speed >= 4:
				$Actions/Speed2.visible = true
			elif _speed > 1:
				$Actions/Speed.visible = true
			elif _speed <= 0.25:
				$Actions/Slow2.visible = true
			elif _speed < 1:
				$Actions/Slow.visible = true

func realign():
	if line == null: return
	$Actions.rotation_degrees = -angle
	$Midspin.visible = false
	line.visible = true
	if midspin:
		move_to_front()
		if midspin_object == null:
			line.visible = false
			$Midspin.visible = true
	line.set_point_position(2,Vector2(
		cos(deg_to_rad(angle)),
		-sin(deg_to_rad(angle))
		)*(length-SEPARATION))
	if aligned_to != null:
		$Midspin.rotation_degrees = -angle
		var last_angle = aligned_to.angle
		line.set_point_position(0,Vector2(
			cos(deg_to_rad(last_angle)),
			-sin(deg_to_rad(last_angle))
			)*-(length-SEPARATION))
		if midspin:
			if midspin_object == null: position = Vector2(
				cos(deg_to_rad(last_angle)),
				-sin(deg_to_rad(last_angle))
				)*(length + aligned_to.length)
			else: position = Vector2()
			z_index = 1
		else:
			position = aligned_to.position + Vector2(
				cos(deg_to_rad(last_angle)),
				-sin(deg_to_rad(last_angle))
				)*(length + aligned_to.length)
func align_to_floor(object:FloorObject):
	aligned_to = object
	realign()

func hit(player:Player):
	if passed: return
	if next_floor == null and !midspin: return

	for object in midspins:
		if !object.passed:
			object.hit(player)
			return

	var spinner_position = player.spinner.global_position - player.position
	var next_position:Vector2
	if midspin:
		next_position = Vector2(
			cos(deg_to_rad(angle)),
			-sin(deg_to_rad(angle))
			)*length
	else:
		next_position = next_floor.position-position

	var difference = rad_to_deg(spinner_position.angle_to(next_position))
	var abs_difference = abs(difference)
#	if abs_difference <= 30:
#		print("Perfect")
#	elif abs_difference <= 45:
#		print("Good")
#	elif abs_difference <= 60:
#		print("Poor")
	if abs_difference > 60:
		return

	if midspin:
		midspin_object.hide_animated(player)
		next_floor = midspin_object
	next_floor.run_actions(player)
	passed = true

	if midspin:
		var midspin_index = midspin_parent.midspins.find(self)
		var next:FloorObject = midspin_parent.next_floor
		if midspin_index+1 < midspin_parent.midspins.size():
			next = midspin_parent.midspins[midspin_index+1]
		player.advance(next,false,player.rotation_degrees)
	else:
		var next = next_floor
		if next_floor.midspins.size() > 0:
			next = next_floor.midspins[0]
		player.advance(next_floor,true,player.rotation_degrees-180)
	return

func run_actions(player:Player):
	$Light.visible = true
	var all_actions:Array[Action] = []
	all_actions.append_array(actions)
	for object in midspins:
		all_actions.append_array(object.actions)
	for action in all_actions:
		match action.type:
			Action.Type.Twirl:
				player.clockwise = not player.clockwise
			Action.Type.SetSpeed:
				var speed_type = action.data.get("speedType","Multiplier")
				var _bpm = action.data.get("beatsPerMinute",100)
				var _speed = action.data.get("bpmMultiplier",1)
				if speed_type == "Multiplier":
					player.speed *= _speed
				elif speed_type == "Bpm":
					player.bpm = _bpm

func show_animated(player:Player):
	modulate.a = 0
	show()
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self,"modulate:a",1,player.seconds_per_beat)
	tween.play()
func hide_animated(player:Player):
	modulate.a = 1
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self,"modulate:a",0,player.seconds_per_beat)
	tween.tween_callback(hide)
	tween.play()
