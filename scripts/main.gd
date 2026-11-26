extends Control
## Main screen controller. Layout lives in scenes/main.tscn.
## This script: theme, page switching, list building, effects, debug hooks.

const BuildingRowScene := preload("res://scenes/building_row.tscn")
const ManagerBoxScene := preload("res://scenes/manager_box.tscn")
const PAGES := ["Bones", "Schemes", "Wardrobe", "Stash", "Play", "Fold"]
const PAGE_PLAY := 4
const PAGE_FOLD := 5

var ui := UiTheme.new()
var rows: Array = []
var nav_buttons: Array = []
var _slow_timer := 0.0
var _confirm := {}          # button -> seconds left in "tap again" state
var _scheme_buttons := {}   # scheme id -> Button
var _costume_buttons := {}  # costume id -> Button
var _item_widgets := {}     # item id -> {buy, equip, gift, count}
var _rebury_widgets := {}
var manager_box: PanelContainer
var _scene_queue: Array = []   # [i, tier] waiting for the manager box

@onready var pages: Array = [%BuildingsPage, %SchemesPage, %WardrobePage, %StashPage, %PlayPage, %ReburyPage]
var in_minigame := false
var _play_widgets := {}
var _popup_action := Callable()
var challenges_page: VBoxContainer
var blackjack_page: VBoxContainer
var holdem_page: VBoxContainer
var challenges_open := false
var art_viewer: Control
var challenges_button: Button
var auto_open_challenges := true   # tests switch this off
var _last_page := 0
var _challenge_wait := 0.0
var _wardrobe_tints: VBoxContainer

func _ready() -> void:
	theme = ui.build()
	%Bg.color = ui.pal.bg
	manager_box = ManagerBoxScene.instantiate()
	manager_box.add_to_group("manager_box")
	%FxLayer.add_child(manager_box)
	manager_box.scene_finished.connect(_on_scene_finished)
	get_tree().node_added.connect(_touch_scroll_fix)
	for n in find_children("*", "Control", true, false):
		_touch_scroll_fix(n)
	_build_nav()
	_build_buildings()
	_build_schemes()
	_build_wardrobe()
	_build_stash()
	_build_rebury()
	_build_play()
	_build_challenges()
	blackjack_page = preload("res://scripts/cards/blackjack_page.gd").new()
	blackjack_page.visible = false
	blackjack_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	%Pages.add_child(blackjack_page)
	blackjack_page.left_table.connect(func():
		set_minigame_mode(false)
		show_page(PAGE_PLAY))
	holdem_page = preload("res://scripts/cards/holdem_page.gd").new()
	holdem_page.visible = false
	holdem_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	%Pages.add_child(holdem_page)
	holdem_page.left_table.connect(func():
		set_minigame_mode(false)
		show_page(PAGE_PLAY))
	%PoolPage.finished.connect(_on_pool_finished)
	%DogfightPage.finished.connect(_on_dogfight_finished)
	_connect_signals()
	_refresh_top_static()
	_refresh_stage_labels()
	if Game.fever_active:
		_on_fever_mode(true)
	%PopupButton.pressed.connect(_on_popup_button)
	if Game.pending_offline.x > 0.0:
		_show_offline(Game.pending_offline.x, Game.pending_offline.y)
		Game.say.emit("welcome_back", 3)
	else:
		Game.say.emit("hello", 3)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_debug_setup()

func _connect_signals() -> void:
	%DialogueBox.line_started.connect(%Portrait.set_expression)
	%BuyModeButton.pressed.connect(func(): Game.cycle_buy_mode(); _refresh_buy_mode())
	_refresh_buy_mode()
	Game.marrow_changed.connect(_refresh_top_static)
	Game.rank_changed.connect(func(_r): _refresh_top_static(); _flash_screen())
	Game.run_reset.connect(_on_run_reset)
	Game.fever_mode_changed.connect(_on_fever_mode)
	Game.costume_changed.connect(_refresh_stage_labels)
	Game.inventory_changed.connect(_refresh_stage_labels)
	Game.schemes_changed.connect(_build_schemes)
	Game.taste_test.connect(_on_taste_test)
	Game.floating.connect(_on_floating)
	Game.offline_earned.connect(_show_offline)
	Game.building_changed.connect(func(_i): _update_row_visibility())
	Game.manager_scene.connect(_on_manager_scene)
	Game.reburied.connect(_on_reburied)
	Game.level_changed.connect(func(_l): _flash_level())
	Challenges.changed.connect(_refresh_challenge_button)
	Challenges.cosmetic_changed.connect(func(): _build_tints(); _refresh_play())

# =====================================================================
# Per frame
# =====================================================================
var _play_tick := 0.0

func _process(delta: float) -> void:
	_play_tick -= delta
	if _play_tick <= 0.0:
		_play_tick = 5.0
		if Game.table_away.has("cadavire"):
			_refresh_play()           # the Hold'em countdown on the Play page
	%BonesLabel.text = Fmt.num(Game.bones)
	var rate := Game.income_per_sec()
	%RateLabel.text = "+%s /s%s" % [Fmt.num(rate), "   FEVER x2 · -25% cost" if Game.fever_active else ""]
	if manager_box.visible:   # keep the 2nd slot glued under the stage
		manager_box.position.y = %Stage.get_global_rect().end.y + 6.0
	%FeverBar.value = Game.fever
	%LevelLabel.text = "LV %d" % Game.level()
	%LevelBar.value = Game.level_progress()
	%LevelPct.text = "%.2f%%" % (Game.level_progress() * 100.0)
	if Game.fever_active:
		%FeverLabel.text = Fmt.time(Game.fever_left)
	else:
		%FeverLabel.text = "%d%%" % int(Game.fever)
	if %BuildingsPage.visible:
		for r in rows:
			if r.visible:
				r.tick()
	for b in _confirm.keys():
		_confirm[b] -= delta
		if _confirm[b] <= 0.0:
			_confirm.erase(b)
	_slow_timer -= delta
	if _slow_timer <= 0.0:
		_slow_timer = 0.2
		_slow_refresh()

## 5x per second: affordability on the non-building pages.
func _slow_refresh() -> void:
	var ns := Game.next_scheme()
	%NextSchemeLabel.text = "" if ns.is_empty() else "next scheme %s" % Fmt.num(Game.scheme_price(ns))
	var scheme_ready := false
	for s in Game.scheme_list():
		if _scheme_buttons.has(s.id):
			var can: bool = Game.bones >= Game.scheme_price(s)
			_scheme_buttons[s.id].disabled = not can
			_scheme_buttons[s.id].text = Fmt.num(Game.scheme_price(s))
			scheme_ready = scheme_ready or can
	_set_nav_badge(1, scheme_ready)
	for id in _costume_buttons:
		_refresh_costume_button(id)
	for id in _item_widgets:
		_refresh_item(id)
	_refresh_rebury()
	_refresh_play()
	_auto_open_challenges()

# =====================================================================
# Navigation
# =====================================================================
func _build_nav() -> void:
	var group := ButtonGroup.new()
	for i in PAGES.size():
		var b := Button.new()
		b.text = PAGES[i]
		b.toggle_mode = true
		b.button_group = group
		b.theme_type_variation = "NavButton"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(show_page.bind(i))
		%NavButtons.add_child(b)
		nav_buttons.append(b)
	nav_buttons[0].button_pressed = true

func show_page(i: int) -> void:
	if in_minigame:
		return
	if challenges_open:
		_close_challenges_view()
	_last_page = i
	for p in pages.size():
		pages[p].visible = p == i
	nav_buttons[i].button_pressed = true
	_slow_refresh()

## Touch scrolling (web/iPhone bug, 2026-11-26): a Control that STOPs input eats the
## finger drag, so a list only scrolled when you touched an empty gap. Every card,
## button and row inside a ScrollContainer now PASSes input up. Godot still treats a
## short tap as a press, and a drag past the scroll deadzone cancels the press.
func _touch_scroll_fix(n: Node) -> void:
	if not (n is Control) or n is ScrollContainer or n is ScrollBar:
		return
	if (n as Control).mouse_filter != Control.MOUSE_FILTER_STOP:
		return
	var p := n.get_parent()
	while p != null:
		if p is ScrollContainer:
			(n as Control).mouse_filter = Control.MOUSE_FILTER_PASS
			return
		p = p.get_parent()

func _set_nav_badge(i: int, on: bool) -> void:
	nav_buttons[i].text = PAGES[i] + (" •" if on else "")

# =====================================================================
# Buildings
# =====================================================================
func _build_buildings() -> void:
	for i in Balance.BUILDINGS.size():
		var r = BuildingRowScene.instantiate()
		r.setup(i)
		%BuildingList.add_child(r)
		rows.append(r)
	_update_row_visibility()

## Show owned buildings + the next 2 you do not own yet.
func _update_row_visibility() -> void:
	var highest := 0
	for i in Balance.BUILDINGS.size():
		if Game.owned[i] > 0:
			highest = i
	for i in rows.size():
		rows[i].visible = i <= highest + 2

func _refresh_buy_mode() -> void:
	%BuyModeButton.text = "BUY " + Game.BUY_MODE_NAMES[Game.buy_mode_idx]

# =====================================================================
# Small UI helpers
# =====================================================================
func _card(parent: Node, hi := false) -> VBoxContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "CardHi" if hi else "Card"
	parent.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	return v

func _label(parent: Node, text: String, variation := "", wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 100
	parent.add_child(l)
	return l

func _button(parent: Node, text: String, cb: Callable, ghost := false, min_w := 170.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 56)
	if ghost:
		b.theme_type_variation = "GhostButton"
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

## Two-tap confirm for destructive buttons. Returns true on the 2nd tap.
func _confirmed(b: Button, prompt: String) -> bool:
	if _confirm.has(b):
		_confirm.erase(b)
		return true
	_confirm[b] = 3.0
	b.text = prompt
	return false

# =====================================================================
# Schemes page
# =====================================================================
func _build_schemes() -> void:
	_clear(%SchemeList)
	_scheme_buttons.clear()
	var done := 0
	var shown := 0
	_label(%SchemeList, "One-time bone laundering. Each scheme triples income. Schemes reset when you Fold.", "MutedLabel", true)
	for s in Game.scheme_list():
		if Game.schemes.has(s.id):
			done += 1
			continue
		if shown >= 12:
			continue
		shown += 1
		var c := _card(%SchemeList)
		var h := HBoxContainer.new()
		c.add_child(h)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		_label(info, s.name, "TitleLabel", true)
		var target: String = "ALL buildings" if s.target < 0 else Balance.BUILDINGS[s.target].name
		_label(info, "x3 %s" % target, "AccentLabel", true)
		var b := _button(h, Fmt.num(Game.scheme_price(s)), func(): Game.buy_scheme(s.id))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_scheme_buttons[s.id] = b
	_label(%SchemeList, "%d / %d schemes done" % [done, Game.scheme_list().size()], "MutedLabel")

# =====================================================================
# Wardrobe page (Marrow costumes)
# =====================================================================
func _build_wardrobe() -> void:
	_clear(%CostumeList)
	_costume_buttons.clear()
	_label(%CostumeList, "Costumes cost Marrow and are yours forever. What she wears changes how bones grow.", "MutedLabel", true)
	for c in Balance.COSTUMES:
		var v := _card(%CostumeList, c.id == "caveman")
		var h := HBoxContainer.new()
		v.add_child(h)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		_label(info, c.name, "TitleLabel", true)
		_label(info, c.desc, "SmallLabel", true)
		var id: String = c.id
		var b := _button(h, "", func(): _on_costume_pressed(id))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_costume_buttons[id] = b
		_refresh_costume_button(id)
	_wardrobe_tints = VBoxContainer.new()
	%CostumeList.add_child(_wardrobe_tints)
	_build_tints()

## Tints = Challenges prizes. A color overlay on top of any outfit.
func _build_tints() -> void:
	if _wardrobe_tints == null:
		return
	_clear(_wardrobe_tints)
	var v := _card(_wardrobe_tints)
	_label(v, "TINTS", "NamePlate")
	var owned := Challenges.owned_of_type("tint")
	if owned.is_empty():
		_label(v, "Tints recolor her on top of any outfit. Win them on the Challenges wall.", "MutedLabel", true)
		return
	_label(v, "A tint recolors her on top of the outfit she wears.", "MutedLabel", true)
	for rid in owned:
		var h := HBoxContainer.new()
		v.add_child(h)
		var sw := ColorRect.new()
		sw.color = Color(String(Challenges.rewards[rid].color))
		sw.custom_minimum_size = Vector2(44, 44)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(sw)
		var l := _label(h, String(Challenges.rewards[rid].name).trim_prefix("Tint: "), "TitleLabel")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var on: bool = Challenges.tint == rid
		var r: String = rid
		_button(h, "REMOVE" if on else "WEAR", func():
			Challenges.set_tint("" if Challenges.tint == r else r)
			if Challenges.tint != "":
				Game.say.emit("tint_wear", 3), on, 150)

func _on_costume_pressed(id: String) -> void:
	if Game.costumes_owned.has(id):
		Game.wear(id)
	else:
		Game.buy_costume(id)
	_slow_refresh()

func _refresh_costume_button(id: String) -> void:
	var b: Button = _costume_buttons[id]
	var c := Balance.costume(id)
	if Game.costume == id:
		b.text = "WEARING"
		b.disabled = true
	elif Game.costumes_owned.has(id):
		b.text = "WEAR"
		b.disabled = false
	elif not Game.costume_unlocked(id):
		b.text = "RANK %d" % c.rank
		b.disabled = true
	else:
		b.text = "%d MARROW" % c.price
		b.disabled = Game.marrow < c.price

# =====================================================================
# Stash page (items: equip or gift)
# =====================================================================
func _build_stash() -> void:
	_clear(%ItemList)
	_item_widgets.clear()
	_label(%ItemList, "EQUIP one item for a hidden boost (it never shows on her outfit). GIFT an item to use it up: big Fever, and she reacts.", "MutedLabel", true)
	for it in Balance.ITEMS:
		var id: String = it.id
		var v := _card(%ItemList)
		var top := HBoxContainer.new()
		v.add_child(top)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(info)
		_label(info, it.name, "TitleLabel", true)
		_label(info, "Equip: " + it.equip_desc, "SmallLabel", true)
		_label(info, "Gift: +%d Fever" % int(it.gift_fever), "AccentLabel")
		var count := _label(top, "x0", "TitleLabel")
		var btns := HBoxContainer.new()
		v.add_child(btns)
		var buy := _button(btns, "", func(): Game.buy_item(id); _refresh_item(id), false, 0)
		buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var equip := _button(btns, "EQUIP", func(): _on_equip(id), true, 130)
		var gift := _button(btns, "GIFT", func(): Game.gift(id); _refresh_item(id), true, 130)
		_item_widgets[id] = {"buy": buy, "equip": equip, "gift": gift, "count": count}
		_refresh_item(id)

func _on_equip(id: String) -> void:
	if Game.equipped == id:
		Game.unequip()
	else:
		Game.equip(id)
	_refresh_item(id)

func _refresh_item(id: String) -> void:
	var w: Dictionary = _item_widgets[id]
	var n := Game.item_count(id)
	var price := Game.item_price(id)
	w.count.text = "x%d" % n
	w.buy.text = "BUY  " + Fmt.num(price)
	w.buy.disabled = Game.bones < price
	w.equip.text = "UNEQUIP" if Game.equipped == id else "EQUIP"
	w.equip.disabled = n <= 0
	w.gift.disabled = n <= 0

# =====================================================================
# Fold page (internal name: rebury)
# =====================================================================
func _build_rebury() -> void:
	_clear(%ReburyBox)
	var r := _card(%ReburyBox)
	_label(r, "PRESTIGE RANK", "NamePlate")
	_rebury_widgets.rank = _label(r, "", "TitleLabel", true)
	_rebury_widgets.rank_next = _label(r, "", "SmallLabel", true)
	var lvc := _card(%ReburyBox)
	_label(lvc, "LEVEL", "NamePlate")
	_rebury_widgets.level = _label(lvc, "", "SmallLabel", true)
	var d := _card(%ReburyBox)
	_label(d, "GHOUL LOYALTY", "NamePlate")
	_label(d, "Every manager you had hired moves up 1 loyalty tier when you Fold. The bonus is permanent. Rehire them to hear what they think.", "MutedLabel", true)
	_rebury_widgets.loyalty = _label(d, "", "SmallLabel", true)
	var rb := _card(%ReburyBox, true)
	_label(rb, "FOLD", "NamePlate")
	_label(rb, "Fold the business and start over. You KEEP: Marrow, costumes, items, rank, level, ghoul loyalty. You LOSE: bones, buildings, managers, schemes.", "SmallLabel", true)
	_rebury_widgets.gain = _label(rb, "", "TitleLabel", true)
	_rebury_widgets.next = _label(rb, "", "MutedLabel", true)
	var b := _button(rb, "", _on_rebury_pressed)
	_rebury_widgets.button = b
	var sc := _card(%ReburyBox)
	_label(sc, "SETTINGS", "NamePlate")
	var snd := _button(sc, "SOUND: ON" if Game.sfx_on else "SOUND: OFF", func(): pass, true)
	snd.pressed.connect(func():
		Game.sfx_on = not Game.sfx_on
		if not Game.sfx_on:
			Sfx.stop_loops()
		snd.text = "SOUND: ON" if Game.sfx_on else "SOUND: OFF"
		Game.save_game())
	_rebury_widgets.sound = snd
	var w := _card(%ReburyBox)
	_label(w, "DEBUG", "NamePlate")
	var wipe := _button(w, "WIPE SAVE", func(): pass, true)
	wipe.pressed.connect(func():
		if _confirmed(wipe, "TAP AGAIN TO WIPE"):
			Game.wipe_save()
			Game.autosave_enabled = false
			get_tree().quit())
	_rebury_widgets.wipe = wipe
	_refresh_rebury()

func _on_rebury_pressed() -> void:
	var b: Button = _rebury_widgets.button
	if Game.rebury_gain() < 1:
		return
	if _confirmed(b, "TAP AGAIN TO FOLD"):
		Game.rebury()

func _refresh_rebury() -> void:
	var w := _rebury_widgets
	if w.is_empty():
		return
	w.rank.text = "%s  (rank %d)  ·  +%d%% income" % [Balance.RANK_NAMES[Game.rank], Game.rank, int(Game.rank * Balance.RANK_INCOME_BONUS * 100)]
	if Game.rank < Balance.RANK_THRESHOLDS.size():
		w.rank_next.text = "Next rank: own %d of EVERY building. Your lowest: %d. First time only, never lost." % [Balance.RANK_THRESHOLDS[Game.rank], Game.owned.min()]
	else:
		w.rank_next.text = "Max rank."
	w.level.text = "Level %d (%.2f%% to next). Fed by every bone you earn. Never lost when you Fold. Only the endgame resets it." % [Game.level(), Game.level_progress() * 100.0]
	var lines: Array = []
	for i in Balance.BUILDINGS.size():
		var lv: int = Game.loyalty[i]
		if lv == 0:
			lines.append("???  (hire to meet)")
			continue
		var t := "%s   L%d/%d   x%s" % [Balance.BUILDINGS[i].manager, lv, Balance.LOYALTY_MAX, Fmt.mult(Game.loyalty_mult(i))]
		if Game.scenes_seen[i] >= Balance.LOYALTY_MAX:
			t += "   · " + manager_box.db.get(Balance.BUILDINGS[i].id, {}).get("motive", "?")
		lines.append(t)
	w.loyalty.text = "\n".join(lines)
	var g := Game.rebury_gain()
	w.gain.text = "+%d Marrow if you fold now" % g
	var need := pow(float(g + 1), 2.0) * Balance.REBURY_DIVISOR
	w.next.text = "Bones this run: %s. Next Marrow at %s." % [Fmt.num(Game.run_bones), Fmt.num(need)]
	if not _confirm.has(w.button):
		w.button.text = "FOLD  +%d" % g
	w.button.disabled = g < 1
	if not _confirm.has(w.wipe):
		w.wipe.text = "WIPE SAVE"

# =====================================================================
# Play page (minigames)
# =====================================================================
func _build_play() -> void:
	_clear(%PlayList)
	_play_widgets.clear()
	# ---- home screen: one tap = play (T: "condense play into an app icon screen basically")
	var home := VBoxContainer.new()
	home.add_theme_constant_override("separation", 14)
	%PlayList.add_child(home)
	_play_widgets.home = home
	var hint := _label(home, "Skill games pay bones + Fever. Marrow bets only at the card table.", "MutedLabel", true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cc := CenterContainer.new()
	home.add_child(cc)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 6)
	cc.add_child(grid)
	_play_widgets.start = _play_icon(grid, "pool", "Pool", func(): start_pool())
	_play_widgets.df_start = _play_icon(grid, "dogfight", "Dogfight", func(): start_dogfight())
	_play_widgets.cards_start = _play_icon(grid, "blackjack", "Blackjack", func(): start_cards())
	_play_widgets.holdem_start = _play_icon(grid, "holdem", "Hold'em", func(): start_holdem())
	_play_widgets.pinball = _play_icon(grid, "pinball", "Pinball", func(): pass)
	_play_widgets.pinball.disabled = true
	_play_widgets.options = _play_icon(grid, "options", "Options", func(): _show_play_options(true))
	_play_widgets.df_best = _label(home, "", "AccentLabel", true)
	_play_widgets.df_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play_widgets.bet_short = _label(home, "", "SmallLabel", true)
	_play_widgets.bet_short.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# ---- options sheet (the settings that used to make this page scroll)
	var opts := VBoxContainer.new()
	opts.visible = false
	%PlayList.add_child(opts)
	_play_widgets.opts = opts
	var back := _button(opts, "< PLAY", func(): _show_play_options(false), true, 170)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var v := _card(opts, true)
	_label(v, "DOGFIGHT", "NamePlate")
	var jh := HBoxContainer.new()
	v.add_child(jh)
	_play_widgets.jet_name = _label(jh, "", "SmallLabel", true)
	_play_widgets.jet_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_widgets.jet_btn = _button(jh, "CHANGE JET", func(): _cycle_cosmetic("ship"), true, 170)
	var ah := HBoxContainer.new()
	v.add_child(ah)
	_play_widgets.assist_lbl = _label(ah, "", "SmallLabel", true)
	_play_widgets.assist_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_widgets.assist_btn = _button(ah, "ASSIST", func():
		Game.df_assist = not Game.df_assist
		Game.save_game()
		_refresh_play(), true, 170)
	var rh := HBoxContainer.new()
	v.add_child(rh)
	var rl := _label(rh, "Replay the KO: the kill that clears a wave, or your crash. Tap to skip.", "SmallLabel", true)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_widgets.replay_btn = _button(rh, "KO REPLAY", func():
		Game.df_replays = not Game.df_replays
		Game.save_game()
		_refresh_play(), true, 170)
	_label(v, "Steer with the stick. Guns fire by themselves. Drift, then let go to boost. Double-tap the stick (Q / E on PC) to barrel roll.", "MutedLabel", true)
	var c := _card(opts)
	_label(c, "CARD TABLE", "NamePlate")
	var th := HBoxContainer.new()
	c.add_child(th)
	_play_widgets.table_swatch = Control.new()
	_play_widgets.table_swatch.custom_minimum_size = Vector2(96, 56)
	_play_widgets.table_swatch.draw.connect(_draw_table_swatch)
	th.add_child(_play_widgets.table_swatch)
	_play_widgets.table_name = _label(th, "", "SmallLabel", true)
	_play_widgets.table_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_widgets.table_btn = _button(th, "CHANGE", func(): _cycle_cosmetic("table"), true, 130)
	_play_widgets.bet_info = _label(c, "", "MutedLabel", true)
	var pc := _card(opts)
	_label(pc, "POOL", "NamePlate")
	_play_widgets.pool_desc = _label(pc, "", "SmallLabel", true)
	_refresh_play()

func _play_icon(parent: Node, kind: String, title: String, cb: Callable) -> PlayIcon:
	var b := PlayIcon.new().setup(kind, title)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _show_play_options(on: bool) -> void:
	_play_widgets.home.visible = not on
	_play_widgets.opts.visible = on
	%PlayPage.scroll_vertical = 0

func _refresh_play() -> void:
	if _play_widgets.is_empty():
		return
	var prof := PoolAI.profile()
	var style: String = {"normal": "a solid player", "precise": "very precise (Lab Coat)", "SMASH": "wild and VERY strong (Cave-Gal Pelt)",
		"regal": "elegant and accurate (Regal Decay)"}.get(prof.name, "a solid player")
	_play_widgets.pool_desc.text = "You: solids. She: stripes. You break. Pocket your 7, then the 8. She plays in her current outfit, so today she is %s%s." % [
		style, ", and too excited to aim well (Fever)" if Game.fever_active else ""]
	if _play_widgets.has("df_best"):
		_play_widgets.df_best.text = ("Dogfight best: wave %d · %d points" % [Game.df_best_wave, Game.df_best_score]) if Game.df_best_wave > 0 else "Dogfight pays bones for every wave you survive."
		_play_widgets.df_start.set_state(("W%d" % Game.df_best_wave) if Game.df_best_wave > 0 else "", "")
		_play_widgets.assist_btn.text = "ASSIST: ON" if Game.df_assist else "ASSIST: OFF"
		_play_widgets.assist_lbl.text = "Wings level themselves when you let go." if Game.df_assist else "Expert: the jet holds any attitude, even upside down."
		_play_widgets.replay_btn.text = "KO REPLAY: ON" if Game.df_replays else "KO REPLAY: OFF"
	var bets: Array = []
	for r in Game.MAX_BET_BY_RANK.size():
		bets.append("rank %d: %d" % [r, Game.MAX_BET_BY_RANK[r]])
	if _play_widgets.has("jet_name"):
		var ships := Challenges.owned_of_type("ship")
		_play_widgets.jet_name.text = "Jet: " + ("Bone Ace (default)" if Challenges.ship == "" else String(Challenges.rewards[Challenges.ship].name).trim_prefix("Jet: "))
		_play_widgets.jet_btn.visible = not ships.is_empty()
	if _play_widgets.has("table_name"):
		_play_widgets.table_name.text = "Table: " + ("Green felt (default)" if Challenges.table == "" else String(Challenges.rewards[Challenges.table].name).trim_prefix("Table: "))
		_play_widgets.table_btn.visible = not Challenges.owned_of_type("table").is_empty()
		_play_widgets.table_swatch.queue_redraw()
	_play_widgets.bet_info.text = "Max bet by prestige rank: " + ", ".join(bets) + ". Your max now: %d." % Game.max_bet()
	var cap: int = Game.MAX_BET_BY_RANK[clampi(Game.rank, 0, Game.MAX_BET_BY_RANK.size() - 1)]
	_play_widgets.bet_short.text = "Card table: bet up to %d Marrow at rank %d (you have %d)" % [cap, Game.rank, Game.marrow]
	_play_widgets.pinball.set_state("SOON", "")
	var shut := Game.away_left("cadavire") > 0.0
	_play_widgets.holdem_start.set_state("", ("Closed " + holdem_page.away_text("cadavire")) if shut else "")
	_play_widgets.holdem_start.disabled = shut

## Default -> each owned prize -> default.
func _cycle_cosmetic(kind: String) -> void:
	var list: Array = [""] + Challenges.owned_of_type(kind)
	var cur: String = Challenges.ship if kind == "ship" else Challenges.table
	var nxt: String = list[(list.find(cur) + 1) % list.size()]
	if kind == "ship":
		Challenges.set_ship(nxt)
	else:
		Challenges.set_table(nxt)
	_refresh_play()

func _draw_table_swatch() -> void:
	var sw: Control = _play_widgets.table_swatch
	var tc := Challenges.table_colors()
	var r := Rect2(Vector2(0, 4), sw.size - Vector2(0, 8))
	sw.draw_rect(r, tc.rim)
	sw.draw_rect(r.grow(-7), tc.felt)

func set_minigame_mode(on: bool, which := "pool") -> void:
	in_minigame = on
	%TopBar.visible = not on
	%NavBar.visible = not on
	%Portrait.custom_minimum_size = Vector2(150, 190) if on else Vector2(250, 330)
	%CostumeLabel.visible = not on
	%EquipLabel.visible = not on
	for p in pages:
		p.visible = false
	%PoolPage.visible = on and which == "pool"
	%DogfightPage.visible = on and which == "dogfight"
	if blackjack_page:
		blackjack_page.visible = on and which == "cards"
	if holdem_page:
		holdem_page.visible = on and which == "holdem"
	%Portrait.set_override("pilot" if on and which == "dogfight" else "")

func start_pool(seed_value := -1) -> bool:
	if in_minigame:
		return false
	Game.start_minigame()
	set_minigame_mode(true)
	%PoolPage.start(seed_value)
	return true

func start_dogfight(seed_value := -1) -> bool:
	if in_minigame:
		return false
	Game.start_minigame()
	set_minigame_mode(true, "dogfight")
	%DogfightPage.start(seed_value)
	return true

## The card table (blackjack). Marrow is bet per hand inside the table.
func start_cards(seed_value := -1) -> bool:
	if in_minigame:
		return false
	set_minigame_mode(true, "cards")
	blackjack_page.open(seed_value)
	return true

func start_holdem(seed_value := -1) -> bool:
	if in_minigame:
		return false
	set_minigame_mode(true, "holdem")
	holdem_page.open(seed_value)
	return true

func _on_dogfight_finished(result_text: String) -> void:
	%PopupTitle.text = "Dogfight over"
	%PopupText.text = result_text
	%PopupButton.text = "BACK"
	_popup_action = func():
		%DogfightPage.stop()
		set_minigame_mode(false)
		show_page(PAGE_PLAY)
	%PopupLayer.show()

func _on_pool_finished(won: bool, result_text: String) -> void:
	%PopupTitle.text = "You win!" if won else "Cadavire wins"
	%PopupText.text = result_text
	%PopupButton.text = "BACK"
	_popup_action = func():
		set_minigame_mode(false)
		show_page(PAGE_PLAY)
	%PopupLayer.show()

# =====================================================================
# Challenges wall (Brawl-style). Opened from the top bar, or by itself when
# a window breaks (never during a minigame, a popup, a manager scene or the art viewer).
# =====================================================================
func _build_challenges() -> void:
	challenges_page = preload("res://scripts/challenges_page.gd").new()
	challenges_page.visible = false
	%Pages.add_child(challenges_page)
	challenges_page.set_palette(ui.pal)
	challenges_page.back_pressed.connect(close_challenges)
	challenges_page.view_art.connect(open_art)
	art_viewer = preload("res://scripts/art_viewer.gd").new()
	add_child(art_viewer)
	challenges_button = Button.new()
	challenges_button.theme_type_variation = "GhostButton"
	challenges_button.custom_minimum_size = Vector2(0, 44)
	challenges_button.pressed.connect(open_challenges)
	$Root/TopBar/TopV/HBox/RightBox.add_child(challenges_button)
	_refresh_challenge_button()

func _refresh_challenge_button() -> void:
	if challenges_button:
		var n := Challenges.pending.size()
		challenges_button.text = "CHALLENGES %d/%d%s" % [Challenges.cleared_count(), Challenges.rows * Challenges.cols, "  •" if n > 0 else ""]

func open_challenges() -> void:
	if in_minigame or challenges_open:
		return
	challenges_open = true
	for p in pages:
		p.visible = false
	%TopBar.visible = false
	%NavBar.visible = false
	%Portrait.custom_minimum_size = Vector2(150, 190)
	%CostumeLabel.visible = false
	%EquipLabel.visible = false
	challenges_page.visible = true
	challenges_page.open()
	Game.say.emit("challenge_open", 2)

func _close_challenges_view() -> void:
	challenges_open = false
	challenges_page.visible = false
	%TopBar.visible = true
	%NavBar.visible = true
	%Portrait.custom_minimum_size = Vector2(250, 330)
	%CostumeLabel.visible = true
	%EquipLabel.visible = true
	_refresh_challenge_button()

func close_challenges() -> void:
	_close_challenges_view()
	show_page(_last_page)

func open_art(reward_id: String) -> void:
	var rw: Dictionary = Challenges.rewards.get(reward_id, {})
	if rw.is_empty():
		return
	art_viewer.open(String(rw.file), String(rw.name).trim_prefix("Art: "), String(rw.get("credits", "")))

func _auto_open_challenges() -> void:
	if not auto_open_challenges or Challenges.pending.is_empty() or challenges_open or in_minigame \
			or %PopupLayer.visible or manager_box.visible or art_viewer.visible:
		_challenge_wait = 0.0
		return
	_challenge_wait += 0.2
	if _challenge_wait >= 1.0:      # a short beat, so the player sees what they did first
		_challenge_wait = 0.0
		open_challenges()

func _on_popup_button() -> void:
	%PopupLayer.hide()
	if _popup_action.is_valid():
		var a: Callable = _popup_action
		_popup_action = Callable()
		a.call()

# =====================================================================
# Top bar / stage
# =====================================================================
func _refresh_top_static() -> void:
	%MarrowLabel.text = "MARROW %d" % Game.marrow
	%RankLabel.text = "RANK %d" % Game.rank
	var sb: StyleBoxFlat = %RankBox.get_theme_stylebox("panel", "RankBox")
	sb.bg_color = Balance.RANK_COLORS[mini(Game.rank, Balance.RANK_COLORS.size() - 1)]
	%RankLabel.add_theme_color_override("font_color", ui.pal.ink if Game.rank > 0 else ui.pal.text)

func _refresh_stage_labels() -> void:
	%CostumeLabel.text = "Wearing: " + Balance.costume(Game.costume).name
	%EquipLabel.text = "Holding: " + (Balance.item(Game.equipped).name if Game.equipped != "" else "nothing")

func _on_run_reset() -> void:
	for r in rows:
		r.refresh()
	_update_row_visibility()
	_build_schemes()
	show_page(0)

# =====================================================================
# Events
# =====================================================================
func _on_manager_scene(i: int, tier: int) -> void:
	if manager_box.playing:
		if tier > 0 and _scene_queue.size() < 10:
			_scene_queue.append([i, tier])
		return
	var top: float = %Stage.get_global_rect().end.y + 6.0
	manager_box.home_x = 12.0
	manager_box.position = Vector2(get_viewport_rect().size.x, top)
	manager_box.size = Vector2(get_viewport_rect().size.x - 24.0, 0.0)
	manager_box.play(i, tier, %DialogueBox)

func _on_scene_finished(i: int, tier: int) -> void:
	if tier > 0:
		var b: Dictionary = Balance.BUILDINGS[i]
		var msg := "%s · Loyalty %d/%d" % [b.manager, Game.loyalty[i], Balance.LOYALTY_MAX]
		if Game.loyalty_mult(i) > 1.0:
			msg += " · x%s forever" % Fmt.mult(Game.loyalty_mult(i))
		_on_floating(msg, i)
	if not _scene_queue.is_empty():
		var q: Array = _scene_queue.pop_front()
		_on_manager_scene.call_deferred(q[0], q[1])

func _on_reburied(gain: int, promoted: Array) -> void:
	_scene_queue.clear()
	%PopupTitle.text = "The business folded"
	var t := "Everything was seized. But bones aren't money, so they couldn't take them.\n+%d Marrow." % gain
	if not promoted.is_empty():
		var names: Array = []
		for i in promoted:
			names.append("%s → L%d (x%s)" % [Balance.BUILDINGS[i].manager, Game.loyalty[i], Fmt.mult(Game.loyalty_mult(i))])
		t += "\n\nStill loyal:\n" + "\n".join(names) + "\nRehire them to hear why."
	%PopupText.text = t
	%PopupButton.text = "START OVER"
	%PopupLayer.show()

func _flash_level() -> void:
	var tw := %LevelLabel.create_tween()
	%LevelLabel.modulate = Color(2, 2, 2)
	tw.tween_property(%LevelLabel, "modulate", Color.WHITE, 0.8)

func _on_fever_mode(active: bool) -> void:
	ui.apply_palette(UiTheme.FEVER if active else UiTheme.NORMAL)
	%Bg.color = ui.pal.bg
	if challenges_page:
		challenges_page.set_palette(ui.pal)
	if blackjack_page:
		blackjack_page.set_palette(ui.pal)
	%FeverTitle.text = "FEVER!" if active else "FEVER"
	_refresh_top_static()
	_flash_screen()

func _on_taste_test(i: int, quality: int, eaten: float) -> void:
	%Portrait.shake()
	if i < rows.size():
		rows[i].flash()
	var q: String = Balance.QUALITY_NAMES[quality]
	var txt := "Taste test: %s bone" % q
	if eaten > 0.0:
		txt += "  -%s" % Fmt.num(eaten)
	if quality >= 2:
		txt += "  x%s boost" % Fmt.mult(Balance.TASTE_BUFF_MULT[quality])
	_on_floating(txt, i)

func _on_floating(text: String, i: int) -> void:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "TitleLabel"
	l.add_theme_color_override("font_color", ui.pal.accent2)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	%FxLayer.add_child(l)
	var pos: Vector2
	if i >= 0 and i < rows.size() and rows[i].is_visible_in_tree():
		var r: Rect2 = rows[i].get_global_rect()
		pos = Vector2(r.position.x + 130, r.position.y + 10)
	else:
		pos = %BonesLabel.get_global_rect().position + Vector2(0, 60)
	l.global_position = pos
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "global_position:y", pos.y - 70, 1.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.4).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)

func _flash_screen() -> void:
	var f := ColorRect.new()
	f.color = Color(ui.pal.accent, 0.35)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	%FxLayer.add_child(f)
	var tw := f.create_tween()
	tw.tween_property(f, "color:a", 0.0, 0.5)
	tw.tween_callback(f.queue_free)

func _show_offline(amount: float, seconds: float) -> void:
	Game.pending_offline = Vector2.ZERO
	%PopupTitle.text = "Welcome back"
	%PopupButton.text = "NICE"
	%PopupText.text = "You were gone %s.\nYour ghouls dug up %s bones." % [Fmt.time(seconds), Fmt.num(amount)]
	%PopupLayer.show()

# =====================================================================
# Mobile safe area (notch / home bar)
# =====================================================================
func _apply_safe_area() -> void:
	if not OS.has_feature("mobile"):
		return
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return
	var s := get_viewport_rect().size.y / float(win.y)
	%Root.offset_top = maxf(0.0, safe.position.y) * s
	%Root.offset_bottom = -maxf(0.0, win.y - safe.end.y) * s

# =====================================================================
# Debug hooks (command line, after "--"):
#   --fresh  --tab=N  --state=rich|late  --fever  --caveman  --say=key
#   --taste  --offline  --shot=/abs/path.png  --wait=SECONDS
# =====================================================================
func _debug_setup() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.is_empty():
		return
	if args.has("shot"):
		Game.autosave_enabled = false
	if args.get("state", "") in ["rich", "late"]:
		var late: bool = args.state == "late"
		for i in Balance.BUILDINGS.size():
			Game.owned[i] = (60 - i * 5) if (late or i < 6) else 0
			Game.managers[i] = late or i < 4
		Game.bones = 3.4e11 if late else 2.7e7
		Game.marrow = 140 if late else 70
		Game.marrow_earned = Game.marrow
		Game.run_bones = 9.0e10 if late else 3.0e7
		Game.inventory = {"dog_chew": 2, "knuckle_jar": 1, "velvet_ribbon": 1}
		Game.equipped = "knuckle_jar"
		Game.costumes_owned = ["grave_casual", "hard_hat", "caveman"]
		Game.progress[1] = 0.4
		Game.progress[2] = 0.7
		Game.progress[3] = 0.2
		if late:
			Game.rank = 1
			Game._check_rank()
		Game._refresh_all()
		Game.costume_changed.emit()
		_on_run_reset()
		_refresh_top_static()
	if args.has("caveman"):
		Game.costumes_owned.append("caveman")
		Game.wear("caveman")
	if args.has("fever"):
		Game.start_fever()
	if args.has("taste"):
		Game.do_taste_test(2)
	if args.has("say"):
		Game.say.emit(args.say, 5)
	if args.has("offline"):
		_show_offline(4.2e6, 3 * 3600 + 17 * 60)
	# Card table: --marrow=N --rankset=N --seat=broth,xylo (those managers get loyalty 1+)
	#   --cards [--bjseed=N] [--bjdeal=BET] [--bjevent=peek] [--bjact=hit,stand,double]
	if args.has("marrow"):
		Game.marrow = int(args.marrow)
		Game.marrow_changed.emit()
	if args.has("rankset"):
		Game.rank = int(args.rankset)
	if args.has("seat"):
		for id in String(args.seat).split(","):
			for i in Balance.BUILDINGS.size():
				if Balance.BUILDINGS[i].id == id:
					Game.loyalty[i] = maxi(Game.loyalty[i], 1 + (2 if id == "broth" else 0))
	if args.has("cards"):
		start_cards(int(args.get("bjseed", "-1")))
		if args.has("fast"):
			Game.fast_table = true
		if args.has("bjpair"):         # rig your first two cards to a pair: --bjpair=8
			var r := int(args.bjpair)
			blackjack_page.rig = {"p": [{"r": r, "s": 0}, {"r": r, "s": 1}]}
		if args.has("bjdeal"):
			blackjack_page._set_bet(int(args.bjdeal))
			blackjack_page.deal()
			blackjack_page.flush()
			if args.has("bjevent"):
				blackjack_page.force_event(String(args.bjevent))
			for a in String(args.get("bjact", "")).split(",", false):
				blackjack_page.call({"hit": "hit", "stand": "stand", "double": "double_down", "split": "split"}[a])
				blackjack_page.flush()
			blackjack_page._t += 5.0     # cards finished sliding
		if args.has("bjauto"):        # the table plays itself (GIF demos); --bjnext=peek forces the event
			blackjack_page.auto = true
			blackjack_page.force_next = String(args.get("bjnext", ""))
		if args.has("bjshot"):        # camera shot for screenshots: seat, hand, dealer, seat0, seat1, result
			blackjack_page.table.focus(String(args.bjshot), 999.0)
			blackjack_page.table.snap()
	# Hold'em: --holdem [--bjseed=N] [--hebuy=N --heauto --henext=peek --hehands=N --heshot=result]
	if args.has("holdem"):
		start_holdem(int(args.get("bjseed", "-1")))
		var hp = holdem_page
		if args.has("henext"):
			hp.force_next = String(args.henext)
		if args.has("hebuy"):
			hp._set_buyin(int(args.hebuy))
			hp.sit()
			if args.has("hehands"):       # fast-forward: the AI plays your hands too
				hp.auto = true
				for h in int(args.hehands):
					hp.flush()
					if h < int(args.hehands) - 1 and hp.state == "result":
						hp.start_hand()
				hp.auto = args.has("heauto")
			else:
				hp.flush()
			hp._t += 5.0
		if args.has("hehome"):         # screenshot: the seat-0 manager goes home broke
			for p in hp.players:
				if p.who == "s0":
					p.stack = 1
					p.reloads = 0
			hp.state = "result"
			hp._bankrolls()
			hp._refresh()
		if args.has("hebroke"):        # screenshot: you broke the house
			for p in hp.players:
				if p.id == "cadavire":
					p.stack = 1
					p.reloads = 0
			hp.state = "result"
			hp._bankrolls()
			hp._refresh()
		if args.has("heauto"):
			hp.auto = true
		if args.has("heshot"):
			hp.table.focus(String(args.heshot), 999.0)
			hp.table.snap()
	if args.has("loyalty"):
		for i in Balance.BUILDINGS.size():
			Game.loyalty[i] = int(args.loyalty)
			Game.scenes_seen[i] = int(args.loyalty) - 1
		Game._refresh_all()
	if args.has("hire"):
		var hi := int(args.hire)
		Game.owned[hi] = maxi(1, Game.owned[hi])
		Game.managers[hi] = false
		Game.bones = maxf(Game.bones, Game.manager_cost(hi))
		Game.hire_manager(hi)
		await get_tree().process_frame
		for n in int(args.get("beats", "0")):   # step the scene for screenshots
			manager_box._complete_typing()
			%DialogueBox.complete()
			manager_box._on_reply()
	if args.has("rebury"):
		Game.run_bones = 4.0e9
		Game.rebury()
	if args.has("pool"):
		start_pool(3)
		if args.has("scatter"):   # mid-game layout for screenshots
			var sim: PoolSim = %PoolPage.sim
			sim.shoot(Vector2(0.03, -1).normalized(), 1.0)
			for k in 600:
				sim.step(1.0 / 60.0)
			sim.respot_cue()
			%PoolPage.state = "aim"
			%PoolPage._refresh_labels()
		if args.has("aim"):
			var a: PackedStringArray = String(args.aim).split(",")
			%PoolPage.aim_dir = Vector2(float(a[0]), float(a[1])).normalized()
		if args.has("pull"):
			%PoolPage.power = float(args.pull)
		if args.has("herturn"):
			%PoolPage.turn = PoolSim.Side.CADAVIRE
			%PoolPage.state = "ai_think"
			%PoolPage._timer = 0.2
		if args.has("poolend"):
			%PoolPage._end(args.poolend == "win")
	if args.has("dogfight"):
		start_dogfight(5)
		var df = %DogfightPage
		if args.has("autopilot"):
			df.autopilot = true
		if args.has("dfgod"):    # screenshots only: cannot die
			df.player.max_hp = 1.0e9
			df.player.hp = 1.0e9
		if args.has("dfface"):
			var target: Vector3 = df.world.volcano.pos if args.dfface == "volcano" else df.world.islands[0].pos
			var to: Vector3 = target - df.player.position
			df.player.yaw = atan2(-to.x, -to.z)
			df.player.vel = df.player.forward() * df.player.speed
			df._update_camera(0.0)
		if args.has("dfwave"):   # jump: simulate the intro, then start at wave N
			df._timer = 0.0
			df.wave = int(args.dfwave) - 1
			df.sim_step(0.016)
		if args.has("dfsim"):    # simulate N seconds before the screenshot
			var t := 0.0
			while t < float(args.dfsim) and df.state != "over":
				df.sim_step(1.0 / 30.0)
				df._update_camera(1.0 / 30.0)
				t += 1.0 / 30.0
			Engine.time_scale = 1.0
		if args.has("dfat"):     # place the jet: --dfat=x,y,z facing the main island
			var a: PackedStringArray = String(args.dfat).split(",")
			df.player.position = Vector3(float(a[0]), float(a[1]), float(a[2]))
			var to: Vector3 = df.world.islands[0].pos - df.player.position
			df.player.yaw = atan2(-to.x, -to.z)
			df.player.pitch = -0.35
			df.player.vel = df.player.forward() * df.player.speed
			df._update_camera(0.0)
		if args.has("dfboost"):
			df.player.boost_in = true
			df.player.boost = 80.0
		if args.has("dfstage"):   # hold boost into stage N (1, 2, 3 = top speed)
			df.force_boost = true
			df.player.boost = 100.0
			df.player.boost_in = true
			df.player.boosting = true
			df.player.boost_time = [0.0, 0.1, 1.3, 2.6][int(args.dfstage)]
			df.debug_stage = int(args.dfstage)
		if args.has("dfhold"):    # hold BOOST from now on (walks through all 3 stages)
			df.force_boost = true
			df.player.boost = 100.0
			df.autopilot = false
		if args.has("dfcrashat"): # wreck the jet at S s of match time (KO replay check)
			df.debug_crash_at = float(args.dfcrashat)
		if args.has("dfdemo"):    # scripted demo for GIFs
			df.start_demo(String(args.dfdemo))
		if args.has("dfsky"):     # force a weather look: morning, rain, storm, eruption, impact, night
			df.weather.set_preset(String(args.dfsky), true)
			df._update_camera(0.0)
		if args.has("dfahead"):   # put enemy 0 ahead of the jet (screenshots)
			if df.enemies.is_empty():
				df._spawn_enemy("fighter")
			var en = df.enemies[0]
			var fw: Vector3 = df.player.forward()
			en.position = df.player.position + fw * float(args.dfahead) + fw.cross(Vector3.UP) * 40.0 + Vector3.UP * 12.0
			en.yaw = df.player.yaw + 0.6
			en.alive = true
			df._update_camera(0.0)
		if args.has("dforbit"):   # degrees around the jet: 180 = look at the nose
			df.debug_orbit = deg_to_rad(float(args.dforbit))
			df._update_camera(0.0)
		if args.has("dflaser"):   # laser charged
			df.laser_charge = 1.0
		if args.has("dffire"):    # fire the laser at the locked target, stop the beam mid-flight
			df.laser_charge = 1.0
			df.laser_target = df._find_laser_target()
			if df.laser_target != null:
				df.fire_laser()
				for k in int(float(args.dffire) * 30.0):
					df.lasers[0].t += 1.0 / 30.0 if df.lasers.size() > 0 else 0.0
					df.laser_burst_t = maxf(0.0, df.laser_burst_t - 1.0 / 30.0)
				df.set_process(false)
	if args.has("tab"):
		show_page(int(args.tab))
	if args.has("playopts"):
		_show_play_options(true)
	# Challenges: --chdone=id,id (break silently) --chpend=id,id (break, shatter on open)
	#   --chbones=N --tint=rid --ship=rid --table=rid --challenges (open the wall)
	#   --chsel=col,row --chbone (Golden Bone mode) --chstep=SECONDS (stop mid-shatter)
	#   --art=reward_id (open the art viewer) --artzoom=Z
	if args.has("chdone") or args.has("chpend"):
		for id in String(args.get("chdone", "")).split(",", false) + String(args.get("chpend", "")).split(",", false):
			Challenges._break(id, "met")
		if not args.has("chpend"):
			Challenges.pending.clear()
		else:
			var keep: PackedStringArray = String(args.chpend).split(",", false)
			Challenges.pending = Array(keep)
		_refresh_challenge_button()
	if args.has("chbones"):
		Challenges.golden_bones = int(args.chbones)
	for k in ["tint", "ship", "table"]:
		if args.has(k):
			Challenges.owned[args[k]] = true
			Challenges.call("set_" + k, args[k])
	if args.has("challenges"):
		auto_open_challenges = false
		open_challenges()
		await get_tree().process_frame
		await get_tree().process_frame
		if args.has("chsel"):
			var cs: PackedStringArray = String(args.chsel).split(",")
			challenges_page.wall.select(Vector2i(int(cs[0]), int(cs[1])))
			challenges_page.wall.scroll_to(challenges_page.wall.selected, true)
		if args.has("chbone"):
			challenges_page._toggle_bone_mode()
		if args.has("chstep"):
			var w = challenges_page.wall
			var t := 0.0
			while t < float(args.chstep):
				w._process(1.0 / 60.0)
				t += 1.0 / 60.0
			w.set_process(false)
	if args.has("art"):
		Challenges.owned[args.art] = true
		open_art(args.art)
		if args.has("artzoom"):
			await get_tree().process_frame
			art_viewer._zoom_at(art_viewer.size * 0.5, art_viewer.fit_zoom * float(args.artzoom))
	if args.has("shot"):
		var wait := float(args.get("wait", "1.5"))
		await get_tree().create_timer(wait).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args.shot)
		print("saved ", args.shot)
		get_tree().quit()
