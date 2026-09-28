class_name CommsRules
extends RefCounted
## Who may talk to whom (GAME_SPEC §5.3, §5.4, §8.5).
## Downed players cannot communicate at all. Eliminated players/spectators talk
## only among themselves. In meetings the reported victim is muted.

const PROXIMITY := "proximity"
const MEETING := "meeting"
const DEAD := "dead"


## Channel a sender uses right now, or "" if they may not communicate.
static func sender_channel(state: int, in_meeting: bool, is_meeting_victim: bool) -> String:
	match state:
		Vitals.State.DOWNED:
			return ""
		Vitals.State.ELIMINATED:
			return DEAD
	if in_meeting:
		return "" if is_meeting_victim else MEETING
	return PROXIMITY


## Whether a recipient hears a message on `channel`.
static func can_receive(channel: String, recipient_state: int, distance: float, proximity_range: float) -> bool:
	match channel:
		DEAD:
			return recipient_state == Vitals.State.ELIMINATED
		MEETING:
			return true  # everyone watches the meeting; only participants may speak
		PROXIMITY:
			return recipient_state != Vitals.State.DOWNED and distance <= proximity_range
	return false
