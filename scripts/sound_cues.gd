class_name SoundCues
extends Node
## Listens to the game and plays what happened (Sfx events, files in data/sounds.tres):
## rooms fitted, money spent, paperwork taken, inspectors setting out and stamping,
## buildings taken, Reps trained. Also keeps the city humming in the background and makes
## every button click. Sound only: nothing here changes the game.

const Sfx := preload("res://scripts/sfx.gd")
const AMBIENCE_SECONDS := 6.0

@export var districts: Districts
@export var rooms: Rooms
@export var treasury: Treasury
@export var faith: Faith
@export var campaigns: Campaigns
@export var inspectors: Inspectors
@export var population: Population
@export var breaches: Breaches
@export var unit_upkeep: UnitUpkeep

var _money := 0.0
var _hum: AudioStreamPlayer
var _clock := 0.0

@onready var _s: SoundSettings = Sfx.settings()


func _ready() -> void:
	Sfx.watch_buttons(get_tree())
	_money = treasury.money
	rooms.placed.connect(func(i: int, _k: RoomKind) -> void: _at(i, &"room_placed"))
	rooms.room_closed.connect(func(i: int, _k: RoomKind) -> void: _at(i, &"room_closed"))
	rooms.room_reopened.connect(func(i: int, _k: RoomKind) -> void: _at(i, &"room_reopened"))
	treasury.money_changed.connect(_on_money_changed)
	treasury.ran_dry.connect(_ui.bind(&"ran_dry"))
	faith.spent.connect(_on_paperwork_spent)
	campaigns.taken.connect(func(_b: Node3D, _r: Resident) -> void: _ui(&"taken"))
	campaigns.mark_refused.connect(func(_b: Node3D, _why: String) -> void: _ui(&"error"))
	inspectors.sent.connect(func(_i: Inspector, from: Node3D) -> void: _near(from, &"inspector_out"))
	inspectors.papers_shown.connect(func(b: Node3D, _c: float) -> void: _near(b, &"stamp"))
	inspectors.short_taken.connect(func(b: Node3D, _t: float) -> void: _near(b, &"short"))
	inspectors.thrown.connect(func(i: Inspector) -> void: _near(i, &"thrown"))
	inspectors.gave_up.connect(func(at: Vector3) -> void: Sfx.play(get_tree(), at, &"gave_up"))
	inspectors.fixer_caught.connect(func(b: Node3D) -> void: _near(b, &"caught"))
	population.rank_changed.connect(_on_rank_changed)
	population.canvasser_set_down.connect(func(_r: Resident, b: Node3D) -> void: _near(b, &"set_down"))
	population.fixer_set_down.connect(func(_r: Resident, b: Node3D) -> void: _near(b, &"set_down"))
	breaches.opened.connect(func(_b: Node3D) -> void: _ui(&"key_open"))
	unit_upkeep.reverted.connect(func(_r: Resident) -> void: _ui(&"reverted"))
	districts.block_changed.connect(func(_b: int, complete: bool) -> void:
		if complete:
			_ui(&"block"))
	districts.district_controlled.connect(func(_d: int) -> void: _ui(&"district"))
	# Nobody hears a headless run, and a loop playing when a test quits leaks its stream.
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_hum = AudioStreamPlayer.new()
	_hum.stream = Sfx.ambience(AMBIENCE_SECONDS)
	_hum.volume_db = _s.ambience_db
	_hum.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_hum)
	_hum.play()


# A loop still playing when the game quits leaks its stream.
func _exit_tree() -> void:
	if _hum == null:
		return
	_hum.stop()
	_hum.stream = null


## The street swells and falls back, slowly.
func _process(delta: float) -> void:
	_clock += delta
	_hum.volume_db = _s.ambience_db + _s.swell_db * sin(TAU * _clock / _s.swell_seconds)


func _ui(event: StringName) -> void:
	Sfx.ui(get_tree(), event)


func _near(node: Node3D, event: StringName) -> void:
	if is_instance_valid(node):
		Sfx.play(get_tree(), node.global_position, event)


func _at(index: int, event: StringName) -> void:
	if districts.buildings[index]:
		_near(districts.buildings[index], event)


func _on_money_changed(money: float) -> void:
	if absf(money - _money) >= _s.coins_min:
		_ui(&"coins")
	_money = money


## Paperwork handed over at once rustles; the Reps' upkeep, a little a second, doesn't.
func _on_paperwork_spent(amount: float, use: StringName) -> void:
	if use != &"upkeep" and amount >= 1.0:
		_ui(&"pages")


func _on_rank_changed(_who: Resident, old: Resident.Rank, new: Resident.Rank) -> void:
	if new in [Resident.Rank.MISSIONARY, Resident.Rank.AGENT] and old < new:
		_ui(&"trained")
