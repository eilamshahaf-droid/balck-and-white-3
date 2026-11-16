extends RefCounted
## Every sound the game plays. An event (a surface the hand touches, or something that
## happened: "coins", "stamp", "click") plays one of its recorded files from
## `data/sounds.tres` (Kenney's CC0 packs); an event with no files is made here in code,
## as all of them were before (one short sound per surface, rain, fire, chimes).

const RATE := 22050

static var _cache := {}
static var _settings: SoundSettings
static var _watching := false


## Play `event` at `where` in the world. loudness 0..1.
static func play(tree: SceneTree, where: Vector3, event: StringName, loudness := 1.0) -> void:
	if tree.current_scene == null:
		return
	var s := settings()
	var player := AudioStreamPlayer3D.new()
	player.stream = _stream(event)
	player.volume_db = linear_to_db(clampf(loudness, 0.05, 1.0)) + s.volumes.get(event, 0.0)
	player.pitch_scale = randf_range(1.0 - s.pitch_spread, 1.0 + s.pitch_spread)
	player.unit_size = s.unit_size
	player.max_distance = s.max_distance
	tree.current_scene.add_child(player)
	player.global_position = where
	player.finished.connect(player.queue_free)
	player.play()


## Play `event` as part of the screen (a click, a confirmation), not from a place.
static func ui(tree: SceneTree, event: StringName, loudness := 1.0) -> void:
	var s := settings()
	var player := AudioStreamPlayer.new()
	player.stream = _stream(event)
	player.volume_db = linear_to_db(clampf(loudness, 0.05, 1.0)) + s.volumes.get(event, 0.0)
	player.pitch_scale = randf_range(1.0 - s.pitch_spread * 0.5, 1.0 + s.pitch_spread * 0.5)
	tree.root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## Every button that enters `tree` from now on clicks when pressed.
static func watch_buttons(tree: SceneTree) -> void:
	if _watching:
		return
	_watching = true
	tree.node_added.connect(func(node: Node) -> void:
		if node is BaseButton and not node.has_meta(&"sfx"):
			node.set_meta(&"sfx", true)
			(node as BaseButton).pressed.connect(ui.bind(tree, &"click", 1.0)))


static func settings() -> SoundSettings:
	if _settings == null:
		_settings = load("res://data/sounds.tres")
	return _settings


## A loop of the city far off: a low, soft roar of traffic, `seconds` long.
static func ambience(seconds: float) -> AudioStreamWAV:
	var smoothing := settings().ambience_smoothing
	var count := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var smooth := 0.0
	var fade := int(0.5 * RATE)
	for i in count:
		smooth = lerpf(randf_range(-1.0, 1.0), smooth, smoothing)
		var v := smooth / (1.0 - smoothing * 0.95) * 0.5
		# The ends fade into each other so the loop has no seam.
		if i < fade:
			v *= float(i) / fade
		elif i > count - fade:
			v *= float(count - i) / fade
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = count
	return wav


## What something sounds like when touched or hit.
static func surface_of(obj: Object) -> StringName:
	if obj == null or not obj is Node:
		return &"asphalt"
	if obj.has_meta("surface"):
		return obj.get_meta("surface")
	var node: Node = obj
	if node.is_in_group("citizens"):
		return &"cloth"
	if BuildingBox.building_of(node):
		return &"concrete"
	return &"asphalt"


## The stream for `event`: one of its files at random, or the sound made in code.
static func _stream(event: StringName) -> AudioStream:
	var s := settings()
	var names: PackedStringArray = s.files.get(event, PackedStringArray())
	if names.is_empty():
		if not _cache.has(event):
			_cache[event] = _make(event)
		return _cache[event]
	var path := s.folder + names[randi() % names.size()]
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


static func _make(surface: StringName) -> AudioStreamWAV:
	# Each recipe: length (s), tones [Hz], tone decay (s), noise amount,
	# noise smoothing (0 = hiss, near 1 = rumble), noise decay (s), flutter (Hz).
	var r: Array = {
		&"concrete": [0.25, [85.0, 140.0], 0.08, 0.8, 0.9, 0.06, 0.0],
		&"asphalt": [0.18, [], 0.0, 1.0, 0.85, 0.05, 0.0],
		&"glass": [0.6, [2150.0, 3320.0, 4710.0], 0.25, 0.3, 0.0, 0.01, 0.0],
		&"metal": [0.5, [420.0, 1130.0, 1870.0], 0.2, 0.5, 0.3, 0.03, 0.0],
		&"wood": [0.2, [210.0, 470.0], 0.06, 0.5, 0.6, 0.03, 0.0],
		&"cloth": [0.2, [], 0.0, 0.7, 0.92, 0.07, 0.0],
		&"paper": [0.15, [], 0.0, 0.5, 0.1, 0.05, 40.0],
		&"feathers": [0.3, [], 0.0, 0.5, 0.7, 0.12, 22.0],
		&"grass": [0.2, [], 0.0, 0.6, 0.8, 0.08, 0.0],
		&"earth": [0.5, [60.0], 0.15, 1.0, 0.95, 0.2, 0.0],
		&"strain": [0.45, [70.0, 73.0], 0.3, 0.3, 0.97, 0.2, 9.0],
		&"rain": [1.0, [], 0.0, 0.5, 0.2, 5.0, 0.0],
		&"fire": [0.12, [], 0.0, 0.8, 0.5, 0.02, 0.0],
		&"chime": [1.2, [523.0, 659.0, 784.0], 0.5, 0.0, 0.0, 0.01, 0.0],
		&"thunder": [2.0, [45.0], 0.3, 1.0, 0.97, 0.7, 0.0],
		&"zap": [0.3, [], 0.0, 1.0, 0.0, 0.08, 0.0],
		&"hum": [1.0, [110.0, 220.0], 0.5, 0.1, 0.9, 0.3, 3.0],
		&"shimmer": [1.6, [880.0, 1320.0, 1760.0], 0.6, 0.1, 0.0, 0.3, 6.0],
	}.get(surface, [0.15, [], 0.0, 1.0, 0.85, 0.05, 0.0])
	var count := int(r[0] * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var smooth := 0.0
	for i in count:
		var t := float(i) / RATE
		var attack := minf(t / 0.004, 1.0)
		var v := 0.0
		for f in r[1]:
			v += sin(TAU * f * t) * exp(-t / r[2]) / r[1].size()
		smooth = lerpf(randf_range(-1.0, 1.0), smooth, r[4])
		var noise: float = smooth * (1.0 / (1.0 - r[4] * 0.9)) * r[3] * exp(-t / r[5])
		if r[6] > 0.0:
			noise *= 0.5 + 0.5 * sin(TAU * r[6] * t)
		v = clampf((v + noise) * attack * 0.8, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
