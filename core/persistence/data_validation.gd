class_name DataValidation
extends RefCounted


static func bounded_number(value: Variant, minimum: float, maximum: float) -> bool:
	if not (value is float or value is int):
		return false
	var number: float = float(value)
	return is_finite(number) and number >= minimum and number <= maximum


static func safe_transform(value: Variant) -> bool:
	if not value is Transform3D:
		return false
	var transform: Transform3D = value
	if not transform.is_finite() or transform.origin.length() >= 100000.0:
		return false
	if not is_equal_approx(transform.basis.determinant(), 1.0):
		return false
	return transform.basis.is_equal_approx(transform.basis.orthonormalized())


static func flags_valid(data: Dictionary) -> bool:
	if data.size() > 128:
		return false
	for key: Variant in data:
		if not key is String or String(key).length() > 128:
			return false
		var value: Variant = data[key]
		if not (value is bool or value is String or value is int or value is float):
			return false
		if value is String and String(value).length() > 1000:
			return false
		if value is float and not is_finite(float(value)):
			return false
	return true
