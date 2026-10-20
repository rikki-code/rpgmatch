## Entry scene: the start screen. Hands the chosen RunConfig to the game scene.
class_name MenuRoot
extends Control

func _ready() -> void:
	var bench := BenchRunner.mode()
	if bench != &"":
		SceneRouter.to_game.call_deferred(RunConfig.defaults(ModeCatalog.find(&"battle" if bench == &"battle" else ModeCatalog.INFINITE)))
		return
	_fit()
	get_tree().root.size_changed.connect(_fit)
	var select := ModeSelect.new()
	add_child(select)
	var runs := {}
	for definition in ModeCatalog.all():
		var run := SaveStore.load_run(definition.id())
		if run != null:
			runs[definition.id()] = run
	select.setup(ModeCatalog.all(), GameSession.profile(), runs, not OS.has_feature("web"))
	select.start_requested.connect(_on_start)
	select.continue_requested.connect(_on_continue)
	select.quit_requested.connect(func() -> void: get_tree().quit())
	select.sound_pack_selected.connect(_on_sound_pack_selected)
	Audio.play_music(&"menu")

func _on_start(config: RunConfig) -> void:
	var profile := GameSession.profile()
	profile.remember_settings(config.mode_id, config.settings)
	profile.stats_for(config.mode_id).add(ModeStats.RUNS)
	SaveStore.save_profile(profile)
	SceneRouter.to_game(config)

func _on_sound_pack_selected(id: String) -> void:
	PackCatalog.apply({PackCatalog.AUDIO: id})
	PackPaths.refresh()
	Audio.reload()

func _on_continue(run: RunSave) -> void:
	GameSession.resume = run.game
	SceneRouter.to_game(run.config)

func _fit() -> void:
	UiScale.fit(get_window())
