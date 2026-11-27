extends Control
## DOGFIGHT: survive the waves. Cadavire flies the jet; you steer.
## Look: SEGA "Super Scaler" 3D (After Burner / Galaxy Force): Mode-7 ground with a rolling
## horizon, every object a baked pixel-stack sprite, scaled with hard pixels (DfRender).
## Feel: Star Fox / Burnout chase cam, boost from flying dangerously (low flying, drifting,
## hoops, takedowns), slow-motion takedowns, orbiting crash cam.
## Weather marks time passing: morning, rain, fog+thunder, volcano, asteroid, night.

signal finished(result_text: String)

const SHRINK := 3                 # world renders at 1/3 res, nearest filter = 1 art px = 3 screen px
const AREA_RADIUS := DfWorld.AREA_RADIUS
const CEILING := 300.0
const WAVE_BREAK := 5.0
const BULLET_SPEED := 950.0
const BULLET_LIFE := 0.7
const BULLET_DMG := 5.0
const FIRE_INTERVAL := 0.07
const GUN_CONE := deg_to_rad(13.0)   # T: "a little wider than the reticle shows" (was 11)
const RETICLE_TO_CONE := 1.2           # the gun cone is at least 20% wider than the idle reticle
const RETICLE_MAX := 56.0              # px half-size cap: a cone-sized box (~90 px) hid the jet
const GUN_RANGE := 650.0
const ENEMY_BULLET_SPEED := 650.0
const ENEMY_BULLET_DMG := 3.0
const ENEMY_FIRE_INTERVAL := 0.24
const ENEMY_GUN_CONE := deg_to_rad(5.0)
const ENEMY_GUN_RANGE := 450.0
const FLAK_SPEED := 380.0
const FLAK_RADIUS := 26.0
const FLAK_DMG := 16.0
const SHIP_FIRE_INTERVAL := 2.8
const SHIP_RANGE := 750.0
const SHIP_HP := 60.0
const BOMB_COOLDOWN := 1.0
const BOMB_RADIUS := 34.0
const BOMB_DMG := 90.0
const KAMIKAZE_DMG := 34.0
const LAVA_RADIUS := 26.0
const LAVA_DMG := 28.0
const ASTEROID_RADIUS := 300.0
const ASTEROID_WARN := 18.0         # countdown (s): the rock is in the sky the whole time (was 10)
const SHOCK_SPEED := 850.0          # m/s: the impact shockwave racing out over the water
const SHOCK_MAX := 2800.0           # m: it fades out here
const DEBRIS_COUNT := 34
const DEBRIS_GRAV := 70.0           # m/s² (slower than real: the arcs hang in the air)
const DEBRIS_HIT := 9.0             # damage if a burning rock hits you (a barrel roll dodges it)
# ---- QUAD GUNSHIP boss (wave 6). T: "Quad helicopter boss, boss meter in middle of screen, along
# with his charged meter, shoots a blue laser out of a bottom mounted cannon bigger than yours and
# the only way to dodge is top speed hard turn or a well tuned drift boost"
const BOSS_CHARGE := 8.0            # s to fill the cannon meter
const BOSS_CHARGE2 := 6.0           # phase 2: faster cannon
const BOSS_WARN := 2.8              # s from LOCK to FIRE: react (~0.3 s), drift 2.2 s (tier 2), let go ~0.3 s early
const BOSS_LOCK_FOLLOW := 8.0       # the lock lags you by ~1/8 s
const BOSS_TRACK := 240.0           # m/s: the beam's aim chases your LEAD point this fast. The beam's
                                    # light takes time to fly out (it bends), which costs it ~10 m/s,
                                    # so 240 here = the old 230 feel (T: "Yes" to 230). Measured over a
                                    # full 2 s shot: cruise 125 dead, boost 2 (220) half a hull, top
                                    # speed 255 across it escapes with ~16 m to spare.
const BOSS_NEAR_MISS := 30.0        # m past the edge of the beam: a near miss (slow-mo, +350)
const BOSS_BEAM_TIME := 2.0
const BOSS_BEAM_TIME2 := 2.4
const BOSS_ORBIT_R2 := 430.0
const BOSS_PHASE2_HP := 0.55        # phase 2 at 55% hull, or with 2 rotors down
const ROTOR_HP := 150.0             # each rotor: a weak spot (bolts x2 on it, x1.5 to the hull)
const ROTOR_HIT_R := 12.0
const ROTOR_HULL_DMG := 150.0       # losing a rotor also costs the hull this much
const BOSS_BEAM_R := 10.0           # m: hit radius round the beam line = the visible cyan core (yours is ~3 m)
const BOSS_BEAM_DPS := 55.0         # a full hit is ~a whole hull; a barrel roll does NOT dodge it
const BOSS_BEAM_RANGE := 2400.0
const BOSS_BEAM_SPEED := 2200.0     # m/s the beam's light flies: a sweep BENDS it; the gunner leads you by this
const BOSS_ORBIT_R := 650.0
const BOSS_ALT := 235.0
const LASER_BOSS_DMG := 260.0       # your super laser on the boss (5-6 lasers, or guns)
const LASER_ROTOR_DMG := 100.0      # ...and on the rotor nearest you
const BOSS_MUZZLE := Vector3(0.0, 2.5, -21.0) * DfPlane.BOSS_PX   # belly cannon tip (art px -> m; the stack's origin is its bottom slice)
const LOW_ALT := 14.0
const BOOST_LOW := 26.0
const BOOST_DRIFT := 16.0
const BOOST_HOOP := 30.0
const BOOST_KILL := 18.0
const BOOST_TAKEDOWN := 30.0
const HEAL_BETWEEN := 25.0
# Big laser (T's sheet): charges, locks on (red sparks in the reticle, target glows),
# then a homing beam bends into the target.
const LASER_CHARGE_TIME := 9.0
const KINDS_HP_KAMI := 18.0
const LASER_CONE := deg_to_rad(32.0)
const LASER_RANGE := 1100.0
const LASER_TRAVEL := 0.42      # seconds for the beam head to reach the target
const LASER_LINGER := 0.45
const LASER_BURST := 0.45       # seconds of the burst out of the cyclops visor
const VISOR_FWD := 9.0          # m from jet center to the cyclops visor
const LASER_SHIP_DMG := 80.0
# Cyan laser (T, 2026-11-26): a cleared ring course supercharges the laser: big and cyan, the
# jet sparks until it fires. "The cyan laser can chain multiple enemies possibly combo all of
# them. The enemies will spark blue instead of red if they will chain. When the cyan laser
# makes contact with enemy ship thunder also strikes the ship".
const CYAN := Color("39f3ff")
const CHAIN_RANGE := 380.0      # m from one chained enemy to the next
const CHAIN_HOP := 0.13         # s between hops
const CYAN_BOSS_DMG := 420.0    # cyan hit on the gunship hull (normal laser: 260)
const CYAN_SHIP_DMG := 240.0
const STRIKE_LIFE := 0.4
const ARC_LIFE := 0.35
const CHAIN_SCORE := 120.0      # per hop, times the hop number (combo)
const BOOST_FOV := [70.0, 82.0, 90.0, 104.0]

@onready var viewport: SubViewport = %Viewport
@onready var hud: Control = %Hud
@onready var controls: Control = %Controls
@onready var wave_label: Label = %WaveLabel
@onready var score_label: Label = %ScoreLabel
@onready var hp_bar: ProgressBar = %HpBar
@onready var boost_bar: ProgressBar = %BoostBar
@onready var center_msg: Label = %CenterMsg
@onready var sub_msg: Label = %SubMsg
@onready var enemies_label: Label = %EnemiesLabel
@onready var rings_label: Label = %RingsLabel
@onready var flash_rect: ColorRect = %Flash
@onready var quit_button: Button = %QuitButton

var render: DfRender
var world: DfWorld
var weather: DfWeather
var fx: DfFx
var player: DfPlane
var enemies: Array = []
var ships: Array = []           # {node, pos, hp, alive, cd, bob}
var projectiles: Array = []     # {p, v, life, kind, dmg}
var state := "idle"             # idle, intro, wave, break, crash, over
var wave := 0
var waves_cleared := 0
var score := 0.0
var kills := 0
var takedowns := 0
var autopilot := false
var rng := RandomNumberGenerator.new()
var _timer := 0.0
var _fire_cd := 0.0
var _bomb_cd := 0.0
var _shake := 0.0
var _slowmo_until := 0
var _msg_t := 0.0
var _crash_point := Vector3.ZERO
var _crash_t := 0.0
var _cam_pos := Vector3.ZERO
var _cam_yaw := 0.0
var _cam_up := Vector3.UP
var _look_ahead := 60.0
var _roll_key_was := 0
var dodge_t := 0.0                # "DODGE!" flash timer
var _cam_fov := 70.0
var _lava_t := 0.0
var _hit_say_cd := 0.0
var _low_say_cd := 0.0
var _hoop_say_cd := 0.0
var _red_flash := 0.0
var _white_flash := 0.0
# asteroid show (slice 14d, T: "Go nuts")
var ast_glance_t := 0.0             # > 0: the camera glances at the incoming rock (warning start)
var _ast_beep := 0                  # last countdown second that beeped
var shock: Dictionary = {}          # {center, r, alive}: the impact shockwave ring
var debris: Array = []              # {pos, vel, spin, size, trail: PackedVector3Array}
# KO replay (slice 15, T: "cinematic replay on ko like a fighting game and bars on top and bottom")
var sim_time := 0.0                 # seconds of simulated match time
var replay := DfReplay.new()
var _replay_at := -1.0              # sim_time when the pending replay starts (-1 = none)
var _ko: Dictionary = {}
var _last_kill: Dictionary = {}     # {t, pos, id}: the most recent kill (the KO candidate)
var _replay_back := ""              # state to go back to after the replay
var _after_replay_msg: Array = []   # [text, time, sub]: shown when the replay ends
var _lb := 0.0                      # letterbox bars 0..1
var debug_crash_at := -1.0          # --dfcrashat=S: wreck the jet at S s of match time (replay tests)
var boss: DfPlane = null            # the QUAD GUNSHIP while it lives
var boss_st: Dictionary = {}        # {charge, phase: charge|lock|fire|cool, aim, t, orbit, hit, beam_end, rotors, phase2, min_d, near}
var _ko_by := ""
var _lb_strip := 0.0                # 0..1: how far the bars have closed to the movie strip                    # what killed you ("beam" = the boss cannon), for the KO replay
var _lb_top: ColorRect
var _lb_bot: ColorRect
var _lb_label: Label
var _lb_caption: Label              # film-style caption in the bottom bar ("LASERED BY THE QUAD GUNSHIP")
var _lb_director: Label             # debug builds: the replay director's pick + score (tuning)
var _lb_rule_t: ColorRect           # thin gold rules on the strip edges
var _lb_rule_b: ColorRect
const LB_RATIO := 2.39              # the replay strip is a real movie frame
var _bomb_key_was := false
var _quit_armed := 0.0
var _target_lock: Variant = null
var laser_charge := 0.0          # 0..1
var laser_target: Variant = null # {"e": DfPlane} or {"s": ship dict}
var lasers: Array = []           # {t, target, end: Vector3, hit: bool}
var muzzle_t := 0.0              # muzzle flash timer (render)
var laser_burst_t := 0.0         # visor burst timer (render), counts down from LASER_BURST
var laser_burst_cyan := false
var cyan_laser := false          # supercharged by a ring course; spent by the next shot
var chain_preview: Array = []    # targets the armed cyan laser would chain (sparks blue)
var zaps: Array = []             # {a, b, t, life, kind: "arc" | "strike", seed}
var _chain: Dictionary = {}      # running chain: {list, i, t, last, hits}
var rings := DfRings.new()
var _laser_key_was := false
var force_boost := false         # debug / screenshots
var debug_stage := 0             # debug: pin the boost stage (1..3)
var demo := ""                   # scripted demo for GIFs ("kami"); empty = normal play
var _demo_t := 0.0
var _demo_phase := ""
var demo_log: Array = []
var debug_orbit := -1.0          # debug: look at the jet from this angle (rad, 0 = behind, PI = front)
var _wave_def := {}

func _ready() -> void:
	render = DfRender.new()
	viewport.add_child(render)
	hud.draw.connect(_draw_hud)
	quit_button.pressed.connect(_on_quit)
	# cinematic letterbox bars (KO + replay), on top of everything
	_lb_top = ColorRect.new()
	_lb_bot = ColorRect.new()
	for r in [_lb_top, _lb_bot]:
		r.color = Color.BLACK
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.visible = false
		add_child(r)
	_lb_label = Label.new()
	_lb_label.text = "REPLAY"
	_lb_label.add_theme_font_size_override("font_size", 26)
	_lb_label.add_theme_color_override("font_color", Color("ffe14a"))
	_lb_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_lb_label.add_theme_constant_override("outline_size", 9)
	_lb_label.visible = false
	_lb_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lb_label)
	_lb_caption = Label.new()
	_lb_caption.add_theme_font_size_override("font_size", 24)
	_lb_caption.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_lb_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lb_caption.visible = false
	_lb_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lb_caption)
	_lb_director = Label.new()
	_lb_director.add_theme_font_size_override("font_size", 14)
	_lb_director.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_lb_director.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lb_director.visible = false
	_lb_director.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lb_director)
	_lb_rule_t = ColorRect.new()
	_lb_rule_b = ColorRect.new()
	for r in [_lb_rule_t, _lb_rule_b]:
		r.color = Color(1.0, 0.8, 0.35, 0.55)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.visible = false
		add_child(r)

# =====================================================================
# Setup
# =====================================================================
func start(seed_value := -1) -> void:
	laser_charge = 0.0
	lasers = []
	laser_target = null
	muzzle_t = 0.0
	if seed_value >= 0:
		rng.seed = seed_value
		seed(seed_value)
		weather_rng.seed = seed_value * 7919 + 13
	else:
		rng.randomize()
		weather_rng.randomize()
	weather_log = []
	world = DfWorld.new()
	world.build(rng.randi_range(1, 9999) if seed_value < 0 else seed_value)
	weather = DfWeather.new()
	weather.setup(world)
	rings.setup(func(p: Vector3) -> float: return world.ground_y(p), (seed_value if seed_value >= 0 else rng.randi()) + 77, world.spires)
	cyan_laser = false
	chain_preview = []
	zaps = []
	_chain = {}
	weather.lightning.connect(_on_lightning)
	weather.asteroid_impact.connect(_on_impact)
	fx = DfFx.new()
	player = DfPlane.new()
	player.setup("player", Vector3(0, 90, 900), 0.0)
	player.free = true                # full 360 flight
	player.assist = Game.df_assist
	_cam_up = Vector3.UP
	player.boost = 40.0
	_cam_pos = player.position + Vector3(0, 8, 34)
	_cam_yaw = player.yaw
	render.setup(self)
	enemies.clear()
	ships.clear()
	projectiles.clear()
	wave = 0
	waves_cleared = 0
	score = 0.0
	kills = 0
	takedowns = 0
	state = "intro"
	_timer = 3.0
	_crash_t = 0.0
	sim_time = 0.0
	boss = null
	boss_st = {}
	_ko_by = ""
	replay = DfReplay.new()
	replay.full_frame = Game.is_phone()
	_replay_at = -1.0
	_last_kill = {}
	_lb = 0.0
	_quit_armed = 0.0
	quit_button.text = "QUIT"
	# T: "Make sure the wave 1 weather loads on boot": roll wave 1 now and show it during
	# GET READY (it used to start in morning and switch when the wave began).
	_wave1_plan = wave_plan(1)
	weather.set_preset(_wave1_plan.preset, true)
	_update_camera(0.0)
	controls.release_all()
	controls.enabled = true
	Engine.time_scale = 1.0
	_show_msg("GET READY", 2.5, "Drag left side to steer · BOOST · DRIFT · BOMB")
	Game.say.emit("df_start", 3)

# =====================================================================
# Main loop
# =====================================================================
func _process(delta: float) -> void:
	if state == "idle" or state == "over" or world == null:
		_letterbox(delta)
		return
	if state == "replay":
		if replay.step(self, delta):
			var c: Array = replay.camera(self)
			# the replay gives a HORIZONTAL fov (it fills the 2.39:1 strip); the renderer wants vertical
			var vs: Vector2 = render.view_size
			var vfov := rad_to_deg(2.0 * atan(tan(deg_to_rad(float(c[2])) * 0.5) * vs.y / maxf(1.0, vs.x)))
			render.set_camera_frame(c[0], c[1], c[3] if c.size() > 3 else Vector3.UP, minf(vfov, 150.0))
		else:
			_end_replay()
		_letterbox(delta)
		return
	sim_step(minf(delta, 1.0 / 30.0))
	if _replay_at >= 0.0 and sim_time >= _replay_at:
		_replay_at = -1.0
		_begin_replay()
		_letterbox(delta)
		return
	_update_camera(minf(delta, 1.0 / 30.0))
	_update_hud(delta)
	_letterbox(delta)
	if _slowmo_until > 0 and Time.get_ticks_msec() > _slowmo_until:
		Engine.time_scale = 1.0
		_slowmo_until = 0

func sim_step(dt: float) -> void:
	sim_time += dt
	if debug_crash_at > 0.0 and sim_time >= debug_crash_at and state == "wave":
		debug_crash_at = -1.0
		player.hp = 0.0
		_crash()
	world.tick(dt)
	weather.tick(dt)
	fx.tick(dt)
	_zaps_step(dt)
	match state:
		"intro":
			_timer -= dt
			if _timer <= 0.0:
				_next_wave()
		"break":
			_timer -= dt
			if _timer <= 0.0:
				_next_wave()
		"crash":
			_crash_t += dt
			if _crash_t > 2.6:
				_finish()
				return
	if state != "crash":
		_player_step(dt)
	_enemies_step(dt)
	_ships_step(dt)
	_projectiles_step(dt)
	_hazards_step(dt)
	if weather.asteroid_active:   # countdown alarm: a red pulse + beep each second for the last 5 s
		var left := int(ceil(weather.asteroid_time - weather.asteroid_t))
		if left <= 5 and left < _ast_beep:
			_ast_beep = left
			_red_flash = maxf(_red_flash, 0.45)
			Sfx.play("warning", -2.0, 0.0)
	ast_glance_t = maxf(0.0, ast_glance_t - dt)
	_shock_step(dt)
	_debris_step(dt)
	if state == "wave" and demo != "beach" and not (demo == "rings" and _demo_phase != "chain_done") and enemies.is_empty() and _ships_alive() == 0 and not weather.asteroid_active:
		_on_wave_clear()
	_hit_say_cd = maxf(0.0, _hit_say_cd - dt)
	_low_say_cd = maxf(0.0, _low_say_cd - dt)
	_hoop_say_cd = maxf(0.0, _hoop_say_cd - dt)
	if state in ["wave", "break", "crash"]:
		replay.record(self)

# =====================================================================
# Player
# =====================================================================
func _player_step(dt: float) -> void:
	if demo != "":
		_demo_inputs(dt)
	elif autopilot:
		_autopilot()
	else:
		_read_inputs()
	# keep the fight inside the area
	var flat := Vector2(player.position.x, player.position.z)
	if flat.length() > AREA_RADIUS:
		player.turn = player.steer_to(Vector3(0.0, player.position.y, 0.0)).x   # nose toward home
		if _msg_t <= 0.0:
			_show_msg("TURN BACK", 1.0)
	if player.position.y > CEILING:        # push the nose down (in the jet's frame: works inverted)
		var fl := Vector3(player.forward().x, 0.0, player.forward().z).normalized() if absf(player.forward().y) < 0.99 else Vector3.FORWARD
		player.pitch_in = player.steer_to(player.position + fl * 200.0 + Vector3.DOWN * 90.0).y
	if force_boost:
		player.boost = maxf(player.boost, 60.0)   # debug hold: never runs dry
	if debug_stage > 0:
		player.boost = 100.0
		player.boost_time = [0.0, 0.1, 1.3, 2.6][debug_stage]
	dodge_t = maxf(0.0, dodge_t - dt)
	var prev := player.position
	var was_rolling := player.rolling()
	player.step(dt)
	if player.rolling() and not was_rolling:
		Sfx.play("roll", -3.0)
	var bs := player.boost_stage()
	Sfx.loop("boost_loop", bs > 0, -10.0 + bs * 2.0, 0.85 + bs * 0.15)
	if player.drift_boost_fired > 0:       # drift boost just fired
		var tier := player.drift_boost_fired
		player.drift_boost_fired = 0
		_show_msg("DRIFT BOOST!" if tier == 1 else "MEGA DRIFT BOOST!", 0.8)
		Sfx.play("drift_boost", -2.0)
		_shake = maxf(_shake, 0.25 + 0.15 * tier)
		if _hoop_say_cd <= 0.0 and rng.randf() < 0.5:
			Game.say.emit("df_driftboost", 1)
			_hoop_say_cd = 8.0
	var ground := world.ground_y(player.position)
	var alt := player.position.y - ground
	if alt < 1.2:
		_crash()
		return
	if alt < LOW_ALT:
		player.boost += BOOST_LOW * dt
		score += 12.0 * dt
		sub_msg.text = "LOW FLYING!"
		if _low_say_cd <= 0.0 and rng.randf() < 0.01:
			_low_say_cd = 20.0
			Game.say.emit("df_low", 1)
	elif sub_msg.text == "LOW FLYING!":
		sub_msg.text = ""
	if player.drift and absf(player.turn) > 0.3:
		player.boost += BOOST_DRIFT * dt * absf(player.turn)
		score += 4.0 * dt
	player.boost = minf(player.boost, 100.0)
	# ring courses (DfRings): fly the next ring, all of them in time = cyan laser
	if state in ["wave", "break", "intro"] and demo == "":
		if rings.tick(dt, player.position, player.forward()) == "fail":
			_show_msg("RINGS RESET", 1.2, "Too slow: start again from ring 1")
			Sfx.play("lose", -8.0, 0.0)
	if rings.active() and rings.crossed(prev, player.position):
		var done := rings.pass_ring()
		player.boost = minf(100.0, player.boost + BOOST_HOOP)
		player.speed += 25.0
		score += 50.0
		Sfx.play("hoop", -4.0, 0.0)
		for k in 8:                  # gold flecks fly out of the ring (one big puff this close to the camera drew a box)
			var off := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(4.0, 10.0)
			fx.puff(player.position + player.forward() * 10.0 + off, Color("ffd23f") if k % 2 else Color.WHITE, 0.5, 0.1, 0.4, player.vel + off * 6.0, 0.0, 5.0)
		_ring_launch(done)
		if done:
			_supercharge()
		else:
			_show_msg("RING %d/%d" % [rings.next, DfRings.RINGS], 0.9, "+BOOST")
			if _hoop_say_cd <= 0.0:
				_hoop_say_cd = 15.0
				Game.say.emit("df_hoop", 1)
	# guns: auto-fire at anything inside the cone
	_fire_cd -= dt
	_target_lock = _gun_target()
	if _target_lock != null and _fire_cd <= 0.0:
		_fire_cd = FIRE_INTERVAL
		_fire_player(_target_lock)
	muzzle_t = maxf(0.0, muzzle_t - dt)
	laser_burst_t = maxf(0.0, laser_burst_t - dt)
	_laser_step(dt)
	_bomb_cd -= dt
	var bomb_key := Input.is_key_pressed(KEY_B)
	if (controls.bomb_queued or (bomb_key and not _bomb_key_was)) and _bomb_cd <= 0.0:
		_drop_bomb()
	controls.bomb_queued = false
	_bomb_key_was = bomb_key

# =====================================================================
# Scripted demo (GIFs). "kami": a kamikaze dives at you, you drift out of
# its path, swing round while it turns back, then the super laser stops it.
# =====================================================================
func start_demo(name: String) -> void:
	# demos keep the old fixed weather order: drop the random wave-1 roll, start in the
	# scripted sky of the wave being played (the demo code may set its own after this)
	_wave1_plan = {}
	weather.set_preset(wave_def(maxi(wave, 1)).preset, true)
	if name == "volcano":
		_start_demo_volcano()
		return
	if name == "loop":
		_start_demo_loop()
		return
	if name == "koi":
		_start_demo_koi()
		return
	if name == "asteroid":
		_start_demo_asteroid()
		return
	if name == "boss":
		_start_demo_boss()
		return
	if name == "bossko":
		_start_demo_boss(true)
		return
	if name == "fog":
		_start_demo_fog()
		return
	if name == "beach":
		_start_demo_beach()
		return
	if name.begins_with("rings"):          # "rings" or "rings_<kind>": a course, then a cyan chain
		_start_demo_rings(name.trim_prefix("rings").trim_prefix("_"))
		return
	demo = name
	_demo_t = 0.0
	_demo_phase = "approach"
	demo_log.clear()
	enemies.clear()
	ships.clear()
	state = "wave"
	wave = 2
	_msg_t = 0.0
	center_msg.modulate.a = 0.0
	player.position = Vector3(player.position.x, 95.0, player.position.z)
	player.pitch = 0.0
	player.speed = 125.0
	player.vel = player.forward() * 125.0
	var k := DfPlane.new()
	var f := player.forward()
	var p := player.position + f * 640.0 + f.cross(Vector3.UP) * 20.0 + Vector3.UP * 6.0
	k.setup("kamikaze", p, player.yaw + PI)
	k.hp = 5000.0                # demo: gun bolts flash on it, only the super laser stops it
	enemies.append(k)
	laser_charge = 0.93          # finishes charging during the approach: you see it get ready

## "volcano": the volcano erupts ahead. Two kamikazes dive out of the smoke. Drift through
## the first one (S-drift, let go: DRIFT BOOST), super laser on the second, then drift
## round and take the first one down with the guns.
var _dk1: DfPlane
var _dk2: DfPlane
var _demo_pt := 0.0          # time in the current phase

## "loop" (slice 13): a full loop, a barrel roll through a burst of enemy bolts (DODGE!),
## a half loop released at the top (ASSIST rolls upright: an Immelmann), then a charged
## drift so the contrails change color.
func _start_demo_loop() -> void:
	demo = "loop"
	_demo_t = 0.0
	_demo_phase = "level"
	demo_log.clear()
	enemies.clear()
	ships.clear()
	state = "wave"
	wave = 1
	_msg_t = 0.0
	center_msg.modulate.a = 0.0
	player.position = Vector3(-150.0, 72.0, 520.0)   # low: the loops stay under the 300 m ceiling
	player.yaw = 0.35
	player.pitch = 0.0
	player.speed = 125.0
	player.vel = player.forward() * 125.0
	player.assist = true
	_cam_up = Vector3.UP
	for k in 3:                # a few fighters around, for the sky to have something in it
		var e := DfPlane.new()
		e.setup("fighter", player.position + player.forward() * (500.0 + k * 140.0) + Vector3(k * 60.0 - 60.0, 60.0 + k * 25.0, 0.0), player.yaw + PI * 0.5)
		e.hp = 5000.0
		enemies.append(e)

func _demo_loop(dt: float) -> void:
	var t := _demo_t
	player.turn = 0.0
	player.pitch_in = 0.0
	player.drift = false
	player.boost_in = false
	for e in enemies:              # keep the extras out of the way
		e.turn = 0.4
		e.pitch_in = 0.0
		e.fire_cd = 99.0
	if t < 1.0:
		_demo_phase = "level"
	elif t < 1.0 + TAU / DfPlane.FREE_PITCH_RATE:
		if _demo_phase != "loop":
			_demo_phase = "loop"
			_show_msg("LOOP", 0.8)
		player.pitch_in = 1.0
	elif t < 6.4:
		_demo_phase = "level2"
	elif t < 7.6:
		if _demo_phase != "roll":
			_demo_phase = "roll"
			var f := player.forward()
			for k in 4:               # a burst of bolts straight at you
				var from := player.position + f * (70.0 + k * 9.0) + player.right() * (k - 1.5) * 1.2
				projectiles.append({"p": from, "v": (player.position + player.vel * 0.12 - from).normalized() * ENEMY_BULLET_SPEED, "life": 0.6, "kind": "enemy_bullet", "dmg": ENEMY_BULLET_DMG})
			player.roll_in = 1
			demo_log.append("roll at %.2f s" % t)
	elif t < 7.6 + PI / DfPlane.FREE_PITCH_RATE:
		if _demo_phase != "half":
			_demo_phase = "half"
			_show_msg("HALF LOOP...", 0.8)
		player.pitch_in = 1.0
	elif t < 11.6:
		if _demo_phase != "immelmann":
			_demo_phase = "immelmann"
			_show_msg("LET GO: ASSIST ROLLS YOU UP", 1.4)
			demo_log.append("inverted at %.2f s, canopy y %.2f" % [t, player.up().y])
	elif t < 14.0:
		_demo_phase = "drift"
		player.drift = true
		player.turn = -1.0
	else:
		player.turn = 0.0

## "koi" (slice 14): nose up at the sky, a giant koi swims across, a laser-size blast goes off
## next to it and it bolts away and up, tail thrashing, then calms down.
func _start_demo_koi() -> void:
	demo = "koi"
	_demo_t = 0.0
	_demo_phase = "watch"
	demo_log.clear()
	enemies.clear()
	ships.clear()
	state = "wave"
	wave = 1
	_msg_t = 0.0
	center_msg.modulate.a = 0.0
	player.position = Vector3(0.0, 150.0, 700.0)
	player.yaw = 0.0
	player.pitch = 0.3
	player.speed = 110.0
	player.vel = player.forward() * 110.0
	_cam_up = Vector3.UP
	var f: Dictionary = render.koi.fish[0]
	var h: Vector3 = player.position + player.forward() * 900.0
	f.radius = 700.0
	f.dir = 1.0
	f.ang = PI * 0.5 + 0.06
	f.center = Vector2(h.x, h.z) - Vector2(cos(f.ang), sin(f.ang)) * 700.0
	f.alt = h.y
	f.lift = 0.0
	f.length = 320.0

## "asteroid" (T: "Can I see asteroid event?"): jump to wave 5, put the jet 2.6 km out
## facing the main island, and fly in. The warning runs 10 s, the rock comes down on the
## island, the blast and the crater, the koi scatter; then a drift turn round the crater.
## "boss" (T: the QUAD GUNSHIP): 1) fly at it, drift-turn hard on the LOCK, let go just
## before it fires: drift boost at 255 m/s across the beam = (CLOSE) DODGED. 2) nose on two
## rotors (guns aim at the one nearest your nose): ROTOR DOWN x2 -> PHASE 2. 3) super laser
## = BOSS DOWN -> KO replay. Rotor hull is set low so the demo stays short.
## "bossko": the same fight, but you cruise straight at it: the cannon LASERS you -> KO replay.
func _start_demo_boss(ko := false) -> void:
	demo = "bossko" if ko else "boss"
	_demo_t = 0.0
	_demo_phase = "pass"
	demo_log.clear()
	enemies.clear()
	ships.clear()
	boss = null
	_spawn_boss()
	state = "wave"
	var b := boss.position
	var inward := Vector3(-b.x, 0.0, -b.z).normalized()
	var side := inward.cross(Vector3.UP).normalized()
	player.position = Vector3(b.x, 222.0, b.z) + inward * 620.0 + side * 40.0
	var to := -inward
	player.yaw = atan2(-to.x, -to.z)
	player.pitch = 0.0
	player.speed = 125.0
	player.vel = player.forward() * 125.0
	boss_st.charge = 0.30
	boss_st.phase = "charge"
	if ko:
		player.hp = 70.0              # already roughed up by the escorts
	_cam_up = Vector3.UP
	_update_camera(0.0)

var _demo_ext := false

func _demo_boss(dt: float) -> void:
	var t := _demo_t
	player.turn = 0.0
	player.boost_in = false
	player.drift = false
	player.pitch_in = clampf((222.0 - player.position.y) * 0.02, -0.25, 0.25)
	if boss == null:
		player.turn = 0.3
		return
	var fire_at := (1.0 - 0.30) * BOSS_CHARGE           # first shot (lock 3.2 s, fire 5.6 s)
	if demo == "bossko":
		# a FAILED dodge: on the lock it breaks across the beam with boost, but it never reaches
		# top speed (capped at 215 m/s, like boost stage 2). The beam whips after it, BENDING,
		# and catches it -> LASERED -> beam KO replay.
		if boss_st.get("phase", "") == "charge" and t < 4.0:
			var stk := player.steer_to(boss.position + Vector3(0, -40, 0), 1.2)
			player.turn = stk.x * 0.4
		else:
			var away_k := boss.position - player.position
			away_k.y = 0.0
			var perp_k := away_k.normalized().cross(Vector3.UP)
			var stk2 := player.steer_to(player.position + perp_k * 800.0, 1.5)
			player.turn = clampf(stk2.x * 2.0, -1.0, 1.0)
			player.boost_in = true
			player.speed_cap = 215.0
		return
	if _demo_phase == "pass":
		var away := boss.position - player.position
		away.y = 0.0
		var perp := away.normalized().cross(Vector3.UP)  # across the beam's line
		# a human timing: react 0.3 s after the LOCK, a full tier-2 drift, let go 0.3 s before the shot
		var d_on := BOSS_WARN - 0.3
		var d_off := 0.3
		if t < fire_at - d_on:
			var st0 := player.steer_to(boss.position, 1.5)
			player.turn = st0.x * 0.5
		elif t < fire_at - d_off:                        # hard drift turn through the lock...
			player.drift = true
			var st1 := player.steer_to(player.position + perp * 800.0, 1.5)
			player.turn = clampf(st1.x * 3.0, -1.0, 1.0)
		else:                                            # ...let go just before it fires, keep boosting
			var st2 := player.steer_to(player.position + perp * 800.0, 1.5)
			player.turn = clampf(st2.x, -0.6, 0.6)
			player.boost_in = true
		if t > fire_at + 2.4:
			_demo_phase = "rotors"
			for k in 4:
				boss_st.rotors[k] = 25.0
			demo_log.append("dodge: hit=%s near=%s" % [boss_st.get("hit", "?"), boss_st.get("near", "?")])
	elif _demo_phase == "rotors":
		var tgt := -1                                    # nose on the nearest live rotor
		var bd := INF
		for k in 4:
			if float(boss_st.rotors[k]) > 0.0 and boss_hub(k).distance_to(player.position) < bd:
				bd = boss_hub(k).distance_to(player.position)
				tgt = k
		var dist_b := player.position.distance_to(boss.position)
		if dist_b < 300.0:
			_demo_ext = true                             # attack run over: extend out...
		elif dist_b > 520.0:
			_demo_ext = false                            # ...then turn back in
		if _demo_ext:
			var away_p := player.position + (player.position - boss.position).normalized() * 600.0
			away_p.y = 222.0
			var st5 := player.steer_to(away_p, 1.5)
			player.turn = st5.x
		elif tgt >= 0:
			var st3 := player.steer_to(boss_hub(tgt), 1.8)
			player.turn = st3.x
			player.pitch_in = clampf(st3.y, -0.4, 0.4)
		if boss_st.get("phase2", false) and boss_rotors_down() >= 2:
			_demo_phase = "kill"
			boss.hp = 240.0
			laser_charge = 1.0
			demo_log.append("phase 2 at t=%.1f" % t)
	elif _demo_phase == "kill":
		var st4 := player.steer_to(boss.hit_center(), 1.8)
		player.turn = st4.x
		player.pitch_in = clampf(st4.y, -0.4, 0.4)
		laser_charge = 1.0
		if laser_ready() and _find_laser_target() != null and player.angle_to_point(boss.position) < 0.25:
			fire_laser()
			_demo_phase = "done"

## "beach" (art review, T's tropical-cove references): no enemies, a slow low pass along
## the main island's shore, ~60 m up, the beach on the left: shallows, sand, sea stacks, palms.
func _start_demo_beach() -> void:
	demo = "beach"
	_demo_t = 0.0
	enemies.clear()
	ships.clear()
	state = "wave"
	var isl: Dictionary = world.islands[0]
	var r: float = isl.radius * 1.12
	var c: Vector3 = isl.pos
	player.position = c + Vector3(r, 60.0, 0.0)
	var tang := Vector3(0, 0, -1)
	player.yaw = atan2(-tang.x, -tang.z)
	player.pitch = 0.0
	player.speed = 70.0
	player.speed_cap = 70.0
	player.vel = player.forward() * 70.0
	_cam_up = Vector3.UP
	_update_camera(0.0)

## "rings" (slice 16n, T: rings that move + twinkle, a cleared course = cyan chain laser):
## fly one course ring by ring, get supercharged, then 5 jets show up ahead in a loose line
## and the cyan laser chains them, lightning on each.
func _start_demo_rings(kind := "") -> void:
	demo = "rings"
	wave = 1
	_demo_t = 0.0
	_demo_phase = "rings"
	demo_log.clear()
	enemies.clear()
	ships.clear()
	weather.set_preset("morning", true)
	state = "wave"
	player.position = Vector3(0, 140, 600)
	player.yaw = 0.0
	player.pitch = 0.0
	player.speed = 95.0
	player.vel = player.forward() * 95.0
	rings.spawn(player.position - player.forward() * 300.0, player.forward(), kind if kind != "" else "slalom")
	_cam_up = Vector3.UP
	_update_camera(0.0)

func _demo_rings(dt: float) -> void:
	player.boost_in = false
	player.drift = false
	match _demo_phase:
		"rings":
			player.speed_cap = 95.0
			rings.tick(dt, player.position, player.forward())
			if rings.next < rings.rings.size():
				var nx: Vector3 = rings.pose(rings.next, rings.t + 0.35)[0]       # lead the moving ring
				var st := player.steer_to(nx, 2.6)
				player.turn = st.x
				player.pitch_in = st.y
			if cyan_laser:
				demo_log.append("course clear %.2f s" % _demo_t)
				_demo_phase = "chain"
				_demo_t = 0.0
				var f := player.forward()
				var sd := f.cross(Vector3.UP).normalized()
				for k in 5:
					var e := DfPlane.new()
					var ep := player.position + f * (520.0 + 170.0 * k) + sd * (60.0 if k % 2 else -60.0)
					ep.y = maxf(player.position.y, world.ground_y(ep) + 90.0) + 10.0 * k      # above the terrain
					e.setup("fighter", ep, 0.0)
					e.yaw = player.yaw + PI
					e.speed = 40.0
					e.speed_cap = 40.0
					e.vel = e.forward() * 40.0
					enemies.append(e)
		"chain":
			player.speed_cap = 80.0
			if not enemies.is_empty():
				var st2 := player.steer_to(enemies[0].position, 1.6)
				player.turn = st2.x
				player.pitch_in = st2.y
			if cyan_laser and laser_target != null and (chain_preview.size() >= 4 or _demo_t > 2.5):
				demo_log.append("cyan fired, chain %d" % chain_preview.size())
				fire_laser()
				_demo_phase = "chain_done"
		"chain_done":
			player.speed_cap = 80.0

func _demo_beach() -> void:
	var isl: Dictionary = world.islands[0]
	var c: Vector3 = isl.pos
	var r: float = isl.radius * 1.12
	var rel := player.position - c
	rel.y = 0.0
	var a := atan2(rel.z, rel.x) - 0.25          # aim a bit ahead along the circle (counter-clockwise)
	var tgt := c + Vector3(cos(a) * r, 60.0, sin(a) * r)
	var st := player.steer_to(tgt, 1.5)
	player.turn = st.x
	player.pitch_in = clampf((60.0 - player.position.y) * 0.03, -0.3, 0.3)
	player.boost_in = false
	player.drift = false
	enemies.clear()

## "fog" (T: "lights should pierce fog"): thickest fog (storm), the jet crawling, the
## gunship 1.4 km out (past the fog: its hull is gone, its beacons + cannon glow are not),
## and explosions going off at 400 m, 900 m and 1.6 km every 0.7 s.
func _start_demo_fog() -> void:
	demo = "fog"
	_demo_t = 0.0
	demo_log.clear()
	enemies.clear()
	ships.clear()
	weather.set_preset("storm", true)
	boss = null
	_spawn_boss()
	state = "wave"
	player.position = Vector3(0, 200, 700)
	player.yaw = 0.0
	player.pitch = 0.0
	player.speed = 60.0
	player.speed_cap = 60.0
	player.vel = player.forward() * 60.0
	boss.position = player.position + Vector3(120, 40, -1400)
	boss_st.orbit = atan2(boss.position.z, boss.position.x)
	boss_st.charge = 0.6
	_cam_up = Vector3.UP
	_update_camera(0.0)

func _demo_fog() -> void:
	player.turn = 0.0
	player.boost_in = false
	player.pitch_in = clampf((200.0 - player.position.y) * 0.02, -0.2, 0.2)
	if boss != null:
		boss.position = player.position + Vector3(120, 40, -1400)
		boss.vel = Vector3.ZERO
	var slot := int(_demo_t / 0.7)
	if slot > int((_demo_t - 1.0 / 30.0) / 0.7):
		var dists := [400.0, 900.0, 1600.0]
		var d: float = dists[slot % 3]
		var side := -180.0 + 120.0 * float((slot / 3) % 4)
		var p := player.position + Vector3(side, randf_range(-30, 30), -d)
		if slot % 2 == 0:
			fx.laser_explosion(p)
		else:
			fx.explosion(p, 2.0)

func _start_demo_asteroid() -> void:
	demo = "asteroid"
	_demo_t = 0.0
	demo_log.clear()
	var isl: Vector3 = world.islands[0].pos
	# start on the far side of the map from the island, inside the area (no TURN BACK)
	var away := Vector3(-isl.x, 0.0, -isl.z)
	var from_dir := away.normalized() if away.length() > 50.0 else Vector3(0.6, 0.0, 0.8).normalized()
	var p0 := isl + from_dir * 1500.0
	var flat := Vector2(p0.x, p0.z).limit_length(AREA_RADIUS - 120.0)
	player.position = Vector3(flat.x, 120.0, flat.y)
	var to := isl - player.position
	player.yaw = atan2(-to.x, -to.z)
	player.pitch = 0.0
	player.speed = 125.0
	player.vel = player.forward() * 125.0
	_cam_up = Vector3.UP
	_update_camera(0.0)

func _start_demo_volcano() -> void:
	demo = "volcano"
	_demo_t = 0.0
	_demo_pt = 0.0
	_demo_phase = "approach"
	demo_log.clear()
	enemies.clear()
	ships.clear()
	state = "wave"
	wave = 4
	weather.set_preset("eruption", true)
	_msg_t = 0.0
	center_msg.modulate.a = 0.0
	player.position = Vector3(250.0, 100.0, 330.0)
	var to: Vector3 = world.volcano.pos - player.position
	player.yaw = atan2(-to.x, -to.z)
	player.pitch = 0.06
	player.speed = 125.0
	player.vel = player.forward() * 125.0
	var f := player.forward()
	f.y = 0.0
	f = f.normalized()
	var r := f.cross(Vector3.UP)
	_dk1 = DfPlane.new()
	_dk1.setup("kamikaze", player.position + f * 560.0 + r * 12.0 + Vector3.UP * 4.0, player.yaw + PI)
	_dk1.hp = 5000.0           # survives the head-on pass; the guns get it later
	_dk2 = DfPlane.new()
	_dk2.setup("kamikaze", player.position + f * 980.0 - r * 70.0 + Vector3.UP * 18.0, player.yaw + PI)
	_dk2.hp = 5000.0           # only the super laser stops this one
	enemies.append(_dk1)
	enemies.append(_dk2)
	laser_charge = 0.82
	_show_msg("WAVE 4 · THE VOLCANO WAKES", 1.6)

func _bearing(p: Vector3) -> float:
	var to := p - player.position
	var r := player.forward().cross(Vector3.UP).normalized()
	return clampf(to.normalized().dot(r) * 3.0, -1.0, 1.0)

func _demo_volcano(dt: float) -> void:
	_demo_pt += dt
	var ph := _demo_phase
	match _demo_phase:
		"approach":
			player.boost_in = true
			if _dk1.alive and _dk1.position.distance_to(player.position) < 290.0:
				_demo_phase = "dodge"
		"dodge":                       # S-drift: left, then back right; keep drifting to charge
			player.drift = true
			player.turn = -1.0 if _demo_pt < 0.7 else 1.0
			var passed := (_dk1.position - player.position).dot(player.forward()) < 0.0
			if player.drift_tier() >= 1 and passed and _demo_pt > 1.25:
				_demo_phase = "release"
		"release":                     # let go: DRIFT BOOST
			player.turn = _bearing(_dk2.position) * 0.6
			if _demo_pt > 0.5:
				_demo_phase = "laser"
		"laser":
			player.turn = _bearing(_dk2.position) * 0.8
			if laser_ready() and _dk2.alive and player.angle_to_point(_dk2.position) < LASER_CONE * 0.7:
				laser_target = {"e": _dk2}
				fire_laser()
				_demo_phase = "after_laser"
		"after_laser":
			player.turn = 0.0
			if not _dk2.alive and _demo_pt > 0.9:
				_demo_phase = "turn"
		"turn":                        # drift round to face the first kamikaze again
			player.drift = true
			player.turn = signf(_bearing(_dk1.position)) if absf(_bearing(_dk1.position)) > 0.05 else 1.0
			if player.angle_to_point(_dk1.position) < deg_to_rad(20.0) and _demo_pt > 0.6:
				_demo_phase = "guns"
		"guns":                        # regular takedown: aim, the guns do the rest
			player.turn = _bearing(_dk1.position)
			# stay ~14 m under it: the kill shows ABOVE your jet, not hidden behind it
			player.pitch_in = clampf((_dk1.position.y - 14.0 - player.position.y) * 0.03, -0.6, 0.6)
			if _dk1.hp > KINDS_HP_KAMI and _dk1.position.distance_to(player.position) < 320.0:
				_dk1.hp = KINDS_HP_KAMI      # close enough to see it: now the bolts can finish it
			if not _dk1.alive:
				_demo_phase = "done"
		"done":
			player.boost_in = _demo_pt > 0.6
	if ph != _demo_phase:
		demo_log.append("%s at %.2f s" % [_demo_phase, _demo_t])
		_demo_pt = 0.0

func _demo_inputs(dt: float) -> void:
	if demo == "fog":
		_demo_t += dt
		_demo_fog()
		return
	if demo == "beach":
		_demo_t += dt
		_demo_beach()
		return
	if demo == "rings":
		_demo_t += dt
		_demo_rings(dt)
		return
	if demo == "boss" or demo == "bossko":
		_demo_t += dt
		_demo_boss(dt)
		return
	if demo == "asteroid":
		_demo_t += dt
		var isl: Vector3 = world.islands[0].pos
		player.boost_in = false
		player.drift = false
		player.speed_cap = 62.0 if weather.asteroid_active else INF    # slow, so the impact is still ahead of us
		if weather.asteroid_active:   # watch the rock all the way down (its path ends on the island)
			var st := player.steer_to(weather.asteroid_position(), 1.8)
			player.turn = st.x
			player.pitch_in = clampf(st.y, -0.3, 0.6) if player.position.y < 240.0 else minf(st.y, -0.1)
		elif _demo_t < ASTEROID_WARN + 1.5:
			var si2 := player.steer_to(isl + Vector3(0.0, 150.0, 0.0), 1.5)
			player.turn = si2.x
			player.pitch_in = clampf((150.0 - player.position.y) * 0.02, -0.25, 0.25)
		else:                          # then a wide drift turn round the crater
			player.turn = 0.55
			player.drift = _demo_t > ASTEROID_WARN + 2.0 and _demo_t < ASTEROID_WARN + 4.0
			player.pitch_in = clampf((170.0 - player.position.y) * 0.02, -0.25, 0.25)
		return
	if demo == "koi":
		_demo_t += dt
		player.turn = 0.0
		player.drift = false
		player.boost_in = false
		player.pitch_in = clampf((0.3 - player.pitch) * 3.0, -1.0, 1.0)
		if _demo_t > 2.6 and _demo_phase == "watch":
			_demo_phase = "boom"
			var f: Dictionary = render.koi.fish[0]
			var hp := render.koi.spine(f, 0.0)[3]
			fx.laser_explosion(hp + Vector3(30.0, -40.0, 20.0))
			Sfx.play("explosion_big", -5.0, 0.0)
			demo_log.append("boom at %.1f s, koi %s" % [_demo_t, String(f.pal.name)])
		return
	if demo == "loop":
		_demo_t += dt
		_demo_loop(dt)
		return
	if demo == "volcano":
		_demo_t += dt
		player.pitch_in = clampf((100.0 - player.position.y) * 0.04, -0.5, 0.5)
		player.drift = false
		player.boost_in = false
		player.turn = 0.0
		_demo_volcano(dt)
		return
	_demo_t += dt
	player.pitch_in = clampf((95.0 - player.position.y) * 0.04, -0.5, 0.5)
	player.drift = false
	player.boost_in = false
	player.turn = 0.0
	if enemies.is_empty():
		player.boost_in = _demo_t < 99.0
		return
	var k: DfPlane = enemies[0]
	var d := k.position.distance_to(player.position)
	var ang := player.angle_to_point(k.position)
	match _demo_phase:
		"approach":
			player.boost_in = true          # boost 1 flames toward it
			if d < 260.0:
				_demo_phase = "dodge"
				demo_log.append("dodge at %.2f s, %.0f m" % [_demo_t, d])
		"dodge":
			player.drift = true
			player.turn = -1.0
			var to_k := k.position - player.position
			if to_k.dot(player.forward()) < 0.0 and d > 120.0:
				_demo_phase = "swing"
				demo_log.append("passed at %.2f s, %.0f m" % [_demo_t, d])
		"swing":
			player.drift = true
			player.turn = -1.0
			if ang < LASER_CONE * 0.8 and laser_ready():
				_demo_phase = "fire"
		"fire":
			player.turn = 0.0
			controls.laser_queued = true
			demo_log.append("fire at %.2f s, %.0f m" % [_demo_t, d])
			_demo_phase = "after"
		"after":
			player.boost_in = true

func _read_inputs() -> void:
	var kt := 0.0
	var kp := 0.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		kt += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		kt -= 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		kp += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		kp -= 1.0
	player.turn = clampf(controls.turn + kt, -1.0, 1.0)
	player.pitch_in = clampf(controls.pitch + kp, -1.0, 1.0)
	# barrel roll: Q / E, or double-tap the stick (rolls toward the side you steer)
	var rk := (1 if Input.is_key_pressed(KEY_E) else 0) - (1 if Input.is_key_pressed(KEY_Q) else 0)
	if rk != 0 and _roll_key_was == 0:
		player.roll_in = rk
	_roll_key_was = rk
	if controls.roll_queued:
		controls.roll_queued = false
		player.roll_in = -1 if player.turn < -0.15 else 1
	player.boost_in = controls.boost or Input.is_key_pressed(KEY_SHIFT) or force_boost
	player.drift = controls.drift or Input.is_key_pressed(KEY_SPACE)

## Test / demo pilot: chase the nearest target, avoid terrain, use boost, drift, bombs.
func _autopilot() -> void:
	var target := Vector3.ZERO
	var best := INF
	var is_ship := false
	for e in enemies:
		var d: float = e.position.distance_to(player.position)
		if d < best:
			best = d
			target = e.position + e.vel * 0.4
			is_ship = false
	for s in ships:
		if s.alive:
			var d: float = s.pos.distance_to(player.position) * 1.3
			if d < best:
				best = d
				target = s.pos + Vector3.UP * 40.0
				is_ship = true
	if best == INF:
		target = Vector3(0, 110, 0)
	var st := player.steer_to(target, 2.0)
	player.turn = st.x
	player.pitch_in = clampf(st.y, -0.28, 0.28) if absf(st.y) < 0.9 else st.y   # gentle: keeps ASSIST on
	var climb := player.steer_to(player.position + Vector3(player.forward().x, 0.0, player.forward().z).normalized() * 200.0 + Vector3.UP * 120.0, 2.5)
	for ahead in [60.0, 150.0, 260.0]:
		var p: Vector3 = player.position + player.forward() * ahead
		if p.y < world.ground_y(p) + 30.0:
			player.pitch_in = climb.y
			player.turn = climb.x
			break
	if player.position.y < 35.0:
		player.pitch_in = climb.y
	var l := player.basis.inverse() * (target - player.position)
	player.drift = absf(atan2(l.x, -l.z)) > 1.2
	player.boost_in = player.boost > 55.0 and best > 450.0
	if laser_ready() and laser_target != null:
		controls.laser_queued = true
	if is_ship:
		for s in ships:
			if s.alive and Vector2(s.pos.x - player.position.x, s.pos.z - player.position.z).length() < 90.0:
				controls.bomb_queued = true
	if weather.asteroid_active:
		var a := weather.asteroid_target
		if Vector2(a.x - player.position.x, a.z - player.position.z).length() < ASTEROID_RADIUS + 120.0:
			var away := player.position + (player.position - a) * Vector3(1, 0, 1)
			player.turn = player.steer_to(away).x
			player.boost_in = true

func _gun_target() -> Variant:
	var best: Variant = null
	var best_a := GUN_CONE
	for e in enemies:
		if not e.alive:
			continue
		var d: float = e.position.distance_to(player.position)
		if d > GUN_RANGE:
			continue
		if e.kind == "boss":          # aim at the point nearest your nose: a live rotor or the hull
			var pts: Array = [e.hit_center()]
			for k in 4:
				if float(boss_st.rotors[k]) > 0.0:
					pts.append(boss_hub(k))
			for pt in pts:
				var ap := player.angle_to_point(pt)
				if ap < best_a:
					best_a = ap
					best = {"pos": pt, "vel": e.vel}
			continue
		var a := player.angle_to_point(e.position)
		if a < best_a:
			best_a = a
			best = {"pos": e.position, "vel": e.vel}
	for s in ships:
		if not s.alive:
			continue
		var d: float = s.pos.distance_to(player.position)
		if d > GUN_RANGE:
			continue
		var a := player.angle_to_point(s.pos)
		if a < best_a:
			best_a = a
			best = {"pos": s.pos + Vector3.UP * 2.0, "vel": Vector3.ZERO}
	return best

func _fire_player(t: Dictionary) -> void:
	Sfx.play("gun", -10.0, 0.1)
	var muzzle := player.position + player.forward() * 6.0
	var tp: Vector3 = t.pos
	var lead_t := tp.distance_to(muzzle) / BULLET_SPEED
	var aim: Vector3 = tp + (t.vel as Vector3) * lead_t
	var dir := (aim - muzzle).normalized()
	dir = dir.rotated(Vector3.UP, deg_to_rad(rng.randf_range(-0.6, 0.6)))
	projectiles.append({"p": muzzle, "v": dir * BULLET_SPEED, "life": BULLET_LIFE, "kind": "bullet", "dmg": BULLET_DMG})
	muzzle_t = 0.05

# =====================================================================
# Big laser
# =====================================================================
func laser_ready() -> bool:
	return laser_charge >= 1.0

func target_pos(t: Variant) -> Vector3:
	if t == null:
		return Vector3.ZERO
	if t.has("e"):
		return (t.e as DfPlane).position
	return t.s.pos + Vector3.UP * 3.0

func _target_alive(t: Variant) -> bool:
	if t == null:
		return false
	return (t.e as DfPlane).alive if t.has("e") else bool(t.s.alive)

func _find_laser_target() -> Variant:
	var best: Variant = null
	var best_a := LASER_CONE
	for e in enemies:
		if e.alive and e.position.distance_to(player.position) < LASER_RANGE:
			var a := player.angle_to_point(e.position)
			if a < best_a:
				best_a = a
				best = {"e": e}
	for sh in ships:
		if sh.alive and sh.pos.distance_to(player.position) < LASER_RANGE:
			var a := player.angle_to_point(sh.pos)
			if a < best_a * 0.9:     # jets first
				best_a = a
				best = {"s": sh}
	return best

func _laser_step(dt: float) -> void:
	var was_ready := laser_charge >= 1.0
	laser_charge = minf(1.0, laser_charge + dt / LASER_CHARGE_TIME)
	if laser_charge >= 1.0 and not was_ready:
		Sfx.play("laser_charge", -6.0, 0.0)
	laser_target = _find_laser_target()
	chain_preview = _chain_from(laser_target) if cyan_laser and laser_target != null else []
	controls.laser_cyan = cyan_laser
	controls.laser_charge = laser_charge
	controls.laser_locked = laser_target != null
	controls.queue_redraw()
	var key := Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_L)
	if (controls.laser_queued or (key and not _laser_key_was)) and laser_ready() and laser_target != null:
		fire_laser()
	controls.laser_queued = false
	_laser_key_was = key
	var keep: Array = []
	for b in lasers:
		b.t += dt
		if _target_alive(b.target):
			b.end = target_pos(b.target)
		if not b.hit and b.t >= LASER_TRAVEL and b.get("cyan", false):
			b.hit = true
			_shake = maxf(_shake, 0.9)
			if _target_alive(b.target):
				_cyan_hit(b.target)
			_chain = {"list": b.chain, "i": 1, "t": 0.0, "last": b.end, "hits": 1}
		if not b.hit and b.t >= LASER_TRAVEL:
			b.hit = true
			fx.laser_explosion(b.end)
			Sfx.play("explosion_big", -5.0, 0.05)
			_shake = maxf(_shake, 0.7)
			if _target_alive(b.target):
				if b.target.has("e"):
					var e: DfPlane = b.target.e
					e.last_hit_by_player = 0.0
					if e.kind == "boss":          # the laser also cooks the rotor nearest you
						var ri := -1
						var rd := INF
						for k in 4:
							if float(boss_st.rotors[k]) > 0.0 and boss_hub(k).distance_to(player.position) < rd:
								rd = boss_hub(k).distance_to(player.position)
								ri = k
						if ri >= 0:
							boss_st.rotors[ri] = float(boss_st.rotors[ri]) - LASER_ROTOR_DMG
							if float(boss_st.rotors[ri]) <= 0.0:
								_rotor_down(e, ri)
					if boss == null and e.kind == "boss":
						pass                          # the rotor blast finished it
					elif e.damage(LASER_BOSS_DMG if e.kind == "boss" else 9999.0):
						_kill_enemy(e, "player")
					elif e.kind == "boss":
						_check_phase2()
				else:
					_damage_ship(b.target.s, LASER_SHIP_DMG)
		if b.t < LASER_TRAVEL + LASER_LINGER:
			keep.append(b)
	lasers = keep
	_chain_step(dt)

func fire_laser() -> void:
	Sfx.play("laser_fire", 0.0, 0.0)
	if demo != "":
		demo_log.append("laser fired %.2f s" % _demo_t)
	laser_charge = 0.0
	laser_burst_t = LASER_BURST
	_shake = maxf(_shake, 0.35)
	var beam := {"t": 0.0, "target": laser_target, "end": target_pos(laser_target), "hit": false,
		"curl": rng.randf_range(-1.0, 1.0)}
	laser_burst_cyan = cyan_laser
	if cyan_laser:
		beam.cyan = true
		beam.chain = _chain_from(laser_target)
		cyan_laser = false
		chain_preview = []
		Sfx.play("zap", -2.0, 0.0)
	lasers.append(beam)
	score += 25.0
	Game.say.emit("df_laser", 2)

func visor_pos() -> Vector3:
	return player.position + player.forward() * VISOR_FWD + player.up() * 0.6

## Beam path: leaves the cyclops visor going forward, then bends into the target (cubic bezier).
func laser_point(b: Dictionary, u: float) -> Vector3:
	var p0 := visor_pos()
	var f := player.forward()
	var side := f.cross(Vector3.UP).normalized()
	var p1 := p0 + f * 140.0 + Vector3.UP * 35.0 + side * 60.0 * float(b.curl)
	var p3: Vector3 = b.end
	var p2 := p3 + (p0 - p3) * 0.25 + Vector3.UP * 45.0 - side * 30.0 * float(b.curl)
	var v := 1.0 - u
	return p0 * v * v * v + p1 * 3.0 * v * v * u + p2 * 3.0 * v * u * u + p3 * u * u * u

## Ring launch: aim at where the next ring will be when you get there, and throw the jet
## at it (DfPlane.launch: straight line, >= 210 m/s, the nose swings onto it). The last
## ring throws you straight ahead.
func _ring_launch(done: bool) -> void:
	if done or rings.next >= rings.rings.size():
		player.launch(player.forward(), 0.3, 230.0)
		return
	var p: Vector3 = rings.rings[rings.next].pos
	for k in 3:                      # lead: predict the ring at arrival (3 passes converge)
		var tt: float = player.position.distance_to(p) / 210.0
		p = rings.pose(rings.next, rings.t + tt)[0]
	player.launch(p - player.position, 0.55, 210.0)
	Sfx.play("drift_boost", -6.0, 0.05)

# ---------------------------------------------------------------- cyan laser
func _supercharge() -> void:
	cyan_laser = true
	laser_charge = 1.0
	score += 500.0
	_show_msg("COURSE CLEAR!", 2.2, "LASER SUPERCHARGED · CYAN CHAIN")
	Sfx.play("power_up", 0.0, 0.0)
	for k in 10:                     # a crackle of cyan flecks around the jet (a blast this close filled the screen)
		var off := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 0.8), rng.randf_range(-1, 1)).normalized() * rng.randf_range(6.0, 14.0)
		fx.puff(player.position + off, CYAN if k % 3 else Color(0.8, 1.0, 1.0), 0.5, 0.1, 0.45, player.vel + off * 5.0, 0.0, 5.0)
	Game.say.emit("df_supercharge", 2)

func _target_key(t: Variant) -> Variant:
	return t.e if t.has("e") else t.s

## The chain the cyan laser would follow from `first`: each hop jumps to the nearest live
## enemy (jet, kamikaze, boss or ship) within CHAIN_RANGE of the last one. No cap: one shot
## can chain the whole wave.
func _chain_from(first: Variant) -> Array:
	if first == null or not _target_alive(first):
		return []
	var out: Array = [first]
	var used: Array = [_target_key(first)]
	var cur := target_pos(first)
	while true:
		var best: Variant = null
		var bd := CHAIN_RANGE
		for e in enemies:
			if e.alive and not used.has(e):
				var d: float = e.position.distance_to(cur)
				if d < bd:
					bd = d
					best = {"e": e}
		for sh in ships:
			if sh.alive and not used.has(sh):
				var d: float = (sh.pos as Vector3).distance_to(cur)
				if d < bd:
					bd = d
					best = {"s": sh}
		if best == null:
			break
		out.append(best)
		used.append(_target_key(best))
		cur = target_pos(best)
	return out

func _chain_step(dt: float) -> void:
	if _chain.is_empty():
		return
	_chain.t += dt
	var list: Array = _chain.list
	while _chain.t >= CHAIN_HOP and int(_chain.i) < list.size():
		_chain.t -= CHAIN_HOP
		var tgt: Variant = list[_chain.i]
		_chain.i = int(_chain.i) + 1
		if not _target_alive(tgt):
			continue                       # died on the way: the arc skips it
		var p := target_pos(tgt)
		zaps.append({"a": _chain.last, "b": p, "t": 0.0, "life": ARC_LIFE, "kind": "arc", "seed": rng.randi()})
		Sfx.play("zap", -6.0, 0.15)
		_chain.last = p
		_chain.hits = int(_chain.hits) + 1
		score += CHAIN_SCORE * float(_chain.hits)
		_cyan_hit(tgt)
	if int(_chain.i) >= list.size():
		if int(_chain.hits) >= 2:
			_show_msg("CHAIN x%d!" % int(_chain.hits), 1.4, "+%d" % int(CHAIN_SCORE * _chain.hits * (_chain.hits + 1) / 2.0))
		_chain = {}

## One cyan hit: lightning strikes from the sky, a blue blast, heavy damage.
func _cyan_hit(t: Variant) -> void:
	var p := target_pos(t)
	zaps.append({"a": p + Vector3(rng.randf_range(-40, 40), 420.0, rng.randf_range(-40, 40)), "b": p, "t": 0.0, "life": STRIKE_LIFE, "kind": "strike", "seed": rng.randi()})
	fx.beam_explosion(p, 0.8)
	Sfx.play("thunder", -3.0, 0.1)
	_white_flash = maxf(_white_flash, 0.35)
	_shake = maxf(_shake, 0.8)
	if t.has("e"):
		var e: DfPlane = t.e
		e.last_hit_by_player = 0.0
		if e.kind == "boss":
			for k in 4:                      # the strike fries every live rotor a little
				if float(boss_st.rotors[k]) > 0.0:
					boss_st.rotors[k] = float(boss_st.rotors[k]) - LASER_ROTOR_DMG * 0.5
					if float(boss_st.rotors[k]) <= 0.0:
						_rotor_down(e, k)
			if boss != null and e.alive:
				if e.damage(CYAN_BOSS_DMG):
					_kill_enemy(e, "player")
				else:
					_check_phase2()
		elif e.damage(9999.0):
			_kill_enemy(e, "player")
	else:
		_damage_ship(t.s, CYAN_SHIP_DMG)

func _zaps_step(dt: float) -> void:
	if zaps.is_empty():
		return
	var keep: Array = []
	for z in zaps:
		z.t = float(z.t) + dt
		if float(z.t) < float(z.life):
			keep.append(z)
	zaps = keep

func _drop_bomb() -> void:
	Sfx.play("bomb_drop", -6.0)
	_bomb_cd = BOMB_COOLDOWN
	projectiles.append({"p": player.position + Vector3.DOWN * 2.0, "v": player.vel * 0.85, "life": 12.0, "kind": "bomb", "dmg": BOMB_DMG})

# =====================================================================
# Enemies + ships
# =====================================================================
func _spawn_enemy(kind: String) -> void:
	var e := DfPlane.new()
	var ang := rng.randf() * TAU
	var r := rng.randf_range(650.0, 950.0)
	var p := player.position + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
	p.x = clampf(p.x, -AREA_RADIUS, AREA_RADIUS)
	p.z = clampf(p.z, -AREA_RADIUS, AREA_RADIUS)
	p.y = maxf(world.ground_y(p) + 50.0, rng.randf_range(70.0, 180.0))
	var to := player.position - p
	e.setup(kind, p, atan2(-to.x, -to.z))
	e.fire_cd = rng.randf_range(0.5, 2.0)
	enemies.append(e)

func _enemies_step(dt: float) -> void:
	var dead: Array = []
	for e in enemies:
		if not e.alive:
			dead.append(e)
			continue
		if e.kind == "boss":
			_boss_step(e, dt)
			continue
		if state != "crash":
			e.ai_think(player, world.ground_y, dt)
		e.step(dt)
		if e.position.y < world.ground_y(e.position) + 1.0:
			_kill_enemy(e, "terrain")
			dead.append(e)
			continue
		var d: float = e.position.distance_to(player.position)
		if e.kind == "kamikaze" and state != "crash" and d < e.radius + player.radius and not player.rolling():
			fx.explosion(e.position, 1.3)
			e.alive = false
			dead.append(e)
			_shake += 0.8
			Game.say.emit("df_hit", 1)
			_hit_player(KAMIKAZE_DMG)
			continue
		if e.kind == "kamikaze" and d < 260.0 and not e.has_meta2("warned"):
			e.set_meta2("warned", true)
			Sfx.play("warning", -6.0, 0.0)
			if rng.randf() < 0.4:
				Game.say.emit("df_kamikaze", 1)
		if e.kind == "fighter" and state != "crash" and e.fire_cd <= 0.0 \
				and d < ENEMY_GUN_RANGE and e.angle_to_point(player.position) < ENEMY_GUN_CONE:
			e.fire_cd = ENEMY_FIRE_INTERVAL
			var muzzle: Vector3 = e.position + e.forward() * 6.0
			var aim: Vector3 = player.position + player.vel * (d / ENEMY_BULLET_SPEED)
			var dir := (aim - muzzle).normalized().rotated(Vector3.UP, deg_to_rad(rng.randf_range(-1.8, 1.8)))
			dir = dir.rotated(Vector3.RIGHT, deg_to_rad(rng.randf_range(-1.2, 1.2)))
			projectiles.append({"p": muzzle, "v": dir * ENEMY_BULLET_SPEED, "life": 0.9, "kind": "enemy_bullet", "dmg": ENEMY_BULLET_DMG})
			if e.position.distance_to(player.position) < 500.0:
				Sfx.play("enemy_gun", -14.0, 0.1)
		if not e.alive:
			dead.append(e)
	for e in dead:
		enemies.erase(e)

func _kill_enemy(e: DfPlane, how: String) -> void:
	Sfx.play("explosion", -7.0, 0.12)
	if not is_instance_valid(e):
		return
	e.alive = false
	_last_kill = {"t": sim_time, "pos": e.position, "id": e.get_instance_id(), "boss": e.kind == "boss"}
	if e.kind == "boss":
		_boss_down(e)
	fx.explosion(e.position, 1.0)
	if e.position.y < 3.0:
		fx.splash(e.position, 1.4)
	var pts := 100.0 if e.kind == "fighter" else 80.0
	match how:
		"player":
			kills += 1
			score += pts
			player.boost = minf(100.0, player.boost + BOOST_KILL)
			_takedown("KO!", 0.0)
		"terrain":
			if e.last_hit_by_player < 4.0 or e.position.distance_to(player.position) < 160.0:
				kills += 1
				score += pts
				player.boost = minf(100.0, player.boost + BOOST_TAKEDOWN)
				_takedown("TERRAIN KO!", 150.0)
		"asteroid":
			score += 50.0
			_show_msg("ASTEROID KO!", 1.2)

func _takedown(text: String, bonus: float) -> void:
	takedowns += 1
	score += bonus
	_show_msg(text, 1.0)
	_shake = maxf(_shake, 0.45)
	if state == "wave" or state == "break":
		Engine.time_scale = 0.3
		_slowmo_until = Time.get_ticks_msec() + 380
	if rng.randf() < 0.45:
		Game.say.emit("df_takedown", 1)

func _spawn_ship() -> void:
	var p := Vector3.ZERO
	for tries in 60:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(250.0, AREA_RADIUS * 0.85)
		p = Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		var clear := true
		for off in [Vector3(40, 0, 0), Vector3(-40, 0, 0), Vector3(0, 0, 40), Vector3(0, 0, -40), Vector3.ZERO]:
			if not world.is_sea(p + off):
				clear = false
		if clear:
			break
	ships.append({"pos": p + Vector3.UP * 2.0, "hp": SHIP_HP, "alive": true, "cd": rng.randf_range(1.0, 3.0),
		"bob": rng.randf() * TAU, "yaw": rng.randf() * TAU})

func _ships_alive() -> int:
	var n := 0
	for s in ships:
		if s.alive:
			n += 1
	return n

func _ships_step(dt: float) -> void:
	for s in ships:
		if not s.alive:
			continue
		s.bob += dt
		if state != "wave":
			continue
		s.cd -= dt
		var d: float = s.pos.distance_to(player.position)
		if s.cd <= 0.0 and d < SHIP_RANGE:
			s.cd = SHIP_FIRE_INTERVAL
			var t := d / FLAK_SPEED
			var aim: Vector3 = player.position + player.vel * t + Vector3(rng.randf_range(-10, 10), rng.randf_range(-6, 6), rng.randf_range(-10, 10))
			var from: Vector3 = s.pos + Vector3.UP * 5.0
			projectiles.append({"p": from, "v": (aim - from).normalized() * FLAK_SPEED, "life": t, "kind": "flak", "dmg": FLAK_DMG})
			fx.puff(from, Color(1, 0.8, 0.4, 1), 2.0, 4.0, 0.15)

func _damage_ship(s: Dictionary, v: float) -> void:
	if not s.alive:
		return
	s.hp -= v
	if s.hp <= 0.0:
		s.alive = false
		_last_kill = {"t": sim_time, "pos": s.pos, "id": 0}
		kills += 1
		score += 150.0
		player.boost = minf(100.0, player.boost + BOOST_KILL)
		fx.explosion(s.pos, 1.6)
		fx.splash(s.pos, 2.0)
		_takedown("SHIP SUNK!", 0.0)

# =====================================================================
# Projectiles + hazards
# =====================================================================
func _projectiles_step(dt: float) -> void:
	var keep: Array = []
	for pr in projectiles:
		var a: Vector3 = pr.p
		if pr.kind == "bomb":
			pr.v += Vector3.DOWN * 38.0 * dt
		elif pr.kind == "lava":
			pr.v += Vector3.DOWN * 26.0 * dt
		pr.p = a + (pr.v as Vector3) * dt
		pr.life -= dt
		var b: Vector3 = pr.p
		var gone := false
		match pr.kind:
			"bullet":
				for e in enemies:
					if e.alive and _seg_hit(a, b, e.hit_center(), e.radius + 1.0):
						e.last_hit_by_player = 0.0
						fx.puff(b, Color("ffd23f"), 1.0, 2.5, 0.12)
						if e.kind == "boss":
							_boss_bullet(e, b, pr.dmg, a)
						elif e.damage(pr.dmg):
							_kill_enemy(e, "player")
						gone = true
						break
				if not gone:
					for s in ships:
						if s.alive and _seg_hit(a, b, s.pos, 10.0):
							fx.puff(b, Color("ffd23f"), 1.0, 2.5, 0.12)
							_damage_ship(s, pr.dmg * 0.6)
							gone = true
							break
			"enemy_bullet":
				if state != "crash" and _seg_hit(a, b, player.position, player.radius):
					_hit_player(pr.dmg)
					gone = not player.rolling()      # a roll lets the bolt fly past
			"flak":
				if pr.life <= 0.0:
					fx.flak_burst(b)
					var d := b.distance_to(player.position)
					if d < FLAK_RADIUS and state != "crash":
						_hit_player(FLAK_DMG * (1.0 - d / FLAK_RADIUS))
					gone = true
			"bomb", "lava":
				var g := world.ground_y(b)
				var hit_air: bool = pr.kind == "lava" and state != "crash" and b.distance_to(player.position) < player.radius + 3.0
				if b.y <= g or hit_air:
					var big: bool = pr.kind == "bomb"
					if g <= 0.0 and not hit_air:
						fx.splash(b, 1.6 if big else 1.0)
					fx.explosion(Vector3(b.x, maxf(b.y, g), b.z), 1.4 if big else 0.9)
					if big:
						for s in ships:
							var ds: float = s.pos.distance_to(Vector3(b.x, g, b.z))
							if ds < BOMB_RADIUS:
								_damage_ship(s, pr.dmg * (1.0 - ds / BOMB_RADIUS) + 20.0)
						for e in enemies:
							if e.alive and e.position.distance_to(b) < BOMB_RADIUS:
								if e.damage(pr.dmg):
									_kill_enemy(e, "player")
					else:
						var dp := b.distance_to(player.position)
						if (dp < LAVA_RADIUS or hit_air) and state != "crash":
							_hit_player(LAVA_DMG * (1.0 if hit_air else (1.0 - dp / LAVA_RADIUS)), false)
					gone = true
		if not gone and pr.life <= 0.0:
			gone = true
		if not gone and (pr.kind == "bullet" or pr.kind == "enemy_bullet") and b.y < world.ground_y(b):
			if world.ground_y(b) <= 0.0:
				fx.puff(Vector3(b.x, 0.5, b.z), Color(0.9, 0.97, 1, 0.8), 1.0, 2.0, 0.3)
			gone = true
		if not gone:
			keep.append(pr)
	projectiles = keep

static func _seg_hit(a: Vector3, b: Vector3, c: Vector3, r: float) -> bool:
	var ab := b - a
	var t := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (a + ab * t).distance_to(c) < r

func _hazards_step(dt: float) -> void:
	if weather.erupting and state in ["wave", "break"]:
		_lava_t -= dt
		if _lava_t <= 0.0:
			_lava_t = rng.randf_range(0.5, 1.3)
			var ang := rng.randf() * TAU
			var r := rng.randf_range(0.0, 420.0)
			var p := player.position + Vector3(cos(ang) * r, 0.0, sin(ang) * r) + player.vel * 3.0
			p.y = 420.0
			projectiles.append({"p": p, "v": Vector3(rng.randf_range(-25, 25), -80.0, rng.randf_range(-25, 25)), "life": 20.0, "kind": "lava", "dmg": LAVA_DMG})

## dodge: bullets, flak and kamikazes miss you during a barrel roll (lava and the asteroid do not).
func _hit_player(v: float, dodge := true) -> void:
	if state == "crash" or state == "over":
		return
	if dodge and player.rolling():
		if dodge_t <= 0.0:
			_show_msg("DODGE!", 0.5)
			Sfx.play("dodge", -4.0, 0.0)
			score += 15.0
		dodge_t = 0.4
		return
	_red_flash = minf(1.0, _red_flash + 0.35)
	Sfx.play("hit", -4.0)
	_shake = maxf(_shake, 0.25)
	if player.damage(v):
		_crash()
		return
	if player.hp < 35.0 and _hit_say_cd <= 0.0:
		_hit_say_cd = 12.0
		Game.say.emit("df_hit", 1)

func _crash() -> void:
	Sfx.play("explosion_big", -3.0, 0.0)
	Sfx.loop("boost_loop", false)
	if state == "crash" or state == "over":
		return
	state = "crash"
	_crash_t = 0.0
	player.alive = false
	_crash_point = player.position
	if _ko_by == "beam":
		fx.beam_explosion(player.position, 1.3)
	else:
		fx.explosion(player.position, 2.2)
	if player.position.y < 4.0:
		fx.splash(player.position, 2.5)
	player.visible = false
	_shake = 1.2
	Engine.time_scale = 0.45
	_slowmo_until = Time.get_ticks_msec() + 1300
	controls.release_all()
	controls.enabled = false
	_show_msg("LASERED" if _ko_by == "beam" else "WRECKED", 3.0, "")
	Game.say.emit("df_beam_ko" if _ko_by == "beam" else "df_crash", 3)
	if _ko_ready():
		_ko = {"kind": "crash", "t": sim_time, "pos": player.position, "victim": player.get_instance_id(), "by": _ko_by}
		_replay_at = sim_time + 1.4
		_after_replay_msg = ["K.O.", 1.2, ""]

# =====================================================================
# Waves + weather
# =====================================================================
# ---- Random weather (T, 2026-11-26: "Weather should be random")
# Each wave rolls its weather; never the same twice in a row. The asteroid wave keeps its
# "impact" sky (that is the event, not weather). Demos keep the old fixed order.
const WEATHER_POOL := ["morning", "rain", "storm", "eruption", "night"]
const WEATHER_TITLE := {"morning": "CLEAR SKIES", "rain": "RAIN ROLLS IN", "storm": "FOG + THUNDER",
	"eruption": "THE VOLCANO WAKES", "night": "NIGHTFALL"}
const WEATHER_SAY := {"morning": "", "rain": "df_rain", "storm": "df_storm", "eruption": "df_volcano", "night": "df_storm"}
var fixed_weather := false          # true = the old scripted order (demos, some tests)
var weather_rng := RandomNumberGenerator.new()
var weather_log: Array = []         # presets rolled this match (tests)
var _wave1_plan: Dictionary = {}    # wave 1 is rolled at start() so its sky shows on boot

func roll_weather() -> String:
	var last: String = weather_log.back() if not weather_log.is_empty() else ""
	var pool: Array = WEATHER_POOL.filter(func(p): return p != last)
	return pool[weather_rng.randi_range(0, pool.size() - 1)]

## The wave's content (enemies, boss, asteroid) with this match's weather applied.
func wave_plan(w: int) -> Dictionary:
	var d := wave_def(w)
	if fixed_weather or demo != "" or d.get("asteroid", false):
		return d
	var p := roll_weather()
	d.preset = p
	if not d.get("boss", false):
		d.title = "WAVE %d · %s" % [w, WEATHER_TITLE[p]]
		d.say = WEATHER_SAY[p]
	return d

func wave_def(w: int) -> Dictionary:
	match w:
		1:
			return {"preset": "morning", "fighters": 3, "kamikaze": 0, "ships": 0, "title": "WAVE 1 · MORNING", "say": ""}
		2:
			return {"preset": "rain", "fighters": 4, "kamikaze": 2, "ships": 0, "title": "WAVE 2 · RAIN ROLLS IN", "say": "df_rain"}
		3:
			return {"preset": "storm", "fighters": 3, "kamikaze": 3, "ships": 2, "title": "WAVE 3 · FOG + THUNDER", "say": "df_storm"}
		4:
			return {"preset": "eruption", "fighters": 4, "kamikaze": 3, "ships": 2, "title": "WAVE 4 · THE VOLCANO WAKES", "say": "df_volcano"}
		5:
			return {"preset": "impact", "fighters": 5, "kamikaze": 4, "ships": 3, "title": "WAVE 5 · IMPACT", "say": "df_asteroid_warn", "asteroid": true}
		6:
			return {"preset": "night", "fighters": 2, "kamikaze": 2, "ships": 0, "title": "WAVE 6 · BOSS: QUAD GUNSHIP", "say": "df_boss", "boss": true}
	return {"preset": "night", "fighters": 3 + w, "kamikaze": 2 + w / 2, "ships": 2 + w / 3, "title": "WAVE %d · NIGHT" % w, "say": "df_storm"}

func _next_wave() -> void:
	wave += 1
	if wave == 1 and not _wave1_plan.is_empty() and demo == "":
		_wave_def = _wave1_plan
	else:
		_wave_def = wave_plan(wave)
	_wave1_plan = {}
	weather_log.append(_wave_def.preset)
	if _wave_def.preset != weather.preset:
		weather.set_preset(_wave_def.preset)
	for k in int(_wave_def.fighters):
		_spawn_enemy("fighter")
	for k in int(_wave_def.kamikaze):
		_spawn_enemy("kamikaze")
	for k in int(_wave_def.ships):
		_spawn_ship()
	state = "wave"
	_show_msg(_wave_def.title, 2.5)
	if _wave_def.say != "":
		Game.say.emit(_wave_def.say, 2)
	if _wave_def.get("boss", false):
		_spawn_boss()
	if _wave_def.get("asteroid", false):
		var main_isl: Dictionary = world.islands[0]
		weather.start_asteroid(main_isl.pos + Vector3(-90, 0, 30), ASTEROID_WARN, player.position)
		ast_glance_t = 2.4
		_ast_beep = int(ASTEROID_WARN) + 1
		_show_msg("INCOMING!", 2.2, "Look up")

func _on_wave_clear() -> void:
	waves_cleared += 1
	score += 250.0 * wave
	state = "break"
	_timer = WAVE_BREAK
	player.hp = minf(player.max_hp, player.hp + HEAL_BETWEEN)
	ships.clear()
	if _ko_ready() and not _last_kill.is_empty() and sim_time - float(_last_kill.t) < 1.5:
		# the kill that cleared the wave is a KO: slow-mo + "K.O." now, the replay in 0.9 s
		_ko = {"kind": "wave", "t": _last_kill.t, "pos": _last_kill.pos, "victim": _last_kill.id, "boss": _last_kill.get("boss", false)}
		_replay_at = sim_time + 0.9
		_after_replay_msg = ["WAVE %d CLEAR" % wave, 2.5, "+%d HULL" % int(HEAL_BETWEEN)]
		_show_msg("K.O.", 1.4, "")
		Engine.time_scale = 0.3
		_slowmo_until = Time.get_ticks_msec() + 700
	else:
		_show_msg("WAVE %d CLEAR" % wave, 2.5, "+%d HULL" % int(HEAL_BETWEEN))
	Game.say.emit("df_wave_clear", 2)

func _on_lightning() -> void:
	_white_flash = 0.6

func _on_impact(point: Vector3) -> void:
	_white_flash = 0.75                  # short: you should SEE the island break, not a white screen
	_shake = 2.6
	fx.explosion(point + Vector3.UP * 20.0, 7.0)
	fx.splash(point, 6.0)
	# a column of fire climbing out of the crater
	for k in 7:
		var j := Vector3(randf_range(-40, 40), 0.0, randf_range(-40, 40))
		fx.blasts.append({"pos": point + j + Vector3.UP * (40.0 + k * 75.0), "t": -0.1 * k, "life": 1.3 + 0.1 * k, "size": 9.0 - k * 0.6, "kind": "fire"})
	# the shockwave ring and the debris
	shock = {"center": Vector3(point.x, 0.0, point.z), "r": 0.0, "alive": true, "hit_player": false, "hit": {}}
	debris.clear()
	for k in DEBRIS_COUNT:
		var a := randf() * TAU
		var out := randf_range(55.0, 190.0)
		debris.append({"pos": point + Vector3(cos(a), 0.0, sin(a)) * randf_range(20.0, 120.0) + Vector3.UP * 40.0,
			"vel": Vector3(cos(a) * out, randf_range(110.0, 260.0), sin(a) * out),
			"spin": randf() * TAU, "size": randf_range(0.12, 0.42), "trail": PackedVector3Array()})
	Sfx.play("impact_rumble", 0.0, 0.0)
	Engine.time_scale = 0.3              # a beat of slow motion as it lands
	_slowmo_until = Time.get_ticks_msec() + 900
	world.carve(point, ASTEROID_RADIUS)
	var dead: Array = []
	for e in enemies:
		if Vector2(e.position.x - point.x, e.position.z - point.z).length() < ASTEROID_RADIUS + 40.0:
			_kill_enemy(e, "asteroid")
			dead.append(e)
	for e in dead:
		enemies.erase(e)
	for s in ships:
		if s.alive and Vector2(s.pos.x - point.x, s.pos.z - point.z).length() < ASTEROID_RADIUS + 40.0:
			_damage_ship(s, 999.0)
	var dp := Vector2(player.position.x - point.x, player.position.z - point.z).length()
	if dp < ASTEROID_RADIUS + 70.0:
		_hit_player(55.0 * (1.0 - dp / (ASTEROID_RADIUS + 70.0)) + 10.0, false)
	_show_msg("IMPACT!", 2.0, "Half the island is gone")
	Game.say.emit("df_asteroid_hit", 3)

## The shockwave: a ring racing out at SHOCK_SPEED. As it passes a jet it shoves it away
## and up (no damage); passing you: a big shake and "SHOCKWAVE!".
func _shock_step(dt: float) -> void:
	if shock.is_empty() or not shock.alive:
		return
	var r0: float = shock.r
	shock.r = r0 + SHOCK_SPEED * dt
	if shock.r > SHOCK_MAX:
		shock.alive = false
		return
	var c: Vector3 = shock.center
	var dp := Vector2(player.position.x - c.x, player.position.z - c.z).length()
	if not shock.hit_player and dp >= r0 and dp < shock.r and state != "crash":
		shock.hit_player = true
		var away := Vector3(player.position.x - c.x, 0.0, player.position.z - c.z).normalized()
		player.vel += away * 55.0 + Vector3.UP * 25.0
		_shake = maxf(_shake, 1.4)
		_show_msg("SHOCKWAVE!", 0.9)
		Sfx.play("hit", -2.0, 0.0)
	for e in enemies:
		var key: int = e.get_instance_id()
		if shock.hit.has(key):
			continue
		var de := Vector2(e.position.x - c.x, e.position.z - c.z).length()
		if de >= r0 and de < shock.r:
			shock.hit[key] = true
			var aw := Vector3(e.position.x - c.x, 0.0, e.position.z - c.z).normalized()
			e.vel += aw * 70.0 + Vector3.UP * 30.0

## Burning rocks thrown out of the crater: ballistic arcs with fire trails. Each one
## blows up where it lands (a splash on water). One that hits you does DEBRIS_HIT damage;
## a barrel roll dodges it.
func _debris_step(dt: float) -> void:
	if debris.is_empty():
		return
	var keep: Array = []
	for d in debris:
		var tr: PackedVector3Array = d.trail
		tr.insert(0, d.pos)
		if tr.size() > 8:
			tr.resize(8)
		d.trail = tr
		d.vel += Vector3.DOWN * DEBRIS_GRAV * dt
		d.pos += d.vel * dt
		d.spin += dt * 3.0
		var gy := world.ground_y(d.pos)
		if d.pos.y <= gy + 1.0:
			fx.explosion(Vector3(d.pos.x, gy + 4.0, d.pos.z), 1.3 + float(d.size) * 2.0)
			if gy <= 0.5:
				fx.splash(Vector3(d.pos.x, 0.0, d.pos.z), 1.5)
			continue
		if state != "crash" and d.pos.distance_to(player.position) < 10.0 + float(d.size) * 40.0:
			_hit_player(DEBRIS_HIT)
			if not player.rolling():
				fx.explosion(d.pos, 1.2)
				continue
		keep.append(d)
	debris = keep

# =====================================================================
# QUAD GUNSHIP boss
# =====================================================================
func _spawn_boss() -> void:
	var e := DfPlane.new()
	var a := atan2(player.position.z, player.position.x) + PI      # across the map from you
	e.setup("boss", Vector3(cos(a) * BOSS_ORBIT_R, BOSS_ALT, sin(a) * BOSS_ORBIT_R), 0.0)
	e.vel = Vector3.ZERO
	enemies.append(e)
	boss = e
	boss_st = {"charge": 0.25, "phase": "charge", "aim": player.position, "t": 0.0, "orbit": a, "hit": false,
		"beam_end": Vector3.ZERO, "fx_t": 0.0, "rotors": [ROTOR_HP, ROTOR_HP, ROTOR_HP, ROTOR_HP],
		"phase2": false, "min_d": INF, "near": false, "smoke_t": 0.0, "parts": [], "beam_t": 0.0}

func boss_muzzle() -> Vector3:
	return boss.position + boss.basis * BOSS_MUZZLE

## World position of rotor i's hub (0/2 left, 1/3 right; 0/1 back, 2/3 front).
func boss_hub(i: int) -> Vector3:
	return boss.position + boss.basis * (DfRender.ROTOR_HUBS[i] as Vector3)

func boss_charge_time() -> float:
	return BOSS_CHARGE2 if boss_st.get("phase2", false) else BOSS_CHARGE

## The lock always comes BOSS_WARN s before the shot (enough for a full tier-2 drift).
func boss_lock_at() -> float:
	return 1.0 - BOSS_WARN / boss_charge_time()

func boss_rotors_down() -> int:
	var n := 0
	for r in boss_st.get("rotors", []):
		if float(r) <= 0.0:
			n += 1
	return n

## The beam: from the belly cannon through the aim point, out to range or the ground.
## The beam is light that FLIES out of the cannon (T: "the beam doesn't bend"). Each step the
## cannon emits a part along its current aim; a part's light travels BOSS_BEAM_SPEED along its
## own direction and stops where it hits the ground. The beam = the line through the parts,
## so when the gunship sweeps after you, the far end lags behind and the beam BENDS like a hose.
func _beam_emit() -> void:
	var m := boss_muzzle()
	var d: Vector3 = ((boss_st.aim as Vector3) - m).normalized()
	var ln := BOSS_BEAM_RANGE
	for k in 48:
		var p := m + d * BOSS_BEAM_RANGE * (k + 1) / 48.0
		if p.y <= world.ground_y(p):
			ln = BOSS_BEAM_RANGE * (k + 1) / 48.0
			break
	(boss_st.parts as Array).push_front({"o": m, "d": d, "t0": float(boss_st.beam_t), "len": ln})

## The beam as a polyline: the cannon first (while firing), then each part's light, newest to
## oldest, ending at the newest part that already hit the ground. After the shot the tail
## (no cannon point) keeps flying until every part has landed.
func boss_beam_pts() -> PackedVector3Array:
	var pts := PackedVector3Array()
	if boss == null:
		return pts
	var bs := boss_st
	if bs.get("phase", "") == "fire":
		pts.append(boss_muzzle())
	for p in bs.get("parts", []):
		var r := minf((float(bs.beam_t) - float(p.t0)) * BOSS_BEAM_SPEED, float(p.len))
		pts.append((p.o as Vector3) + (p.d as Vector3) * r)
		if r >= float(p.len) - 0.01:
			break
	return pts

## Drop parts behind the newest landed one (they are under the ground); count kept parts.
func _beam_prune() -> void:
	var keep := 0
	var parts: Array = boss_st.get("parts", [])
	for p in parts:
		keep += 1
		if (float(boss_st.beam_t) - float(p.t0)) * BOSS_BEAM_SPEED >= float(p.len) - 0.01:
			break
	if keep < parts.size():
		boss_st.parts = parts.slice(0, keep)

## Distance from you to the (bent) beam, and the nearest point on it.
func boss_beam_dist() -> Array:
	var pts := boss_beam_pts()
	var best := INF
	var near := boss_muzzle() if boss != null else Vector3.ZERO
	for k in pts.size() - 1:
		var a := pts[k]
		var ab := pts[k + 1] - a
		var u := 0.0 if ab.length_squared() < 0.0001 else clampf((player.position - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var q := a + ab * u
		var d := q.distance_to(player.position)
		if d < best:
			best = d
			near = q
	return [best, near]

func _boss_step(e: DfPlane, dt: float) -> void:
	var bs := boss_st
	var p2: bool = bs.phase2
	# hover: a slow circle round the map (phase 2: closer and faster), bobbing; nose on you,
	# tilted by its motion and by lost rotors (it sags toward the dead corners)
	bs.orbit = float(bs.orbit) + dt * (0.09 if p2 else 0.05)
	var r := BOSS_ORBIT_R2 if p2 else BOSS_ORBIT_R
	var want := Vector3(cos(bs.orbit) * r, BOSS_ALT + sin(sim_time * 0.6) * 8.0, sin(bs.orbit) * r)
	e.vel = e.vel.lerp((want - e.position).limit_length(48.0 if p2 else 32.0), clampf(dt * 0.8, 0.0, 1.0))
	e.position += e.vel * dt
	var to := player.position - e.position
	var yaw_w := atan2(-to.x, -to.z)
	var y := lerp_angle(e.yaw, yaw_w, clampf(dt * 1.2, 0.0, 1.0))
	var lv := Basis.from_euler(Vector3(0.0, y, 0.0)).inverse() * e.vel
	var sag := Vector3.ZERO
	for i in 4:
		if float(bs.rotors[i]) <= 0.0:
			sag += (DfRender.ROTOR_HUBS[i] as Vector3).normalized()
	e.basis = Basis.from_euler(Vector3(-0.05 + lv.z * 0.004 - sag.z * 0.09 + sin(sim_time * 7.0) * 0.01 * sag.length(), y, lv.x * 0.006 + sag.x * 0.09))
	e.roll_vis = 0.0
	bs.fx_t = maxf(0.0, float(bs.fx_t) - dt)
	bs.smoke_t = float(bs.smoke_t) - dt
	if bs.smoke_t <= 0.0:                 # dead rotors trail black smoke and sparks
		bs.smoke_t = 0.09
		for i in 4:
			if float(bs.rotors[i]) <= 0.0:
				var h := boss_hub(i)
				fx.puff(h + Vector3(randf_range(-3, 3), 2.0, randf_range(-3, 3)), Color(0.12, 0.1, 0.12, 0.8), 5.0, 16.0, 1.4)
				if randf() < 0.35:
					fx.puff(h, Color("ffb000"), 1.0, 2.0, 0.25)
	match String(bs.phase):
		"charge":
			bs.charge = float(bs.charge) + dt / boss_charge_time()
			if bs.charge >= boss_lock_at() and state != "crash":
				bs.phase = "lock"
				bs.aim = player.position
				Sfx.play("laser_charge", -2.0, 0.0)
				_show_msg("CANNON LOCK!", 1.2, "Top speed. Hard turn.")
		"lock":
			bs.charge = float(bs.charge) + dt / boss_charge_time()
			# the lock already LEADS you (the ring sits ahead of your nose): a hard turn throws it off
			var lk_t := clampf(boss_muzzle().distance_to(player.position) / BOSS_BEAM_SPEED, 0.0, 1.2)
			bs.aim = (bs.aim as Vector3).lerp(player.position + player.vel * lk_t, clampf(dt * BOSS_LOCK_FOLLOW, 0.0, 1.0))
			if bs.charge >= 1.0:
				bs.charge = 1.0
				bs.phase = "fire"
				bs.t = 0.0
				bs.parts = []
				bs.beam_t = 0.0
				bs.hit = false
				bs.near = false
				bs.min_d = INF
				_shake = maxf(_shake, 0.9)
				Sfx.play("laser_fire", 2.0, 0.0)
				Sfx.play("explosion_big", -8.0, 0.0)
		"fire":
			bs.t = float(bs.t) + dt
			bs.beam_t = float(bs.get("beam_t", 0.0)) + dt
			if not bs.has("parts"):
				bs.parts = []
			# the gunner LEADS you by the light's flight time: steady flight gets hit; a hard
			# turn swings your future point away faster than the aim can follow (T's dodge)
			var lead_t := clampf(boss_muzzle().distance_to(player.position) / BOSS_BEAM_SPEED, 0.0, 1.2)
			var lead_pt := player.position + player.vel * lead_t
			bs.aim = (bs.aim as Vector3).move_toward(lead_pt, BOSS_TRACK * dt)
			_beam_emit()
			_beam_prune()
			var bpts := boss_beam_pts()
			var bd := boss_beam_dist()
			bs.beam_end = bpts[bpts.size() - 1]
			if float(bs.fx_t) <= 0.0:     # the beam scorches where it ends
				bs.fx_t = 0.07
				var be: Vector3 = bs.beam_end
				if be.y <= world.ground_y(be) + 1.0:
					fx.puff(be + Vector3.UP * 3.0, Color("7fe9ff"), 6.0, 22.0, 0.5)
					if world.ground_y(be) <= 0.5:
						fx.splash(be, 1.2)
			if state != "crash":
				var dist: float = bd[0]
				var hit_r := BOSS_BEAM_R + player.radius
				bs.min_d = minf(float(bs.min_d), dist)
				if dist < hit_r:
					if not bs.hit:
						_show_msg("CANNON HIT!", 0.9)
						Game.say.emit("df_hit", 0)     # priority 0: dropped, not queued (no "hull's crunchy" after a KO)
					bs.hit = true
					_beam_hit(BOSS_BEAM_DPS * dt)
				elif dist < hit_r + BOSS_NEAR_MISS and not bs.near and not bs.hit and bs.t > 0.15:
					bs.near = true                 # it went right past you: a beat of slow motion
					Engine.time_scale = 0.35
					_slowmo_until = Time.get_ticks_msec() + 450
					Sfx.play("dodge", 0.0, 0.0)
			if bs.t >= (BOSS_BEAM_TIME2 if p2 else BOSS_BEAM_TIME):
				bs.phase = "cool"
				bs.t = 0.0
				bs.charge = 0.0
				if not bs.hit and state != "crash":
					if bs.near:
						_show_msg("CLOSE DODGE!", 1.1, "+350")
						score += 350.0
					else:
						_show_msg("DODGED!", 1.0, "+200")
						score += 200.0
					player.boost = minf(100.0, player.boost + 15.0)
		"cool":
			bs.t = float(bs.t) + dt
			if not (bs.get("parts", []) as Array).is_empty():   # the cut-off tail flies on, then lands
				bs.beam_t = float(bs.get("beam_t", 0.0)) + dt
				_beam_prune()
				if bs.t > 1.1:
					bs.parts = []
			if bs.t > 1.2:
				bs.phase = "charge"

## Your bolt hit the gunship at point p. Rotors are weak spots: a bolt within ROTOR_HIT_R of a
## live hub hurts that rotor x2 and the hull x1.5. Elsewhere it is armour (x1).
func _boss_bullet(e: DfPlane, p: Vector3, dmg: float, from: Variant = null) -> void:
	var best := -1
	var bd := ROTOR_HIT_R
	var a: Vector3 = p if from == null else from     # measure along the bolt's whole step
	var ab := p - a
	for i in 4:
		if float(boss_st.rotors[i]) <= 0.0:
			continue
		var h := boss_hub(i)
		var u := 0.0 if ab.length_squared() < 0.001 else clampf((h - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := h.distance_to(a + ab * u)
		if d < bd:
			bd = d
			best = i
	var hull := dmg
	if best >= 0:
		hull = dmg * 1.5
		boss_st.rotors[best] = float(boss_st.rotors[best]) - dmg * 2.0
		fx.puff(p, Color("9df4ff"), 1.5, 4.0, 0.15)
		if float(boss_st.rotors[best]) <= 0.0:
			_rotor_down(e, best)
	if boss != null and e.damage(hull):
		_kill_enemy(e, "player")
	elif boss != null:
		_check_phase2()

func _rotor_down(e: DfPlane, i: int) -> void:
	boss_st.rotors[i] = 0.0
	var h := boss_hub(i)
	fx.explosion(h, 2.4)
	fx.laser_explosion(h)
	score += 300.0
	_shake = maxf(_shake, 1.0)
	Sfx.play("explosion_big", -3.0, 0.0)
	_show_msg("ROTOR DOWN!", 1.1, "+300")
	if e.damage(ROTOR_HULL_DMG):
		_kill_enemy(e, "player")
		return
	_check_phase2()

func _check_phase2() -> void:
	if boss == null or boss_st.get("phase2", false):
		return
	if boss.hp <= boss.max_hp * BOSS_PHASE2_HP or boss_rotors_down() >= 2:
		boss_st.phase2 = true
		_shake = maxf(_shake, 1.4)
		Sfx.play("impact_rumble", -6.0, 0.0)
		_show_msg("PHASE 2", 1.6, "It's enraged: faster cannon, closer orbit")
		Game.say.emit("df_boss_phase2", 2)
		if boss_st.phase == "charge":       # keep the meter where it is on the new, faster clock
			boss_st.charge = minf(float(boss_st.charge), boss_lock_at() - 0.05)

## Beam damage, every frame you are in it: no roll dodge, one hit sound per 0.15 s, a steady
## red flash (not stacked per frame), and a constant shake.
func _beam_hit(v: float) -> void:
	if state == "crash" or state == "over":
		return
	_red_flash = maxf(_red_flash, 0.6)
	_shake = maxf(_shake, 0.5)
	var now := Time.get_ticks_msec()
	if now - int(boss_st.get("snd_ms", 0)) > 150:
		boss_st.snd_ms = now
		Sfx.play("hit", -6.0)
	if player.damage(v):
		_ko_by = "beam"
		_crash()

func _boss_down(e: DfPlane) -> void:
	fx.laser_explosion(e.position)
	for k in 6:
		var j := Vector3(randf_range(-25, 25), randf_range(-10, 15), randf_range(-25, 25))
		fx.blasts.append({"pos": e.position + j, "t": -0.12 * k, "life": 1.2, "size": 5.0 + k * 0.5, "kind": "fire" if k % 2 else "laser"})
	for k in 18:                      # wreckage falls out of the sky
		var a := randf() * TAU
		debris.append({"pos": e.position, "vel": Vector3(cos(a) * randf_range(30, 90), randf_range(20, 90), sin(a) * randf_range(30, 90)),
			"spin": randf() * TAU, "size": randf_range(0.08, 0.22), "trail": PackedVector3Array()})
	score += 2500.0
	_shake = maxf(_shake, 2.0)
	Sfx.play("impact_rumble", -2.0, 0.0)
	_show_msg("BOSS DOWN!", 2.0, "QUAD GUNSHIP destroyed")
	Game.say.emit("df_boss_down", 3)
	Challenges.bump("df_boss")
	boss = null
	boss_st = {}

# =====================================================================
# KO replay + letterbox
# =====================================================================
func _ko_ready() -> bool:
	return Game.df_replays and (demo == "" or demo == "ko" or demo == "boss" or demo == "bossko")

func _begin_replay() -> void:
	if not replay.can_play(float(_ko.t)):
		_show_after_replay()
		return
	_replay_back = state
	state = "replay"
	Engine.time_scale = 1.0
	_slowmo_until = 0
	replay.begin(self, _ko)
	if _ko.get("by", "") == "beam":
		_lb_caption.text = "LASERED BY THE QUAD GUNSHIP"
	elif _ko.kind == "crash":
		_lb_caption.text = "WRECKED · WAVE %d" % maxi(wave, 1)
	elif _ko.get("boss", false):
		_lb_caption.text = "BOSS DOWN · QUAD GUNSHIP"
	else:
		_lb_caption.text = "K.O. · WAVE %d CLEAR" % maxi(wave, 1)
	hud.visible = false
	controls.visible = false
	center_msg.modulate.a = 0.0
	sub_msg.modulate.a = 0.0
	Sfx.loop("boost_loop", false)

func _end_replay() -> void:
	if state != "replay":
		return
	replay.end(self)
	state = _replay_back
	hud.visible = true
	controls.visible = true
	_update_camera(0.0)
	_show_after_replay()

func _show_after_replay() -> void:
	if not _after_replay_msg.is_empty():
		_show_msg(_after_replay_msg[0], _after_replay_msg[1], _after_replay_msg[2])
		_after_replay_msg = []

## Tap anywhere to skip the replay.
func _input(event: InputEvent) -> void:
	if state != "replay":
		return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
		_end_replay()
		get_viewport().set_input_as_handled()

## Bars slide in for the KO slow-mo and the replay, out again after.
func _letterbox(delta: float) -> void:
	if _lb_top == null:
		return
	var want := 1.0 if (state == "replay" or _replay_at >= 0.0) else 0.0
	_lb = move_toward(_lb, want, delta * 3.5)
	var e := _lb * _lb * (3.0 - 2.0 * _lb)
	# KO slow-mo: thin bars (12%). Replay: the bars close to a 2.39:1 strip.
	# Phones: no bars at all, the replay is full screen with a REPLAY tag (PC keeps the film look).
	var phone := Game.is_phone()
	var strip_h := 0.0 if phone else (size.y - size.x / LB_RATIO) * 0.5
	var h := 0.0 if phone else size.y * 0.12 * e
	if state == "replay":
		_lb_strip = move_toward(_lb_strip, 1.0, delta * 2.2)
	else:
		_lb_strip = move_toward(_lb_strip, 0.0, delta * 3.0)
	var se := _lb_strip * _lb_strip * (3.0 - 2.0 * _lb_strip)
	h = lerpf(h, strip_h, se)
	_lb_top.visible = h > 0.5
	_lb_bot.visible = h > 0.5
	_lb_top.position = Vector2.ZERO
	_lb_top.size = Vector2(size.x, h)
	_lb_bot.position = Vector2(0.0, size.y - h)
	_lb_bot.size = Vector2(size.x, h)
	_lb_label.visible = state == "replay"
	_lb_caption.visible = state == "replay" and se > 0.6 and not phone
	_lb_rule_t.visible = _lb_caption.visible
	_lb_rule_b.visible = _lb_caption.visible
	if _lb_label.visible:
		_lb_label.position = Vector2(24.0, 96.0) if phone else Vector2(24.0, h - 44.0)
		_lb_label.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.008)
	_lb_director.visible = _lb_caption.visible and OS.is_debug_build()
	if _lb_director.visible:
		_lb_director.text = replay.director_label()
		_lb_director.position = Vector2(0.0, h - 30.0)
		_lb_director.size = Vector2(size.x - 16.0, 24.0)
	if _lb_caption.visible:
		_lb_caption.modulate.a = clampf((se - 0.6) * 2.5, 0.0, 1.0)
		_lb_caption.position = Vector2(0.0, size.y - h + 18.0)
		_lb_caption.size = Vector2(size.x, 40.0)
		_lb_rule_t.position = Vector2(0.0, h)
		_lb_rule_t.size = Vector2(size.x, 2.0)
		_lb_rule_b.position = Vector2(0.0, size.y - h - 2.0)
		_lb_rule_b.size = Vector2(size.x, 2.0)

# =====================================================================
# End
# =====================================================================
func _finish() -> void:
	state = "over"
	Engine.time_scale = 1.0
	_slowmo_until = 0
	controls.release_all()
	var s := int(score)
	var best := s > Game.df_best_score
	Game.df_best_score = maxi(Game.df_best_score, s)
	Game.df_best_wave = maxi(Game.df_best_wave, waves_cleared)
	var reward := Game.end_minigame(waves_cleared >= 1, 0.5 + 0.5 * waves_cleared)
	Challenges.bump("df_matches")
	Game.say.emit("df_over", 3)
	var txt := "Waves survived: %d\nKOs: %d · Score: %d%s\n%s" % [waves_cleared, takedowns, s, "  NEW BEST!" if best else "", reward]
	finished.emit(txt)

func _on_quit() -> void:
	if state == "over" or state == "idle":
		return
	if _quit_armed > 0.0:
		_quit_armed = 0.0
		if state != "crash":
			_crash()
		_finish()
		return
	_quit_armed = 3.0
	quit_button.text = "SURE?"

func stop() -> void:
	Sfx.loop("boost_loop", false)
	## Called when leaving the screen.
	state = "idle"
	Engine.time_scale = 1.0
	_slowmo_until = 0
	if replay.active:
		replay.end(self)
	_replay_at = -1.0
	shock = {}
	debris.clear()
	ast_glance_t = 0.0
	boss = null
	boss_st = {}
	render.clear()
	world = null
	enemies.clear()
	ships.clear()
	projectiles.clear()

# =====================================================================
# Camera + HUD
# =====================================================================
## Star Fox / Burnout chase cam: close behind and a little above, springy, swings out in
## drifts, the horizon rolls with your bank (After Burner), wider FOV on boost.
## Crash = orbit around the wreck.
func _update_camera(dt: float) -> void:
	_shake = maxf(0.0, _shake - dt * 1.8)
	var shake_v := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 2.5
	if state == "crash":
		_cam_yaw += dt * 0.9
		var cp := _crash_point + Vector3(cos(_cam_yaw) * 70.0, 28.0, sin(_cam_yaw) * 70.0)
		cp.y = maxf(cp.y, world.ground_y(cp) + 6.0)
		render.set_camera(cp + shake_v, _crash_point, 0.0, 70.0)
		return
	var f := player.forward()
	if debug_orbit >= 0.0:   # screenshot orbit: show the nose / visor
		var back := (-f).rotated(Vector3.UP, debug_orbit)
		render.set_camera(player.position + back * 30.0 + Vector3.UP * 6.0, player.position, 0.0, 70.0)
		return
	# 360: the camera's "up" follows the jet's canopy (smoothed), so loops and rolls turn
	# the world around you. The cosmetic bank is followed at 85% (After Burner roll).
	var want_up: Vector3 = (player.basis * Basis(Vector3(0, 0, -1), -player.roll_vis * 0.85)).y
	if player.rolling():
		want_up = _cam_up             # the camera does not spin with a barrel roll: you see the jet roll
	_cam_up = want_up if dt <= 0.0 else _cam_up.slerp(want_up, clampf(dt * 7.0, 0.0, 1.0)).normalized()
	var desired := player.position - f * 34.0 + _cam_up * 7.5
	if player.drift:
		desired += player.vel.normalized().cross(_cam_up) * player.turn * -10.0
	_cam_pos = desired if dt <= 0.0 else _cam_pos.lerp(desired, clampf(dt * (4.0 if player.drift else 9.0), 0.0, 1.0))
	# a lagging camera falls far to the side in a long hard drift (the jet slides off screen):
	# keep it within 28 deg of the spot behind the jet, and at least 30 m away
	var off := _cam_pos - player.position
	var back := desired - player.position
	var ang := off.angle_to(back)
	if ang > 0.49:
		off = back.normalized().slerp(off.normalized(), 0.49 / ang) * off.length()
	_cam_pos = player.position + off.normalized() * maxf(off.length(), 30.0)
	_cam_pos.y = maxf(_cam_pos.y, world.ground_y(_cam_pos) + 3.0)
	var stage := player.boost_stage()
	_cam_fov = lerpf(_cam_fov, BOOST_FOV[stage], clampf(dt * 4.0, 0.0, 1.0))
	if stage == 3:
		_shake = maxf(_shake, 0.12)
	# long hard drifts swing the camera out; look nearer the jet then, so it stays in frame
	_look_ahead = lerpf(_look_ahead, 30.0 if player.drift else 60.0, clampf(dt * 3.0, 0.0, 1.0)) if dt > 0.0 else 60.0
	var look := player.position + f * _look_ahead + _cam_up * 3.0
	if boss != null and boss_st.get("phase", "") == "fire" and state != "crash":
		# the beam is passing close: glance toward it (up to 35%), so you SEE what you dodge
		var bd := boss_beam_dist()
		var gw := clampf(1.0 - (float(bd[0]) - BOSS_BEAM_R) / 140.0, 0.0, 1.0) * 0.35
		if gw > 0.0:
			var d0 := (look - _cam_pos).normalized()
			var d1 := ((bd[1] as Vector3) - _cam_pos).normalized()
			look = _cam_pos + d0.slerp(d1, gw) * 100.0
	if ast_glance_t > 0.0 and weather.asteroid_active:
		# the warning: the camera glances up at the incoming rock (2.4 s, eases in and out),
		# you keep control of the jet the whole time
		var g := ast_glance_t
		var w := smoothstep(0.0, 0.6, g) * smoothstep(2.4, 1.9, g) * 0.75
		var d0 := (look - _cam_pos).normalized()
		var d1 := (weather.asteroid_position() - _cam_pos).normalized()
		look = _cam_pos + d0.slerp(d1, w) * 100.0
	render.set_camera_frame(_cam_pos + shake_v, look, _cam_up, _cam_fov)

## T (2026-11-26): dogfight text "yellow with black outlines and fade faster".
## Messages hold for MSG_TIME of their asked time (min 0.45 s) and fade in the last MSG_FADE s.
const MSG_TIME := 0.65
const MSG_FADE := 0.25
const MSG_YELLOW := Color("ffe14a")

## T: "have enemies remaining in the right side top". Jets + kamikazes + ships + the boss.
## Shown during a wave; pops white and big for a moment when the count drops.
var _left_last := -1
var _left_pop := 0.0
func enemies_left() -> int:
	var n := _ships_alive()
	for e in enemies:
		if e.alive:
			n += 1
	return n

func _update_enemies_left(real: float) -> void:
	if enemies_label == null:
		return
	if rings_label != null:
		rings_label.visible = rings.active() and rings.timer >= 0.0 and state in ["wave", "break", "intro"]
		if rings_label.visible:
			rings_label.text = "RINGS %d/%d · %ds" % [rings.next, DfRings.RINGS, int(ceil(rings.time_left()))]
			rings_label.add_theme_color_override("font_color", Color("ff4b4b") if rings.time_left() < 6.0 else Color("ffd23f"))
	var n := enemies_left()
	enemies_label.visible = state == "wave" and n > 0
	if n < _left_last:
		_left_pop = 0.35
	_left_last = n
	_left_pop = maxf(0.0, _left_pop - real)
	enemies_label.text = "ENEMIES LEFT %d" % n
	var k := _left_pop / 0.35
	enemies_label.add_theme_color_override("font_color", MSG_YELLOW.lerp(Color.WHITE, k))
	enemies_label.pivot_offset = enemies_label.size * Vector2(1.0, 0.5)
	enemies_label.scale = Vector2.ONE * (1.0 + 0.25 * k)

func _show_msg(text: String, time: float, sub := "") -> void:
	center_msg.text = text
	center_msg.modulate.a = 1.0
	sub_msg.modulate.a = 1.0
	_msg_t = maxf(0.45, time * MSG_TIME)
	sub_msg.text = sub

func _update_hud(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	wave_label.text = "WAVE %d" % maxi(wave, 1)
	_update_enemies_left(real)
	score_label.text = "%d" % int(score)
	hp_bar.value = player.hp
	boost_bar.value = player.boost
	_msg_t -= real
	center_msg.modulate.a = clampf(_msg_t / MSG_FADE, 0.0, 1.0)
	sub_msg.modulate.a = 1.0 if sub_msg.text == "LOW FLYING!" else center_msg.modulate.a
	if _msg_t < 0.0 and sub_msg.text != "LOW FLYING!":
		sub_msg.text = ""
	_red_flash = maxf(0.0, _red_flash - real * 2.5)
	_white_flash = maxf(_white_flash, weather.flash_amount() * 0.5)
	_white_flash = maxf(0.0, _white_flash - real * 1.6)
	flash_rect.color = Color(1, 1, 1, _white_flash * 0.7) if _white_flash > _red_flash else Color(0.9, 0.1, 0.1, _red_flash * 0.35)
	%ViewContainer.modulate = weather.cur.tint
	if _quit_armed > 0.0:
		_quit_armed -= real
		if _quit_armed <= 0.0:
			quit_button.text = "QUIT"
	hud.queue_redraw()

## Markers for enemies (brackets on screen, arrows at the edge when off screen).
func _draw_hud() -> void:
	if world == null or state == "idle" or state == "over":
		return
	var rect := Rect2(Vector2.ZERO, hud.size)
	var _center := hud.size * 0.5
	var font := get_theme_default_font()
	var items: Array = []
	for e in enemies:
		if e.alive:
			items.append([e.position, Color("2fa8ff") if e.kind == "boss" else (Color("ff1f4b") if e.kind == "fighter" else Color("ffb000")), 3.0 if e.kind == "boss" else 1.0])
	for s in ships:
		if s.alive:
			items.append([s.pos, Color("d6dde8"), 1.3])
	if weather.asteroid_active:
		items.append([weather.asteroid_position(), Color("ff3c00"), 2.2])
	if rings.active() and rings.next < rings.rings.size():
		items.append([rings.rings[rings.next].pos, Color("ffd23f"), 2.0])   # the next ring
	var volcano_marker := false
	if weather.erupting:
		var vp: Vector3 = world.volcano.pos + Vector3(0, world.volcano.height, 0)
		if not rect.grow(-30.0).has_point(render.world_to_screen(vp) * SHRINK):
			items.append([vp, Color("ff6a00"), 1.0])
			volcano_marker = true
	for it in items:
		var sp: Vector2 = render.world_to_screen(it[0]) * SHRINK
		var col: Color = it[1]
		if rect.grow(-30.0).has_point(sp):
			var pr := render.project(it[0])
			var hsz := clampf(render.focal * SHRINK * 9.0 / maxf(pr.z, 1.0), 10.0, 40.0) * float(it[2])
			draw_bracket(sp, hsz, col)
		else:
			_draw_edge_arrow(it[0], col, rect)
	# T's lock-on reticle: red corner brackets + center dot. On the gun target when
	# locked, else dim at the aim point. Laser ready: red electric sparks on its target.
	if state != "crash":
		var red := Color("ff1f2e")
		if _target_lock != null:
			var tp: Vector3 = _target_lock.pos
			var sp: Vector2 = render.world_to_screen(tp) * SHRINK
			var pr := render.project(tp)
			var hsz := clampf(render.focal * SHRINK * 10.0 / maxf(pr.z, 1.0), 22.0, 48.0)
			draw_reticle(sp, hsz, red)
		else:
			var ap: Vector2 = render.world_to_screen(player.position + player.forward() * 300.0) * SHRINK
			draw_reticle(ap, idle_reticle_size(), Color(red, 0.55))
		if laser_ready() and laser_target != null:
			# cyan armed: every enemy the chain will reach sparks BLUE (normal laser: red)
			var marks: Array = chain_preview if cyan_laser and not chain_preview.is_empty() else [laser_target]
			var mcol := CYAN if cyan_laser else red
			for mk in marks:
				var lp := target_pos(mk)
				var ls: Vector2 = render.world_to_screen(lp) * SHRINK
				var lz := render.project(lp)
				if lz.z > 0.0:
					var lsz := clampf(render.focal * SHRINK * 10.0 / maxf(lz.z, 1.0), 26.0, 52.0) + 6.0
					draw_reticle(ls, lsz, mcol)
					draw_sparks(ls, lsz * 0.85, mcol)
		if cyan_laser and player.alive:      # supercharged: the jet crackles
			var pp := render.project(player.position)
			if pp.z > 0.0:
				var ps: Vector2 = render.world_to_screen(player.position) * SHRINK
				var pr2 := clampf(render.focal * SHRINK * 12.0 / maxf(pp.z, 1.0), 30.0, 90.0)
				hud.draw_circle(ps, pr2 * 0.9, Color(CYAN, 0.08 + 0.05 * sin(Time.get_ticks_msec() * 0.02)))
				draw_sparks(ps, pr2, CYAN)
				draw_sparks(ps + Vector2(randf_range(-pr2, pr2) * 0.4, 0), pr2 * 0.7, Color(0.75, 1.0, 1.0))
	# altimeter: left edge
	var top_y := 150.0
	var bot_y := rect.size.y - 330.0
	hud.draw_rect(Rect2(14, top_y, 10, bot_y - top_y), Color(0, 0, 0, 0.35))
	var g := world.ground_y(player.position)
	var gy := lerpf(bot_y, top_y, clampf(g / CEILING, 0.0, 1.0))
	hud.draw_rect(Rect2(14, gy, 10, bot_y - gy), Color("ffd23f") if g > 0.0 else Color("21b6ff"))
	var py := lerpf(bot_y, top_y, clampf(player.position.y / CEILING, 0.0, 1.0))
	hud.draw_rect(Rect2(8, py - 3, 22, 6), Color("ff6a00"))
	hud.draw_string(font, Vector2(8, top_y - 8), "ALT", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	if boss != null and boss.alive:
		_draw_beam_glow(rect)
		_draw_boss_meters(rect, font)
	if weather.asteroid_active:
		var left := weather.asteroid_time - weather.asteroid_t
		var txt := "ASTEROID  %.1f" % left
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		hud.draw_string(font, Vector2((rect.size.x - tw) / 2.0, 190.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("ff3c00"))

## While the beam fires it is often behind the camera (a good dodge puts the gunship off to
## your side). A blue glow on the screen edge shows where it is; brighter = closer.
func _draw_beam_glow(rect: Rect2) -> void:
	if boss_st.get("phase", "") != "fire":
		return
	var bdg := boss_beam_dist()
	var near: Vector3 = bdg[1]
	var dist: float = bdg[0]
	var k := clampf(1.0 - (dist - BOSS_BEAM_R) / 160.0, 0.0, 1.0)
	if k <= 0.0:
		return
	var p0 := render.project(player.position)
	var p1 := render.project(player.position + (near - player.position).normalized() * 12.0)
	var sd := Vector2(p1.x - p0.x, p1.y - p0.y)
	if p1.z <= 1.0 or sd.length() < 0.01:
		sd = Vector2(-1.0 if randf() < 0.5 else 1.0, 0.0)
	var horiz := absf(sd.x) >= absf(sd.y)
	var depth := (rect.size.x if horiz else rect.size.y) * 0.22
	var fl := 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.05)
	for i in 14:
		var t0 := i / 14.0
		var a := (1.0 - t0) * (1.0 - t0) * 0.55 * k * fl
		var c := Color(0.2, 0.6, 1.0, a)
		var w := depth / 14.0
		var r := Rect2()
		if horiz:
			r = Rect2((t0 * depth) if sd.x < 0.0 else (rect.size.x - (t0 * depth) - w), 0, w + 1, rect.size.y)
		else:
			r = Rect2(0, (t0 * depth) if sd.y < 0.0 else (rect.size.y - (t0 * depth) - w), rect.size.x, w + 1)
		hud.draw_rect(r, c)

## Boss meters, top middle: the name, his hull (red) and his cannon charge (blue).
## The charge bar flashes LOCK! when he locks on and FIRING while the beam is out.
func _draw_boss_meters(rect: Rect2, font: Font) -> void:
	var w := rect.size.x * 0.62
	var x := (rect.size.x - w) * 0.5
	var y := 128.0
	var p2: bool = boss_st.get("phase2", false)
	var name_txt := "QUAD GUNSHIP · ENRAGED" if p2 else "QUAD GUNSHIP"
	var nw := font.get_string_size(name_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var nc := Color(1.0, 0.35 + 0.3 * sin(Time.get_ticks_msec() * 0.012), 0.35) if p2 else Color.WHITE
	hud.draw_string(font, Vector2((rect.size.x - nw) * 0.5, y), name_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, nc)
	y += 8.0
	var hpk := clampf(boss.hp / boss.max_hp, 0.0, 1.0)
	hud.draw_rect(Rect2(x - 3, y - 3, w + 6, 22), Color(0, 0, 0, 0.6))
	hud.draw_rect(Rect2(x, y, w, 16), Color("3a0d18"))
	hud.draw_rect(Rect2(x, y, w * hpk, 16), Color("ff2e4a"))
	hud.draw_rect(Rect2(x, y, w * hpk, 4), Color("ff8fa0"))
	hud.draw_line(Vector2(x + w * BOSS_PHASE2_HP, y - 2), Vector2(x + w * BOSS_PHASE2_HP, y + 18), Color(1, 1, 1, 0.45), 1.0)
	for i in 4:                          # rotor pips, right of the hull bar: cyan = up, red X = down
		var rp := Vector2(x + w + 10.0 + (i % 2) * 14.0, y - 2.0 + (1 - i / 2) * 10.0)
		var up: bool = float(boss_st.rotors[i]) > 0.0
		hud.draw_rect(Rect2(rp, Vector2(10, 8)), Color("2fa8ff") if up else Color("5a1020"))
		if not up:
			hud.draw_line(rp, rp + Vector2(10, 8), Color("ff2e4a"), 2.0)
			hud.draw_line(rp + Vector2(0, 8), rp + Vector2(10, 0), Color("ff2e4a"), 2.0)
	y += 22.0
	var ch: float = boss_st.get("charge", 0.0)
	var phase: String = boss_st.get("phase", "charge")
	var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
	var cc := Color("2fa8ff")
	if phase == "lock":
		cc = Color("2fa8ff").lerp(Color.WHITE, blink * 0.7)
	elif phase == "fire":
		cc = Color("9df4ff")
	hud.draw_rect(Rect2(x - 3, y - 3, w + 6, 14), Color(0, 0, 0, 0.6))
	hud.draw_rect(Rect2(x, y, w, 8), Color("0d2340"))
	hud.draw_rect(Rect2(x, y, w * (1.0 if phase == "fire" else ch), 8), cc)
	hud.draw_line(Vector2(x + w * boss_lock_at(), y - 2), Vector2(x + w * boss_lock_at(), y + 10), Color(1, 1, 1, 0.6), 1.0)
	var tag := "CANNON"
	var tagc := Color("7fd0ff")
	if phase == "lock":
		tag = "LOCK!"
		tagc = Color(1, 1, 1, 0.5 + 0.5 * blink)
	elif phase == "fire":
		tag = "FIRING"
		tagc = Color("9df4ff")
	hud.draw_string(font, Vector2(x, y + 26), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, tagc)

## Off-screen marker: an arrow that slides around the screen border and points at the
## enemy. Direction comes from camera space, so enemies behind you still point the right way.
const ARROW_MARGIN := Vector4(26.0, 118.0, 26.0, 40.0)   # left, top, right, bottom (px)

func _draw_edge_arrow(pos: Vector3, col: Color, rect: Rect2) -> void:
	var v: Vector3 = pos - render.cam_pos
	var dir := Vector2(v.dot(render.cam_right), -v.dot(render.cam_up))
	if v.dot(render.cam_fwd) < 0.0 and dir.length() < v.length() * 0.35:
		dir.y = absf(dir.y) + v.length() * 0.35       # nearly straight behind: bottom edge
	if dir.length() < 0.001:
		dir = Vector2.DOWN
	dir = dir.normalized()
	var inner := Rect2(rect.position + Vector2(ARROW_MARGIN.x, ARROW_MARGIN.y),
		rect.size - Vector2(ARROW_MARGIN.x + ARROW_MARGIN.z, ARROW_MARGIN.y + ARROW_MARGIN.w))
	var c := inner.get_center()
	var tx := (inner.size.x * 0.5) / maxf(absf(dir.x), 0.0001)
	var ty := (inner.size.y * 0.5) / maxf(absf(dir.y), 0.0001)
	var p := c + dir * minf(tx, ty)
	var dist := pos.distance_to(player.position)
	var s := clampf(1.6 - dist / 1200.0, 0.8, 1.5)
	if col == Color("ffb000") and dist < 450.0:            # kamikaze close: pulse
		s *= 1.0 + 0.25 * sin(Time.get_ticks_msec() * 0.02)
	var side := dir.orthogonal()
	var tri := PackedVector2Array([p + dir * 16.0 * s, p - dir * 9.0 * s + side * 11.0 * s, p - dir * 9.0 * s - side * 11.0 * s])
	hud.draw_colored_polygon(tri, Color("1a0f2e"))
	var small := PackedVector2Array()
	for q in tri:
		small.append(p + (q - p) * 0.72)
	hud.draw_colored_polygon(small, col)

## Half-size (screen px) of the dim aim reticle: the gun cone on screen / RETICLE_TO_CONE,
## so a target inside the brackets always locks, with a little room to spare.
func idle_reticle_size() -> float:
	return clampf(render.focal * SHRINK * tan(GUN_CONE) / RETICLE_TO_CONE, 20.0, RETICLE_MAX)

func draw_reticle(c: Vector2, h: float, col: Color) -> void:
	var l := h * 0.5
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := c + Vector2(sx * h, sy * h)
			hud.draw_line(corner, corner - Vector2(sx * l, 0), col, 5.0)
			hud.draw_line(corner, corner - Vector2(0, sy * l), col, 5.0)
	hud.draw_circle(c, 5.0, col)

## Electric sparks inside the reticle (new random bolts every frame).
func draw_sparks(c: Vector2, r: float, col: Color) -> void:
	for k in 4:
		var a := randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * randf_range(0.0, r * 0.4)
		var pts := PackedVector2Array([p])
		for i in 4:
			a += randf_range(-1.2, 1.2)
			p += Vector2(cos(a), sin(a)) * r * 0.22
			pts.append(p)
		hud.draw_polyline(pts, Color(1, 1, 1, 0.9) if k == 0 else col, 2.0)

func draw_bracket(c: Vector2, h: float, col: Color) -> void:
	var l := h * 0.45
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := c + Vector2(sx * h, sy * h)
			hud.draw_line(corner, corner - Vector2(sx * l, 0), col, 2.0)
			hud.draw_line(corner, corner - Vector2(0, sy * l), col, 2.0)
