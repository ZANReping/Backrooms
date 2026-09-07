class_name ItemDescriptionResolver
extends RefCounted


static func resolve(item: ItemInstance, flags: Dictionary) -> String:
	if item == null:
		return ""
	var lines: PackedStringArray = [TranslationServer.translate(item.definition.description_key)]
	for rule: ItemDescriptionRule in item.definition.description_rules:
		if rule.required_world_flag != &"" and not bool(flags.get(String(rule.required_world_flag), false)):
			continue
		if rule.required_item_flag != &"" and not bool(item.custom_flags.get(String(rule.required_item_flag), false)):
			continue
		lines.append(TranslationServer.translate(rule.text_key))
	if item.contents.maximum > 0.0 and item.contents.current <= 0.0:
		lines.append(TranslationServer.translate(&"DESCRIPTION_EMPTY"))
	if item.charge.maximum > 0.0 and item.charge.current <= 0.0:
		lines.append(TranslationServer.translate(&"DESCRIPTION_UNCHARGED"))
	return "\n".join(lines)
