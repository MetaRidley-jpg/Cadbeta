extends VBoxContainer
## Pool vs Cadavire. You = solids (1-7), she = stripes (9-15). You break.
## Her skill comes from what she wears (see PoolAI.profile()).

signal finished(won: bool, result_text: String)

const AIM_NUDGE_DEG := 0.3
const IDLE_TAUNT_AFTER := 14.0

@onready var table: Control = %PoolTable
@onready var power_strip: Control = %PowerStrip
@onready var you_label: Label = %YouLabel
@onready var her_label: Label = %HerLabel
@onready var wager_label: Label = %WagerLabel
@onready var quit_button: Button = %QuitButton
@onready var nudge_left: Button = %NudgeLeft
@onready var nudge_right: Button = %NudgeRight

var sim := PoolSim.new()
var rng := RandomNumberGenerator.new()
var state := "idle"          # idle, aim, roll, ai_think, ai_aim, over
var turn := PoolSim.Side.PLAYER
var aim_dir := Vector2.UP
var power := 0.0
var profile := {}
var _targets_at_start: Array = []
var _ai_shot := {}
var _timer := 0.0
var _idle := 0.0
var _taunted := false
var _nudge := 0
var _nudge_t := 0.0
var _quit_armed := 0.0

func _ready() -> void:
	table.game = self
	power_strip.pulled.connect(func(p): power = p)
	power_strip.released.connect(_on_release)
	quit_button.pressed.connect(_on_quit)
	nudge_left.button_down.connect(func(): _start_nudge(-1))
	nudge_right.button_down.connect(func(): _start_nudge(1))
	nudge_left.button_up.connect(func(): _nudge = 0)
	nudge_right.button_up.connect(func(): _nudge = 0)

func start(seed_value := -1) -> void:
	rng.randomize()
	sim.rack(seed_value)
	turn = PoolSim.Side.PLAYER
	aim_dir = Vector2.UP
	power = 0.0
	profile = PoolAI.profile()
	state = "aim"
	_idle = 0.0
	_taunted = false
	_quit_armed = 0.0
	wager_label.text = "FRIENDLY"
	_refresh_labels()
	Game.say.emit("pool_start", 3)

func can_aim() -> bool:
	return state == "aim" and turn == PoolSim.Side.PLAYER

func show_cue() -> bool:
	return state in ["aim", "ai_aim"]

func set_aim(d: Vector2) -> void:
	aim_dir = d
	_idle = 0.0

func _start_nudge(sign_v: int) -> void:
	if not can_aim():
		return
	_nudge = sign_v
	_nudge_t = 0.0
	aim_dir = aim_dir.rotated(deg_to_rad(AIM_NUDGE_DEG * sign_v))

func _on_release(p: float) -> void:
	power = 0.0
	if not can_aim() or p < 0.04:
		return
	player_shoot(p)

func player_shoot(p: float) -> void:
	_targets_at_start = sim.legal_targets(PoolSim.Side.PLAYER)
	sim.shoot(aim_dir, p)
	state = "roll"

func _process(delta: float) -> void:
	if _quit_armed > 0.0:
		_quit_armed -= delta
		if _quit_armed <= 0.0:
			quit_button.text = "QUIT"
	if _nudge != 0 and can_aim():
		_nudge_t += delta
		if _nudge_t > 0.35:   # hold to keep rotating
			aim_dir = aim_dir.rotated(deg_to_rad(AIM_NUDGE_DEG * 0.5 * _nudge))
	power_strip.enabled = can_aim()
	power_strip.shown_power = power if state == "ai_aim" else 0.0
	power_strip.queue_redraw()
	match state:
		"aim":
			_idle += delta
			if _idle > IDLE_TAUNT_AFTER and not _taunted:
				_taunted = true
				Game.say.emit("pool_idle", 0)
		"roll":
			sim.step(minf(delta, 1.0 / 30.0))
			if not sim.is_moving():
				_after_shot()
		"ai_think":
			_timer -= delta
			if _timer <= 0.0:
				_ai_shot = PoolAI.choose(sim, PoolSim.Side.CADAVIRE, profile, rng)
				_timer = 0.9
				state = "ai_aim"
		"ai_aim":
			_timer -= delta
			aim_dir = aim_dir.slerp(_ai_shot.dir, minf(1.0, delta * 6.0)).normalized()
			power = clampf((0.9 - _timer) / 0.9, 0.0, 1.0) * _ai_shot.power
			if _timer <= 0.0:
				aim_dir = _ai_shot.dir
				power = 0.0
				_targets_at_start = sim.legal_targets(PoolSim.Side.CADAVIRE)
				sim.shoot(aim_dir, _ai_shot.power)
				state = "roll"

func _after_shot() -> void:
	var shooter := turn
	var j := sim.judge(shooter, _targets_at_start)
	if sim.down[0]:
		sim.respot_cue()
	_refresh_labels()
	if j.winner != -1:
		_end(j.winner == PoolSim.Side.PLAYER)
		return
	if shooter == PoolSim.Side.PLAYER:
		if j.foul:
			Game.say.emit("pool_foul_you", 1)
		elif j.potted_own > 0 and rng.randf() < 0.6:
			Game.say.emit("pool_you_pot", 1)
	else:
		if j.foul:
			Game.say.emit("pool_foul_her", 1)
		elif j.potted_own > 0:
			Game.say.emit("pool_her_pot", 1)
	if not j.keep_turn:
		turn = PoolSim.Side.CADAVIRE if turn == PoolSim.Side.PLAYER else PoolSim.Side.PLAYER
	if turn == PoolSim.Side.PLAYER:
		state = "aim"
		_idle = 0.0
		_taunted = false
		# point the cue at your nearest legal ball so the first touch is not random
		var t := sim.legal_targets(PoolSim.Side.PLAYER)
		if not t.is_empty():
			var best: int = t[0]
			for b in t:
				if sim.pos[b].distance_to(sim.pos[0]) < sim.pos[best].distance_to(sim.pos[0]):
					best = b
			aim_dir = (sim.pos[best] - sim.pos[0]).normalized()
	else:
		state = "ai_think"
		_timer = rng.randf_range(0.7, 1.3)

func _end(won: bool) -> void:
	state = "over"
	var text := Game.end_minigame(won)
	if won:
		Challenges.bump("pool_wins")
	Game.say.emit("pool_win" if won else "pool_lose", 3)
	finished.emit(won, text)

func _on_quit() -> void:
	if state == "over":
		return
	if _quit_armed > 0.0:
		_quit_armed = 0.0
		_end(false)
		return
	_quit_armed = 3.0
	quit_button.text = "SURE?"

func _refresh_labels() -> void:
	you_label.text = "YOU  solids  %d" % sim.balls_left(PoolSim.Side.PLAYER)
	her_label.text = "%d  stripes  HER" % sim.balls_left(PoolSim.Side.CADAVIRE)
	if sim.balls_left(PoolSim.Side.PLAYER) == 0:
		you_label.text = "YOU  on the 8"
	if sim.balls_left(PoolSim.Side.CADAVIRE) == 0:
		her_label.text = "on the 8  HER"
