# Milestone 1 验收报告

日期：2026-09-07。状态：**Foundation 灰盒功能验收通过**。范围仅为设计规格第 25 节 Milestone 1；没有制作序章、Level 0 或 Levels 1–11。

## 后续增量：M1 UI 收尾（2026-09-07）

通知与弹层/Debug 分离；短通知保持紧凑，多行通知依据内容高度展开。修复自动换行与裁切配置使 Label 实际高度仅 1px、导致背景有显示但文字不可见的问题。手机聊天区减小最小高度，关闭按钮可在最小窗口内点击；Debug 关闭按钮移到滚动区之外的固定底栏。

HUD 名称与数值分列，100%→9% 不改变数值列位置或宽度；沉浸模式仍隐藏精确数字而不改属性。背包增加可见 ActionHint：未选中、无装备槽、无使用动作时说明原因，选中手机后恢复使用；保存与读取禁用有本地化 tooltip。英文 CSV 中带逗号的文本已正确加引号。

本次修改文件：`ui/shell/foundation_ui.gd`、`ui/shell/shell_theme.tres`、`ui/inventory/inventory_view.gd`、`ui/inventory/inventory_view.tscn`、`resources/translations/shell.csv`、`resources/translations/inventory.csv`、`tools/verify_m1.ps1`、README、本报告和 DEVELOPMENT。新增 `tests/test_ui_layout.gd` / `.tscn`。未更改核心玩法、存档结构、关卡或属性规则。

增量验证结果：

| 验证 | 结果 |
|---|---|
| 五种窗口尺寸的界面/实际点击 | **120/120**：960×540、1280×720、1024×768、1600×900、1600×675 |
| 960×540 真实背包拖放/R/装备/丢弃 | **12/12** |
| 原图形综合流程回归 | **55/55** |
| 最终完整 editor import | 成功，无 ERROR |

日志为 `artifacts/verification/{ui_layout,inventory_ui_minimum,runtime_graphical,import}.log`，多窗口截图为 `artifacts/ui_layout/`。验证实际窗口尺寸、按钮位置或滚动可达性，并通过真实鼠标点击关闭 Debug/手机、从背包使用手机；文字高度检查保证多行通知不是只有可见背景。`verify_m1.ps1 -Graphical` 已包含新增验证。

已复查最小窗口通知、背包、HUD 和 4:3 Debug 原尺寸截图。基于同一 Agent Vision 微观规则，本轮 `HIER-MODAL-TOAST`、`TYPE-STAT-ALIGN`、`AFF-DISABLED` 从 1 提升到 2：通知与弹层分开、数字列对齐、禁用态有文字原因。`TYPE-HUD-FLOOR` 仍为 1，尚无不同系统 DPI、掌机/电视或手柄证据；没有将自动窗口验证等同于长期人工试玩。

## 迁移项目审计

修改前已完整阅读 `AGENT_GODOT_BACKROOMS_DEMO_PLAN_v2.md` 的 2346 行。原工作目录只有项目配置、默认图标、Agent 规则、设计规格及导入缓存，没有迁移后的 gameplay 脚本、模型、场景或 `.git` 仓库。沿用 Godot 4.7、Jolt、Forward+ / D3D12 配置和默认图标，其余基础模块为本轮新增。未修改设计规格或 AGENTS.md，未使用外部资产。

## 功能验收

| M1 项目 | 当前结果与证据 |
|---|---|
| Project boot / Autoload | main.tscn 启动菜单；职责分别由六个服务持有，全项目导入及真实运行通过 |
| SceneRouter / game state | Resource 路由目录、异步加载、入口验证；E 触发 A→B→A；无效路由保留原场景 |
| 第一人称控制器 | WASD、mouse look、冲刺/耐力、低跳、蹲伏/顶阻挡、headbob 开关；真实碰撞与输入验证 |
| 身体基础表现 | 低头可见躯干/腿脚/手臂；主副手与背部真实挂点，交互前伸动画；截图检查通过 |
| Interaction | 中心射线、距离与世界遮挡、动作前重新验证目标；E 拾取与旅行使用同一协议 |
| Stats | 六项属性、配置化消耗恢复、按来源的 Modifier；专项与运动集成测试通过 |
| Grid Inventory | 二维异形、90°旋转、阻塞格、无自由堆叠；模型测试与真实 GUI 拖放/R 输入通过 |
| Equipment / 双手 | 十个槽位、Back 容器、主副手真实 ItemInstance；装备/脱包/回收，饮水与手机使用通过 |
| Weight / nesting | 递归重量、超重可拾取但减速/禁冲刺、循环/深度限制、非空包展开碰撞原子回滚 |
| Phone foundation | 自由 Unicode 文本、本地消息状态、真实物品电量、时钟与六应用入口；完整应用内容留到 M2 |
| HUD / 设置 | 六属性、中心交互提示、手持物品、沉浸 UI 数值开关，暂停与设置界面 |
| Save / difficulty / death | schema 1、校验和/备份、非法数据拒绝、状态恢复；休闲手动保存、硬核 checkpoint、极限结算后限定归属删除 |
| Debug panel | 真实场景/坐标/FPS/种子/属性/负重；物品给予、房间重载/旅行和死亡入口；仅 debug build |

`FoundationApp` 是组合根，只连接服务和 UI 意图。运动、库存规则、存档、世界物品和手机各自独立。核心系统没有 Level 0 分支；灰盒内容来自房间场景与 Resource。数据资源、实例模型、节点接口和集合使用强类型 GDScript；存档边界先验证外部 Variant。

## 运行验证

环境：Windows、Godot **4.7.2.stable.official.ed1daf0bf**、Jolt、Forward+ / D3D12、RTX 4060 Laptop。采用正常桌面权限运行。

| 验证 | 最终结果 | 日志 |
|---|---|---|
| 完整项目 editor import | 成功，无 parser / ERROR | `artifacts/verification/import.log` |
| 属性专项 | PASS | `artifacts/verification/stats.log` |
| 库存模型/物品 Resource | PASS | `artifacts/verification/inventory.log` |
| 手机状态 | PASS | `artifacts/verification/phone.log` |
| 存档/损坏/难度/恢复 | PASS | `artifacts/verification/save.log` |
| 玩家实例隔离/恢复/脚步连接 | PASS | `artifacts/verification/player_audio.log` |
| 真实 Viewport 背包输入 | **12 checks, 0 failures** | `artifacts/verification/inventory_ui.log` |
| 无头真实场景/物理综合流程 | **54 checks, 0 failures** | `artifacts/verification/runtime_headless.log` |
| 图形真实场景/输入综合流程 | **55 checks, 0 failures** | `artifacts/verification/runtime_graphical.log` |

完整验证脚本返回 `MILESTONE_1_VERIFICATION_PASSED`。身体和装备挂点的最后修改后，又运行玩家专项与图形综合流程，55 项仍全部通过。最终日志没有 parser/runtime/ERROR。

综合流程实例化实际 `core/main.tscn`，通过输入事件和物理帧验证移动、冲刺、跳跃、低梁蹲伏、鼠标观察、E 拾取/门交互、存读档、房间往返、世界物品连续性、超重，以及三种难度的死亡/存档权限。UI 专项通过 `Input.parse_input_event` 和 Viewport 分发鼠标及键盘事件，不直接调用 `_gui_input` 或手工发射拖放信号。

默认测试使用 `artifacts/`；图形验证额外使用独立的 `user://m1_validation_<pid>/` 路径验证实际用户存储，不覆盖正常存档。无头 DisplayServer 不支持鼠标捕获，故仅该项交给图形运行验证。自动运动采样采用 `--fixed-fps 60`；测试场景关闭输入事件累积以避免合成事件被合并，这些设置不改变正式游戏运动参数。

最终检查了 `artifacts/runtime_test/` 下的 `hud.webp`、`inventory.webp`、`phone.webp`、`debug.webp`、`body.webp`、`death.webp`：1280×720 下主要文字、按钮、背包网格可读；面板对比与内边距正常；平视身体不挡中心操作视线，低头可见身体与手持物品。美术与声音仍是基础占位；没有把长期人工试玩或音效听感验收记为已完成。

按 godot-master 的 Agent Vision / Taste Receptor Atlas 做局部像素评分：0 为失败，1 为部分满足，2 为截图中清晰满足。以下记录本轮关键条目，属于灰盒视觉检查，不是完整美术或架构的生产认证。

| 条目 | 分数 | 截图证据 / 后续改善 |
|---|---:|---|
| HIER-FOVEAL-CLEAR | 2 | HUD 在边缘，平视中心交互区清晰 |
| HIER-FREQ-PLACEMENT | 2 | 属性与双手信息保持固定角落 |
| HIER-PERIPH-READ | 1 | 图标加文字可读，外围状态变化仍主要靠数字，后续改善形状提示 |
| HIER-MODAL-TOAST | 2 | UI 收尾后通知与手机/Debug 面板分开，最小窗口及多行内容通过截图和实际点击验证 |
| CTRST-BODY-45 | 2 | 实际尺寸下浅色主要文字与深色衬底清晰分离；这是像素检查，非仪器对比度认证 |
| CTRST-PLATE-OPACITY | 1 | 深色面板优先保证阅读，当前仍偏厚重 |
| CTRST-OVERLAP-LEG | 2 | 未见主要文字碰撞、按钮文字截断 |
| TYPE-GLYPH-INTEGRITY | 2 | 简体中文与 Unicode 测试消息可读，无缺字方框 |
| TYPE-DISPLAY-HUD-SPLIT | 2 | 标题与属性数据字号分离，HUD 无装饰字体干扰 |
| TYPE-FACE-CAP | 2 | 字体家族统一，没有跨屏随机字体 |
| TYPE-HUD-FLOOR | 1 | 桌面可读，尚无掌机/电视距离证据 |
| TYPE-STAT-ALIGN | 2 | UI 收尾后数值采用固定宽度独立列，100%→9% 不改变列的位置或尺寸 |
| AFF-OPERABLE | 2 | 可操作按钮的边框与填充区别于静态文字 |
| AFF-DISABLED | 2 | UI 收尾后背包有可见 ActionHint 与禁用原因 tooltip，选择可用手机后恢复 |
| SPACE-PANEL-PAD | 2 | 手机、Debug、死亡面板内部留白均可辨识 |
| SPACE-GUTTER | 2 | 背包格、装备区与详情分组清楚 |

通知弹层、数值列与禁用原因已在后续 UI 收尾修正。外围状态提示与面板质感仍可改善。未把未拍摄的手柄焦点、系统 DPI 状态或动画峰值记为已通过。

复现命令及全部操作见根目录 README.md：

```powershell
./tools/verify_m1.ps1 -GodotPath 'C:/Users/ZANRe/Desktop/Godot_v4.7/Godot_v4.7.2-stable_win64_console.exe' -Graphical -UserStorage
```

## 剩余 Milestone 1 收尾与限制

本轮最小架构和第 25 节 M1 灰盒验收范围内，没有已知阻塞项。后续质量收尾仍包括：

1. 人工持续试玩、系统 DPI 和手柄焦点检查；已完成五种窗口尺寸的桌面键鼠验证以及通知、数字列和禁用原因修整。
2. 替换身体/物品占位，改善走路动画、手部握持及脚步音效听感。现有接口可供 Skeleton/IK 与正式资产替换。
3. 扩展故障注入验证：进程中断写入、未来房间初始化失败。当前已验证损坏校验、备份回退、未知/非法数据拒绝与无效路由保留原场景。
4. 明确损坏极限存档的后续清理策略：目前无法确认 run_id 的损坏文件可能残留，不能加载，也不会被扩大范围删除。

完整手机应用、角色注册、住宅/通勤/noclip 属于 M2；Level 0 图生成、streaming、刚体世界物品与长期生存体验属于后续 milestone。本轮不把它们列为已经实现的内容。M1 世界物品是可持久记录的静态灰盒实体。

## 修改文件清单

原有修改：`project.godot`（主场景、Autoload、InputMap、翻译、类型检查/层配置）、`.gitignore`（忽略本地技能缓存与验证产物）。以下为本轮新增的人工维护文件。Godot 生成的 `.uid`、翻译 `.translation` / `.import` 元数据随引擎导入生成，未逐一展开；`.godot/` 与 `artifacts/` 日志/截图不属于 gameplay 源码。

```text
README.md
THIRD_PARTY_ASSETS.md
artifacts/.gdignore
docs/DEVELOPMENT.md
docs/MILESTONE_1_ARCHITECTURE.md
docs/MILESTONE_1_REPORT.md
tools/verify_m1.ps1

autoload/game_state.gd
autoload/save_service.gd
autoload/scene_router.gd
autoload/session.gd
autoload/settings.gd
autoload/world_state.gd

core/main.tscn
core/foundation_app.gd
core/interaction/interactable.gd
core/interaction/interaction_context.gd
core/interaction/pickup_interactable.gd
core/interaction/travel_interactable.gd
core/inventory/container_definition.gd
core/inventory/container_instance.gd
core/inventory/inventory_model.gd
core/inventory/inventory_placement.gd
core/items/capacity_state.gd
core/items/charge_state.gd
core/items/item_catalog.gd
core/items/item_definition.gd
core/items/item_description_resolver.gd
core/items/item_description_rule.gd
core/items/item_instance.gd
core/items/item_use_config.gd
core/items/item_use_service.gd
core/items/item_visual.gd
core/persistence/data_validation.gd
core/persistence/save_snapshot.gd
core/phone/phone_state.gd
core/session/session_data.gd
core/session/starter_item.gd
core/session/starter_loadout.gd
core/stats/player_stats.gd
core/stats/player_stats_config.gd
core/stats/stat_modifier.gd
core/world/foundation_room.gd
core/world/item_spawn.gd
core/world/room_entrance.gd
core/world/route_catalog.gd
core/world/route_definition.gd
core/world/world_data.gd
core/world/world_item_service.gd

player/player.tscn
player/player_controller.gd
player/player_interactor.gd
player/player_audio.gd
player/equipment_presentation.gd

resources/items/catalog.tres
resources/items/commuter_bag.tres
resources/items/flashlight.tres
resources/items/l_tool.tres
resources/items/phone.tres
resources/items/pouch.tres
resources/items/water.tres
resources/items/weight_block.tres
resources/player/audio_profile.gd
resources/player/carpet_footstep.tres
resources/player/concrete_footstep.tres
resources/player/default_movement.tres
resources/player/default_stats.tres
resources/player/player_movement_config.gd
resources/translations/core.csv
resources/translations/inventory.csv
resources/translations/items.csv
resources/translations/shell.csv
resources/world/test_loadout.tres
resources/world/test_routes.tres

levels/test_rooms/test_room_a.tscn
levels/test_rooms/test_room_b.tscn
ui/inventory/inventory_grid.gd
ui/inventory/inventory_view.gd
ui/inventory/inventory_view.tscn
ui/shell/foundation_ui.gd
ui/shell/foundation_ui.tscn
ui/shell/shell_theme.tres

tests/test_inventory.gd
tests/test_inventory_ui.gd
tests/test_inventory_ui.tscn
tests/test_phone.gd
tests/test_player_audio.gd
tests/test_runtime.gd
tests/test_runtime.tscn
tests/test_save.gd
tests/test_stats.gd
tests/test_ui_layout.gd
tests/test_ui_layout.tscn
```

无 Git 仓库，因此本轮没有 commit、push 或可提供的 Git diff。后续接手先阅读 AGENTS.md、完整设计规格、DEVELOPMENT.md 和 MILESTONE_1_ARCHITECTURE.md，再沿用上述模块增量开发。
