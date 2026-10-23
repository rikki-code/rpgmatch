## Character controller <-> saved data. A new CharacterController adds one line here.
class_name ControllerCodec
extends RefCounted

static func decode(data: Dictionary) -> CharacterController:
	match data["type"]:
		"human":
			return HumanController.new()
		"ai":
			return AiController.new(float(data["skill"]))
		"remote":
			return RemoteController.new()
	push_error("Unknown controller: %s" % data)
	return CharacterController.new()
