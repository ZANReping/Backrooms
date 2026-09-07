class_name PhoneState
extends RefCounted

signal changed

const MAX_MESSAGE_LENGTH: int = 1000
const MAX_MESSAGES: int = 2048
const VALID_STATUSES: Array[StringName] = [&"sent", &"pending", &"failed"]
const VALID_APPS: Array[StringName] = [&"chat", &"maps", &"browser", &"phone", &"camera", &"clock"]

var messages: Array[Dictionary] = []
var active_app: StringName = &"chat"
var offline: bool = false
var _next_sequence: int = 1


func send_message(text: String, conversation_id: StringName = &"default") -> bool:
	var clean_text: String = _sanitize_text(text)
	if clean_text.is_empty() or not _valid_conversation_id(conversation_id):
		return false
	if messages.size() >= MAX_MESSAGES:
		return false
	messages.append({
		"text": clean_text,
		"status": &"failed" if offline else &"sent",
		"sequence": _next_sequence,
		"conversation_id": String(conversation_id),
	})
	_next_sequence += 1
	changed.emit()
	return true


func set_active_app(app_id: StringName) -> void:
	if app_id not in VALID_APPS:
		return
	if active_app == app_id:
		return
	active_app = app_id
	changed.emit()


func to_data() -> Dictionary:
	var serialized_messages: Array[Dictionary] = []
	for message: Dictionary in messages:
		serialized_messages.append(message.duplicate(true))
	return {
		"messages": serialized_messages,
		"active_app": String(active_app),
		"offline": offline,
		"next_sequence": _next_sequence,
	}


func load_data(data: Dictionary) -> bool:
	if not data.has("messages") or not data.has("active_app") or not data.has("offline"):
		return false
	if not data["messages"] is Array or not data["active_app"] is String or not data["offline"] is bool:
		return false
	if StringName(data["active_app"]) not in VALID_APPS:
		return false
	var source_messages: Array = data["messages"]
	if source_messages.size() > MAX_MESSAGES:
		return false
	var validated: Array[Dictionary] = []
	var highest_sequence: int = 0
	for value: Variant in source_messages:
		if not value is Dictionary:
			return false
		var message: Dictionary = value
		if not _is_valid_message(message):
			return false
		var sequence: int = message["sequence"]
		if sequence <= highest_sequence:
			return false
		highest_sequence = sequence
		validated.append({
			"text": message["text"],
			"status": StringName(message["status"]),
			"sequence": sequence,
			"conversation_id": String(message.get("conversation_id", "default")),
		})
	var requested_next: int = highest_sequence + 1
	if data.has("next_sequence"):
		if not data["next_sequence"] is int or int(data["next_sequence"]) < requested_next:
			return false
		requested_next = int(data["next_sequence"])
	messages = validated
	active_app = StringName(data["active_app"])
	offline = data["offline"]
	_next_sequence = maxi(1, requested_next)
	changed.emit()
	return true


func reset() -> void:
	messages.clear()
	active_app = &"chat"
	offline = false
	_next_sequence = 1
	changed.emit()


func _is_valid_message(message: Dictionary) -> bool:
	if not message.has("text") or not message.has("status") or not message.has("sequence"):
		return false
	if not message["text"] is String or not (message["status"] is String or message["status"] is StringName):
		return false
	if not message["sequence"] is int or int(message["sequence"]) <= 0:
		return false
	var conversation: Variant = message.get("conversation_id", "default")
	if not (conversation is String or conversation is StringName) or not _valid_conversation_id(StringName(conversation)):
		return false
	var text: String = message["text"]
	if text.is_empty() or text.length() > MAX_MESSAGE_LENGTH or text != _sanitize_text(text):
		return false
	return StringName(message["status"]) in VALID_STATUSES


func _valid_conversation_id(value: StringName) -> bool:
	var id := String(value)
	if id.is_empty() or id.length() > 64:
		return false
	for character: String in id:
		if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-":
			return false
	return true


func _sanitize_text(text: String) -> String:
	var result: String = ""
	for index: int in text.length():
		var codepoint: int = text.unicode_at(index)
		if codepoint < 32 or codepoint == 127:
			continue
		result += text[index]
	return result.strip_edges().left(MAX_MESSAGE_LENGTH)
