extends Node

signal replaced()

var data: SessionData = SessionData.new()


func replace(next_data: SessionData) -> void:
	data = next_data
	replaced.emit()
