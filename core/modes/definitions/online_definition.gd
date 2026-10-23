## Online match (see OnlineMode). Not on the start screen's mode list: the Multiplayer
## room agrees the settings (seed, level, player names in seat order, this client's seat)
## and builds the RunConfig itself.
class_name OnlineDefinition
extends ModeDefinition

const ID := &"online"

func id() -> StringName:
	return ID

func title() -> String:
	return "Multiplayer"

func create_mode(settings: Dictionary) -> GameMode:
	return OnlineMode.new(settings[&"names"], settings[&"seat"])

func world_params(settings: Dictionary) -> WorldGenParams:
	var params := WorldGenParams.new()
	params.seed_value = settings[&"seed"]
	return params

func start_level(settings: Dictionary) -> int:
	return settings[&"level"]
