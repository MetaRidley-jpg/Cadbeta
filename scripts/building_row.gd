extends PanelContainer
## One building in the list. Icon art: res://art/buildings/<id>.png (optional).

var index := 0

@onready var run_button: Button = %RunButton
@onready var name_label: Label = %NameLabel
@onready var bar: ProgressBar = %Bar
@onready var revenue_label: Label = %RevenueLabel
@onready var time_label: Label = %TimeLabel
@onready var milestone_label: Label = %MilestoneLabel
@onready var buy_button: Button = %BuyButton
@onready var manager_button: Button = %ManagerButton

func setup(i: int) -> void:
	index = i

func _ready() -> void:
	var b: Dictionary = Balance.BUILDINGS[index]
	name_label.text = b.name
	tooltip_text = "%s · %s" % [Balance.CAT_NAMES[b.cat], b.flavor]
	var icon_path := "res://art/buildings/%s.png" % b.id
	if ResourceLoader.exists(icon_path):
		run_button.icon = load(icon_path)
	run_button.pressed.connect(func(): Game.run(index))
	buy_button.pressed.connect(func(): Sfx.play("buy" if Game.buy(index) else "tap", -6.0))
	manager_button.pressed.connect(func(): Game.hire_manager(index))
	Game.building_changed.connect(func(i): if i == index: refresh())
	revenue_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	revenue_label.add_theme_constant_override("outline_size", 6)
	refresh()

## Slow-changing text. Called on building_changed.
func refresh() -> void:
	var owned: int = Game.owned[index]
	var b: Dictionary = Balance.BUILDINGS[index]
	run_button.text = str(owned) if owned > 0 else "?"
	run_button.disabled = owned <= 0
	var m := Game.next_milestone(index)
	milestone_label.text = "next %d" % m if owned > 0 else Balance.CAT_NAMES[b.cat]
	if Game.loyalty[index] >= 2:
		milestone_label.text += "  ·  L%d x%s" % [Game.loyalty[index], Fmt.mult(Game.loyalty_mult(index))]
	manager_button.visible = owned > 0 and not Game.managers[index]
	manager_button.text = "Hire  %s" % Fmt.num(Game.manager_cost(index))
	manager_button.tooltip_text = "Hire %s: runs this building for you, also offline." % b.manager

## Fast-changing parts. Main calls this every frame for visible rows.
func tick() -> void:
	var owned: int = Game.owned[index]
	var n := Game.buy_amount(index)
	var cost := Game.cost_for(index, n)
	buy_button.text = "BUY x%d\n%s" % [n, Fmt.num(cost)]
	buy_button.disabled = Game.bones < cost
	if manager_button.visible:
		manager_button.disabled = Game.bones < Game.manager_cost(index)
	if owned <= 0:
		bar.value = 0
		revenue_label.text = "not owned"
		time_label.text = ""
		return
	var ct := Game.cycle_time(index)
	var fast: bool = ct < 0.2 and Game.managers[index]
	bar.value = 100.0 if fast else Game.progress[index] * 100.0
	if fast:
		revenue_label.text = "%s /s" % Fmt.num(Game.revenue(index) / ct)
	else:
		revenue_label.text = Fmt.num(Game.revenue(index))
	var left: float = ct * (1.0 - Game.progress[index])
	var t: String = Fmt.time(left) if (Game.managers[index] or Game.running[index]) else "tap " + Fmt.time(ct)
	if Game.buff_left[index] > 0.0:
		t += "  · TASTED x%s %s" % [Fmt.mult(Game.buff_mult[index]), Fmt.time(Game.buff_left[index])]
	time_label.text = t

func flash() -> void:
	var tw := create_tween()
	modulate = Color(1.6, 1.3, 1.3)
	tw.tween_property(self, "modulate", Color.WHITE, 0.6)
