class_name CharacterProfile
extends Resource

const VALID_GENDERS: Array[StringName] = [&"male", &"female", &"unspecified"]
const DEFAULT_APPEARANCE: Dictionary = {
	"skin": 0,
	"body": 0,
	"hair": 0,
	"hair_color": 0,
	"face": 0,
}

@export var surname: String = ""
@export var given_name: String = ""
@export var birth_date: Dictionary = {}
@export var gender_id: StringName = &"unspecified"
@export var appearance_preset: Dictionary = DEFAULT_APPEARANCE.duplicate(true)
@export var appearance: CharacterAppearance = CharacterAppearance.new()
@export var company_id: StringName = &"foundation_co"
@export var job_id: StringName = &"office_staff"
@export var employee_id: String = ""
@export var registered: bool = false


func validate(story_date: Dictionary) -> StringName:
	if not _is_valid_date(story_date):
		return &"PROFILE_ERR_BIRTH_DATE"
	if registered:
		if not _is_valid_name(surname) or not _is_valid_name(given_name):
			return &"PROFILE_ERR_NAME"
		if not _is_valid_employee_id(employee_id):
			return &"PROFILE_ERR_NAME"
	elif (not surname.is_empty() and not _is_valid_name(surname)) or (not given_name.is_empty() and not _is_valid_name(given_name)):
		return &"PROFILE_ERR_NAME"
	if not registered and birth_date.is_empty():
		pass
	elif not _is_valid_date(birth_date):
		return &"PROFILE_ERR_BIRTH_DATE"
	else:
		var age: int = age_on(story_date)
		if age < 18 or age > 40:
			return &"PROFILE_ERR_AGE"
	if gender_id not in VALID_GENDERS:
		return &"PROFILE_ERR_APPEARANCE"
	if not _is_valid_appearance(appearance_preset):
		return &"PROFILE_ERR_APPEARANCE"
	var appearance_check := CharacterAppearance.new()
	if appearance == null or not appearance_check.load_data(appearance.to_data()):
		return &"PROFILE_ERR_APPEARANCE"
	if company_id != &"foundation_co" or job_id != &"office_staff":
		return &"PROFILE_ERR_APPEARANCE"
	if not registered and not employee_id.is_empty():
		return &"PROFILE_ERR_NAME"
	return &""


func age_on(story_date: Dictionary) -> int:
	if not _is_valid_date(story_date) or not _is_valid_date(birth_date):
		return -1
	var age: int = int(story_date["year"]) - int(birth_date["year"])
	if int(story_date["month"]) < int(birth_date["month"]) or (
		int(story_date["month"]) == int(birth_date["month"])
		and int(story_date["day"]) < int(birth_date["day"])
	):
		age -= 1
	return age


func to_data() -> Dictionary:
	return {
		"surname": surname,
		"given_name": given_name,
		"birth_date": birth_date.duplicate(true),
		"gender_id": String(gender_id),
		"appearance_preset": appearance_preset.duplicate(true),
		"appearance": appearance.to_data(),
		"company_id": String(company_id),
		"job_id": String(job_id),
		"employee_id": employee_id,
		"registered": registered,
	}


func load_data(data: Dictionary, story_date: Dictionary) -> bool:
	var required: Array[String] = ["surname", "given_name", "birth_date", "gender_id", "appearance_preset", "company_id", "job_id", "employee_id", "registered"]
	for key: String in required:
		if not data.has(key):
			return false
	if not data["surname"] is String or not data["given_name"] is String:
		return false
	if not data["birth_date"] is Dictionary or not data["appearance_preset"] is Dictionary:
		return false
	if not (data["gender_id"] is String or data["gender_id"] is StringName):
		return false
	if not (data["company_id"] is String or data["company_id"] is StringName):
		return false
	if not (data["job_id"] is String or data["job_id"] is StringName):
		return false
	if not data["employee_id"] is String or not data["registered"] is bool:
		return false
	var candidate: Resource = get_script().new()
	candidate.surname = data["surname"]
	candidate.given_name = data["given_name"]
	candidate.birth_date = data["birth_date"].duplicate(true)
	candidate.gender_id = StringName(data["gender_id"])
	candidate.appearance_preset = data["appearance_preset"].duplicate(true)
	if data.has("appearance"):
		if not data["appearance"] is Dictionary or not candidate.appearance.load_data(data["appearance"]):
			return false
	else:
		candidate.appearance = CharacterAppearance.from_legacy(candidate.appearance_preset)
	candidate.company_id = StringName(data["company_id"])
	candidate.job_id = StringName(data["job_id"])
	candidate.employee_id = data["employee_id"]
	candidate.registered = data["registered"]
	if candidate.validate(story_date) != &"":
		return false
	surname = candidate.surname
	given_name = candidate.given_name
	birth_date = candidate.birth_date
	gender_id = candidate.gender_id
	appearance_preset = candidate.appearance_preset
	appearance = candidate.appearance
	company_id = candidate.company_id
	job_id = candidate.job_id
	employee_id = candidate.employee_id
	registered = candidate.registered
	return true


func _is_valid_name(value: String) -> bool:
	var clean: String = value.strip_edges()
	if clean.length() < 1 or clean.length() > 20 or clean != value:
		return false
	for index: int in value.length():
		var codepoint: int = value.unicode_at(index)
		if codepoint < 32 or (codepoint >= 127 and codepoint <= 159):
			return false
	return true


func _is_valid_employee_id(value: String) -> bool:
	if value.length() < 6 or value.length() > 16:
		return false
	for index: int in value.length():
		var codepoint: int = value.unicode_at(index)
		if not ((codepoint >= 48 and codepoint <= 57) or (codepoint >= 65 and codepoint <= 90) or (codepoint >= 97 and codepoint <= 122)):
			return false
	return true


func _is_valid_appearance(value: Dictionary) -> bool:
	if value.size() != DEFAULT_APPEARANCE.size():
		return false
	var limits: Dictionary = {"skin": 5, "body": 2, "hair": 3, "hair_color": 3, "face": 2}
	for key: String in limits:
		if not value.has(key) or not value[key] is int:
			return false
		if int(value[key]) < 0 or int(value[key]) > int(limits[key]):
			return false
	return true


func _is_valid_date(value: Dictionary) -> bool:
	if value.size() != 3 or not value.has("year") or not value.has("month") or not value.has("day"):
		return false
	if not value["year"] is int or not value["month"] is int or not value["day"] is int:
		return false
	var year: int = value["year"]
	var month: int = value["month"]
	var day: int = value["day"]
	if year < 1 or month < 1 or month > 12:
		return false
	var days: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if month == 2 and (year % 400 == 0 or (year % 4 == 0 and year % 100 != 0)):
		days[1] = 29
	return day >= 1 and day <= days[month - 1]
