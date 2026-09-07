class_name ItemCatalog
extends Resource

@export var definitions: Array[ItemDefinition] = []


func find(id: StringName) -> ItemDefinition:
	for definition: ItemDefinition in definitions:
		if definition.id == id:
			return definition
	return null
