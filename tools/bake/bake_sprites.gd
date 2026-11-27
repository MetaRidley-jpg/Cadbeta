extends Node
## Bakes every dogfight sprite atlas to art/baked/ (run by tools/bake_sprites.sh, with --bakesprites).
func _ready() -> void:
	var t := Time.get_ticks_msec()
	DfRender.bake_all()
	for k in ["player", "fighter", "kamikaze", "boss"]:
		DfPlane.sprites_for(k)
	for id in Challenges.rewards:      # alt player jets from the Challenges wall
		var r: Dictionary = Challenges.rewards[id]
		if r.has("strip") and DfSprites.has_strip(String(r.strip)):
			DfSprites.bake_art(String(r.strip), func(): return DfPlane.model("player"), 32, [-80, -55, -25, 0, 18, 38, 65, 80], DfPlane.JET_M_PER_PX)
	DfWeather.rock_sprites()
	print("BAKED %d atlases in %d ms" % [DfSprites.stats.baked, Time.get_ticks_msec() - t])
	get_tree().quit()
