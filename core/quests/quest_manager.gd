## Tracks active quests and their progress. Self-subscribes to the resolver
## like ScoreTracker. With a generator (infinite mode), a completed slot is
## refilled randomly; without one (hand-built levels), it just stays empty.
class_name QuestManager
extends RefCounted

signal quest_added(quest: QuestProgress)
signal quest_progress_changed(quest: QuestProgress)
signal quest_completed(quest: QuestProgress)

var active_quests: Array[QuestProgress] = []
var max_active: int = 3
var generator: QuestGenerator
var board: BoardGraph
## Bumped on every completion — scales future quests' target_count.
var difficulty: int = 0

func _init(p_board: BoardGraph, p_resolver: EffectResolver, p_generator: QuestGenerator = null, p_max_active: int = 3) -> void:
	board = p_board
	generator = p_generator
	max_active = p_max_active
	p_resolver.effect_applied.connect(_on_effect_applied)

func add_quest(definition: QuestDefinition) -> void:
	var progress := QuestProgress.new(definition)
	active_quests.append(progress)
	quest_added.emit(progress)

func fill_from_generator() -> void:
	if generator == null:
		return
	while active_quests.size() < max_active:
		var excluded: Array[StringName] = []
		for quest in active_quests:
			excluded.append(quest.definition.target_kind_id)
		var definition := generator.generate_one(board, difficulty, excluded)
		if definition == null:
			break
		add_quest(definition)

func register_destroyed(entity: BoardEntity) -> void:
	var kind := entity.quest_kind_id()
	if kind == &"":
		return
	for quest in active_quests:
		if quest.is_complete() or quest.definition.target_kind_id != kind:
			continue
		quest.register_progress(1)
		quest_progress_changed.emit(quest)
		if quest.is_complete():
			difficulty += 1
			quest_completed.emit(quest)
	_replace_completed()

func _replace_completed() -> void:
	var still_active: Array[QuestProgress] = []
	for quest in active_quests:
		if not quest.is_complete():
			still_active.append(quest)
	active_quests = still_active
	fill_from_generator()

func _on_effect_applied(effect: Effect) -> void:
	var entity: BoardEntity = null
	if effect is EffectDestroyTile and effect.removed_entity != null:
		entity = effect.removed_entity
	elif effect is EffectEntityRemoved:
		entity = effect.entity
	if entity != null:
		register_destroyed(entity)
