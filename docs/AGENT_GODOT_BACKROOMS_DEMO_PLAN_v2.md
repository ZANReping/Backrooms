# Backrooms 生存游戏 Demo —— Godot Agent 实施规格

> **用途**：本文件是给 Coding Agent / Vibe Coding Agent 的直接实施说明。目标不是一次性制作完整 L0–L11，而是在 Godot 中完成一个可玩的垂直切片 Demo，并建立后续扩展骨架。
>
> **Demo 内容边界**：游戏 UI 与基础框架 + 教程/序章（切入前）完整流程 + Level 0 完整可玩内容 + L1–L11 / The Hub / Level Fun 等后续系统的基础数据与接口骨架。

---

## 0. Agent 总原则

### 2026-09-07 用户补充（优先于旧视觉方案）

- 剧情时间线是 **2026 年**；2000—2010 年代仅描述建筑与生活空间的年代感。手机 App 使用现代界面。
- 相机 App 先显示手机内页面，点击“拍摄”进入全屏真实取景；此按钮不直接拍照。取景时允许正常移动和鼠标观察，左键拍照，Esc/P 返回手机。
- 背包取消帆布背景：左侧竖排装备槽，默认显示装备；选中物品后原位显示物品详情。库存规则继续沿用。
- 装备栏使用部位名称、真实物品缩略图与明确空槽；状态使用不同颜色的完整量条，沉浸模式也始终可判断剩余量。装备和状态栏不使用 SVG 图标。修正反向文字并为序章不可通行边界补碰撞。
- 人物、NPC 与自定义捏脸遵循 `CHARACTERS_MODELS.md` 的统一角色、独立外观数据和后端适配层；本轮不扩展 Levels 1–11。
- 后续六项修订：手臂及手机握持需要自然关节姿态；背包图标按可见内容等比填入占格，不拉伸；实体门需带碰撞绕铰链开门，玩家出楼需迈步过门槛的过渡；普通通勤 NPC 应自然行走；由 Astra 全面审查 UI 的实际可读性、操作语义与沉浸感。仍保留默认无 VHS 和 1080p60 优先方向。

### 2026-09-07 后续八项交互与设置修订

- 拾取伸手期间隐藏主手物品表现，结束后恢复；不改变装备 UID，也不露出手机模态已隐藏的挂点。
- 发型按当前角色头皮坐标校准，覆盖头顶与后脑；沿用独立角色外观和附件后端。
- 背包与装备槽短点击仅选择，再点同物品取消选择；长按后才进入拖动，释放才尝试放置。每次打开默认无选择并显示装备栏。
- 目的显示为任务标题和若干待办事项。可选事项明确标注且不新增推进条件；完成项显示划除线并逐渐收起，条件失效时可重新出现。
- 游戏操作提示常驻屏幕上方，事件通知同样置顶；沉浸状态栏不隐藏这些提示。
- 普通 NPC 使用实体胶囊与玩家、世界、其他 NPC 碰撞。既有路线/停顿/转向行为保留。
- 设置分游戏、画面、音频、操作；游戏含开发者模式、动态准星、沉浸状态栏。画面分基础、光影、性能、氛围；提供窗口尺寸/模式、光影开关、抗锯齿/渲染比例/帧率/同步，以及行走晃动和可选 VCR 录像带滤镜。滤镜默认关闭。
- 本轮仍限序章与可复用核心改进，不扩展 Levels 1–11。

### 0.1 开发目标

制作一款第一人称、沉浸式、系统驱动的 Backrooms 生存探索 Demo。Demo 应证明以下核心体验成立：

1. **Frontrooms 的正常生活 → 异常发生 → noclip 切入后室**的完整情绪转折。
2. Level 0 不是“走迷宫直到找到门”，而是以**空间认知、感知异常、资源压力、迷失、规则学习**为核心。
3. UI 尽量 diegetic / 克制，不把游戏做成传统 FPS HUD；同时提供可切换的沉浸 HUD。
4. 建立可扩展的数据驱动架构，使后续 Level 1–11、阵营、实体、任务、声望、职业、生态、规则怪谈、交通网络都能在不重写核心代码的情况下加入。
5. Demo 首先保证“可玩、稳定、氛围正确”，其次才是视觉精度。

### 0.2 明确禁止

Agent 不应：

- 把所有系统塞进单个 `GameManager.gd`。
- 在 Level 0 随机刷大量敌人制造刺激。
- 用传统任务箭头持续告诉玩家出口在哪里。
- 用大量全屏文字解释 Backrooms 世界观。
- 将随机生成等同于“每个房间随机拼接”。空间必须具有可读性与受控异常。
- 为尚未制作的 L1–L11 编写大量不可维护的假实现。
- 将未来系统直接硬编码到 Level 0 场景脚本。

### Agent 实现说明强制规则

对于“描述容易、实现困难”的内容，Agent **不得只留下概念性 TODO**。涉及非欧几里得/未观察空间变化、超大场景流式加载、异形背包与嵌套容器、世界掉落物持久化、第一人称完整身体、手机与后室时间倍率、动态物品描述、noclip/Threshold、Manila Room 保底生成，以及后续实体 AI / 阵营 / 车辆 / 生态 / 跨层物流骨架时，必须先写出：**最小可行实现路径、核心数据结构、节点/状态机职责、性能兜底、Debug/验收方法**。

若完整版在 Demo 阶段成本过高，允许做可替换的 MVP，但必须明确 `MVP` 与 `Future Upgrade` 边界，不能用不可维护的硬编码假装完成。
- 因缺少最终美术而阻塞开发；允许灰盒和 placeholder。

### 0.3 技术原则

- Godot 4.x。
- GDScript 优先。
- 强类型 GDScript；避免 Variant 推断警告。
- 系统之间使用 signals / event bus / Resource 数据，而非相互深层硬引用。
- 场景小型化、组合化。
- Level 内容与通用系统分离。
- 所有关键参数放入 Resource / config，而不是散落 magic numbers。
- 先做单机；网络功能不属于 Demo 范围。

---

# 0.4 已确认的产品决策（Agent 不得自行改写）

以下属于用户已经确认的设计约束，优先级高于 Agent 的便利性推断：

- 主角由玩家自定义；角色创建伪装成前厅公司账号重新注册流程。
- 年龄 18–40，姓名/生日/性别/外观可设；公司与职位自动登记。
- 第一人称低头可见身体与腿，交互可见手臂。
- 世界物品是真实可丢弃/拾取实体；低重要度物品允许低模兜底。
- 初始高端笔记本电脑在后室无法开机，但不得断言永久损坏；说明随剧情变化。
- Chat 允许玩家自由输入。
- 前厅固定剧情时间按 1× 流逝；后室统一默认 24× 流逝，即现实 2.5 秒 = 游戏 1 分钟。
- Level 0 无实体、无其他生命、无疑似人影/脚步、无 Wanderer 留言/营地等生命痕迹；基础资源可以异常自然生成。
- L0 切入 L1 后立即结束 Demo。
- 物品可 90° 旋转，不自由堆叠；杏仁水等使用可变容器容量。
- 背包可嵌套，但装有物品时按完整体积占格并计入全部重量。
- 手机/手电可进入副手槽并通过副手快捷键使用。
- 难度与存档绑定：Casual 可手动存档；Hardcore 仅自动存档；Extreme 死亡删档。
- 自动保存至少发生于：角色创建完成、进入 Level 0、每次成功睡觉。
- 沉浸 UI 可开关；关闭时生存数值与图标始终显示。
- 简体中文为第一语言；前厅城市与货币模糊化。
- 保留 Frontrooms Keepsake 系统。
- **允许使用免费且开源的第三方资产与 Godot 插件**，包括模型、材质/贴图、音效、音乐、字体、图标、动画、Shader、工具脚本和编辑器插件，以降低 Demo 制作成本并加快迭代。
- 第三方内容优先选择 **CC0 / MIT / BSD / Apache-2.0** 等宽松许可证；不得因为“免费下载”就默认可以使用，必须确认实际许可证。
- 使用 **CC-BY / CC-BY-SA / GPL / LGPL** 或其他带署名、相同方式共享、源码公开、动态链接等义务的内容前，Agent 必须检查其许可证是否与项目发布方式兼容，并把义务记录下来；许可证不清楚时不得纳入正式项目。
- 禁止使用盗版、破解、来源不明、仅限个人用途、禁止再分发或与计划中的商业发布明显冲突的资产/插件。
- 每引入一个第三方依赖，都应登记到 `THIRD_PARTY_ASSETS.md`（没有则创建），至少记录：**名称、用途、来源页面、作者、版本/提交号、许可证、是否需要署名、本地路径、是否修改过**。
- 对关键插件应避免形成不可替代的架构锁定：核心存档、物品、角色数据、Level/Threshold 数据等必须保持项目自身可维护；第三方插件优先作为工具层、表现层或可替换实现。
- 外部资产允许作为 Demo 最终素材或 placeholder；若视觉风格不一致，优先通过统一材质、Shader、光照、后处理和必要的二次制作进行整合，而不是阻塞功能开发。

---

# 1. 项目目录建议

```text
res://
├── autoload/
│   ├── game.gd
│   ├── event_bus.gd
│   ├── save_service.gd
│   ├── scene_router.gd
│   ├── audio_service.gd
│   └── world_state.gd
├── core/
│   ├── interaction/
│   ├── inventory/
│   ├── equipment/
│   ├── phone/
│   ├── stats/
│   ├── items/
│   ├── objectives/
│   ├── dialogue/
│   ├── journal/
│   ├── spawning/
│   ├── procedural/
│   ├── persistence/
│   └── debug/
├── player/
│   ├── player.tscn
│   ├── player_controller.gd
│   ├── player_camera.gd
│   ├── player_interactor.gd
│   ├── player_stats.gd
│   └── player_audio.gd
├── ui/
│   ├── hud/
│   ├── inventory/
│   ├── equipment/
│   ├── phone/
│   ├── pause/
│   ├── journal/
│   ├── dialogue/
│   ├── notifications/
│   └── debug/
├── levels/
│   ├── prologue/
│   ├── level_0/
│   ├── level_1/
│   └── stubs/
├── entities/
│   ├── base/
│   └── stubs/
├── factions/
│   └── data/
├── quests/
│   ├── base/
│   ├── prologue/
│   └── level_0/
├── resources/
│   ├── items/
│   ├── levels/
│   ├── entities/
│   ├── factions/
│   ├── rules/
│   └── audio/
├── assets/
│   ├── models/
│   ├── textures/
│   ├── audio/
│   ├── fonts/
│   └── placeholders/
└── tests/
```

---

# 2. 基础游戏框架

## 2.1 主流程状态

实现：

```text
BOOT
→ MAIN_MENU
→ NEW_GAME
→ DIFFICULTY_SELECT
→ PROLOGUE
→ NOCLIP_TRANSITION
→ LEVEL_0
→ LEVEL_TRANSITION
→ LEVEL_1_ENTRY
→ DEMO_END
```

预留：

```text
LEVEL_1 ... LEVEL_11
THE_HUB
LEVEL_FUN
FREEPLAY
```

`SceneRouter` 负责切换场景；不要让关卡自行 `change_scene_to_file()`。

建议接口：

```gdscript
SceneRouter.travel_to(level_id: StringName, entrance_id: StringName = &"default")
SceneRouter.reload_current_level()
```

`WorldState` 保存跨场景状态：

- 当前 Level。
- 已发现 Level。
- 已发现出口。
- 玩家知识。
- 剧情 flags。
- NPC / faction 状态。
- 时间/旅程状态。

---

# 3. Player Controller

## 3.1 基础移动

必须支持：

- WASD。
- Mouse look。
- Sprint。
- Crouch。
- Jump：弱化，不允许 bunny hopping。
- Lean 可作为后续功能，Demo 非强制。
- Head bob：极轻微，可关闭。
- 第一人称身体：低头可见躯干与腿，常规交互可见手臂；镜面完整反射不属于 Demo 强制范围。
- 背包/装备在身体挂点上有对应表现；缺少高精模型时允许低模/通用模型兜底。
- Footstep material system。

运动应偏沉浸式，而非竞技 FPS。

### 推荐初始值

```text
Walk: 3.6 m/s
Sprint: 5.8 m/s
Crouch: 1.8 m/s
Jump: 低高度
```

全部放入 PlayerMovementConfig Resource。

## 3.2 Interaction

中心视线交互：

```gdscript
interface Interactable:
    get_interaction_text()
    can_interact(player)
    interact(player)
```

支持：

- 拾取。
- 门。
- 开关。
- 检查物体。
- 阅读。
- 使用物品。
- 与 NPC 对话。

不要为每种对象在 PlayerController 中写 `if object is ...`。

---

# 4. 生存属性

Demo 实现：

```text
Health
Stamina
Hunger
Thirst
Sanity / Mental Stability
Fatigue
```

但序章和 L0 不要让所有数值同时强烈下降。

### Level 0 重点

- Thirst：轻度压力。
- Stamina：即时。
- Sanity：重要。
- Hunger：极慢。
- Fatigue：用于长期迷失事件。

Stats 应使用 Modifier 系统：

```text
BaseValue
+ EquipmentModifier
+ EnvironmentModifier
+ StatusEffect
+ Faction/Skill Modifier
```

未来才能支持 Level 6、毒气、伤病、Buff 等。

---

# 5. UI / UX

## 5.1 HUD 设计原则

屏幕常驻信息尽量少。

默认 HUD：

- 中央极小准星，可在无交互时淡出。
- 左下/下方状态图标：只在属性变化或低值时显示。
- 当前手持物。
- 临时交互提示。
- 短暂 Objective 更新。

不要常驻：

- 小地图。
- 任务箭头。
- 敌人红点。

设置中提供 `Immersive HUD / 沉浸 UI` 开关：

- 开启：Health / Hunger / Thirst / Sanity / Fatigue 等不显示精确数字，只在变化、低值或角色产生明显身体反馈时短暂出现图标/状态。
- 关闭：上述状态图标与精确数值始终显示，便于偏系统化玩法与测试。
- 该选项只是显示方式，不改变难度与后台数值。

### 图标

- Health：心脏/医疗符号。
- Hunger：胃。
- Thirst：水滴或口腔/舌头抽象图标；Demo 用水滴以保证可读性。
- Sanity：大脑。
- Fatigue：眼睛。

## 5.2 Inventory / Equipment

Demo 的背包系统必须从一开始按最终游戏结构实现，不使用传统“固定 20 格 + 重量上限”的临时方案。

核心原则：

- **负重能力属于玩家身体属性**，不是背包本身。
- **物品栏可用格数、格子布局与形状属于当前装备的背包容器**。
- 背包本身是装备在 `Back` 槽位中的实体物品，可以脱下、丢弃、替换、损坏。
- 不同物品具有不同二维占格形状；允许旋转的物品可 90° 旋转。
- 物品除了占格，还具有重量。玩家必须同时考虑“有没有地方放”和“背不背得动”。
- 背包内物品不会因为切换场景自动整理。保持玩家摆放结果。
- 允许物品自由 90° 旋转；Demo 不实现任意角度旋转。
- 默认 `max_stack = 1`，不允许把多个同类实体自由堆叠到同一格；数量型资源应通过容器状态、弹药盒等具体物品表达。
- 背包可以装进其他背包，但必须遵守嵌套容器规则，禁止形成递归/无限容量漏洞。

### Equipment Slots

至少预留：

```text
Head
Face
Torso
Legs
Feet
Back
Primary Hand
Secondary Hand
Accessory 1
Accessory 2
```

Demo 实际必须使用 `Back` 与双手槽，其余可以先作为可工作的空槽骨架。

`Secondary Hand` 是额外的可使用快捷槽：装备手机、手电等后，可通过副手快捷键直接使用；同一物品放在 `Primary Hand` 时也必须支持右键/Use 使用。快捷槽只引用真实物品，不复制物品。

### ContainerDefinition

背包不要硬编码格数。使用 Resource：

```gdscript
class_name ContainerDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var grid_width: int
@export var grid_height: int
@export var blocked_cells: Array[Vector2i]
@export var allowed_tags: Array[StringName]
```

`blocked_cells` 用于制作非矩形内部结构。以后军用背包、医疗包、工具腰包、枪套都复用此系统。

### ItemDefinition

```gdscript
class_name ItemDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var description_key: StringName
@export var icon: Texture2D
@export var world_scene: PackedScene
@export var weight_kg: float
@export var inventory_shape: Array[Vector2i]
@export var can_rotate: bool = true
@export var max_stack: int = 1
@export var tags: Array[StringName]
@export var use_action: StringName
@export var equip_slot: StringName
@export var frontrooms_keepsake: bool = false
@export var world_visual_fallback: StringName = &"generic_lowpoly"
```

不要假设所有物品都是矩形。`inventory_shape` 必须支持 L/T/不规则物品；Demo 内可以先主要使用矩形。

物品的显示说明不得只存一个静态字符串。实现 `ItemDescriptionResolver`，根据 `WorldState`、Level、使用次数、剧情 flag、持有时长等返回多行动态说明。说明可随玩家经历变化，但不要覆盖物品原始数据。

物品实例必须与定义分离：`ItemDefinition` 描述“这是什么”，`ItemInstance` 保存“这一件现在是什么状态”。实例至少预留 `condition`、`charge`、`contents`、`custom_flags`、`container_inventory`。

### 初始电脑包

玩家序章开始时拥有一个普通但偏高档的**电脑单肩包 / 通勤电脑包**，装备于 `Back`。它应刻意设计得不适合后室生存。

建议内部约为：

```text
6 × 5 grid
```

但通过 `blocked_cells` 与固定内衬表现真实电脑包结构。

初始内容建议：

- 高端大型笔记本电脑：约 `4×3` 或 `5×3`，重量明显，占据大部分空间。
- 笔记本电源适配器：`2×2`。
- 手机：`1×2`。
- 钱包：`1×1`。
- 钥匙：`1×1`。
- 耳机：`1×1` 或 `2×1`。
- 纸巾 / 充电线等日常用品。
- 玩家在上班路上购买的一瓶普通瓶装水：`1×2`。

物品布局不要自动优化。第一次打开背包时，玩家应一眼看出：

> “这个包几乎全被电脑和日常用品塞满了。”

这是教程，不是文字说明。

### 重量与行动

玩家拥有 `carry_capacity_kg`。负重阶段建议：

```text
0–60%     Normal
60–85%    Encumbered：耐力恢复略慢
85–100%   Heavy：冲刺成本明显增加
>100%     Overloaded：禁止冲刺，移动明显变慢
```

不要因为超重禁止拾取；允许玩家做出“我先硬背着走”的决定。

### Grid UI

背包 UI 类似生存游戏的二维拼包：

- 拖拽物品。
- 合法位置高亮。
- 冲突位置提示。
- `R` 旋转。
- 显示物品实际形状。
- 显示总重量 / 玩家负重能力。
- 显示当前装备的容器名称与容量，而不是写死 `Backpack 20 Slots`。

### “忘记前厅”与物品价值转换

初始大型笔记本电脑必须是有意设计的叙事物：

在前厅：

- 昂贵。
- 工作所需。
- 玩家自然会认为不能丢。

进入后室后，电脑**不能开机**，但游戏不得宣告“已经彻底报废”，也不要给出明确维修结论。它仍然很重并占据大量空间。动态说明按阶段变化：

前厅：

> “这是你以前花了大钱买下的高性能电脑，里面存放着你的工作数据与不少奋斗经历。”

刚进入后室、尝试检查/使用后：

> “开不了机，好像是摔坏了。你家附近有一家电脑店，那家老板非常热情，他一定能帮你修好这台电脑。”

当玩家已经在 Level 0 生存一段时间、资源与负重压力明显且仍携带电脑时，再追加：

> “这个奢侈品已经成为了你的负担。你更需要丢弃它，然后活下去。”

最后一句必须由状态条件触发，而不是进入 Level 0 立刻出现。不要强制玩家丢弃；保留电脑属于有效选择。

Level 0 获得杏仁水、手电、电池或更多资源后，游戏**不弹出“请丢弃电脑”提示**。只让格子和重量自然产生冲突，让玩家自己决定。

这应成为 Demo 第一次核心资源抉择：

> 保留前厅里价值极高、承载过去生活的东西，还是腾出空间活下去？

不要强制玩家扔。有人可以一直背着电脑完成 Demo。后续世界甚至可以对这种坚持做出回应。

### Demo 核心物品尺寸建议

```text
手机              1×2
钱包              1×1
普通瓶装水        1×2
杏仁水            1×2
手电筒            1×2
电池盒            1×1
简易食物          2×1
纸条              1×1
高端笔记本电脑    4×3 / 5×3
电源适配器        2×2
```

Quick Slots 不与背包容量等价。快捷栏只引用背包中可快速使用的物品，不能凭空存放物品。

### 可变容量 / 电量 / 内容物

不要把“喝一次就删除物品”写死。建立通用实例状态：

```text
CapacityState
current
maximum
unit
content_type
```

示例：杏仁水瓶初始可为 `90/100`，一次饮用消耗 `30`。降到 `0/100` 后仍保留空瓶，它仍是可重复利用的液体容器；任何未满瓶均可在合法杏仁水源补充。普通水瓶也复用同一容器机制。

电量使用相同思想，但使用 `ChargeState`：手机、手电等拥有当前/最大电量，可由兼容电池、充电器或未来电源设施补充。液体和电量共享“可变实例状态”基础接口，但不要把两者业务逻辑混成同一个类。

### 嵌套背包规则

背包允许放入背包。空背包折叠后使用较小的 `empty_inventory_shape`；只要内部存在任何物品，就使用其完整 `packed_inventory_shape`，该尺寸原则上应接近/等于其自身可提供容量，防止俄罗斯套娃扩容。禁止容器直接或间接装入自身。嵌套容器中的所有物品重量仍计入玩家总负重。

### 世界物品与低模兜底

拾取物丢弃后应成为真实世界实体，并能在持久化范围内重新拾取。优先使用专属模型；对大量雷同或低重要度物品允许使用低模通用几何体 + 图标/标签材质兜底。重要前厅遗物、杏仁水、手机、电脑、背包等必须有可识别模型。持久化系统保存物品实例数据而不是整个 Node。

## 5.3 前厅遗物（Frontrooms Keepsake）

手机、钱包、钥匙、电脑、耳机等开局携带物可标记 `frontrooms_keepsake = true`，并记录其来源为玩家的前厅生活。该标签不自动提供属性加成，而用于：动态物品说明、Journal、未来 NPC 对话、Level 11 住宅陈列、结局统计与“忘记前厅”主题。

不要把“遗物”理解为必须保存的收藏品。玩家可以丢弃、遗失或消耗其中一部分；世界状态记录玩家是否仍保有某件关键遗物。

## 5.4 Journal

Demo 就建立后续核心 Journal 框架：

```text
Levels
Entities
People
Factions
Rules
Routes
Notes
```

L0 初始只有：

```text
LEVEL 0
Name: Unknown
Safety: Unknown
Known Exits: None
Notes: ...
```

随着玩家经历自动更新，而非开局把 Wiki 全塞进去。

---

## 5.5 语言与前厅地域

Demo 的第一语言为**简体中文**；UI、手机、系统提示、默认字幕和内容资源首先以 `zh_CN` 完成，所有用户可见字符串从一开始使用本地化 key，禁止散落硬编码中文以妨碍未来翻译。

前厅采用**模糊城市**：不明确绑定现实国家/城市，不使用真实地图服务；货币使用模糊化/虚构通用表示，避免通过货币符号锁死地区。手机 UI 默认简体中文。

# 6. 教程 / 序章：切入前完整内容

## 6.1 目标与长度

序章必须短。目标不是讲故事背景，而是让玩家在一个非常普通的早晨完成全部基础操作教学，然后在**上班路上毫无预兆地切入后室**。

首次游玩目标长度：**约 5–8 分钟；熟练玩家 2–4 分钟即可完成。**

核心节奏：

```text
醒来 / 准备上班
→ 在房间内完成移动、交互、背包、装备、手机教程
→ 出门
→ 顺路买水（可选但自然引导）
→ 普通城市步行
→ 一个微妙的不协调瞬间
→ 意外 noclip
→ Level 0
```

不要设计“逐级升级的灵异走廊”“重复门牌”“长时间异常调查”等序章内容。玩家没有理由在前厅主动调查 Backrooms。异常应该像现实生活里一个来不及理解的事故。

## 6.2 场景范围

为了控制 Demo 成本，只制作：

```text
Player Room / Small Apartment
→ Building Exit
→ Very Short Street Segment
→ Convenience Store / Vending Point
→ Commute Segment
→ Noclip Point
```

街区只需给出“城市继续延伸”的视觉假象，不需要开放世界。利用封闭街角、远景建筑、车辆、行人背景动画与不可进入商铺制造生活感。

### CharacterProfile 数据

角色创建写入独立 `CharacterProfile`：

```gdscript
class_name CharacterProfile
extends Resource

@export var surname: String
@export var given_name: String
@export var birth_date: Dictionary
@export var gender_id: StringName
@export var appearance_preset: Dictionary
@export var company_id: StringName
@export var job_id: StringName
@export var employee_id: String
```

姓名允许常见 Unicode 字符并做长度/非法控制字符校验。生日必须基于固定剧情日期校验 18–40 岁。外观系统 Demo 至少提供体型/肤色/发型/发色/面部预设等可组合选项；不要要求捏脸达到商业 RPG 复杂度。

## 6.3 开场：全部基础教程都在房间里完成

黑屏先播放手机闹钟。淡入玩家刚睡醒的普通前厅房间。手机显示一个**固定剧情日期与固定开场时刻**，之后在前厅按现实 1:1 速度流逝；绝不读取玩家设备系统时间。

玩家从手机信息与界面语气判断“时间已经比较紧，需要去上班”，但**不要告诉玩家具体几点必须打卡**，也不要做真实倒计时或迟到失败，以免角色创建与探索房间受到惩罚。

玩家发现公司 App / 企业账号莫名被注销或本地登录资料失效，只能重新注册/登记。这个小故障不应被描写成超自然事件，而是很日常的烦人技术问题。利用此次注册完成角色创建：

- 姓氏。
- 名字。
- 生日；由生日计算年龄，开局必须在 18–40 岁之间。
- 性别。
- 头像/外观自定义。

公司、职位、员工编号等由系统根据模板自动登记，不要求玩家填写；避免职位影响 Demo 数值。角色外观至少驱动第一人称可见身体、手臂和头像。完成个人信息与形象后立即执行一次强制自动保存。

任务只有：

```text
去上班
```

不要显示 Backrooms 标题，不暗示恐怖游戏即将开始。

教程按玩家实际行为逐项短暂提示：

```text
WASD — Move
Mouse — Look
E — Interact
Tab — Inventory
P / Phone Key — Phone
Shift — Sprint
Ctrl — Crouch
```

但 Sprint / Crouch 不需要玩家真的在房间内完成障碍训练；只需在准备离开前用很短的提示告知。

房间内必须完成以下实际操作：

1. 玩家起身并移动。
2. 关闭闹钟 / 拿起手机，教学交互。
3. 打开手机，发现公司账号失效并完成角色注册/外观创建；确认当前时间。
4. 打开电脑包，教学二维格子背包。
5. 检查高端笔记本电脑，让玩家看到它占据巨大空间与较高重量。
6. 教学拖动物品与旋转，但不要要求重新整理出“正确答案”。
7. 查看 `Back` 装备槽，理解背包是装备物而不是角色永久 UI。
8. 拿钥匙 / 钱包等必要日常物品。
9. 开门离开。

完成第 4–7 步后即可认为 Inventory/Equipment 教程完成；以后不要重复弹窗。

## 6.4 前厅房间内容

房间的作用是表现一个可由玩家定义身份的普通成年人正在准备上班。环境避免预先写死姓名、性别、具体职业经历。

可交互内容建议：

- 手机。
- 电脑包与笔记本电脑。
- 钱包 / 钥匙。
- 水杯。
- 衣柜 / 外套。
- 镜子。
- 窗户。
- 电脑桌。
- 门。

背景细节可以暗示工作、朋友与生活，但不要给主角写大量不可修改的传记。

## 6.5 手机系统：前厅状态

手机不是序章道具，而是贯穿游戏的长期系统。Demo 从前厅开始就必须使用同一套 Phone Framework。

打开手机后显示接近现实的主屏幕，至少包含可打开的占位应用：

```text
Chat
Maps
Browser
Phone
Camera
Clock
```

手机使用统一 `WorldClock`，但不同世界状态具有不同时间倍率：

- **前厅**：固定剧情日期/开场时间，倍率 `1.0`，即现实 1 秒 = 游戏 1 秒；不读取设备时间。
- **进入后室后**：倍率变为 `24.0`，即现实 **2.5 秒 = 游戏 1 分钟**，现实 1 小时 = 后室 1 天。
- 切入时手机时间连续推进，不瞬移到另一随机日期；异常体现在时间流速改变。
- 暂停菜单暂停单机世界时钟。

所有后续 Level 默认继承后室倍率，除非某 LevelDefinition 明确覆盖。

前厅应用内容：

**Chat**：展示几段已经存在的普通聊天，例如同事、朋友、群聊。允许玩家点击输入框并自由输入任意文本。前厅中为了不展开支线，NPC 不需要实时回复玩家新输入的内容；已有聊天记录用于体现日常生活。玩家自己输入的消息必须保存。

**Maps**：显示普通前厅城市地图与上班路线。只需要小范围假地图，不需要真实地图服务。

**Browser**：允许打开几个静态页面 / 最近访问记录，例如天气、新闻、工作相关网页或搜索首页，用于生活感。不要接真实互联网。

**Phone**：显示联系人与最近通话。序章不允许玩家真正拨出有效电话，可提示“现在不是打电话的时候”或让呼叫立即取消，但避免强制感过强。

**Camera**：真正调用手机相机视图，可拍摄并把截图保存到游戏内相册数据。

**Clock**：正常时间、闹钟信息。

关键：这些应用可以浏览，但不是前厅沙盒。它们用于让玩家感觉自己有一个“已经存在的生活”。

## 6.6 出门与买水

玩家离开住宅后不要再安排教程房间。

上班路线非常短。HUD 只保持一个低存在感目标：

```text
去上班
```

途中经过便利店、自动售货机或小商店。通过轻量环境提示让玩家想到买水，例如：

- 手机天气页显示今天偏热。
- 玩家房间水瓶为空。
- 商店门口明显摆有饮料。
- Objective 可出现非强制子提示：`顺路买瓶水`。

玩家购买普通瓶装水后，水直接作为 `1×2` 物品进入电脑包。若包内布局没有对应空间，必须打开 Inventory 自己挪位置。这里自然完成第二次背包强化教学。

**买水最好不是硬性门槛。** 不买也允许继续；这样进入 Level 0 后，有水和没水会形成不同的开局资源状态。

## 6.7 日常异常感

切入前的“日常异常感”**只允许保留以下两点，不要额外增加路人消失、透视异常、地图漂移、文字故障、闪烁黑影等预兆**：

- 商店灯光的嗡鸣与后续 Level 0 荧光灯频率有一瞬相似。
- 玩家经过某处时环境声突然被吸走半秒。

两者都必须非常轻微，不触发 Objective，不让角色自言自语“怎么回事”，也不要求玩家调查。它们的目的不是提前告诉玩家“超自然事件正在发生”，而是在玩家进入 Level 0 后回想起来才产生联系。

## 6.8 Noclip 事件

玩家继续上班。事故应发生在一个完全不值得注意的位置，例如：

- 地铁 / 办公楼入口附近的人行通道。
- 建筑侧面一块普通墙角。
- 施工围挡旁边。
- 两栋建筑之间非常普通的转角。

推荐流程：

1. 玩家正常走路。
2. 路面或墙角碰撞在极短时间内表现异常。
3. 玩家一只脚像踩空一样失去支撑。
4. 摄像机急剧失衡，而不是播放预渲染 Cutscene。
5. 手机 / 手上物品根据当前状态被角色本能抓住或收回。
6. 城市声快速远离，荧光灯 hum 混入。
7. 玩家穿过一个本不应该能穿过的表面。
8. 短黑屏。
9. 重重落在 Level 0 地毯上。

整个异常发生后不应给玩家时间回头“研究入口”。不要传送门、裂缝、粒子漩涡或巨大恐怖音效。

核心感觉：

> 刚才明明只是去上班。

## 6.9 切入后的第一秒

玩家落地后保留所有当时携带的前厅物品、背包布局、重量与手机电量。没有“游戏开局清空背包”。

如果玩家买了水，水还在。

如果玩家没有整理电脑包，它仍然被昂贵的笔记本电脑塞满。

如果玩家在切入前打开手机，相机/应用状态可重置到锁屏，但手机本体必须仍在。

玩家起身、观察黄色墙壁数秒后，仅克制显示：

```text
THE BACKROOMS
```

再淡出。不要显示 `LEVEL 0`，因为角色此时没有这个知识。

# 7. Level 0 完整内容

## 7.1 设计核心

Level 0 是游戏真正的 onboarding Level。

玩家学习：

1. **空间不可信。**
2. **不要只依赖视觉。**
3. **资源有限。**
4. **记录路径很重要。**
5. **异常不一定是实体。**
6. **孤独本身就是压力。**
7. **离开 Level 需要观察和试验，而非寻找传统出口门。**

Level 0 不应依赖常规敌人。

## 7.2 美术语言

核心元素：

- 单调黄色壁纸。
- 潮湿旧地毯。
- 荧光灯。
- 低矮吊顶。
- 不合理转角。
- 偶发裸墙/破损墙纸。
- 极少家具。

视觉必须“相似但不完全相同”。

房间模块必须分成“普通模块”和“Wikidot 结构变种”。**最新 Wikidot Level 0 列出的常见结构异常在 Demo 中缺一不可：Arches、Pillars、Holes、Blackout Zones、Red Rooms，以及 Layout Changes / Peripheral Shift。** 这些不是纯换皮房间，而必须改变玩家的移动、导航或风险判断。

普通模块可包括：

```text
Straight Room
L Room
T Junction
Wide Hall
Narrow Hall
Dead End
Low Ceiling Room
Wallpaper Damage Room
Carpet Flood Room
Large Empty Chamber
```

必须实现的结构变种：

| 变种 | 游戏表现 | 最低实现要求 |
|---|---|---|
| **Arch Variation / 拱门区** | 浅色墙体、连续拱洞、地毯更深更湿；相对稳定 | 作为 `STABLE` 房间族，降低 Peripheral Shift 权重；深湿地毯提高移动体力消耗；拱洞局部可短暂坐靠休息 |
| **Pillar Variation / 立柱区** | 大尺度规则柱阵，浅地毯，看似容易定向但身后连接容易改变 | 用可重复柱阵 Chunk + 雾/遮挡控制尺度；进入时记录玩家选定 heading；离开视野后的边缘连接允许重新接线 |
| **Hole Variation / 孔洞区** | 地面出现规则网格状深坑，光照无法照到底 | 坑必须是真实碰撞危险而非贴图；跌落视为死亡/失踪结局；疲劳或超重时跨越/绕行更危险 |
| **Blackout Zone / 断电区** | 无灯、粗糙墙面、荧光嗡鸣消失，局部地面可积有脚踝深液体 | 进入时切换独立环境总线与黑暗材质组；禁止假实体；玩家应能通过远处微光或荧光嗡鸣方向寻找出口 |
| **Red Rooms / 红房间** | 色调逐渐转红、地毯变厚黏粗、墙纸剥落露出深红；越深入越难退出 | 作为高危“闭环”区域，不作为普通随机房间；使用单向风险状态机逐步封闭返回图连接；必须在完全陷入前给出可读环境预兆 |
| **Layout Changes / Peripheral Shift** | 未被观察的 Level 0 连接发生变化 | 由 `SpatialMutationDirector` 修改**房间图连接**而非在玩家眼前移动 Mesh；详见 7.4 |

不要把这些变种做成一次性剧情走廊。除 Manila Room 外，它们都应能由受约束生成器重复出现，只是概率和强度不同。

## 7.3 生成策略

不要在 Demo 中尝试真正无限地图。

使用：

### Controlled Chunk Streaming

玩家周围保持若干房间 Chunk。

后方足够远、不可见且不重要的 Chunk 可以回收。

但关键区域 / landmarks / 已标记地点应保持逻辑稳定。

系统：

```text
Level0Generator
├── ChunkGraph
├── RoomTemplateLibrary
├── ConstraintSolver
├── LandmarkSpawner
├── AnomalyDirector
└── PersistenceMap
```

生成要求：

- 避免明显重复连续出现。
- 保证路线有环。
- 保证死路存在但不过量。
- 控制长直线概率。
- 关键剧情节点使用 authored chunk，而不是随机生成。
- 生成器必须维护 `RoomTag` / `VariantTag`，让测试工具可以强制生成每一种 Wikidot 变种。
- Demo 的自动化/调试验收必须能证明六类结构内容均可到达，不能因为随机种子导致某个变种事实上永远看不到。

### 7.3.1 对“无限 Level 0”的可实现方案

不要真的保存无限几何。世界逻辑采用**有限活动窗口 + 可重建图状态**：玩家附近只实例化活动半径内 Chunk；每个逻辑房间使用稳定 `room_id`；超出活动半径的 Mesh/Collision 可以释放，但模板、随机参数、拾取状态、玩家标记和关键 mutation 保存在 `PersistenceMap`。返回时用 `room_id + world_seed + mutation_revision` 重建。只有满足 Peripheral Shift 条件的连接才允许在卸载期间变化。Manila Room、已发现出口、关键玩家掉落物所在房间属于 `protected_landmark`。

### 7.3.2 结构变种的推荐实现

统一使用 `RoomTemplate` Resource，而不是为每种变种写独立 Level：

```gdscript
class_name RoomTemplate
extends Resource

@export var template_id: StringName
@export var scene: PackedScene
@export var tags: Array[StringName]
@export var connector_types: Array[StringName]
@export var stability_weight: float = 1.0
@export var traversal_cost: float = 1.0
@export var mutation_resistance: float = 0.0
@export var hazard_profile: Resource
```

Arch 添加 `stable_arch`，Pillar 添加 `pillar_grid`，Hole 添加 `fall_hazard`，Blackout 添加 `blackout`；Red Rooms 不进入普通权重池，而由 `RedRoomDirector` 在满足条件时挂接。美术优先用模块化墙、柱、拱、吊顶和地板组合，避免每个房间都制作完整独立 Mesh。

## 7.4 “空间漂移”

Level 0 最大技术特色之一。

只有在玩家没有观察时才允许轻度改变：

- 某条回路长度变化。
- 门口变成墙。
- 墙出现新缺口。
- 地毯污迹位置改变。
- 房间连接被替换。

必须遵守：

```text
Never mutate geometry inside player's direct view.
Never mutate immediate escape route during danger.
Never make every route unstable.
```

否则玩家会认为游戏作弊。

建立：

```gdscript
SpatialMutationDirector
```

参数：

```text
mutation_frequency
max_graph_distance_change
player_observation_memory
protected_landmarks
```

### 7.4.1 Peripheral Shift 的具体实现

每个房间维护 `ConnectorSocket`，逻辑图与实际 Mesh 分离。Camera 周期性更新“被直接观察的房间/连接口集合”，结合 Frustum、遮挡 RayCast 与距离即可。连接只有在**不在直接视野、离玩家至少 N 个 graph hops、不是 protected landmark、不会切断唯一安全路径**时才可 mutation。

mutation 优先修改图的边：例如 A→B 改成 A→C，其次才替换远端房间模板。禁止移动玩家脚下碰撞体、瞬移正在观察的墙，或在玩家身后极近距离凭空封路。

Debug 模式必须显示逻辑 Graph、observation set、protected nodes 和 mutation history，以区分“设计中的异常空间”与生成 Bug。

## 7.5 声音系统

Level 0 的真正“敌人”之一是声音。

至少建立多层音频：

```text
Fluorescent Base Hum
Electrical Variants
Distant Mechanical Noise
Carpet Steps
Player Breathing
Rare Distant Impact
Rare Unexplained Footstep
Silence Zones
```

荧光灯不能是一段 loop 从头放到尾。

根据区域参数混合：

```text
Pitch
Buzz density
Flicker
Distance attenuation
Electrical fault
```

### Silence Zone

极少数区域灯仍亮，但 hum 突然消失。

这应该比普通黑暗更令人不安。

## 7.6 光照

实现：

- 正常荧光灯。
- 老化闪烁。
- 部分损坏。
- 短时熄灭。
- 极少数完全暗区。

不要让每盏灯都随机闪。

使用 LightState Resource / seeded variation。

## 7.7 Sanity

Level 0 的 Sanity 不等于“疯了”。

主要表示：

- 注意力。
- 感知稳定。
- 压力。
- 孤独造成的认知负荷。

低 Sanity 可以产生：

```text
轻微耳鸣
荧光灯嗡鸣的主观增强/减弱
房间熟悉感增强
呼吸急促
交互文字短暂延迟
轻微视觉曝光变化
```

**不要**让低 Sanity 直接刷怪。

不要用廉价 jumpscare。

## 7.8 Level 0 的生命缺席原则

Level 0 的普通区域必须保持本项目确定的核心体验：**不出现实体，不出现其他活人，也不使用疑似人影、疑似脚步、刚刚有人经过等“假生命”恐怖。** 最新 Wikidot 对实体是否存在保持“未确认”，但本 Demo 明确选择不生成实体。**Manila Room 是唯一策划例外：允许出现组织留下的纸质说明与补给，但 Demo 首次抵达时不生成其他 Wanderer/NPC。**

恐怖来源只允许来自空间、荧光灯、重复结构、孤独、资源压力和玩家自己的方向感。不要通过“也许有人”缓解或破坏这种绝对空旷感。

## 7.9 资源

Level 0 资源必须稀少，但生成逻辑要保证首次流程的最低生存可行性。

玩家进入时首先保留所有前厅携带物资；此外 Level 0 会以低密度自然生成少量基础生存物资，确保新玩家不会因为第一次探索稍慢就在首层饿死/渴死。

可生成：

- 1–3 瓶杏仁水。
- 少量兼容电池。
- 极少量密封基础食物。
- 少量无明确人类来源的实用杂物。
- 壁纸碎片等环境材料。

这些物品按“异常出现 / noclip 到此处的物资”处理，不布置成营地、尸体、留言、废弃背包、生活垃圾或其他能证明有人曾在这里生活的痕迹。资源生成器应有最低保障阈值，但不要在玩家面前凭空刷出。

Loot 不使用发光描边。

玩家必须靠观察。

## 7.10 杏仁水首次教学

玩家找到一瓶陌生液体。

Journal：

```text
Unknown Bottle
Clear liquid. Faint almond smell.
```

玩家可以：

- 喝。
- 不喝。
- 保存。

第一次喝后：

- Thirst 恢复。
- Sanity 小幅恢复。

Journal 才更新：

```text
Almond Water (?)
Appears safe.
```

不要因为玩家知道 Backrooms 就开局显示完整资料。

## 7.11 标记路线

Level 0 应允许玩家主动建立导航信息。

Demo 至少实现一种：

- 粉笔 / Marker。
- 放置物品。
- Journal 手动标记 Landmark。

推荐实现简单墙面 Marker：

```text
Arrow
X
Circle
Number
Custom short text (optional)
```

之后空间发生漂移时：

标记可能仍在，但连接改变。

这会非常有效地告诉玩家：

> 不是我记错了。

## 7.12 Level 0 事件导演

建立 `Level0EventDirector`，不要固定每隔 X 分钟触发。

事件池：

### Ambient
- 灯闪。
- 远处碰撞声。
- 水渍。
- 温度感变化。

### Spatial
- 回头出现不同连接。
- 重复房间。
- 超长走廊。
- 不合理环路。

### Psychological
- 荧光灯主观音量变化。
- 重复结构造成的熟悉感。
- 在无生命迹象前提下产生的孤独/认知压力。

### Progress
- 第一瓶杏仁水。
- 第一个明显 noclip hint。
- 出口事件。

Director 必须考虑：

```text
elapsed_time
player_sanity
recent_events
player_progress
current_chunk_type
```

避免连续触发相同事件。

---

# 8. Level 0 的叙事内容

## 8.1 绝对孤独

Level 0 的普通区域不使用 NPC、实体、留言、营地、尸体、脚印、旧地图或其他可确认的生命活动痕迹。玩家在 Demo 中不能得到“这里刚刚还有别人”的安慰。**唯一例外是 Manila Room：桌面文档和志愿者补给是明确、受控的文明痕迹，用来承担 L0 终端教学功能。不要把这种痕迹扩散到普通黄房间。**

## 8.2 环境叙事

叙事只通过 Level 0 自身完成：墙纸差异、湿地毯、荧光灯、不可解释的房间连接、局部结构变化、偶尔出现的基础物资，以及玩家从前厅带来的物品。Level 0 的核心问题不是“谁来过这里”，而是“这里为什么存在，以及我怎么出去”。

## 8.3 手机：进入后室后的状态转换

手机必须是**同一台前厅手机、同一电量、同一相册、同一聊天记录**，而不是换成“后室 PDA”。

切入 Level 0 后立即更新系统状态：

```text
Cellular: No Service
Wi-Fi: None
GPS: Position Unavailable
Internet: Offline
Local Time: Accelerated (24× world-time rate)
```

手机仍可完整打开并交互：

- **Chat**：玩家可以尝试发送消息。消息进入 `Sending...` / `Not Delivered`，永远没有前厅回应。旧聊天记录仍可查看。
- **Maps**：保留最后一次前厅地图缓存，但定位失败。不要立即显示后室地图。
- **Browser**：已缓存页面可查看；任何新网址或刷新请求失败。
- **Phone**：允许拨号，但无信号，呼叫失败。
- **Camera**：仍然可拍照，并保存本地照片。
- **Clock**：显示连续但已加速的后室时间；现实 2.5 秒推进 1 游戏分钟。

不要额外制造随机时间跳变。Demo 的默认规则是：**普通数字设备在 Level 0 仍能作为本地设备工作，只是失去外部网络与可靠定位，并随统一后室世界时钟以 24× 速度推进。** 如果未来某个 Level 会进一步影响电子设备，再通过 Level Modifier 系统实现。

### 手机作为“失联”的叙事工具

第一次切入后，允许玩家主动打开 Chat。游戏不强制弹窗。

如果玩家尝试发送：

> “我不知道我在哪。”

或选择预设的极少数消息动作，界面只显示发送失败。不要让前厅联系人神秘回复。这里的恐怖来自**没有任何回应**。

### M.E.G. 后续升级骨架

手机 UI 从一开始预留本地可安装 App / Offline Package 机制。未来首次接触 M.E.G. 后，M.E.G. 可以通过本地数据传输、离线包、局域网或其他设定内方式安装：

```text
M.E.G. Map
G.P.D. / Backrooms Database
Route Cache
Emergency Guide
Local Faction Contacts
```

届时：

- `Maps` 从“前厅缓存地图 + 无定位”升级为基于玩家已知信息的后室离线地图。
- `Browser` 可以增加 G.P.D./M.E.G. 离线数据库，而不是突然恢复互联网。
- `Chat/Contacts` 可以在存在局域通信设施的 Level 中连接后室联系人。
- 手机因此从“前厅生活遗物”逐步转化为“后室生存终端”。

必须保证这个升级是数据层变化，而不是替换一套全新的 Phone Scene。

---

## 8.4 Manila Room：Level 0 的终端与第一次明确出口教学

Manila Room 必须存在，而且不是普通随机彩蛋。按当前 Wikidot 设定，它是 Level 0 中内部稳定的特殊房间：约 8×8 米、米色墙纸、木地板、八角桌与两把椅子、四面木门；桌上存在 Backrooms / noclip 资料，桌下柜体可有志愿者从别处带来的补给。靠近时荧光灯嗡鸣逐渐淡去，并出现舒缓钢琴声。Demo 第一次抵达时不强制生成其他人。

在本游戏里它额外承担明确玩法职责：**第一次可靠地告诉玩家，此前可能见过的“闪烁墙面”就是 Level 0 的出口，穿过后可抵达 Level 1。**

### 抵达 Manila Room 前

中前段即可低概率生成 `FlickeringWallCandidate`。它仍像普通墙，只出现短暂、不规律的相位/灯光闪烁；不显示“出口”、Noclip、任务箭头或交互轮廓。玩家可以提前发现甚至主动尝试。

**知识不是通行证。** 如果玩家在没有读 Manila 文档的情况下正确尝试 noclip，出口必须照常工作并直接进入 Level 1；不得用剧情锁强迫先去 Manila Room。

### Manila Room 的保底生成

不能完全依赖 RNG。采用 `pity + authored insertion`：早期概率为 0；完成最低探索后概率逐步增加；经历主要 L0 结构变种与一定生存压力后，Director 可把 Manila Room 安排为未来可达 landmark；设置流程上限，保证首次 Demo 不会因坏随机种子永远找不到。发现后立即标记为 `protected_landmark`。

入口使用棕色墙面中的木门。

### 文档与 Knowledge 解锁

不要弹系统教程窗口。玩家阅读桌面纸质资料后明确获得：

```text
knowledge.level0.flickering_wall_exit = VERIFIED
knowledge.noclip.basic = KNOWN
knowledge.level1.exists = KNOWN
```

资料必须让玩家明确理解：

```text
LEVEL 0
异常闪烁的墙面可能是出口。
不要寻找普通的门。
尝试穿过它。
NOCLIP → LEVEL 1
```

此后再看到闪烁墙时，才允许根据“沉浸 UI”设置提供非常克制的 contextual affordance；沉浸模式不要画巨大出口图标。

### 资源与实现

柜体物资来源标记为 `VOLUNTEER_SUPPLY`，与普通 L0 自然生成物资分开。Manila Room 是喘息、理解规则、补充最低资源、再返回 Level 0 寻找闪烁墙的终端，不是长期基地。

建议创建：

```text
ManilaRoom.tscn
ManilaRoomController.gd
ManilaDocumentReader.tscn
KnowledgeUnlockResource.gd
FlickeringWallComponent.gd
```

`FlickeringWallComponent` 只负责异常表现、碰撞/穿越窗口和 Threshold 触发；是否显示提示由 `KnowledgeSystem` 决定。这样玩家提前知道 noclip、跳过 Manila Room 或未来从其他来源获得知识时，底层出口仍然正常工作。

---

# 9. Level 0 完整进度结构

目标总时长：首次玩家约 **30–60 分钟**。

不是硬计时。

### Phase 1 — Arrival

0–5 min。

玩家醒来。

此阶段**不再重复前厅已经完成的操作教学**。玩家可以立即打开手机、背包和装备界面，验证所有前厅物品仍然存在。

主要让玩家自然注意到：

- 手机失去网络、GPS 与电话服务，但本地功能仍正常。
- 普通瓶装水（若购买）突然从“顺路消费品”变成重要资源。
- 昂贵笔记本电脑仍然占据大量空间和重量。
- 玩家开始第一次考虑是否要保留前厅日常用品。
- Level 0 没有明显 NPC 或出口。

没有明显异常事件，让玩家先体验空间和失联感。

### Phase 2 — Orientation

5–15 min。

出现：

- 人类痕迹。
- 第一个环路。
- 第一瓶杏仁水。
- 第一次明显灯光事件。

Journal 解锁：

```text
Unknown Area
```

### Phase 3 — Disorientation

15–30 min。

空间漂移开始明显。

出现：

- 标记与路线不一致。
- Silence Zone。
- 重复结构造成的强烈既视感。

Sanity 压力提高。

### Phase 4 — Understanding

玩家通过纯环境反馈逐渐理解某些表面存在“薄弱”差异，例如局部 hum 音调、墙纸接缝、碰撞/脚步反馈、材质错位和空间连接异常。不要用人类留言告诉玩家答案。

玩家开始主动检查：

- 墙。
- 地面。
- 阴影。
- 异常材质。

### Phase 5 — Exit Search

生成一个 authored Exit Region。

特点：

- hum 音调异常。
- 墙纸略不同。
- 地毯干燥。
- 某面墙产生视觉错位。

玩家需要通过观察找到“薄弱区域”。

不要出现：

```text
Press E to Exit Level 0
```

交互提示最多是：

```text
[Examine]
```

玩家靠近/冲刺/与异常表面互动后发生 noclip。

### Phase 6 — Demo Resolution

如果 Demo 只完整制作到 L0：

玩家切出。

短暂黑屏。

听见 Level 1 的工业环境声。

画面只需要短暂淡入 Level 1 的入口视觉，确认玩家确实离开了 Level 0；**不要提供 3–5 分钟 teaser、探索、拾取或额外教程。**

显示：

```text
LEVEL 1
HABITABLE ZONE

DEMO COMPLETE
```

并允许：

- 返回主菜单。
- 继续进入开发中的 Sandbox（Debug build）。

---

# 10. Level 0 可选秘密

Demo 建议至少做 3 个：

### Secret A — The Impossible Loop

连续走 4 次同一回路后出现一个原本不存在的小房间。

奖励：壁纸碎片 / lore note。

### Secret B — Silence

找到一个完全没有 hum 的房间。

停留足够久：

Journal 自动记录：

> “The silence is worse.”

### Secret C — False Exit

一面非常明显的异常墙。

玩家以为是出口。

穿过后：

回到 Level 0 的另一区域。

让玩家理解：

**noclip ≠ 一定离开当前 Level。**

---

# 11. 难度 / Save / Load / Death

## 11.1 难度与存档绑定

创建新存档时，必须先选择难度；创建后该存档难度不可在普通设置中修改：

```text
休闲模式 Casual
硬核模式 Hardcore
极限模式 Extreme
```

- **休闲模式**：保留所有自动存档，同时允许玩家在绝大多数非过场/非死亡状态手动保存。
- **硬核模式**：禁止手动保存，只允许系统自动保存。死亡后显示死亡结算，并允许回到主菜单或读取该存档最近自动保存。
- **极限模式**：禁止手动保存；死亡后只能进入死亡结算并返回主菜单，随后自动删除该存档。删除动作必须在死亡结算状态确认完成，避免因崩溃/误判提前损坏存档。

难度系统预留其他倍率，但 Demo 不应仅靠“敌人血量”区分难度。

## 11.2 自动保存节点

Demo 强制自动保存：

1. 玩家完成公司账号重新注册、个人信息与形象创建后。
2. 玩家第一次完成 noclip、正式进入 Level 0 后。
3. 后续每次玩家成功睡觉后。

Demo 可额外在关键不可逆世界状态后安全自动保存，但不要在玩家即将死亡或卡死位置覆盖唯一存档。Level 0 不因普通 Landmark 自动保存，除非后续测试证明有必要。

## 11.3 保存内容

保存至少包括：

```text
profile / appearance
difficulty
player transform（合法保存点）
stats
inventory + nested containers
equipment
item instance states（液体、电量、condition、动态 flags）
phone messages / photos / battery
world clock
journal
world flags
seed
level generator persistent landmarks
placed markers
world item persistence records
settings
```

不要保存所有动态房间 Node。Level 0 保存 Seed、Graph state、关键 mutation、玩家标记，再重建。世界掉落物保存定义 ID + 实例状态 + transform + persistence id。

## 11.4 Death Ending

死亡不是即时 respawn。解锁/记录对应的“死亡结局”，进入结算画面，显示本次存档的基础经历与死亡原因。

- Casual / Hardcore：`返回主菜单`、`读取最近存档`。
- Extreme：只允许 `返回主菜单`，随后该存档删除。

Demo 不要求制作大量独立死亡 CG，但结局系统必须数据驱动，为未来特殊死亡结局预留 `EndingDefinition`。

# 12. 后续 Level 的统一数据骨架

建立 `LevelDefinition` Resource：

```gdscript
class_name LevelDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var subtitle: String
@export var scene: PackedScene
@export var survival_class: String
@export var tags: Array[StringName]
@export var default_environment_profile: Resource
@export var allowed_entity_tables: Array[Resource]
@export var entrance_ids: Array[StringName]
@export var exit_definitions: Array[Resource]
```

预注册：

```text
prologue
level_0
level_1
level_2
level_3
level_4
level_5
level_6
level_6_1
level_7
level_8
level_9
level_10
level_11
the_hub
level_fun
```

未制作 Level 的 `scene` 可为空，UI 显示 unavailable。

---

# 13. Entity 系统骨架

不要现在制作所有实体。

只建立可扩展架构：

```text
EntityBase
├── PerceptionComponent
├── NeedComponent
├── MovementComponent
├── HealthComponent (optional)
├── RelationshipComponent
├── TerritoryComponent
└── EntityStateMachine
```

Perception：

```text
Vision
Hearing
LightSensitivity
Smell (future)
Touch (future)
```

AI 不使用统一：

```text
see player → attack
```

而是：

```text
Perception
→ Evaluate
→ Motivation
→ State
```

为未来预留行为：

```text
Observe
Avoid
Warn
Guide
Hunt
Defend Territory
Feed
Sleep
Flee
Trade
Mimic
Escort
```

这样以后才能实现：

- Light Guide。
- Hound。
- Smiler。
- Skin-Stealer。
- Neighborhood Watch。
- Warning Kite。
- Partygoer。

---

# 14. Faction 系统骨架

预定义 faction IDs：

```text
meg
bntg
camp_amber
eyes_of_argos
followers_of_jerry
uec
ariadne_circle
  └── hippocrates  # Ariadne Circle 子团体，不作为独立顶级阵营注册
amor_incrementum
speednoclippers
the_lost
originals
partygoers
independent
```

声望不能只有 -100~100。

建议：

```text
Trust
Respect
Fear
Obligation
IdeologicalAlignment
OperationalValue
```

每个阵营通过 `FactionDefinition` 决定使用哪些维度。

例如未来：

```text
M.E.G.:
Trust + ServiceRecord

B.N.T.G.:
Trust + CommercialReliability

Eyes:
Virtue / Sin

U.E.C.:
OperationalValue + Clearance

Followers of Jerry:
Faith / Acceptance
```

Demo 不需要 UI 完整展示这些值，只实现数据模型和 Debug Inspector。

---

# 15. Quest / Job 系统骨架

Quest 由 Objective 节点组成：

```text
Quest
├── Objective
│   ├── ReachArea
│   ├── Interact
│   ├── AcquireItem
│   ├── Observe
│   ├── Survive
│   ├── Talk
│   └── CustomCondition
├── Branch
├── Rewards
└── Consequences
```

支持：

- 主线。
- 支线。
- 工作 Job。
- 阵营任务。
- 动态 Contract。
- Investigation。

序章与 L0 本身就使用这套系统，避免做一次性脚本。

---

# 16. Dialogue 系统骨架

需要：

- 对话节点。
- 条件。
- 选项。
- Flag。
- Reputation requirement。
- Skill check hook。

不要把文本写死在 NPC 脚本。

Demo 序章店员即可验证系统。

---

# 17. Rule / Information 系统骨架

为 Level 5、Level Fun、谣言系统提前建立：

```text
InformationClaim
├── text
├── source
├── reliability
├── corroboration
├── status
└── tags
```

status：

```text
unknown
suspected
verified
false
contradictory
```

未来用于：

- Hotel Rules。
- Partygoer misinformation。
- M.E.G. 情报。
- Wanderer rumor。
- Entity behavior hypothesis。

L0 可以先用于“某墙面留言是否可靠”。

---

# 18. Knowledge / Journal 系统

玩家知识和世界真实数据必须分开。

```text
WorldTruth != PlayerKnowledge
```

例如：

世界知道：

```text
item = Almond Water
```

玩家第一次看到只知道：

```text
Unknown Bottle
```

同理未来：

```text
World entity = Skin-Stealer
Player knowledge = Unknown Humanoid
```

这是整个游戏最重要的长期架构之一。

---

# 19. Travel / Threshold 骨架

为 Level 9、11、Hub 提前建立：

```text
ThresholdDefinition
├── source_level
├── destination_level
├── entrance_id
├── conditions
├── stability
├── one_way
├── discovery_state
└── transition_profile
```

支持：

- Door。
- Noclip wall。
- Tunnel。
- Vehicle route。
- Hub door。
- Level Key requirement。

Level 0 出口就必须使用该系统。

不要写：

```gdscript
if level == 0:
    load level1
```

---

# 20. 后续系统接口占位

只做接口，不做完整 gameplay。

## 20.1 Level 1

预留：

- Supply crates。
- Flickering event。
- Base Alpha。
- Entity spawning。
- Wanderer encounters。

## 20.2 Level 2

预留：

- Heat。
- Pipe network。
- Engineering interactions。
- Faction workplaces。

## 20.3 Level 3

预留：

- Electricity hazard。
- Dense entity ecology。
- Base Gamma。
- Storage facilities。

## 20.4 Level 4

预留：

- Apartment/home ownership。
- Urban NPC schedules。
- Economy/social hub。

## 20.5 Level 5

预留：

- Hotel rule engine。
- Staff roles。
- Social etiquette。
- Terror Hotel states。
- 5.1 / 5.3 transitions。

## 20.6 Level 6

预留：

- Near-total darkness。
- Auditory navigation。
- Perception distortion。

## 20.7 Level 6.1

预留：

- Safe social rest area。
- Food abundance。
- NPC recovery。

## 20.8 Level 7

预留：

- Water volume / swimming。
- Boat controller。
- Diving pressure。
- Depth zones。

## 20.9 Level 8

预留：

- EcosystemRegion。
- Population simulation。
- Gas hazard。
- Cave generation。
- Ecology journal。

## 20.10 Level 9

预留：

- Journey distance。
- Vehicle system。
- Shelter houses。
- Fog event。
- Line-of-sight entity gameplay。

## 20.11 Level 10

预留：

- Homestead。
- Agriculture。
- Soil。
- Settlement/community。

## 20.12 Level 11

预留：

- Final social hub。
- Districts。
- Player housing。
- Operations Base。
- Dynamic Threshold Network。
- Faction HQs。
- Urban incident system。

## 20.13 The Hub

预留：

```text
HubDoor
LevelKey
KeyResonance
DoorRegistry
```

## 20.14 Level Fun

预留：

```text
Misinformation
FunCompliance
Partygoer social AI
PartyHost influence
```

不要在 Demo 实际生成这些内容。

---

# 21. Debug / Agent 开发工具

必须制作一个开发 Debug Panel，按 F1 开启，仅 debug build。

功能：

```text
Current Level
Player Position
FPS
Current Chunk
Seed
Sanity
Hunger
Thirst
Active Events
World Flags
Give Item
Teleport to Landmark
Force Spatial Mutation
Force Event
Reload Level
Show Chunk Graph
```

这会极大提高 Agent 后续迭代速度。

Level 0 特别需要：

### Chunk Graph Visualization

可以简单使用 DebugDraw3D / Gizmo 显示房间连接。

---

# 22. 性能要求

目标优先：普通 PC 1080p 可稳定运行。

Level 0：

- 使用模块化网格。
- 尽可能共享材质。
- MultiMesh 用于重复小物件。
- 房间灯光控制数量。
- 避免每个荧光灯一个实时 shadow light。
- 使用 baked / cheap lighting + 少量动态灯。
- Chunk streaming。
- Occlusion culling。

不要因为“无限 Level”把几百个房间永久实例化。

---

# 23. Audio 是 P0，不是 polish

Demo 的优先级：

```text
Gameplay > Audio > Lighting > Environment Art > Character Art
```

Level 0 没有 NPC 和实体撑场，音频就是核心玩法的一部分。

必须尽早建立：

- Footsteps。
- Fluorescent hum layers。
- Reverb zones。
- Silence events。
- Occluded sound。
- Player breathing。

不要等“最后再加声音”。

---

# 24. 美术占位策略

如果已有 Three.js 项目的模型：

1. 优先转换/整理为 `.glb`。
2. 导入 Godot。
3. 统一 scale、collision、material。
4. 原模型只作为资源来源，不复制 Three.js 运行时结构。

建立 importer 后处理约定：

```text
SM_*  Static Mesh
MI_*  Material
TX_*  Texture
SFX_* Sound
ENV_* Environment prop
MOD_* Modular architecture
```

Level 0 模块必须 grid-compatible。

---

# 25. Demo 任务列表 / 实施顺序

## Milestone 1 — Foundation

- [ ] Godot project boot。
- [ ] Autoload services。
- [ ] SceneRouter。
- [ ] Player controller。
- [ ] Interaction。
- [ ] Basic HUD + 沉浸 UI 开关。
- [ ] Grid Inventory + 90° rotation + no free stacking。
- [ ] Equipment slots / Back container / Primary + Secondary Hand use。
- [ ] Weight / encumbrance / nested container rules。
- [ ] Phone framework + free text chat input + battery state。
- [ ] Stats。
- [ ] Save system skeleton + difficulty-bound save metadata + death ending skeleton。
- [ ] Debug panel。

**验收**：灰盒房间中能移动、拾取、装备/脱下背包、按二维形状放置与旋转物品、计算负重、打开手机基础框架，并可保存/读取上述状态。

## Milestone 2 — Prologue

- [ ] Difficulty selection before save creation。
- [ ] Player room / compact apartment。
- [ ] 公司账号异常注销 → 角色注册：姓名、生日/18–40 校验、性别、外观。
- [ ] 角色创建完成自动保存。
- [ ] 房间内完成移动、交互、Inventory、Equipment、Phone 教学。
- [ ] 初始电脑包及固定日常用品布局。
- [ ] 高端大型笔记本电脑重量 / 占格 / 不可开机 / 动态多阶段说明。
- [ ] 前厅 Phone Apps：Chat / Maps / Browser / Phone / Camera / Clock。
- [ ] WorldClock：前厅固定剧情时间 1×；进入后室后 24×（2.5 秒 = 1 分钟）。
- [ ] 极短 Building Exit / Street / commute segment。
- [ ] 可选买水流程，普通水为 1×2 物品。
- [ ] 极轻微日常异常。
- [ ] 无传送门式 noclip sequence。
- [ ] 完整携带状态进入 Level 0。

**验收**：首次玩家约 5–8 分钟内可从 New Game 自然完成教程并意外切入 Level 0；熟练玩家可以快速离开住宅，不受强制教程拖延。

## Milestone 3 — Level 0 Core

- [ ] Modular room kit。
- [ ] Chunk graph generator。
- [ ] Streaming。
- [ ] Lighting variants。
- [ ] Audio system。
- [ ] Resource spawning with minimum survival guarantee, no human-life traces。
- [ ] Landmark spawning。
- [ ] Route markers。
- [ ] ItemInstance 可变液体/电量状态。
- [ ] 世界物品物理掉落 + persistence + low-poly fallback。
- [ ] Level 0 普通区域绝对无实体/无生命痕迹约束测试（Manila Room 文档/补给为唯一受控例外）。
- [ ] Arch / Pillar / Hole / Blackout / Red Rooms / Peripheral Shift 六类结构内容均可强制测试并在正常生成中出现。
- [ ] Manila Room 保底生成、文档阅读、Knowledge 解锁与闪烁墙出口联动。

**验收**：可连续探索 20 分钟，无明显生成错误和重复灾难。

## Milestone 4 — Level 0 Experience

- [ ] Spatial mutation。
- [ ] Event director。
- [ ] Sanity effects。
- [ ] Human traces。
- [ ] Journal knowledge progression。
- [ ] Secrets。
- [ ] Exit search phase。
- [ ] Level transition。

**验收**：新玩家无需开发者解释，能够通过环境线索理解“寻找异常表面 / noclip”并离开。

## Milestone 5 — Future Skeleton

- [ ] LevelDefinition registry。
- [ ] Threshold system。
- [ ] Entity base architecture。
- [ ] Faction data model。
- [ ] Quest framework。
- [ ] Dialogue framework。
- [ ] InformationClaim system。
- [ ] Knowledge system。
- [ ] Stub definitions L1–L11 / Hub / Fun。

**验收**：创建一个测试 Level 1 scene 后，仅配置 Resource 即可从 L0 出口跳转，不修改 L0 核心代码。

## Milestone 6 — Demo Polish

- [ ] Settings。
- [ ] Key rebinding。
- [ ] Sensitivity。
- [ ] Audio sliders。
- [ ] Subtitle options。
- [ ] Motion/headbob toggles。
- [ ] Performance pass。
- [ ] Bug pass。
- [ ] Demo ending。

---

# 26. Definition of Done

Demo 完成必须满足：

### 新游戏

玩家能从主菜单开始，不需要 console。

### 序章

完整可玩；首次约 5–8 分钟；移动、交互、二维格子背包、背包装备、重量、手机都在前厅房间内完成基础教学；出门后流程简短；买水可选；noclip 像日常事故而非恐怖机关，并完整保留玩家携带物进入 Level 0。

### Level 0

至少具有：

- 可持续探索空间。
- 受控程序生成。
- 空间异常。
- 资源。
- Sanity。
- 声音事件。
- 人类痕迹。
- Journal。
- 标记系统。
- 至少 3 个秘密。
- 一个合理可发现的离开机制。

### 架构

L0 不知道 L1 的具体实现。

Inventory 不知道“电脑包”具体尺寸；容器布局来自 Resource。物品尺寸、重量、装备槽均数据驱动。

Phone 使用同一套长期框架，前厅/后室/M.E.G. 数据升级通过状态与 App 数据切换完成。

实体、阵营、Level、任务、出口均可数据驱动扩展。

### 体验

玩家第一次游玩应该形成以下心理变化：

```text
“这里是哪？”
↓
“房间是不是重复了？”
↓
“刚才这里不是这样。”
↓
“有人来过。”
↓
“我需要水。”
↓
“那是人吗？”
↓
“墙有问题。”
↓
“我能切出去。”
```

而不是：

```text
找钥匙
→ 开门
→ 躲怪
→ 下一关
```

---

# 27. Agent 每次修改时的工作协议

每次 Coding Agent 接手任务：

1. 先阅读本文件。
2. 检查现有实现，不假定文件不存在。
3. 优先复用现有系统。
4. 修改前指出涉及的模块。
5. 小步提交；一次不要重写整个项目。
6. 新增系统必须说明未来扩展接口。
7. 对关键逻辑加入简短注释，但避免注释重复代码。
8. 强类型，修复 warning，不通过关闭 warning 规避。
9. 修改场景后运行项目验证。
10. 至少测试：New Game → Prologue → Noclip → L0。
11. 若改生成器，再测试至少 5 个不同 seed。
12. 若出现设计与本文冲突，优先保持本文的玩家体验目标；必要时记录冲突再调整。

---

# 28. 首轮 Agent Prompt 建议

可以把下面这段直接交给 Coding Agent：

```text
Read AGENT_GODOT_BACKROOMS_DEMO_PLAN.md completely before making changes.

Implement the project incrementally, beginning with Milestone 1 only.
Do not attempt to build Levels 1–11 yet.

First inspect the current Godot project and identify reusable assets/code from the existing migration. Then create or refactor the minimum architecture required for:
- SceneRouter / game state
- first-person player controller
- interaction system
- player stats
- inventory/item resources
- minimal HUD
- save skeleton
- debug panel

Keep all gameplay systems modular and strongly typed in GDScript.
Do not place unrelated responsibilities in a single GameManager.
Do not hard-code Level 0-specific logic into reusable core systems.

After implementation:
1. run the project,
2. fix parser/runtime errors,
3. verify movement, interaction, inventory and scene transition,
4. report files changed,
5. report remaining Milestone 1 tasks.
```

---

# 29. 最终设计原则

这个 Demo 最重要的不是证明“Godot 能生成无限黄色房间”。

它需要证明整个游戏的设计语言：

> **玩家不是在逐层清怪，而是在逐渐学会后室如何运作。**

因此序章负责让玩家失去现实；Level 0 负责让玩家失去对空间的信任；未来 Level 1–11 再逐步引入资源、实体、社会、阵营、规则、生态、旅行、定居与文明。

技术架构必须服务于这一点。
