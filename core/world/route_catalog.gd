class_name RouteCatalog
extends Resource

@export var routes: Array[RouteDefinition] = []


func find(id: StringName) -> RouteDefinition:
	for route: RouteDefinition in routes:
		if route.id == id:
			return route
	return null
