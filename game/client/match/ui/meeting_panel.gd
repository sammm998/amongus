class_name MeetingPanel
extends Control
## Meeting screen (GAME_SPEC §5.4, §8.4): incident summary, player cards,
## revive vote, suspect nominations, discussion chat + quick chat.

const QUICK := ["Where were you?", "I saw someone here", "I heard gunshots", "Camera was disabled", "Power went out",
	"I don't trust them", "I was at Medical", "Check the cameras", "Stay together", "Report the body"]

var game: ClientGameState
var _title: Label
var _timer: Label
var _summary: Label
var _cards: GridContainer
var _actions: HBoxContainer
var _chat_log: RichTextLabel
var _chat_input: LineEdit
var _quick: HFlowContainer
var _note: Label
var _selected_nominee := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.06, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	_title = UIKit.label("INCIDENT MEETING", 34, UITheme.AMBER)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_timer = UIKit.label("0:00", 34, UITheme.CYAN)
	head.add_child(_timer)
	var summary_panel := UIKit.panel()
	col.add_child(summary_panel)
	_summary = UIKit.label("", 18)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_panel.add_child(_summary)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	col.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.6
	body.add_child(scroll)
	_cards = GridContainer.new()
	_cards.columns = 3
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("h_separation", 8)
	_cards.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_cards)
	var chat_col := VBoxContainer.new()
	chat_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(chat_col)
	var chat_panel := UIKit.panel()
	chat_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_col.add_child(chat_panel)
	_chat_log = RichTextLabel.new()
	_chat_log.scroll_following = true
	_chat_log.bbcode_enabled = true
	_chat_log.add_theme_font_size_override("normal_font_size", 17)
	chat_panel.add_child(_chat_log)
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Say something… (Enter)"
	_chat_input.max_length = 140
	_chat_input.text_submitted.connect(_send_chat)
	chat_col.add_child(_chat_input)
	_quick = HFlowContainer.new()
	chat_col.add_child(_quick)
	for q: String in QUICK:
		var b := UIKit.button(q, func() -> void: _send_chat(q), 14, Vector2(0, 34))
		_quick.add_child(b)
	_note = UIKit.label("", 18, UITheme.AMBER)
	col.add_child(_note)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 12)
	_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_actions)
	game.chat_received.connect(_on_chat)
	game.meeting_changed.connect(_rebuild)


func open() -> void:
	visible = true
	_selected_nominee = -1
	_chat_log.clear()
	_rebuild()


func _process(_delta: float) -> void:
	if visible and not game.meeting.is_empty():
		_timer.text = UIKit.fmt_time(float(game.meeting["time_left"]))
		size = get_viewport_rect().size
		_cards.columns = 2 if size.x < 900 else 3


func _my_voice() -> String:
	var me := game.my_id()
	if game.is_spectator() or game.my_state() == Vitals.State.ELIMINATED:
		return "dead"
	if game.my_state() == Vitals.State.DOWNED:
		return "downed"
	if int(game.meeting.get("victim", -1)) == me:
		return "muted"
	return "ok"


func _rebuild() -> void:
	if game.meeting.is_empty() or not is_inside_tree():
		return
	var m := game.meeting
	var phase: String = m["phase"]
	var titles := {"INCIDENT_REVIEW": "INCIDENT REVIEW", "DISCUSSION": "DISCUSSION", "REVIVE_VOTE": "REVIVE VOTE", "SUSPECT_VOTE": "SUSPECT VOTE", "DONE": "RESOLVING"}
	_title.text = ("EMERGENCY MEETING — " if m["kind"] == Meeting.KIND_EMERGENCY else "INCIDENT — ") + titles.get(phase, phase)
	var info: Dictionary = m["info"]
	var lines := PackedStringArray()
	if m["kind"] == Meeting.KIND_EMERGENCY:
		lines.append("Called by %s." % info.get("caller", "?"))
	else:
		lines.append("Victim: %s (%s)   ·   Reported by %s" % [info.get("victim_name", "?"), info.get("victim_state", "?"), game.player_name(m["reporter"])])
		lines.append("Location: %s   ·   Est. time: ~%d s ago (±15 s)" % [info.get("district", "?"), int(info.get("seconds_ago", 0))])
		lines.append("Damage: %s   ·   Weapon family: %s   ·   Range: %s   ·   Last hit from: %s" % [info.get("damage_type", "?"), info.get("weapon_family", "?"), info.get("range", "?"), info.get("direction", "?")])
		lines.append("Nearby cameras: %s   ·   Power: %s" % [info.get("cameras", "?"), "ON" if info.get("power", true) else "OFF"])
	_summary.text = "\n".join(lines)
	UIKit.clear(_cards)
	var states := _player_states()
	var ids: Array = game.players.keys()
	ids.sort()
	for id: int in ids:
		_cards.add_child(_card(id, states.get(id, "eliminated"), phase))
	UIKit.clear(_actions)
	var voice := _my_voice()
	var can_vote: bool = game.my_id() in m["participants"] and not game.my_id() in m["voted"]
	_note.text = ""
	match voice:
		"downed":
			_note.text = "YOU ARE DOWN — you cannot communicate."
		"muted":
			_note.text = "You are the victim: you are muted and cannot vote."
		"dead":
			_note.text = "You are eliminated — spectating."
	_chat_input.editable = voice == "ok" and phase in ["DISCUSSION", "REVIVE_VOTE", "SUSPECT_VOTE", "INCIDENT_REVIEW"]
	for b in _quick.get_children():
		(b as Button).disabled = not _chat_input.editable
	if phase == "REVIVE_VOTE" and can_vote:
		_actions.add_child(UIKit.button("REVIVE", func() -> void: _vote(Meeting.Choice.REVIVE), 26, Vector2(220, 64)))
		_actions.add_child(UIKit.button("KEEP ELIMINATED", func() -> void: _vote(Meeting.Choice.KEEP), 26, Vector2(260, 64)))
		_actions.add_child(UIKit.button("ABSTAIN", func() -> void: _vote(Meeting.Choice.ABSTAIN), 22, Vector2(160, 64)))
	elif phase == "SUSPECT_VOTE" and can_vote:
		var hint := UIKit.label("Tap a player card to MARK SUSPECT" if _selected_nominee < 0 else "Mark %s as SUSPECT?" % game.player_name(_selected_nominee), 20, UITheme.AMBER)
		_actions.add_child(hint)
		if _selected_nominee >= 0:
			_actions.add_child(UIKit.button("MARK SUSPECT", func() -> void: _nominate(_selected_nominee), 24, Vector2(220, 64)))
		_actions.add_child(UIKit.button("SKIP", func() -> void: NetworkManager.send_action("skip"), 22, Vector2(140, 64)))
	elif phase in ["REVIVE_VOTE", "SUSPECT_VOTE"] and game.my_id() in m["voted"]:
		_actions.add_child(UIKit.label("Vote cast. Waiting for others…", 20, UITheme.CYAN))


func _player_states() -> Dictionary:
	var out := {}
	var snap := game.latest()
	for e: Array in snap.get("players", []):
		out[e[0]] = "alive" if e[4] == Vitals.State.ALIVE else "downed"
	for b: Array in snap.get("bodies", []):
		out[b[0]] = "eliminated"
	return out


func _card(id: int, state: String, phase: String) -> Control:
	var m := game.meeting
	var p := UIKit.panel(Vector2(0, 64))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)
	var colors := UIKit.suit_colors(game.player_color(id))
	row.add_child(UIKit.color_swatch(colors[0], 30))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var title := game.player_name(id) + ("  (you)" if id == game.my_id() else "")
	col.add_child(UIKit.label(title, 20, UITheme.TEXT))
	var status := state.to_upper()
	if id == int(m["victim"]):
		status = "VICTIM — " + status
	var status_color := UITheme.TEXT_DIM
	if state == "downed":
		status_color = UITheme.AMBER
	elif state == "eliminated":
		status_color = UITheme.DANGER
	col.add_child(UIKit.label(status, 14, status_color))
	if game.is_suspect(id):
		row.add_child(UIKit.label("⚠", 26, UITheme.AMBER))
	if id in m["voted"]:
		row.add_child(UIKit.label("✓", 26, UITheme.CYAN))
	if phase == "SUSPECT_VOTE" and id != game.my_id() and state != "eliminated":
		p.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed:
				_selected_nominee = id
				_rebuild())
		if id == _selected_nominee:
			var box: StyleBoxFlat = p.get_theme_stylebox("panel").duplicate()
			box.border_color = UITheme.AMBER
			box.set_border_width_all(3)
			p.add_theme_stylebox_override("panel", box)
	return p


func _vote(choice: int) -> void:
	NetworkManager.send_action("vote_revive", choice)


func _nominate(id: int) -> void:
	NetworkManager.send_action("nominate", id)
	_selected_nominee = -1


func _send_chat(text: String) -> void:
	if text.strip_edges().is_empty() or _my_voice() != "ok":
		return
	NetworkManager.send_action("chat", 0, text)
	_chat_input.clear()


func _on_chat(p: Dictionary) -> void:
	if not visible:
		return
	var colors := UIKit.suit_colors(game.player_color(p["from"]))
	var tag := "[dead] " if p["channel"] == CommsRules.DEAD else ""
	_chat_log.append_text("%s[color=#%s][b]%s[/b][/color]: %s\n" % [tag, colors[0].to_html(false), p["name"], p["text"].replace("[", "(")])
