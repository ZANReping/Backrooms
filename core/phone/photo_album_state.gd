class_name PhotoAlbumState
extends RefCounted

const MAX_PHOTOS: int = 64
var photos: Array[Dictionary] = []


func append(photo_id: String, clock_seconds: float) -> bool:
	if photos.size() >= MAX_PHOTOS or not valid_id(photo_id) or not DataValidation.bounded_number(clock_seconds, 0.0, 1e12):
		return false
	for row: Dictionary in photos:
		if row["id"] == photo_id:
			return false
	photos.append({"id": photo_id, "clock_seconds": clock_seconds})
	return true


func to_data() -> Dictionary:
	return {"photos": photos.duplicate(true)}


func load_data(data: Dictionary) -> bool:
	if not data.get("photos") is Array or data["photos"].size() > MAX_PHOTOS:
		return false
	var next: PhotoAlbumState = PhotoAlbumState.new()
	for value: Variant in data["photos"]:
		if not value is Dictionary or not value.get("id") is String:
			return false
		if not DataValidation.bounded_number(value.get("clock_seconds"), 0.0, 1e12) or not next.append(value["id"], value["clock_seconds"]):
			return false
	photos = next.photos
	return true


static func valid_id(value: String) -> bool:
	if value.length() != 32:
		return false
	for index: int in value.length():
		if value[index] not in "0123456789abcdef":
			return false
	return true
