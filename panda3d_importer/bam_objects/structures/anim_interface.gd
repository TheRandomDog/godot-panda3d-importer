extends RefCounted
class_name PandaAnimInterface

enum PlayMode { POSE, PLAY, LOOP, PINGPONG }

class PandaAnimationPlayer extends AnimationPlayer:
	var section: Array[float]
	
	func _ready():
		if section:
			animation_started.connect(_ensure_played_with_section)
		
	func _ensure_played_with_section(anim_name: String):
		if section and not has_section():
			play_section(anim_name, section[0], section[1])

var frame_count: int
var frame_rate: float
var play_mode: PlayMode
var from_frame: int
var to_frame: int
var play_rate: float = 1.0
var paused: bool

func parse_data(bam_parser: BamParser) -> void:
	frame_count = bam_parser.decode_s32()
	frame_rate = bam_parser.decode_stdfloat()
	play_mode = bam_parser.decode_u8() as PlayMode
	bam_parser.decode_stdfloat()  # start_time
	bam_parser.decode_stdfloat()  # start_frame
	bam_parser.decode_stdfloat()  # play_frames
	from_frame = bam_parser.decode_s32()
	to_frame = bam_parser.decode_s32()
	play_rate = bam_parser.decode_stdfloat()
	paused = bam_parser.decode_bool()
	bam_parser.decode_stdfloat()  # paused_f

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
