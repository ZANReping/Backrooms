class_name PrologueTasks
extends RefCounted

## A read-only projection of existing progress. Optional entries never gate travel.
static func describe(session: SessionData) -> Dictionary:
	var state: PrologueState = session.prologue
	var entries: Array[Dictionary] = []
	var task_id: StringName = StringName(session.run_id + "/morning")
	var title: String = "出门前"
	if not state.enabled or state.stage == PrologueState.Stage.ARRIVED:
		return {"id": StringName(session.run_id + "/none"), "title": "", "entries": entries}
	if state.stage == PrologueState.Stage.COMMUTE:
		task_id = StringName(session.run_id + "/commute")
		title = "去上班"
		entries.append(_entry(&"walk", "沿人行道走到路口", false))
		entries.append(_entry(&"water", "在售货机买一瓶水", state.bought_water, true))
	else:
		entries.append(_entry(&"alarm", "关掉床头的闹钟", not state.alarm_active))
		entries.append(_entry(&"registration", "用手机完成入职登记", session.profile.registered))
		entries.append(_entry(&"essentials", "带上手机、钥匙和钱包", _owns(session.inventory, &"phone") and _owns(session.inventory, &"keys") and _owns(session.inventory, &"wallet")))
		entries.append(_entry(&"bag", "背好通勤包，带上工作电脑", not session.inventory.get_back_container().is_empty() and _owns(session.inventory, &"work_laptop")))
		entries.append(_entry(&"inspect", "查看工作电脑的物品说明", state.has_tutorial("inspect_laptop"), true))
		entries.append(_entry(&"organize", "旋转物品，整理背包空间", state.has_tutorial("rotate"), true))
		entries.append(_entry(&"leave", "走出公寓楼", false))
	return {"id": task_id, "title": title, "entries": entries}


static func _entry(id: StringName, text: String, completed: bool, optional: bool = false) -> Dictionary:
	return {"id": id, "text": text, "completed": completed, "optional": optional}


static func _owns(inventory: InventoryModel, definition_id: StringName) -> bool:
	for item: ItemInstance in inventory.items.values():
		if item.definition.id == definition_id and inventory.is_owned(item.uid):
			return true
	return false
