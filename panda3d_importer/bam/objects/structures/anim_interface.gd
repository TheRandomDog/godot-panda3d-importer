extends BAMStruct
class_name PandaAnimInterface

enum PlayMode { POSE, PLAY, LOOP, PINGPONG }

var frame_count: int
var frame_rate: float
var play_mode: PlayMode
var from_frame: int
var to_frame: int
var play_rate: float = 1.0
var paused: bool

func _init(datagram: PandaBAMDatagramReader = null) -> void:
	if not datagram:
		return

	frame_count = datagram.decode_s32()
	frame_rate = datagram.decode_stdfloat()
	play_mode = datagram.decode_u8() as PlayMode
	datagram.decode_stdfloat()  # start_time
	datagram.decode_stdfloat()  # start_frame
	datagram.decode_stdfloat()  # play_frames
	from_frame = datagram.decode_s32()
	to_frame = datagram.decode_s32()
	play_rate = datagram.decode_stdfloat()
	paused = datagram.decode_bool()
	datagram.decode_stdfloat()  # paused_f

func get_frame_time(frame: int) -> float:
	if frame_rate == 0.0:
		return 0.0
	else:
		return frame * (1 / frame_rate)

func make_animation_player(animation: Animation) -> PandaAnimationPlayer:
	match play_mode:
		PlayMode.POSE, PlayMode.PLAY:
			animation.loop_mode = Animation.LOOP_NONE
		PlayMode.LOOP:
			animation.loop_mode = Animation.LOOP_LINEAR
		PlayMode.PINGPONG:
			animation.loop_mode = Animation.LOOP_PINGPONG
	if frame_count:
		animation.length = get_frame_time(frame_count)
	else:
		animation.length = get_frame_time(to_frame)

	var library := AnimationLibrary.new()
	library.add_animation('anim', animation)

	var animation_player := PandaAnimationPlayer.new()
	animation_player.add_animation_library('', library)
	if not paused:
		animation_player.autoplay = 'anim'
	animation_player.speed_scale = play_rate
	if from_frame != 0 or (frame_count and to_frame != frame_count):
		animation_player.section = [get_frame_time(from_frame), get_frame_time(to_frame)]
	return animation_player


class PandaAnimationPlayer extends AnimationPlayer:
	var section: Array[float]

	func _ready():
		if section:
			animation_started.connect(_ensure_played_with_section)

	func _ensure_played_with_section(anim_name: String):
		if section and not has_section():
			play_section(anim_name, section[0], section[1])
