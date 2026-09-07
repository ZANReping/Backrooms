# Milestone 2 — 序章交付记录

2026-09-07。范围为用户授权的序章、早期八项改进、六项动作/UI修订，以及最新八项交互/状态/设置修订。剧情时间是 **2026 年 10 月 18 日**，建筑保留 2000—2010 年代生活痕迹。M1 模块与灰盒回归入口保留；有限后室抵达区仅收束序章，未制作 M3 无限生成或 Levels 1–11。

## 当前可玩内容

关掉床头手机闹钟，在公司工作台登记姓名、生日及外观，拿起装有大型笔记本的通勤包、钥匙和钱包，穿过普通住宅走廊；街道上可以花三元买水，也可以直接走向右侧普通转角。行走切入经下坠、声音过渡和短暂黑场进入黄色墙纸、地毯和荧光灯的有限抵达空间。没有迟到惩罚、唯一拼包布局、传送门或追逐；序章只保留既定两次微弱预兆。

| 用户要求 | 本轮实际实现 |
|---|---|
| 2026 年、现代手机 | 主屏采用彩色 App 图标；聊天气泡与固定输入栏、地图街网/路线、浏览器地址栏、联系人及最近记录、时钟卡片、公司工作台。内容仍为本地虚构数据，没有外部联网服务。剧情日期、日历和账号日期统一为 2026。 |
| 全屏相机 | App 先打开手机内页面；点击“拍摄”进入全屏取景，不直接存照片。允许移动、碰撞与鼠标观察，左键拍摄，Esc/P 返回手机。独立世界 Viewport 排除专用手机/握持层和 UI，保留世界层身体；保存横屏 WebP 和相册引用。新旧照片 ID 与纹理显式绑定。 |
| 背包与装备栏 | 移除帆布/皮革/拉链背景；左侧默认竖排十槽，每槽有部位名称和真实装备缩略图，不使用SVG。短点只选，再点取消，长按0.32秒拖动；每次打开默认无选择。保留实物图像及原二维占格、R 旋转、嵌套、装备、丢弃、重量和 UID 事务。 |
| 反向文字 | 修正商店、售水处和公交站牌朝向；世界 Label3D 不再显示背面镜像。住宅日历改为正确年份和星期。 |
| 防掉出地图 | 住宅窗户、街道低围栏和开放尽头增加静态碰撞保护，复用楼道/抵达区原实体边界；正常出口及右转切入缺口保持通行。 |
| 状态与槽位表现 | 装备栏不用SVG；六状态改为不同颜色刻度条，始终显示真实比例，沉浸模式只藏数字。手机电量与App图标仍保留。 |
| 免费资产 | 39 个 Lucide SVG，ISC/Feather MIT 许可、固定版本与 SHA-256；MakeHuman 官方 CC0 皮肤、眼睛、头发和鞋；原 Poly Haven 家具/PBR 保留。详见资产账本。 |
| 人物/NPC 与捏脸 | 引入 CharacterAppearance → HumanCharacter → CharacterBackend 独立边界；66 骨骼实际蒙皮模型，12 面部与 5 体型参数、肤色/发色、四个发型选项和三种体型基底。玩家、手机登记头像和两个通勤 NPC 复用该实现。 |

公司工作台的“编辑形象”打开独立 3D 捏脸预览，拖动旋转、滚轮缩放、脸部/全身视图切换；确认仅回填登记草稿，完成登记才写入角色并保存，取消不修改角色。新运行会清除上一运行的登记草稿。手机屏幕仍为真实 3D 道具上的 360×640 SubViewport。

此前六项修订结果（后续交互规则以最新修订为准）：

| 要求 | 已实现及验证 |
|---|---|
| 手臂/手机握持 | 模型空间校准手臂、松弛手指、真实蒙皮抬手交互；独立近景握持复用同一骨架和皮肤，拇指沿边框、其余手指托背。手机窄边框与原生屏幕统一，移除旧圆 Home 键。 |
| 图标不拉伸且合适填格 | alpha 裁剪透明留白、等比最大容纳、四向旋转与拖拽统一；缓存首次 alpha 扫描，资源 changed 后失效。 |
| 相机先取景并允许移动 | 实际输入验证 App→取景→移动/观察→左键存照；相机模式沿真实通勤动线穿过切入区域也通过。 |
| 门和出门动画 | 实体把手、门扇及碰撞随铰链旋转，住宅门不再隐藏。玩家出楼会转向、走近、开门、迈过门槛、淡出并抵达街道；失败恢复。 |
| NPC 自然行走 | 两位通勤 NPC 有不同速度和起步时刻，按路线加速、减速、停顿、转身；真实位移驱动步态，墙碰撞有效。手机/背包/相机期间继续行走。 |
| Astra 全 UI 审查 | 已完成基线审查、局部实现与实际截图终审。本轮 P1/P2 已闭环：菜单/暂停/设置、通知、手机、相册、装备/详情、捏脸三页与持续选色均复核。可读性改善，写实度仍为 1，详见 UI_ASTRA_REVIEW.md。 |

前厅时钟 1×，抵达后室 24×；手机、相机和背包中时间继续，暂停、Debug、捏脸期间冻结。断网后的消息保留失败状态。笔记本为 4×3 / 2.7kg，不可开机，说明随剧情阶段变化。

## 人物实现边界

已经完成 CHARACTERS_MODELS.md 的现有系统调查、独立数据/后端边界、GD-Human 与 Configura 调查、至少一个可运行后端及普通 NPC 迁移；有确定种子的加权平民外观生成和配置 Resource。没有把整份人物规范的全部阶段标为完成，没有新增派系 NPC、AI 或后室实体。

运行时直接使用原生 BlendShape，不启用第三方插件/Autoload，不逐帧重建顶点。衣服与眼睛只同步已有对应目标；离线清理源模型面部形变造成的身体残余移动。Body Mask 使用独立区域标签，遮住衣服下身体和第一人称头部，避免插值产生颈部条纹。

目前衣柜是固定衬衫、牛仔裤和鞋的适配；四种发型包含同一短发的短裁变体。8 个骨骼挂点和现有库存挂点已连接，但这不等于任意服装都能自动适配。只开放有校准映射的 12/14 面部、5/9 体型参数，未实现项不以假滑杆出现。HumanPoseDriver 采用模型空间方向与解析两骨骼求解，包含待机、支撑/摆腿、下蹲贴地及抬手交互；手机手是实际蒙皮网格与当前道具校准握持。完整 AnimationTree/动画重定向、任意道具抓握、精确门把接触、脚趾及衣物校正、多级 LOD 尚未完成。

基础 GD-Human GLB 的上游声明为 CC0，但逐文件来源证据弱于官方 MakeHuman 附件，仍标记 **EVALUATION_CANDIDATE_NOT_COMMERCIAL_CLEARANCE**。源文件、固定提交、许可、哈希与派生处理记录均保留；不能把当前评估候选直接描述为已完成商用清关。详细调查见 CHARACTER_BACKEND_EVALUATION.md。

## 架构与存档

- PrologueApplication 只装配序章模块和模态界面；PrologueDirector 管理序章阶段/门控。控制器分别控制移动与观察，库存/属性/路由不加入 Level 0 特判。
- CharacterAppearance 保存项目稳定 ID、颜色与有限范围的规范 Morph；CharacterBackend 负责实际网格/材质/骨骼映射，玩家控制器只提供运动状态。预览和 NPC 的材质及外观实例独立。
- schema **3** 保存外观 Resource 的纯数据；读取 schema 1/2/3。schema 1 继续灰盒路线；schema 2 补充外观数据，旧错误 2010 剧情迁到 2026 时生日年份也加 16，保留虚构角色年龄并更新旧账号日期前缀。此处采用已说明的保留年龄默认方案。
- 存档外层 MAGIC 保持兼容；内部 schema 明确升级，不把新结构伪装为旧版本。候选数据先验证再提交，非有限 Morph 值拒绝且不修改原状态。
- PhotoStorage 保存独立 WebP，run/photo ID 受限；缺图容错，成功存档后清理保留主档和有效备份引用，禁止扩大归属不明文件的删除范围。测试不覆盖正常 user://foundation.save。
- PhoneState 消息增加可选 conversation_id，旧数据缺字段默认 default；UI 将其展示于首会话。schema 3 不变，ID 验证和旧档兼容有测试。HingedDoor/PlayerTraversal 无序章路线业务，门控、过渡及失败恢复留在 PrologueDirector。

## 此前阶段新增/修改文件

仓库没有 Git；下表按实际职责列出本次八项调整，自动生成的 .uid、.import、.translation 归对应源文件。

| 类别 | 文件/目录 |
|---|---|
| 时间与模态装配 | autoload/game_state.gd；core/prologue/{prologue_application,prologue_director}.gd；core/session/session_data.gd；resources/prologue/{prologue_config.gd,default_prologue.tres} |
| 外观数据与保存 | characters/resources/{character_appearance,clothing_definition,faction_appearance_profile}.gd；characters/resources/civilian_profile.tres；core/session/character_profile.gd；core/persistence/save_snapshot.gd |
| 人物与后端 | characters/{human_character.gd,human_character.tscn,appearance_generator.gd}；characters/backends/{character_backend,gd_human_backend,gd_human_wardrobe}.gd；characters/backends/human_skin.gdshader；characters/generated/{human.glb,manifest.json} |
| 玩家接入 | player/{player_controller,player_appearance,handheld_phone}.gd |
| 手机与捏脸 | ui/phone/{diegetic_phone_view.gd,phone_theme.tres,avatar_preview.gd,camera_overlay.gd}；ui/character_creator/；resources/phone/local_content.tres |
| 背包与状态 | ui/inventory/field_inventory_{view.gd,view.tscn,grid.gd,theme.tres}；ui/shell/foundation_ui.gd；ui/shared/ui_icons.gd |
| 场景修复 | levels/prologue/{apartment,commute,arrival}.tscn；tools/{build_apartment_scene,build_commute_scene}.gd |
| 图标与人物资产 | assets/ui/icons/{lucide,project}/；assets/third_party/characters/{gd_human_delta_v1,makehuman_system_cc0}/；tools/{fetch_ui_icons.ps1,prepare_character_asset.py} |
| 翻译与配置 | project.godot；resources/translations/{phone,camera,character_creator,inventory,shell,prologue_shell}.csv |
| 验证 | tools/verify_m2.ps1；tests/test_{prologue_data,prologue_save,player_appearance,character_generation}.gd；test_{prologue_runtime,prologue_boundaries,character_visual,handheld_phone,field_inventory_ui} 对应 gd/tscn |
| 文档 | README.md；THIRD_PARTY_ASSETS.md；docs/{DEVELOPMENT,MILESTONE_2_REPORT,PROLOGUE_IMPLEMENTATION_PLAN,UI_ICON_ASSETS,CHARACTER_BACKEND_EVALUATION,AGENT_GODOT_BACKROOMS_DEMO_PLAN_v2}.md |

### 本次六项修订的具体变更清单

前表为累计 M2 范围；以下对应最新请求。生成的 .uid/.translation/.import 归相应源文件。

| 职责 | 新增/修改文件 |
|---|---|
| 姿态与握持 | 新增 characters/backends/human_pose_driver.gd、player/skinned_phone_hand.gd；修改 characters/{human_character.gd,backends/character_backend.gd,backends/gd_human_backend.gd,backends/human_skin.gdshader,generated/human.glb,generated/manifest.json}、player/{player_controller,handheld_phone}.gd、tools/prepare_character_asset.py |
| 门与出楼 | 新增 core/presentation/hinged_door.gd、player/player_traversal.gd；修改 core/prologue/prologue_director.gd、tools/build_apartment_scene.gd、levels/prologue/{apartment,arrival}.tscn |
| 通勤 NPC | 新增 characters/ambient_walker.gd；修改 tools/build_commute_scene.gd、levels/prologue/commute.tscn |
| 相机、会话与相册整合 | core/prologue/prologue_application.gd、core/foundation_app.gd、core/phone/phone_state.gd、ui/phone/{diegetic_phone_view.gd,camera_overlay.gd,phone_theme.tres} |
| UI 审查落实 | ui/shell/{prologue_shell.gd,prologue_shell_theme.tres}、ui/inventory/field_inventory_{grid.gd,view.gd,view.tscn,theme.tres}、ui/character_creator/character_creator.gd；resources/translations/{phone,camera,character_creator,prologue_shell}.csv |
| 手机道具 | tools/build_prologue_props.gd、art/prologue/props/phone.tscn、assets/prologue/icons/phone.png；生成器同时重新保存原四个物品材质（配置不变） |
| 新测试 | tests/test_{character_pose,ambient_walkers,hinged_door,inventory_icon_fit,creator_navigation,prologue_ui_review}.{gd,tscn} |
| 回归更新 | tests/test_{prologue_runtime,prologue_walk,handheld_phone,phone}.gd、tools/verify_m2.ps1 |
| 工程记录 | docs/{UI_ASTRA_REVIEW,DEVELOPMENT,MILESTONE_2_REPORT,AGENT_GODOT_BACKROOMS_DEMO_PLAN_v2}.md、README.md、THIRD_PARTY_ASSETS.md |

## 验证结果

环境为 Godot 4.7.2.stable.official.ed1daf0bf / Windows / Jolt / Forward+ / D3D12 / RTX 4060 Laptop。本轮 M1 无头回归与 M2 图形统一验证通过；Astra 收尾发现的相册及图标问题修复后，重新运行受影响的 1080p 综合和手机图形测试。以下计数来自最终成功日志。

| 验证 | 结果 |
|---|---|
| 编辑器导入、序章数据、schema 1/2/3 与照片清理 | PASS |
| 人物种子/权重生成、66 骨骼、身体/服装/眼睛 Morph 与实例隔离、玩家音频 | PASS |
| 窗户/围栏空气墙及文字朝向；真实玩家完整走通住宅→走廊→街道→转角 | PASS |
| 序章无头综合 | 45/45 |
| 1080p 图形综合：登记/捏脸/保存/相机移动和两照片对应/库存/开门出楼/切入/读档 | 57/57 |
| 手机真实鼠标/键盘、电量、照片、模态恢复、跨运行草稿隔离 | 26/26 |
| 背包默认装备/选中详情/再次取消、三种尺寸、长按拖动/R/关闭 | 无头30/30；图形30/30 |
| 人物实际渲染与 960×540 确认按钮可见 | PASS |
| 本轮 M1 专项、原库存、综合无头、多窗口 | PASS；12/12、54/54、120/120；此前综合图形55/55为历史验收 |
| 骨骼待机/交互/下蹲及实际手机手网格 | 10/10，实际 WebP 复查 |
| NPC 路线、转向、速度、碰撞及模态 | 22/22 |
| 门把/门扇动画、运动碰撞、反向/重复调用 | 13/13 |
| 图标 alpha 等比、旋转、尺寸与缓存失效 | 16/16 |
| 真实 Application Esc 模态、960×540 捏脸三页/底部操作 | 20/20；独立 creator_navigation PASS |

最新验收日志为 artifacts/verification_m2/ 各对应测试名日志及 artifacts/verification/。当前验收日志没有 parser/runtime ERROR；早期诊断日志不计入最终成功结论。一次中途 headless walk 出现 Jolt jobs 警告，最终统一运行未复现；曾遗留的自有测试进程已按精确命令归属关闭，保留用户编辑器及其运行实例。

修复过程中发现：窗口 resize 必须等待真实 viewport 事件，不能把固定 0.25 秒当完成；App 图标与浅色按钮图标需要不同着色；登记头像必须与实际模型使用同一后端；发型源文件静止位置不同，需分别对齐头骨。最终画面复查后相应专项已重跑。

## 性能与实际画面

1920×1080，每场景预热 60 帧后采样 180 帧，未固定 FPS。以下为实际帧间隔而非纯 GPU 时间；最新运行前观察到用户编辑器开启，未做系统资源隔离。

| 场景 | 中位数 | p95 | p99 | 绘制调用 |
|---|---:|---:|---:|---:|
| 住宅 | 4.18ms | 4.83ms | 5.14ms | 815 |
| 通勤 | 4.18ms | 4.96ms | 5.30ms | 1504 |
| 抵达 | 4.18ms | 4.95ms | 7.36ms | 67 |

以上为此前不限帧采样，保留作历史对照；最新默认60FPS/vsync样本见下面八项修订记录。不能宣称持续稳定60FPS。仍需单实例冷启动、长时间运行及热降频采样。没有删去异常值。

实际查看的 WebP 包括：
- artifacts/prologue_runtime/：住宅、工作台、登记/捏脸、全屏相机、背包、走廊、街道、抵达、离线手机。
- artifacts/phone_modern/{home_screen_native,chat_screen_native}.webp：实际手机 SubViewport 的 360×640 原尺寸截图。
- artifacts/character_visual/{full_body,face,face_bob_custom,minimum_960}.webp：实际角色及修改后预览。
- artifacts/field_inventory/{equipment,details}.webp：使用旋转物品测试夹具，等待切换动画结束后的默认栏与详情；实际序章物品画面见 prologue_runtime/06_backpack.webp。
- artifacts/ui_layout/960x540_hud.webp：历史六状态布局；新量条见prologue_refinements。
- artifacts/character_pose/：松弛手臂、步行/交互/下蹲和实际手机握持；artifacts/prologue_runtime/07b_exit_opening.webp 与 08b_walker_*.webp 为实际开门和行人。
- artifacts/ui_review/creator_960_*.webp：实际应用下三页捏脸与长文滚动；phone_modern 中离线地图、浏览器和登记原生页已更新。

以下按 Godot Agent Vision 的 0/1/2 标准进行局部检查，不是全套美术评级或发布认证：

| 检查 | 分数 | 证据/限制 |
|---|---:|---|
| COMP-CENTER-CLEAR | 2 | 全屏相机保留世界中心视野，提示在边缘 |
| COMP-SAFE-EDGE | 2 | 捏脸确认/取消及背包主操作在最小窗口内 |
| TYPE-GLYPH-INTEGRITY | 2 | 中文实际渲染、日历年份、修正的单面世界文字 |
| TYPE-TIMER-STABLE | 2 | 时钟原位更新，不每秒重建当前 App |
| TYPE-HUD-FLOOR | 1 | 已测多窗口；系统 DPI、文本缩放尚未专项验收 |
| AFF-OPERABLE / AFF-DISABLED | 各 2 | 实际输入通过，耗尽电量即时禁用 |
| AFF-DRAG | 1 | 拖放/R 功能通过，实体开合与更自然操作反馈待完善 |
| LIGHT-KEY-FILL | 1 | 人物和环境可读，皮肤/发片、接触阴影和 GI 仍需美术打磨 |
| LIGHT-SPEC-LOT | 1 | 环境 PBR 有材质区分，人物衣物与皮肤距离最终写实质量仍有差距 |
| LIGHT-POST-STACK | 2 | 默认无 VHS、色差或颗粒掩盖细节 |

## 剩余任务

1. 首次玩家完整试玩：确认 5–8 分钟教程节奏、拿齐物品和出门引导、预兆及音量。
2. 人物：完整动作重定向与任意道具抓握、门把精准接触、任意衣物的 Morph/Mask 适配、其余规范参数、鞋与脚趾校正、LOD；不重建本轮已校准的骨架与手机手。基础模型逐文件来源需完善或替换为可追溯离线导出。
3. 视觉/声音：皮肤、发片、街景细节与背包开合继续打磨，烘焙间接光、素材接缝和有来源的环境/脚步录音。
4. 1080p 单实例至少 20 分钟性能、冷启动/切换/热降频、系统 DPI/文本缩放/手柄焦点。
5. M1 延续项：存储中断与房间初始化失败故障注入；已验证的库存/属性/路由/保存基础不重做。
6. M3 和 Levels 1–11 未开工；不把整份人物规范的后续派系及大规模 NPC 阶段纳入本次完成声明。

## 最新八项交互／状态／设置修订（2026-09-07）

- 拾取伸手期间隐藏主手道具，0.75秒后恢复；物品UID和装备状态不变，手机模态不会被提前显露。
- 四款发型改按实际头皮接触带校准；短发与马尾后脑穿透已修。覆盖正面/侧面和宽深变化，发片边缘与高光仍属后续美术质量问题。
- 十槽装备清单移除SVG；六种克制颜色状态条带刻度，沉浸模式仍可读比例。常驻操作说明和事件通知位于屏幕上方。
- 任务标题下面显示待办复选框，可选项注明“可选”；完成项划除、停留1秒后淡出收起；丢掉必需物品后相关待办可恢复。既有出门门控不增加可选项条件。
- NPC与世界、玩家及彼此使用真实胶囊碰撞；保留路线缓起缓停、转向和暂停模式，不新增人群绕行。
- 网格及装备短点只选中，同物品再次点击取消；装备详情顶部也可点实际物品缩略图取消或长按拖出。长按0.32秒才能拖动，释放时提交原库存事务；隐藏立即取消计时/持有状态。重开清选与透明装备栏问题已修。
- 设置分游戏／画面／音频／操作，画面下分基础／光影／性能／氛围，共20个真实配置键。开发者模式默认关闭；VCR滤镜默认关闭，状态栏/动态准星可调；鼠标/FOV、3D渲染、窗口、总线音量均实际生效。
- 设置内容宽度最多860px；自绘开关明确两态，滑杆完整轨道可见，960×540性能页能滚到MSAA且返回始终可点。手机FOV过渡覆盖新设置的竞态已修。

### 最新变更文件

| 职责 | 新增／修改路径（相对项目根） |
|---|---|
| 偏好与实际应用 | autoload/settings.gd；core/settings/{preference_schema,settings_runtime}.gd；core/persistence/save_snapshot.gd |
| HUD／设置组件 | ui/hud/{vital_strip,task_checklist,dynamic_crosshair}.gd；ui/settings/{settings_view,settings_toggle_switch}.gd；ui/effects/vcr_filter.gdshader |
| 主UI和任务 | ui/shell/{foundation_ui,prologue_shell}.gd；core/prologue/{prologue_tasks,prologue_director,prologue_application,prologue_audio}.gd；core/foundation_app.gd |
| 背包交互 | ui/inventory/{inventory_grid,inventory_view,field_inventory_view}.gd |
| 拾取与相机参数 | player/{equipment_presentation,player_controller,handheld_phone}.gd |
| 发型附件 | characters/backends/{gd_human_wardrobe,hair_fit_calibration}.gd |
| NPC碰撞 | characters/ambient_walker.gd；player/player.tscn；core/{main,prologue/main}.tscn；levels/prologue/commute.tscn；tools/build_commute_scene.gd；project.godot |
| 专项验证 | tests/test_{hair_alignment,hud_components,settings_view,preferences_runtime,prologue_refinements}.{gd,tscn}；test_{ambient_walkers,field_inventory_ui,inventory_ui,runtime,ui_layout}.gd；tools/verify_m{1,2}.ps1 |
| 文案和工程记录 | resources/translations/{core,inventory,prologue,prologue_shell}.csv；README.md；docs/{DEVELOPMENT,AGENT_GODOT_BACKROOMS_DEMO_PLAN_v2,UI_ASTRA_REVIEW,MILESTONE_2_REPORT}.md |

没有下载新第三方资产；手机现有SVG保留，装备与状态组件使用文字、实际物品图与Godot自绘。

### 最新验收证据

`verify_m2.ps1 -Graphical`已完整成功；收尾新增详情入口后重跑受影响专项：背包无头/图形各30/30，拾取/清单/状态/重开/VCR及真实960装备选择/取消图形30/30。新设置图形53/53、发型30/30、NPC22/22、序章综合57/57。M1无头五专项、库存12/12、运行时54/54及本轮多窗口120/120通过。

补测修正了测试在侧栏布局变化前缓存鼠标目的格的时序错误，释放前重新读取实际几何；保留真实输入事件、事务数量和精确放置断言。旧Debug布局夹具按新增开关规则显式启用开发者模式。最终对应日志没有parser/runtime ERROR。Astra本轮已列P1/P2闭环，960详情入口完整可见且与底部操作不冲突。

1080p使用默认60FPS上限和垂直同步，住宅／通勤／抵达的median均约16.66ms，p99分别19.88／17.67／18.50ms。含限帧等待，不能当GPU渲染耗时或持续60FPS认证。

实图：artifacts/prologue_refinements/（量条、划除、装备、equipment_details_960、VCR），artifacts/preferences/（1080与960各页、性能页滚底），artifacts/character_visual/hair_alignment/（四款正侧面与变形），artifacts/prologue_runtime/（完整实际流程）。
