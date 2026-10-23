## Online duel (see OnlineMode). Not on the start screen's mode list: the
## Multiplayer lobby agrees the settings (seed, level, names, who is the host) with
## the opponent and builds the RunConfig itself.
class_name OnlineDefinition
extends ModeDefinition

const ID := &"online"

func id() -> StringName:
	return ID

func title() -> String:
	return "Multiplayer"

func create_mode(settings: Dictionary) -> GameMode:
	return OnlineMode.new(settings[&"host_name"], settings[&"guest_name"], settings[&"role"] == 0)

func world_params(settings: Dictionary) -> WorldGenParams:
	var params := WorldGenParams.new()
	params.seed_value = settings[&"seed"]
	return params

func start_level(settings: Dictionary) -> int:
	return settings[&"level"]
