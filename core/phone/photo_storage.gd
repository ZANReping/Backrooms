class_name PhotoStorage
extends RefCounted

## Immutable image files stay outside the bounded binary save. Only generated IDs
## become path components; missing images never invalidate a save or its backup.
var base_path: String = "user://photos"


func capture(run_id: String, picture: Image, album: PhotoAlbumState, clock_seconds: float) -> String:
	if not PhotoAlbumState.valid_id(run_id) or picture == null or picture.is_empty() or album.photos.size() >= PhotoAlbumState.MAX_PHOTOS:
		return ""
	var photo_id: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var directory: String = base_path.path_join(run_id)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
		return ""
	var bounded: Image = picture.duplicate()
	if bounded.get_width() > 960:
		bounded.resize(960, maxi(1, roundi(picture.get_height() * 960.0 / picture.get_width())), Image.INTERPOLATE_LANCZOS)
	var path: String = directory.path_join(photo_id + ".webp")
	if bounded.save_webp(path, false, 0.85) != OK:
		return ""
	if not album.append(photo_id, clock_seconds):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return ""
	return photo_id


func read(run_id: String, photo_id: String) -> Texture2D:
	if not PhotoAlbumState.valid_id(run_id) or not PhotoAlbumState.valid_id(photo_id):
		return null
	var path: String = base_path.path_join(run_id).path_join(photo_id + ".webp")
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 4 * 1024 * 1024:
		return null
	var picture: Image = Image.new()
	if picture.load_webp_from_buffer(file.get_buffer(file.get_length())) != OK:
		return null
	return ImageTexture.create_from_image(picture)


func erase_run(run_id: String) -> bool:
	if not PhotoAlbumState.valid_id(run_id):
		return false
	var directory_path: String = base_path.path_join(run_id)
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return true
	for filename: String in directory.get_files():
		if filename.get_extension() == "webp" and PhotoAlbumState.valid_id(filename.get_basename()):
			if directory.remove(filename) != OK:
				return false
	return true


func remove_unreferenced_runs(retained_runs: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(base_path)
	if directory == null:
		return
	# Only our 32-hex generated directories and .webp files are eligible. A backup
	# run is retained even after the primary checkpoint belongs to a newer run.
	for run_id: String in directory.get_directories():
		if PhotoAlbumState.valid_id(run_id) and run_id not in retained_runs:
			if erase_run(run_id):
				var run_directory: DirAccess = DirAccess.open(base_path.path_join(run_id))
				if run_directory != null and run_directory.get_files().is_empty() and run_directory.get_directories().is_empty():
					directory.remove(run_id)
