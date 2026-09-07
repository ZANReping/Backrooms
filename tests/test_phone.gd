extends SceneTree

const PhoneStateScript := preload("res://core/phone/phone_state.gd")


func _initialize() -> void:
	var phone: PhoneState = PhoneStateScript.new()
	_assert(not phone.send_message("\n\t"), "control-only message is rejected")
	_assert(phone.send_message("  你好\u0007 world  "), "unicode message is accepted")
	_assert(phone.messages[0]["text"] == "你好 world", "control characters are stripped")
	_assert(phone.messages[0]["status"] == &"sent", "online local message records sent status")
	phone.offline = true
	_assert(phone.send_message("offline"), "offline message is retained locally")
	_assert(phone.messages[1]["status"] == &"failed", "offline message records failed status")
	phone.set_active_app(&"clock")
	phone.set_active_app(&"invalid")
	_assert(phone.active_app == &"clock", "invalid app selection is ignored")
	var saved: Dictionary = phone.to_data()
	var restored: PhoneState = PhoneStateScript.new()
	_assert(restored.load_data(saved), "valid snapshot loads")
	_assert(restored.to_data() == saved, "snapshot round trip preserves phone state")
	var before: Dictionary = restored.to_data()
	var invalid: Dictionary = saved.duplicate(true)
	invalid["active_app"] = "invalid"
	_assert(not restored.load_data(invalid), "invalid active app is rejected")
	_assert(restored.to_data() == before, "failed load is transactional")
	_assert(phone.send_message("给朋友", &"a_ming"), "message accepts stable conversation id")
	var conversations := PhoneStateScript.new()
	_assert(conversations.load_data(phone.to_data()), "conversation ids load")
	_assert(conversations.messages.back()["conversation_id"] == "a_ming", "conversation recipient survives serialization")
	var legacy := saved.duplicate(true)
	for message: Dictionary in legacy["messages"]:
		message.erase("conversation_id")
	_assert(conversations.load_data(legacy), "old phone data without recipient still loads")
	_assert(conversations.messages[0]["conversation_id"] == "default", "legacy messages have explicit default conversation")
	var invalid_recipient := phone.to_data()
	invalid_recipient["messages"][0]["conversation_id"] = "../wrong"
	var conversation_before := conversations.to_data()
	_assert(not conversations.load_data(invalid_recipient), "invalid recipient rejected")
	_assert(conversations.to_data() == conversation_before, "invalid recipient cannot partially replace saved messages")
	print("PASS: phone state")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("FAIL: %s" % message)
	quit(1)
