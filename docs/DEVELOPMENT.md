# Development Log

## Current Status

当前为 Milestone 2 序章可玩版本，Godot 4.7.2 / Windows / Forward+ / D3D12。剧情保持2026年，旧年代建筑；有限后室抵达空间收束序章，未制作 M3 或 Levels 1–11。Milestone 1 模块与灰盒回归保留。

2026-09-07 最新八项交互/UI/设置修订已实现并运行验证：拾取主手表现暂隐、发型头皮校准、无 SVG 装备栏与全量彩色状态条、带可选项的待办清单、顶部常驻提示、NPC 实体互碰、短点选择/长按拖动、四类实际设置。统一 `verify_m2.ps1 -Graphical` 已通过；收尾背包专项无头/图形各30/30、真实序章整合图形30/30、旧版多窗口120/120通过。Astra 发现的装备栏透明、设置末项滚动等本轮 P1/P2 已修复，新增960详情入口也已复核。

## Implemented

- M1 模块化 GameState / Session / WorldState / SceneRouter / Settings / SaveService；第一人称运动、射线交互、六属性、递归重量、异形/旋转/嵌套/十装备槽、世界 UID、难度死亡、HUD、Debug。完整回归通过：五专项、库存 12/12、无头 54/54、图形 55/55、多窗口 120/120；旧 core/main.tscn 可独立运行。
- M2 闹钟→公司登记→拿包/钥匙/钱包→住宅/楼道出口→可选买水→普通转角行走切入→有限后室。真实控制器已走通；门控/阶段在 PrologueDirector，通用核心无 L0 特判。笔记本 4×3、2.7kg、不可开机，描述随阶段变化。
- 时间线统一 2026。手机保留实体 3D 屏幕和真实 SubViewport 输入；现代图标主页、聊天气泡/固定输入栏、地图路线、浏览器、联系人/最近通话、时钟和工作台。内容本地虚构；Unicode 聊天、断网失败、电量轮询、跨运行登记草稿隔离通过。
- 相机 App 的“拍摄”按钮先进入全屏取景，不直接保存；WASD/冲刺/蹲伏/碰撞和鼠标观察可用，左键拍摄，Esc/P 返回手机。独立拍摄 Viewport 排除专用手机/握持层及 UI，保留与主相机一致的世界层（含身体）；真实两照片检查验证新旧 ID 与纹理一致，缺图明确提示。
- 背包移除布料/皮革/拉链背景；左侧十槽竖排，部位名称/实际物品缩略图，选物切换详情，短点详情缩略图或返回按钮恢复装备。继续使用原库存事务；无头和实际图形均30/30，覆盖三种窗口尺寸、短点/长按/R/关闭以及隐藏时取消持有状态。
- 背包主图按 alpha 可见范围裁剪，再等比最大容纳到占格；四向旋转/拖拽保持比例，16/16 检查通过。实例缓存以弱引用和 Texture2D.changed 失效，避免每帧 GPU 读回/逐像素扫描。Astra 调整半透明背景、常规字重、装备行层级、固定详情动作与滚动长文，切换左栏不再使网格跳位。
- HumanPoseDriver 在导入骨骼的模型空间校准下垂手臂、自然手指、腿部支撑/摆动与交互抬手；解析两骨骼求解保持下蹲脚高，姿态专项 10/10。SkinnedPhoneHand 复用真实 66 骨骼/蒙皮手及皮肤，移除胶囊拼手，拇指沿右框，四指托背；手机外壳改窄边框、移除圆 Home 键。
- HingedDoor 把手先转、门扇绕铰链转，物理碰撞随门移动；住宅门状态读档可恢复，门不消失。PlayerTraversal 扫掠玩家碰撞体迈步过楼道门槛后淡出/切换，失败恢复位置和门状态。门专项 13/13、真实行走和两出口综合通过。
- AmbientWalker 两条平民路线采用不同速度/起步时刻，减速/停顿/转向后加速，以实际位移驱动 HumanCharacter。世界碰撞与人物互碰：NPC layer 8 / mask 11，玩家 layer 2 / mask 13；手机/背包/相机继续活动，暂停/过场冻结。NPC 专项22/22检查通过；真实玩家胶囊和NPC/NPC互碰验证。
- Astra 全 UI 审查及修正：菜单“新的一天”二级难度、主菜单/暂停设置、取消序章暂停剧透、短保存提示；手机会话列表→独立聊天与搜索、电话真页签、只读闹钟、普通网络错误、离线定位和浏览器刷新、注册固定提交；捏脸基础/脸部/身体三页、持续选色与视角联动。真实 Application 中 Esc→暂停→设置→Esc→暂停→Esc→游戏和 960×540 捏脸均通过，20/20。详见 UI_ASTRA_REVIEW.md。
- 手机保留现有 Lucide/项目图标；最新用户要求下装备和六状态栏不使用SVG。装备显示部位名/真实缩略图，VitalStrip六色刻度条始终保留真实比例，沉浸模式只隐藏数字；饱腹/水分满条为好，疲劳满条为坏。
- 修复商店/售水/公交站文字朝向，世界 Label3D 单面避免镜像。住宅窗户和街道低围栏/开放尽头增空气墙；保留正常出入口/切入缺口。真实碰撞专项及完整行走流程通过。
- CharacterAppearance 独立资源、CharacterBackend 抽象边界、HumanCharacter 组合节点；实际 66 骨骼/原生 BlendShape 后端。玩家、手机登记头像和两个普通通勤 NPC 复用；确定种子、有限加权平民配置、实例材质隔离均验证。
- 捏脸开放 12 项面部、5 项体型及体型基底、肤色、发色、四发型选项；实际 3D 预览、旋转缩放、脸/全身切换。确认回填草稿，取消不修改，登记后提交/存档；960×540 确认按钮可见。其余未校准参数隐藏，没有假滑杆。
- 当前衬衫/牛仔裤 Morph 同步、头发和独立双脚鞋挂接、8 骨骼装备挂点、Body Mask 与第一人称隐藏头部。离线清理源面部目标在身体的残余位移，flat 区域标签修复颈部条纹。实际眼睛/皮肤/头发/鞋使用 MakeHuman 官方 CC0 附件。
- schema 3 保存规范外观纯数据，原子验证后写入。schema 1/2 显式迁移；旧 2010 序章档转 2026 时同步生日年份保留年龄。登记/抵达 checkpoint；照片独立目录、缺图容错、归属范围和备份保留测试通过。
- 最新M2统一验证及收尾受影响专项通过：数据/存档/人物生成/身体/音频、边界/完整行走（含相机切入）、无头45/45、1080p图形57/57、实体手机26/26、背包无头/图形30/30、发型30/30、设置组件13/13、设置运行时无头36/36/图形53/53、HUD组件13项、整合拾取/清单/状态/重开/VCR无头27/27、图形30/30。M1五专项、库存12/12、无头54/54、本轮多窗口120/120通过。日志在artifacts/verification_m2与artifacts/verification。

- EquipmentPresentation在成功拾取后隐藏主手物品0.75秒，保留手部动画与UID；不覆盖手机模态的挂点隐藏。真实图形验证主手旧物品、新拾取、手机过渡后恢复。
- InventoryView/Grid短点只选择，0.32秒长按后拖动，释放用事件画布坐标提交；重开清选；同面板重复刷新不杀渐显Tween，避免默认装备栏透明。沿用原库存事务、旋转、嵌套与图像alpha等比。
- PrologueTasks只读投影既有Session进度，TaskChecklist显示任务/复选框/可选项，完成划除停1秒后淡出收起；已完成条件失效会恢复，跨任务取消旧Tween；可选项不参与出门门控。
- SettingsView四主类与画面四子类，独立PreferenceSchema约束20个配置键；Settings拥有偏好和ConfigFile，SettingsRuntime应用窗口、渲染、音频与玩家参数，场景Environment先复制避免污染PackedScene缓存。手机过渡同步最新FOV。
- 发型以额头/太阳穴/后脑接触带做独立标定，四样式每次外观变化均重算局部挂接；短发/紧短发与马尾后脑穿透已通过近景复核。仍为现有发片资产，不代表最终写实发丝质量。

## In Progress

M2 首次玩家节奏与美术品质验收；完整动画重定向、任意道具抓握 IK、完整衣柜和未校准 Morph、LOD；皮肤/发片与环境接触阴影/GI、背包开合、录音、长期性能。CHARACTERS_MODELS.md 的派系 NPC 和扩大迁移阶段未实施。当前功能可运行不代表整份人物规范或最终写实资产完成。

## Known Issues

- 人物动作是校准后的程序骨骼步态/两骨骼求解，不是完整动作捕捉或 AnimationTree 重定向。真实蒙皮手机手使用针对当前道具的校准握持；任意道具抓握和门把精准接触仍待扩展。鞋按脚刚性挂接，脚趾、大变形及衣物褶皱校正待做；固定衣柜不能宣称任意换装自动防穿模。Astra 对人物/握持/环境写实度保留 1（可用、未最终）。
- GD-Human 基础 GLB 上游为 CC0 声明，但逐文件来源证据不足，标记 EVALUATION_CANDIDATE_NOT_COMMERCIAL_CLEARANCE。需完善证据或换可追溯离线导出；官方 MakeHuman 附件有逐文件 CC0 证据。没有使用 Humanizer/AGPL 或上游 CC-BY MicroDetail。
- 人物皮肤、衣物和发片表现仍需美术校准，部分街景简化。未烘焙 LightmapGI；当前环境反射、SSAO/SSIL、克制填充灯。早期 ReflectionProbe 黑斑及 7 个 Texture RID 退出警告已通过移除问题探针修复。
- 声音仍为合成 PCM，首次听感、录音、材质脚步和空间混响未正式验收。
- 最新1080p默认60FPS上限/vsync短采样：住宅 median16.66/p9516.94/p9919.88ms，通勤16.66/16.89/17.67ms，抵达16.67/16.93/18.50ms。包含等待/限帧时间，不是GPU耗时；不能与旧不限帧4ms级采样直接比较，仍未完成20分钟冷启动/热降频稳定性认证。
- 一次中途无头 walk 曾出现 Jolt jobs 警告，最终统一运行未复现。旧 walk_verbose.log 等诊断日志可含历史错误；只以当前各测试名日志判断最新结果。
- 多窗口桌面键鼠已测；系统 DPI、文本缩放、手柄焦点及首次玩家 5–8 分钟体验未专项验收。
- 极限死亡和照片清理只删除可确认 run_id/归属的文件；无法确认的损坏文件可残留但不扩大删除范围。存储中断故障注入待补。
- 无头不验证画面/鼠标捕获。固定步长功能测试不能用于性能结论；真实窗口布局验证需等待 viewport resize 事件。受限沙箱系统证书/编辑器权限错误与产品错误分开，最终正常桌面运行日志为准。
- 无 Git，不能提供 commit/diff；本轮没有远程 push、发布或部署。测试不改正常存档，保留用户编辑器及其运行实例。

## Architecture Decisions

- UI通过preference_changed/restore_preferences_requested上报，Settings负责验证与持久化；SettingsRuntime仅应用表现配置。偏好独立保存user://preferences.cfg，旧两字段档按默认值补齐；schema3新增可选字段保持兼容，非法值在SaveSnapshot阶段拒绝。
- VCR屏幕材质默认关闭，位于世界画面与HUD之间。音频使用Master/Ambience/Effects总线；FOV基准通过SettingsRuntime信号传给HandheldPhone，不让收手机Tween恢复过期值。
- 待办清单不新增任务存档结构，只从原序章状态和物品归属生成；不同run_id隔离表现缓存。NPC碰撞使用独立bit8且与世界时间活动模式一致，无人群寻路系统。

- FoundationApp 为基础组合根；PrologueApplication 装配序章 Director/Audio/State 和模态 UI。通用系统不含具体关卡业务。
- 角色持久化只保存项目稳定 ID、颜色和规范 Morph；不保存第三方脚本/节点路径、BlendShape 索引或插件 Resource。后端替换不牵动玩家、NPC、库存。当前 schema 严格验证字段，未来扩展需明确迁移。
- GD-Human 只复用固定 GLB 的原生骨架与 BlendShape，通过项目适配器接入；不启用其 Autoload/全局脚本，也不引入逐帧顶点重建。Configura 经调查作为架构参考，未作为运行依赖。
- 原始第三方 GLB 不改；tools/prepare_character_asset.py 产生 characters/generated/human.glb：清理面部残余形变，COLOR_0.R 为身体区域，G 为右前臂/手部覆盖标签供手机近景使用。manifest 记录输入/输出哈希和变换。Shader 区域用 flat varying，避免蒙皮后位置或边界插值误判。
- HumanCharacter 统一玩家/NPC/头像/捏脸后端。PlayerAppearance 保留现有控制器/碰撞/挂点边界；CharacterBackend 管理骨架/服装/材质，PlayerController 只传运动并同步现有库存挂点。
- 捏脸以副本编辑，确认回填手机登记草稿，完成登记才原子提交。相册、登记和 NPC 不共享可写材质。新 PhoneState 清除旧运行草稿。
- Item registry、UID placement、完整布局验证提交、256 实例/8 层限制不变。新背包继承旧事务入口，不直接改库存数据。
- schema 3 接受 schema 1/2 迁移，外层 MAGIC 继续兼容；schema 1 prologue.enabled=false，保留旧灰盒路线。旧错误 2010 日期迁移以保留年龄为默认方案，已向用户说明。
- PhotoAlbumState 只保存至多 64 张的引用/时刻，图片在 user://photos/<run_id>/。主/备档保留和受管理目录归属边界不变。测试使用 artifacts 或独立 user://m1_validation_<pid>。
- M2 clock_modes 为 play/phone/camera/inventory；appearance、菜单、暂停、Debug、死亡冻结。用户最新要求下 camera 同时启用移动和观察、禁用物品交互，实际区域触发仍生效；AmbientWalker 的活动模式与世界时间一致。
- 聊天消息新增可选 conversation_id，缺字段按 default 读取，旧消息在首会话中展示；ASCII ID 严格验证、非法候选不修改数据。schema 3 不变，旧 schema 1/2/3 无该可选字段仍可读。UI 用 conversation_send_requested，基础单会话 send_requested 保持兼容。
- HingedDoor 和 PlayerTraversal 仅负责可复用表现/移动；序章路线、门控、黑场、失败恢复归 PrologueDirector。脚本过场调用 enter_session；不放宽 FoundationApp.travel 在 transition 时拒绝普通玩家切换的保护。
- 生成脚本输出可编辑静态 tscn；正式游戏不逐帧生成房间/道具，形变只在外观改变时更新。保持 1080p60 优先与默认无 VHS。

## Pending Design Questions

没有阻塞本轮实现的待答问题。最新用户要求确认剧情 2026、建筑旧风格、现代 App、去帆布、左侧装备栏、全屏相机与可捏脸；已覆盖早前相冲突方向。旧档年龄迁移采用已说明的保留年龄默认选项。有限 L0 抵达区按无生命原则，不放 NPC/派系。

## Next Recommended Tasks

1. 用户/首次玩家实玩序章，验证登记、拿齐物品、动线与 5–8 分钟节奏；沿用现有库存、路由、保存。
2. 沿用 HumanCharacter / CharacterAppearance / CharacterBackend / HumanPoseDriver，继续动作重定向与通用抓握、可追溯基础网格、衣柜/Mask 校正、皮肤/发片与 LOD，扩 NPC 前先单实例性能验证；勿重建已校准的手机手与骨架边界。
3. 烘焙间接光、环境/脚步录音、背包开合及街景细节；覆盖 20 分钟 1080p 冷启动/切换/热降频，定位住宅长帧。
4. 系统 DPI/文本缩放/手柄焦点与存储中断/初始化失败故障注入。
5. M3 按规格另行增量实施；当前不制作 Levels 1–11，不擅自进入全派系 NPC 迁移。

## Session Log

### 2026-09-07 — 拾取、发型、状态清单、NPC碰撞与分类设置

Goal：落实用户最新八项修订；保留2026序章、可复用核心和既有库存/存档规则，不扩展后续关卡。

Completed：拾取时主手物品暂隐；四款发型按头皮接触带重校；装备十槽移除SVG并显示文字与实物图；六属性改彩色刻度量条，沉浸模式仅隐藏数字；任务标题/待办/可选/划除渐隐与条件回退；常驻顶部操作提示；玩家/NPC及NPC彼此实体碰撞；网格/装备/详情缩略图短点选择或取消、0.32秒长按拖动、隐藏立即取消状态、打开默认装备；设置四大类、画面四子类及20个实际可持久化配置。Astra完成实际画面审查，Sol负责边界明确的局部实现，主Agent整合偏好/运行时/FOV/保存、拾取、任务投影与最终验证。

Key files：autoload/settings.gd；core/settings/{preference_schema,settings_runtime}.gd、core/persistence/save_snapshot.gd、core/foundation_app.gd；core/prologue/{prologue_tasks,prologue_director,prologue_application,prologue_audio}.gd；ui/hud/、ui/settings/、ui/effects/vcr_filter.gdshader、ui/shell/{foundation_ui,prologue_shell}.gd、ui/inventory/{inventory_grid,inventory_view,field_inventory_view}.gd；player/{equipment_presentation,player_controller,handheld_phone}.gd；characters/backends/{gd_human_wardrobe,hair_fit_calibration}.gd、characters/ambient_walker.gd；玩家/入口/通勤场景、project.godot、tools/build_commute_scene.gd、verify_m{1,2}.ps1；相关测试与四份翻译CSV；README、规格增补、MILESTONE_2_REPORT、UI_ASTRA_REVIEW及本记录。完整按职责清单见M2报告最新修订节。没有新增第三方素材。

Validation：统一verify_m2.ps1 -Graphical成功，包含真实移动/碰撞/交互/库存/开门出楼/相机移动切入/保存恢复。收尾新增详情交互后，背包无头/图形各30/30、真实序章图形整合30/30再次通过；设置图形53/53、发型30/30、NPC22/22、实体手机26/26、序章无头45/45/图形57/57；M1五专项、库存12/12、无头54/54，本轮旧版五窗口120/120。实际WebP已复查；最终对应测试日志无parser/runtime ERROR。默认60FPS/vsync帧间隔样本与限制见Known Issues，不宣称长期稳定60帧。

Diagnostics resolved：同栏重复刷新杀死alpha渐显导致默认装备透明；设置stack固定高度截断MSAA；开关关态/未填充滑轨不清；手机收起Tween恢复旧FOV；共享Environment被偏好污染；装备释放读取旧系统光标坐标。新增缩略图测试最初复用布局变化前cell坐标，改为释放前读取真实当前几何，保留Input事件和精确模型断言。旧多窗口测试需按新规则显式开启开发者模式，未放松调试关闭断言。

Unfinished / Known issues：局部UI可达性可接受，人物/发片/物品图/环境写实度仍需美术打磨；完整动作重定向、通用抓握、背包开合、GI/真实录音与20分钟性能尚未完成。NPC使用固定路线和物理阻挡，尚无人群避让。M1余项为故障注入及DPI/手柄等环境验证，无需重做基础架构。

Next：首次玩家实玩核对提示密度、待办节奏、长按手感和序章5–8分钟路线；随后沿已有模块提升近景资产、间接光与声音，并做单实例长时性能验证。

### 2026-09-07 — 自然手臂/握持、门与通勤动作，以及 Astra UI 审查

Goal：落实用户六项修订：自然角色与握持、背包图标等比、相机先取景且可移动、门/玩家出门动画、NPC 行走，以及 Astra 全面 UI 沉浸审查。

Completed：新增模型空间 HumanPoseDriver、真实 SkinnedPhoneHand、HingedDoor、PlayerTraversal、AmbientWalker；接回原控制器和序章 Director。等比图标采用 alpha 范围/弱引用缓存；手机壳、App、菜单/暂停、背包和捏脸层级按 Astra 审查修正。相册新旧图绑定 ID；普通会话有收件人字段且旧档兼容。Astra 先只读审查、再负责局部主题和最终复查；Sol 分担图标/手机/捏脸/门/NPC 与局部验证，主 Agent 管理骨骼、模态、出楼流程、相册/消息整合和最终测试。

Key files：characters/backends/{human_pose_driver,character_backend,gd_human_backend}.gd、human_skin.gdshader、characters/{human_character,ambient_walker}.gd、characters/generated/；player/{player_controller,player_traversal,skinned_phone_hand,handheld_phone}.gd；core/presentation/hinged_door.gd、core/prologue/{prologue_application,prologue_director}.gd、core/foundation_app.gd、core/phone/phone_state.gd；ui/{phone,character_creator,shell/prologue_*,inventory/field_*}；levels/prologue/；art/prologue/props/phone.tscn、assets/prologue/icons/phone.png；tools/{build_apartment_scene,build_commute_scene,build_prologue_props}.gd、prepare_character_asset.py、verify_m2.ps1；相关 tests 与翻译。详表见 MILESTONE_2_REPORT.md 的本次六项修订清单。

Validation：M1 五专项 PASS、12/12、54/54。M2 统一脚本通过；收尾实际 1080p 57/57（含两张真实照片对应检查）、无头 45/45、手机 26/26、背包 20/20；角色姿态 10/10、NPC 18/18、门 13/13、图标 16/16；真实 Esc 模态与最小捏脸窗口 20/20。实际相机模式完整行走触发切入通过。PowerShell 解析、生成 GLB 哈希与全部本轮最终日志检查通过；无 parser/runtime ERROR。Astra 已查看实际 WebP 并闭环本轮 P1/P2。

Diagnostics resolved：出口动画中普通 travel 被 transition 保护拒绝，改用序列 enter_session；门代理改为实际运动门扇上的交互碰撞，避免射线被门本身遮挡；测试的直接 camera.look_at 绕过身体转向，改真实 apply_look 并正确考虑 CameraPivot 前移；相册纹理与选中 ID 分离导致错图，改显式绑定。早期失败日志/截图不可当最终结果，最新以对应测试名日志为准。

Unfinished / Known issues：写实度仍为局部 1；程序步态与单道具握持不是完整重定向/通用 IK；肤质/衣物/街景与材质接触仍需美术打磨，完整衣柜/LOD/GI/录音/首次玩家与长期性能未完成。没有新增外部素材；GD-Human 来源限制继续保留。

Next：首次玩家真实试玩本轮入口、观察动作与序章节奏；按 Astra 剩余美术项继续迭代，不重做现有核心，不扩 L1–L11。

### 2026-09-07 — 2026 现代手机、装备侧栏与可捏脸人物

Goal：落实用户八项调整，保留 2026 时间线和旧建筑风格，优化手机/相机/背包/图标、修复文字与越界，并按 CHARACTERS_MODELS.md 重构玩家/NPC。

Completed：现代 App、固定聊天输入区、全屏自由观察与左键实拍；十槽左侧装备/详情切换；状态与部位图标；六处新边界保护及世界文字朝向；项目人物数据/后端/壳、66 骨骼模型、12 面部+5 体型捏脸、官方 CC0 附件、平民种子生成和两个普通 NPC；schema 3 及旧版本迁移。五个 Sol 子 Agent 分别承担后端调查、局部捏脸 UI、手机、库存、场景边界和图标等明确任务，主 Agent 整合模型/保存/控制器/相机和最终审查。修复导入/解析、形变残余、颈部 Mask、发型偏移、草稿跨运行泄漏和图标对比度。

Key files：characters/、ui/character_creator/、ui/phone/、ui/inventory/field_*、ui/shared/ui_icons.gd、ui/shell/foundation_ui.gd、player/{player_controller,player_appearance,handheld_phone}.gd、core/prologue/{prologue_application,prologue_director}.gd、core/session/、core/persistence/save_snapshot.gd、levels/prologue/、resources/{prologue,phone,translations}/、assets/{ui/icons,third_party/characters}/、tools/{prepare_character_asset.py,fetch_ui_icons.ps1,build_apartment_scene.gd,build_commute_scene.gd,verify_m2.ps1}、相关 tests、README/资产账本/规范增补与本记录。完整清单见 MILESTONE_2_REPORT.md。

Validation：完整 M1/M2 脚本通过；M2 无头 43/43、1080p 51/51、手机 22/22、背包无头和图形各 20/20、人物生成/形变/实例隔离、空气墙与真实行走、960×540 捏脸检查通过。M1 专项 PASS、12/12、54/54、55/55、120/120。收尾主题与发型修改后手机/人物/背包图形重跑通过，实际 WebP 已复查。最小窗口测试等待原生 resize 再断言，不删原可见性断言。背包图形检查纳入 verify_m2 -Graphical；两个 PowerShell 工具语法检查通过，图标下载工具补充缓存清理前绝对路径边界检查并验证拒绝相邻目录。

Unfinished / Known issues：人物不是最终写实资产；正式动画/手指 IK、完整衣柜和剩余 Morph、基础网格来源证据、LOD、GI/录音、首次玩家体验及长期性能仍未完成。短时住宅 p99 79.60ms，用户预览并行，不能认证稳定 60FPS。CHARACTERS_MODELS.md 派系阶段及 M3/L1–L11 未开工。

Next：沿当前后端打磨人物和单实例性能，完成首次人工试玩；无需重新搭建核心系统。

### 2026-09-07 — M2 序章与实体界面首版

Goal：在M1基础上制作普通公寓到后室的序章，提升手机、背包、纹理与光影沉浸感。

Completed：分模块实现角色登记/序章阶段/时间、初始实际物品、通勤与买水、无传送门切入；实体手机六App与照片、布料背包、schema2迁移；采用CC0家具/PBR并维护许可证。主Agent整合跨模块数据、存档、序列与验证；Sol子Agent承担资源/手机/背包/街道/局部音频和测试。修正手机白底文字、Viewport输入/实时电量、重新挂载生命周期、路缘碰撞、画面反射暗斑和线程测试时序。

Key files：core/prologue/、core/session/character_profile.gd、core/phone/photo_*、core/persistence/save_snapshot.gd、autoload/{save_service,world_state}.gd、player/{handheld_phone,player_appearance,player_audio}.gd、ui/{phone,inventory/field_*,shell/prologue_*}、resources/prologue/、levels/prologue/、art/prologue/、assets/prologue/及third_party/polyhaven/、tools/build_*与verify_m2.ps1、tests/test_prologue* / test_handheld_phone / test_field_inventory_ui；完整清单见MILESTONE_2_REPORT.md。

Validation：M2数据/迁移/照片清理专项通过；无头38/38、图形39/39、实体手机18/18、背包15/15；实际角色从床边沿路走到noclip通过。M1完整回归为五专项PASS、12/12、54/54、55/55、120/120。实际帧时间和最终图形退出结论见M2报告及最新日志；不以固定步长冒充性能。

Unfinished / Known issues：首版非最终写实画质；首次玩家时长、正式身体/握持、烘焙GI、录音、长期性能和多设备体验未宣称完成。

Next：优先人工节奏验证与正式近景资产替换。保留当前模块和自动验收入口，不重新制作已验证系统。

### 2026-09-07 — M2 序章启动（进行中）

Goal：制作具有写实材质、光影和阈限感的完整序章，并重做手机/背包的沉浸表现。

Completed：用户确认年代/交互/性能方向；复核设计第6节和M2清单；完成现有架构只读审计与免费模型候选研究；制定制作计划。

Key files：docs/PROLOGUE_IMPLEMENTATION_PLAN.md、docs/PROLOGUE_ASSET_CANDIDATES.md；后续代码/资产正在制作，最终清单待补。

Validation：当前仅计划/来源核查；没有宣称序章可运行或达到60帧。M1最后成功回归为图形55/55、UI多窗口120/120。

Unfinished / Next：继续资产下载/导入、视觉样板和各模块实现；保存迁移由主Agent整合，禁止新模块各自修改SaveService造成冲突。

### 2026-09-07 — M1 UI 收尾与多窗口验证

Goal：继续上轮 M1 收尾，处理通知遮挡、数值对齐、禁用原因并验证不同窗口尺寸；不进入 M2。

Completed：Shell 通知安全区域、可换行文字高度、HUD 独立数字列；背包 ActionHint 与中英 tooltip；手机聊天区适配可用高度；Debug 独立固定关闭底栏。审查时修正带英文逗号的 CSV 引用。两个 Sol 子 Agent 局部修改 UI，主 Agent 运行图形检查并修复集成后的文本高度/布局问题。

Key files：ui/shell/foundation_ui.gd、ui/shell/shell_theme.tres、ui/inventory/inventory_view.gd、ui/inventory/inventory_view.tscn、resources/translations/{shell,inventory}.csv、tests/test_ui_layout.{gd,tscn}、tools/verify_m1.ps1、README.md、docs/MILESTONE_1_REPORT.md、本文件。没有修改 Save schema、库存模型、PlayerStats、路由或关卡。

Validation：Godot 4.7.2 D3D12 正常桌面运行；五窗口 120/120，最小窗口背包真实输入 12/12，原综合 55/55。最终 editor import 成功，四份相关日志均无 ERROR。检查最小窗口通知/背包/HUD 和 4:3 Debug 原尺寸 WebP；多行字可读、按钮可点击、通知不盖面板。证据：artifacts/verification/{ui_layout,inventory_ui_minimum,runtime_graphical,import}.log 与 artifacts/ui_layout/。

Unfinished / Known issues：仍为灰盒资产；DPI、手柄、长期试玩及声音听感没有宣称完成。现有生存/存档规则保持不变。

Next：沿用 M1 基础继续身体表现与体验收尾，或等用户明确安排下一 milestone。

### 2026-09-06～07 — Milestone 1 基础实现与验收

Goal：完整读规格、审计现有迁移项目，仅做 Foundation 并实测核心流程。

Completed：新增上述模块、7 项数据物品、两个灰盒房间及独立数据/存档测试。3 个 GPT-5.6 Sol 子 Agent 分别承担玩家/属性、Inventory UI、Shell/Phone UI；主 Agent 审查修正后整合库存事务、场景与存档。修复真实拖动旋转、丢包后 UI 归属、存档/死亡绕过、交互穿墙/过期目标、相机恢复、实例共享碰撞体、HUD/面板对比度、环境光源设置和身体挂点等问题。

Key files：project.godot；autoload/*.gd；core/main.tscn；core/foundation_app.gd；core/{interaction,inventory,items,persistence,phone,session,stats,world}/；player/；ui/；resources/；levels/test_rooms/；tests/；tools/verify_m1.ps1；README.md；THIRD_PARTY_ASSETS.md；docs/MILESTONE_1_ARCHITECTURE.md；docs/MILESTONE_1_REPORT.md；本文件。完整源文件清单见报告。

Validation：2026-09-07 完整 verify_m1.ps1 -Graphical -UserStorage 返回 MILESTONE_1_VERIFICATION_PASSED；五组专项测试通过、UI 12/12、无头综合 54/54、图形综合 55/55。最终身体/挂点调整后 player_audio、stats 与图形综合 55/55 再次通过。所有最终验收日志无 ERROR。artifacts/runtime_test/*.webp 为六张最终检查截图，artifacts/verification/*.log 为最终运行记录。

Unfinished / Known issues：无阻塞 M1 灰盒验收的已知问题；正式资产、长期试玩、多设备 UI 和故障注入验证仍未完成，见 Known Issues。未实现序章、L0 或 L1–L11。

Next：优先沿用当前框架收尾体验；后续开发先读设计规格和本文件，不要重新实现已验证的库存、路由或存档模型。
