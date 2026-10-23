## Online match (see OnlineMode). Not on the start screen's mode list: the Multiplayer
## room agrees the settings (seed, level, player names in seat order, this client's seat)
## and builds the RunConfig itself; between rounds GameRoot updates seed, level, score and
## the seats that left.
class_name OnlineDefinition
extends ModeDefinition

const ID := &"online"

func id() -> StringName:
	return ID

func title() -> String:
	return "Multiplayer"

func default_settings(_stats: ModeStats = null) -> Dictionary:
	return {&"departed": [], &"wins": [0, 0]}

func create_mode(settings: Dictionary) -> GameMode:
	return OnlineMode.new(settings[&"names"], settings[&"seat"], settings[&"departed"], settings[&"wins"])

func world_params(settings: Dictionary) -> WorldGenParams:
	var params := WorldGenParams.new()
	params.seed_value = settings[&"seed"]
	return params

func start_level(settings: Dictionary) -> int:
	return settings[&"level"]
