# Milestone 1 实现边界与接口

设计依据：已完整阅读 `AGENT_GODOT_BACKROOMS_DEMO_PLAN_v2.md`（2346 行）。本轮只制作基础框架与两个灰盒测试房间，不制作序章、L0 或 L1–L11 内容。

## 现有项目审计

2026-09-06：根目录只有 project.godot、默认 icon.svg、AGENTS.md、设计规格及 Godot 导入缓存。没有迁移后的源码或模型；没有 .git 目录和 DEVELOPMENT.md。沿用 Godot 4.7 / Jolt 配置；本机引擎实测 4.7.2。

## 所有权

- `GameState`：BOOT / MENU / PLAYING / PAUSED / TRANSITION / DEAD 生命周期，以及互斥 UI 模式。
- `Session`：当前会话的 Stats、InventoryModel、PhoneState 及不可由设置更改的难度；只组合数据，不处理移动或关卡。
- `WorldState`：通用场景 ID、入口、种子、flags、世界物品记录、时钟。
- `SceneRouter`：数据目录查找、异步场景加载、入口验证与事务切换；失败保留旧房间。
- `SaveService`：带 schema_version 的纯数据快照、校验后恢复、临时文件/备份；不序列化 Node 或执行存档对象。
- `Settings`：沉浸 HUD、轻微 headbob。
- `FoundationApp`：场景组合根，连接 UI 意图、Player、服务；业务规则仍由各模块拥有。

## 背包 MVP（本轮实现）

定义与实例分开：`ItemDefinition` / `ContainerDefinition` 是只读 Resource；`ItemInstance` 保存 uid、condition、ChargeState、CapacityState、custom_flags、ContainerInstance。容器保存物品 UID 的摆放记录，不保存父对象引用。

`InventoryModel.items` 是 `Dictionary[String, ItemInstance]`；equipment 为槽位到 UID 的映射。一次移动先构造候选布局，验证全树占格、标签、唯一归属、循环、最大深度和非空容器完整形状，再提交或回滚。所有嵌套重量计入身体负重；超重仍允许拾取。物品不堆叠。规模上限限制畸形存档/极深嵌套；不在逐帧执行全树校验。

UI 只显示投影并发出意图；库存事务在模型内执行。可拖放、R 旋转、装备/卸下、进入子容器、丢弃与拾取。世界物品用 UID+scene ID+transform 保存，灰盒提供低模实体；后续 M3 再接入流式房间持久化。

## 身体 MVP 与升级边界

组合 `CharacterBody3D` / CameraPivot / Camera3D / 碰撞体 / 身体表现 / Interactor。运动参数使用 Resource；身体用可替换低模躯干、腿、手臂与装备挂点，交互触发手臂动作。后续替换 Skeleton3D/动画/IK 不改变移动、物品或存档接口。

## 存档与难度骨架

保存版本 1，纯 Dictionary/Array/基本 Variant；禁止对象反序列化。记录难度、属性、物品状态与嵌套布局、equipment、手机自由输入、时钟、world flags、世界物品及玩家位置。导入到临时模型并校验，成功加载目的场景后提交，失败不破坏当前会话。Casual 可手动保存，其他难度只允许 checkpoint；Extreme 的删除只在死亡结算后返回菜单时执行。

后续完整角色档案、Journal、ChunkGraph、照片与剧情 checkpoint 在所属 milestone 扩展版本化 section；本轮不造这些系统的假内容。

## 验收

引擎导入/解析；数据测试（异形、旋转、阻塞格、循环、嵌套形状、递归重量、存档损坏）；真实物理帧输入测试（移动、冲刺、蹲伏、跳跃、视线遮挡交互）；两灰盒往返与物品连续性；带图形运行和截图检查 HUD、背包、手机。

## 设计文档冲突

7.5 Rare Unexplained Footstep、9 Phase 2 人类痕迹、Milestone 4 Human traces、26 人类痕迹/疑似人影与 0.4、7.8、8.1 的已确认无生命原则冲突。已确认产品决策优先；后续不在普通 L0 实现这些旧条目。M1 验证两个灰盒场景替代 27.10 要求的完整序章→L0 流程，遵循本次用户只做 M1 的范围。
