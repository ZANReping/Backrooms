# 新人物建模 / NPC 外观系统开发规范

你正在维护一个基于 Godot 4.x 的 3D 游戏项目。项目正在逐步迁移到新的模块化人物系统。

你的目标不是简单“导入几个角色模型”，而是建立一套可长期扩展的统一人物框架，使玩家角色、重要 NPC、普通随机 NPC、派系成员都可以共用同一套人物骨骼、外观、服装、装备和随机生成逻辑。

---

# 1. 总体目标

建立统一的：

`Human Character System`

需要支持：

* 玩家捏脸；
* NPC 随机脸型；
* NPC 随机体型；
* 性别/基础身体类型变化；
* 发型切换；
* 肤色变化；
* 服装动态替换；
* 装备动态挂载；
* 不同派系使用不同服装池；
* 保存和加载完整人物外观；
* 运行时重新换装；
* 重要 NPC 使用固定外观；
* 普通 NPC 使用 Seed 稳定随机生成；
* 后续允许加入更多人物模型、衣服、发型、装备，而不需要修改核心代码。

优先采用：

* 模块化人物模型；
* Skeleton3D；
* Skinned Mesh；
* BlendShape；
* BoneAttachment3D；
* Resource 驱动的数据系统。

不要把角色外观写死在单个场景或脚本中。

---

# 2. 第三方开源人物系统使用策略

本项目允许使用免费、开源人物系统作为：

* Runtime Backend；
* 编辑器工具；
* 离线人物生成器；
* 架构参考；
* 代码参考；
* 随机 NPC 系统参考。

但不得盲目将所有第三方插件直接集成到正式游戏。

当前优先调查和利用以下方案：

```text
GD-Human-Framework
Configura
Blue Zinc Pelican
Humanizer
MakeHuman
ProceduralNPC
```

总体原则：

```text
第三方插件
      ↓
评估
      ↓
┌───────────────┬────────────────┐
│可安全作为Runtime│不适合作为Runtime │
└───────┬───────┴───────┬────────┘
        ↓               ↓
 Adapter Backend     参考/离线生成
        ↓               ↓
 CharacterAppearance
```

核心游戏逻辑不得直接依赖某个插件的节点结构。

必须保留：

`Character Backend Adapter`

作为隔离层。

---

# 3. GD-Human-Framework 使用建议

GD-Human-Framework 是目前优先级较高的人体 Backend 候选。

推荐用途：

* 基础人体；
* 玩家捏脸；
* 重要 NPC 外貌编辑；
* 人体 BlendShape；
* 体型变化；
* MakeHuman 系人物资产；
* 将最终人物 Bake / 导出。

Agent 在项目中发现 GD-Human-Framework 可正常使用时，应优先：

```text
CharacterAppearance
       ↓
GDHumanAdapter
       ↓
GD-Human-Framework
```

不要让 Gameplay 直接访问插件内部节点。

例如不要：

```gdscript
$GDHumanFramework/Body.set_blend_shape_value(...)
```

而应该：

```gdscript
character.appearance_manager.set_morph("weight", 0.6)
```

再由：

```text
GDHumanAdapter
```

负责调用底层插件。

---

## GD-Human-Framework 推荐职责

适合负责：

```text
基础裸体人体
脸部 Morph
身体 Morph
肤色
基础骨骼
基础人物生成
```

不建议让它独自承担：

```text
派系系统
随机NPC规则
装备逻辑
AI
存档
Level逻辑
```

这些仍由本项目自己实现。

---

## GD-Human-Framework 与衣服

如果服装具有与身体一致的关键 BlendShape：

```text
weight
muscle
chest_size
waist_size
hip_size
```

优先同步这些值。

Agent 应建立：

```gdscript
sync_body_morphs_to_clothing()
```

而不是让每件衣服单独连接插件。

---

# 4. Configura 使用建议

Configura 是另一个高优先级 Runtime 候选。

尤其适合：

* Character Creator；
* 模块化服装；
* 模块化身体部件；
* Accessories；
* BlendShape；
* 骨骼变形；
* 自动人物编辑 UI。

如果 Configura 与项目 Godot 版本兼容且运行稳定，可以让它承担：

```text
Character Customization Backend
```

架构：

```text
CharacterAppearance
       ↓
ConfiguraAdapter
       ↓
Configura
       ↓
Mesh / Clothing / Morph
```

---

## Configura 最适合处理

```text
玩家捏脸
重要NPC制作
Hair切换
Body Part切换
衣服切换
Accessory切换
Morph参数
```

但派系随机逻辑仍然由本项目自己实现。

即：

Configura 决定：

> “怎样换衣服”

FactionAppearanceProfile 决定：

> “这个派系允许换什么衣服”。

---

# 5. Blue Zinc Pelican 使用建议

Blue Zinc Pelican 最值得利用的部分不是模型本身，而是：

**随机 NPC 和 Wardrobe 系统设计。**

优先参考或复用：

* Random NPC；
* Wardrobe Slot；
* 随机衣服；
* 随机配色；
* Style；
* Preset；
* Character Seed；
* 模块化人物组合。

如果它的人物模型和当前项目风格不匹配：

不要强行使用原始 Low Poly 人物。

可以：

```text
保留/参考随机逻辑
        +
替换为项目人物模型
```

---

## Agent 应重点借鉴

例如：

```text
NPC Randomizer
│
├─ face_pool
├─ hair_pool
├─ top_pool
├─ bottom_pool
├─ shoe_pool
├─ equipment_pool
└─ color_palette
```

并进一步扩展成：

```text
FactionAppearanceProfile
```

---

## Blue Zinc 的定位

视为：

```text
Random NPC Architecture Reference
```

而不是强制：

```text
Main Character Backend
```

如果代码可复用且许可证允许，可以抽取其中通用逻辑。

不得因为引用 Blue Zinc 而让整个 NPC 系统和其原始场景结构绑定。

---

# 6. Humanizer 使用建议

Humanizer 功能非常完整，可以作为重要的技术参考。

尤其参考：

* MakeHuman 人体系统；
* 大量 Morph；
* 衣服适配人体 Morph；
* Character Creator；
* Runtime 人物生成；
* 面部系统；
* 动画整合；
* 人体资产组织方式。

但是：

**在正式集成当前 Humanizer Runtime 前必须检查其实际许可证。**

如果当前版本属于：

```text
AGPL / 强 Copyleft
```

则不得未经确认直接引入闭源商业 Steam Build。

Agent 不得仅因为 Godot Asset Library 页面显示旧许可证就默认安全。

必须检查：

```text
仓库 LICENSE
具体版本
依赖代码
资源许可证
```

---

## 默认策略

Humanizer 优先作为：

```text
架构参考
代码参考
功能参考
测试工具
```

而不是默认作为正式 Runtime 强依赖。

如果能够通过离线方式生成合法可用资产：

优先：

```text
Humanizer / MakeHuman
        ↓
生成
        ↓
GLB
        ↓
Godot
```

而不是把整个 Runtime 系统带入发行版本。

---

# 7. MakeHuman 使用建议

MakeHuman 优先作为：

**离线人物资产生成工具。**

推荐工作流：

```text
MakeHuman
    ↓
人体生成
    ↓
Blender
    ↓
整理Skeleton
    ↓
减面 / LOD
    ↓
整理Morph
    ↓
导出GLB
    ↓
Godot Character System
```

适合：

* 生成基础人体；
* 生成脸型；
* 创建不同身体比例；
* 创建重要 NPC；
* 创建基础模板；
* 批量生成 NPC Preset。

---

## 不要让 MakeHuman 成为 Runtime 必需依赖

正式游戏运行时最好只需要：

```text
GLB
Resource
Texture
Material
Godot Scripts
```

而不需要 MakeHuman 本体。

---

# 8. ProceduralNPC 使用建议

ProceduralNPC 更适合：

* 临时 NPC；
* 恐怖 NPC；
* 人形异常；
* 模糊远景人物；
* Level 特殊实体；
* 低重要度人形目标；
* 原型测试。

例如：

```text
Level 5 酒店远处客人
Level 6 黑暗中的人影
Level 9 远处居民
异常人形
假人
随机尸体
Jumpscare NPC
```

不建议默认用 ProceduralNPC 取代主要写实人物系统。

---

## Agent 可以借鉴

```text
程序化身体组合
程序化颜色
随机生成
恐怖变体
Style Preset
```

并将其接入统一：

```text
CharacterAppearance
```

如果未来需要“异常化 NPC”，可以创建：

```text
ProceduralNPCAdapter
```

---

# 9. 插件优先级

目前默认优先级建议：

### Tier 1：优先集成/测试

```text
GD-Human-Framework
Configura
```

用途：

```text
基础人体
捏脸
Morph
换装
角色编辑
```

---

### Tier 2：重点参考或部分复用

```text
Blue Zinc Pelican
```

用途：

```text
随机NPC
Wardrobe
Style
Preset
Seed
```

---

### Tier 3：离线生产

```text
MakeHuman
```

用途：

```text
人体模型
NPC Preset
基础资产
```

---

### Tier 4：参考实现

```text
Humanizer
```

用途：

```text
成熟人物系统设计参考
Morph系统参考
衣服适配参考
```

除非许可证再次确认，否则不要默认引入 Runtime。

---

### Tier 5：特殊人物

```text
ProceduralNPC
```

用于：

```text
恐怖人物
低精度NPC
特殊实体
远景人物
```

---

# 10. 禁止重复造轮子

如果第三方插件已经可靠实现：

```text
Morph管理
服装切换
Skeleton适配
Accessory Slot
```

不要无理由重新实现一整套。

但可以增加 Adapter。

推荐：

```text
现有插件能力
      ↓
Adapter
      ↓
项目统一API
```

而不是：

```text
复制插件全部代码
↓
重新写一个更难维护的版本
```

---

# 11. 什么时候应该自行实现

以下部分应该优先由本项目自己控制：

```text
CharacterAppearance
FactionAppearanceProfile
NPC Seed
Weighted Random
保存系统
派系服装规则
Gameplay装备规则
角色身份
LOD策略
网络同步
Level相关逻辑
```

因为这些属于游戏本身，而不是 Character Creator 插件的职责。

---

# 12. 推荐最终技术组合

目前推荐尝试的整体组合为：

```text
                 CharacterAppearance
                        │
            ┌───────────┴───────────┐
            │                       │
      Human Backend           Random Generator
            │                       │
   GD-Human / Configura       自定义随机系统
            │                       │
            │              参考 Blue Zinc
            │                       │
            └───────────┬───────────┘
                        ↓
                  HumanCharacter
                        │
             ┌──────────┴──────────┐
             │                     │
          Clothing             Equipment
             │                     │
       Shared Skeleton        BoneAttachment
             │                     │
             └──────────┬──────────┘
                        ↓
                    NPC / Player
```

MakeHuman：

```text
离线资产生成
```

Humanizer：

```text
架构参考
```

ProceduralNPC：

```text
特殊人形NPC
```

---

# 13. 推荐节点结构

统一人物建议采用类似：

```text
HumanCharacter
├── Skeleton3D
│
├── Body
│   └── MeshInstance3D
│
├── Head
│   └── MeshInstance3D
│
├── Hair
│   └── MeshInstance3D
│
├── Clothing
│   ├── Top
│   ├── Bottom
│   ├── Shoes
│   ├── Gloves
│   └── Outerwear
│
├── Equipment
│   ├── Head
│   ├── Face
│   ├── Chest
│   ├── Back
│   ├── Hip
│   └── Hand
│
├── AnimationTree
├── CharacterAppearance
└── CharacterController
```

具体名称可以根据现有项目调整，但职责必须明确分离。

---

# 14. Body / Face Morph 系统

人物本体使用 BlendShape 实现外貌变化。

Morph 至少分为：

## Face Morph

例如：

```text
nose_width
nose_height
nose_length

eye_size
eye_distance
eye_height

jaw_width
jaw_height

chin_length
chin_width

mouth_width
mouth_height

cheek_size
brow_height
```

Face Morph 可以比较丰富。

Face Morph：

* 不需要同步给衣服；
* 主要作用于头部模型；
* NPC 可以随机；
* 重要 NPC 可以使用固定 preset。

---

## Body Morph

衣服需要适配的 Morph 必须保持有限。

建议只保留：

```text
height
weight
muscle

shoulder_width
chest_size
waist_size
hip_size

arm_size
leg_size
```

不要让所有服装同步几十甚至几百个 Morph。

---

# 15. Clothing 系统

服装必须模块化。

不要：

```text
MEG_Male_01.glb
MEG_Male_02.glb
MEG_Male_03.glb
```

优先：

```text
BaseHuman
+
Hair
+
Top
+
Bottom
+
Shoes
+
Outerwear
+
Accessories
```

所有服装应：

* 与基础人物共享 Skeleton；
* 使用统一骨骼命名；
* 能运行时替换；
* 尽量共享材质；
* 尽量复用纹理。

---

# 16. 衣服 Morph 同步

如果：

```text
weight = 0.7
muscle = 0.3
waist_size = 0.6
```

当前衣服具有同名 BlendShape，则同步参数。

如果不存在：

* 不得报错；
* 自动忽略；
* Debug 模式可 warning。

建立：

```gdscript
sync_body_morphs_to_clothing()
```

---

# 17. Body Mask / 防穿模

不要单纯依赖 Morph。

服装系统需要支持：

`Body Mask`

基础身体区域：

```text
HEAD
NECK

TORSO

UPPER_ARM
LOWER_ARM
HAND

HIP

UPPER_LEG
LOWER_LEG
FOOT
```

Clothing Resource 可声明：

```text
hidden_body_regions
```

例如：

```text
shirt:
TORSO

jacket:
TORSO
UPPER_ARM

pants:
HIP
UPPER_LEG
LOWER_LEG
```

---

# 18. Equipment 系统

装备优先使用：

`BoneAttachment3D`

例如：

```text
helmet
gas_mask
glasses
radio
flashlight
backpack
weapon
holster
oxygen_tank
camera
```

统一 Socket：

```text
HeadSocket
FaceSocket

ChestSocket
BackSocket

HipLeftSocket
HipRightSocket

HandLeftSocket
HandRightSocket
```

---

# 19. CharacterAppearance

创建统一数据对象：

```text
CharacterAppearance
```

至少记录：

```text
character_seed

body_type
skin_tone

face_preset

face_morphs
body_morphs

hair
hair_color

top
bottom
shoes
outerwear
gloves

head_equipment
face_equipment
back_equipment
hip_equipment
hand_equipment

clothing_colors
equipment_colors
```

第三方插件的内部数据不得直接成为存档格式。

---

# 20. Random NPC 系统

NPC 必须支持稳定 Seed。

例如：

```text
NPC seed = 483924
```

统一使用：

```gdscript
RandomNumberGenerator
```

避免无控制：

```gdscript
randf()
randi()
```

---

# 21. Faction Appearance Profile

不同派系拥有：

```text
FactionAppearanceProfile
```

例如：

```text
MEG
├── hairstyles
├── uniforms
├── pants
├── boots
├── backpacks
├── helmets
├── accessories
└── allowed_colors
```

BNTG：

```text
BNTG
├── civilian_clothing
├── work_clothing
├── utility_vests
├── backpacks
└── allowed_colors
```

Wanderer：

```text
Wanderer
├── civilian_tops
├── jeans
├── jackets
├── random_backpacks
└── broad_color_range
```

生成流程：

```text
Faction
↓
FactionAppearanceProfile
↓
Weighted Random
↓
CharacterAppearance
↓
Character Backend
↓
HumanCharacter
```

---

# 22. Weighted Random

随机物品不得默认等概率。

例如：

```text
普通衣服：50
工作服：25
夹克：15
稀有制服：8
特殊装备：2
```

---

# 23. NPC 类型

## Hero NPC

固定：

```text
CharacterAppearance
```

---

## Persistent NPC

固定：

```text
Seed
```

---

## Disposable NPC

根据：

```text
Level Seed
Chunk Seed
Spawn Seed
```

生成。

---

# 24. 性能要求

支持：

```text
LOD0
完整人物
完整脸
完整服装
完整装备

LOD1
简化Mesh
简化头发
减少材质

LOD2
Bake外观
简化Skeleton

LOD3
极低模 / Impostor
```

远处 NPC 不运行：

* Face Morph 更新；
* 面部动画；
* Cloth Morph 实时计算；
* 高频装备逻辑。

---

# 25. Morph 更新策略

禁止：

```text
每帧重新设置全部 BlendShape
```

只在：

```text
创建人物
捏脸
换服装
加载Appearance
特殊变形
```

时更新。

---

# 26. 材质系统

优先：

```text
Shared Material
Shader Parameter
Texture Atlas
Color Parameter
```

避免每个 NPC 创建大量独立材质。

---

# 27. 推荐目录结构

```text
res://characters/

core/
    human_character.tscn
    human_character.gd

backends/
    character_backend.gd
    gd_human_adapter.gd
    configura_adapter.gd
    procedural_npc_adapter.gd

body/

hair/

clothing/
    tops/
    bottoms/
    shoes/
    outerwear/

equipment/
    head/
    face/
    chest/
    back/
    hip/
    hand/

materials/

resources/
    appearances/
    factions/
    clothing/
    equipment/

systems/
    character_generator.gd
    appearance_manager.gd
    wardrobe_manager.gd
    equipment_manager.gd
    morph_manager.gd
    npc_randomizer.gd
```

---

# 28. 对旧 NPC 的迁移

采用渐进式：

```text
旧 NPC
↓
CharacterAppearance Adapter
↓
新人物系统
```

优先顺序：

1. 通用 Skeleton；
2. 基础 HumanCharacter；
3. CharacterAppearance；
4. Backend Adapter；
5. Wardrobe；
6. 随机 NPC；
7. 派系 NPC；
8. 重要 NPC。

不得破坏：

```text
AI
Navigation
Interaction
Inventory
Quest
Combat
```

---

# 29. Gameplay 解耦

AI 不应该直接操作：

```text
MeshInstance3D
BlendShape
第三方插件节点
```

只能调用：

```text
equip_item()
change_outfit()
apply_appearance()
set_character_state()
```

---

# 30. 保存系统

Save Game 保存：

```text
character_id
seed
CharacterAppearance
inventory
state
```

而不是整个 Character Scene。

即使未来：

```text
GD-Human → Configura
```

旧存档仍然应尽量兼容。

---

# 31. 编辑器工具

建议提供：

```text
Character Preview

Backend:
[ GD-Human ]

Seed:
[________]

Faction:
[ MEG ]

Randomize
Randomize Face
Randomize Body
Randomize Clothes
Randomize Equipment

Save Preset
Load Preset
Bake Character
```

方便 Agent 和开发者快速测试。

---

# 32. 第三方依赖许可证检查

新增插件之前检查：

```text
LICENSE
Godot版本
维护情况
商业使用
Runtime依赖
资产许可证
代码许可证
导出资产许可证
```

尤其注意：

```text
GPL
AGPL
CC-BY
CC0
MIT
```

不要假设：

> 免费 = 可随意闭源商业发行。

如果许可证存在风险：

优先：

```text
离线生成
参考架构
重新实现通用逻辑
```

而不是直接绑定 Runtime。

---

# 33. Agent 实施顺序

第一次执行本人物系统迁移时，优先完成：

### Phase 1

调查现有：

```text
NPC模型
Skeleton
AnimationTree
装备系统
角色控制器
```

不要立即删除旧系统。

### Phase 2

创建：

```text
CharacterAppearance
CharacterBackend
HumanCharacter
```

### Phase 3

测试：

```text
GD-Human-Framework
Configura
```

选择至少一个可工作的 Backend。

### Phase 4

实现：

```text
Hair
Clothing
Equipment
Morph
Body Mask
```

### Phase 5

参考 Blue Zinc，实现：

```text
Seed Randomizer
Weighted Random
Faction Profile
```

### Phase 6

迁移一个普通 NPC 作为测试。

### Phase 7

迁移一个完整派系 NPC。

### Phase 8

完成性能测试以后，再扩大迁移范围。

---

# 34. 避免的错误

禁止：

```text
因为Humanizer功能最全就直接整套引入
```

禁止：

```text
每个随机NPC一个完整GLB
```

禁止：

```text
每个派系复制一整套人物代码
```

禁止：

```text
AI脚本直接控制第三方Character插件
```

禁止：

```text
把第三方插件自己的Resource直接当永久存档格式
```

禁止：

```text
每帧同步Morph
```

禁止：

```text
所有NPC都使用最高精度人物系统
```

---

# 35. 最终目标

最终开发者应该可以：

```gdscript
var appearance := character_generator.generate(
    faction = "MEG",
    seed = 583291
)
```

系统自动决定：

```text
身体
脸型
肤色
身高
体型
头发

制服
裤子
鞋

背包
无线电
头灯

颜色
装备
```

然后：

```text
CharacterAppearance
↓
当前Character Backend
↓
HumanCharacter
```

无论 Backend 当前是：

```text
GD-Human
Configura
Custom
```

上层游戏代码都不需要知道。

未来替换插件时：

```text
Gameplay
Faction
SaveGame
AI
```

原则上不应重写。

---

# 36. Agent 最终判断原则

如果第三方插件已经很好解决：

```text
“如何改变人物外貌”
```

就使用 Adapter 调用它。

如果属于：

```text
“这个游戏应该生成什么样的人”
```

则由本项目自己实现。

因此始终区分：

```text
Character Technology
和
Game Character Rules
```

前者可以借助：

```text
GD-Human
Configura
Humanizer
MakeHuman
Blue Zinc
ProceduralNPC
```

后者必须由项目自己的：

```text
CharacterAppearance
FactionAppearanceProfile
NPC Randomizer
Gameplay
Save System
```

负责。

最终目标不是依赖某个 Character Creator 插件，而是让多个开源工具成为统一人物系统背后的可替换组件。
