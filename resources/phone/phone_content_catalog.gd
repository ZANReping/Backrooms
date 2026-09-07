class_name PhoneContentCatalog
extends Resource

@export var conversations: Array[Dictionary] = []
@export var map_places: Array[Dictionary] = []
@export var browser_pages: Array[Dictionary] = []
@export var contacts: Array[Dictionary] = []
@export var recent_calls: Array[Dictionary] = []


func browser_page(page_id: StringName) -> Dictionary:
	for row: Dictionary in browser_pages:
		if StringName(row.get("id", &"")) == page_id:
			return row
	return {}
