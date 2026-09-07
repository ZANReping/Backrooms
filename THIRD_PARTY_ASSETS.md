# Third-party assets

Milestone 1（2026-09-07）没有引入第三方模型、贴图、音频、插件或库。

- 房间、身体、物品由本项目几何体构建；合成脚步为项目代码生成。
- UI 使用 Godot 字体回退或宿主已有系统字体；未把系统字体文件复制到项目或再分发。
- Godot 4.7.2 是运行环境，不作为本项目新引入的资产。本轮不修改引擎。

后续新增依赖时，每项必须记录名称、用途、来源页面、作者、版本/提交号、许可证、署名义务、本地路径、是否修改；未经确认的素材不得加入正式项目。

## Milestone 2 序章候选素材（2026-09-07）

以下资产来自 Poly Haven，统一使用 [CC0 1.0 许可](https://polyhaven.com/license)，允许商业使用且无需署名。下表十项均已实际导入序章场景、UI 或近景道具，并经 Godot 图形运行截图检查，状态为 `ADOPTED_GRAPHICS_VERIFIED`。文件此前已按官方 API 提供的 MD5 校验，并另计算 SHA-256。下载工具调用 Poly Haven 公开 API，因此工具与本文档注明 [Powered by Poly Haven](https://polyhaven.com)；API 代码未复制进游戏。

每个资产目录中的 `manifest.json` 是逐文件记录，包含来源页、API 文件端点、作者与职责、发布日期、获取日期、分辨率、官方 URL、本地路径、文件字节数、API MD5 和本地 SHA-256。下载内容未修改。

| 资产 | 实际采用用途 | 作者 | 发布日期（UTC） | 获取规格 | 本地路径 / SHA-256 记录 |
| --- | --- | --- | --- | --- | --- |
| Metal Office Desk | 序章公寓书桌模型 | Ulan Cabanilla | 2026-03-20 | 1K glTF 及全部引用依赖 | `assets/third_party/polyhaven/models/metal_office_desk/manifest.json` |
| Plastic Monobloc Chair 01 | 序章公寓廉价椅模型（两个实例） | Kuutti Siitonen | 2022-11-14 | 1K glTF 及全部引用依赖 | `assets/third_party/polyhaven/models/plastic_monobloc_chair_01/manifest.json` |
| Desk Lamp Arm 01 | 序章公寓静态书桌灯模型 | Kuutti Siitonen（建模与贴图）、Yann Kervran（绑定） | 2022-08-31 | 1K glTF 及全部引用依赖 | `assets/third_party/polyhaven/models/desk_lamp_arm_01/manifest.json` |
| Wood Floor | 公寓木地板材质 | Dimitrios Savva | 2023-10-24 | Diffuse 2K、Normal GL 1K、ARM 1K，JPG | `assets/third_party/polyhaven/textures/wood_floor/manifest.json` |
| White Plaster 02 | 公寓、通勤段及抵达区墙面材质 | Rob Tuytel | 2018-07-11 | Diffuse 2K、Normal GL 1K、ARM 1K，JPG | `assets/third_party/polyhaven/textures/white_plaster_02/manifest.json` |
| Fabric Pattern 07 | 公寓床品、电脑包、钥匙与人物服装法线；已从背包 UI 移除 | Rob Tuytel | 2020-05-29 | `col_1` 1K、Normal GL 1K、ARM 1K，JPG | `assets/third_party/polyhaven/textures/fabric_pattern_07/manifest.json` |
| Brown Leather | 钱包、电脑包实体材质；已从背包 UI 移除 | Rob Tuytel | 2020-05-25 | Diffuse（文件名为 albedo）1K、Normal GL 1K、ARM 1K，JPG | `assets/third_party/polyhaven/textures/brown_leather/manifest.json` |
| Decrepit Wallpaper | Level 0 有限抵达区旧米黄墙纸 | Rob Tuytel | 2024-10-01 | Diffuse 2K、Normal GL 1K、ARM 1K，JPG | `assets/third_party/polyhaven/textures/decrepit_wallpaper/manifest.json` |
| Dirty Carpet | Level 0 有限抵达区低对比旧地毯 | Rohit Seervi | 2023-11-07 | Diffuse 2K、Normal GL 1K、ARM 1K，JPG | `assets/third_party/polyhaven/textures/dirty_carpet/manifest.json` |
| Terrazzo Tiles | 公寓公共走廊与通勤段水磨石地砖 | Amal Kumar | 2025-05-06 | Diffuse 2K、Normal GL 1K、ARM 1K，JPG | `assets/third_party/polyhaven/textures/terrazzo_tiles/manifest.json` |

来源页面分别为：

- <https://polyhaven.com/a/metal_office_desk>
- <https://polyhaven.com/a/plastic_monobloc_chair_01>
- <https://polyhaven.com/a/desk_lamp_arm_01>
- <https://polyhaven.com/a/wood_floor>
- <https://polyhaven.com/a/white_plaster_02>
- <https://polyhaven.com/a/fabric_pattern_07>
- <https://polyhaven.com/a/brown_leather>
- <https://polyhaven.com/a/decrepit_wallpaper>
- <https://polyhaven.com/a/dirty_carpet>
- <https://polyhaven.com/a/terrazzo_tiles>

`fabric_pattern_07` 的官方 API 没有 `Diffuse` 键，而是提供 `col_1`、`col_2`、`col_03` 三种颜色；本次选择 `col_1`，没有把其他变体或预览图当成资产纹理。`brown_leather` 的 API 键为 `Diffuse`，实际文件名使用 `albedo`。三个模型的导入比例、摆位与材质已在公寓截图中检查；碰撞与交互边界由项目场景实现，不归第三方模型本身提供。

序章中除上述三项模型外的房间结构、门窗、床、柜体、电脑包、笔记本电脑、手机、钱包、钥匙、售水点和其他近景道具均由项目使用 Godot 几何与自有脚本构建；它们不是从素材站下载的模型。闹钟、环境嗡鸣、通勤过渡和脚步等当前声音由项目代码合成，也不是下载的第三方音频。

可重复下载与校验脚本：`tools/fetch_prologue_assets.ps1`。

## 2026 手机、状态及装备图标

采用 Lucide Static 1.41.0 的 39 个 SVG，commit `bca7e75a816dcf1e75e8feb5a3198a68cbb8a052`，作者 Lucide Contributors / Feather Contributors。来源 [Lucide](https://github.com/lucide-icons/lucide)，许可证 ISC 与内含 Feather MIT 声明，完整保存在 `assets/ui/icons/lucide/LICENSE`；分发时保留这些声明。只将 currentColor 改成白色描边，几何未改。逐文件 SHA-256 与可复现抓取见 `docs/UI_ICON_ASSETS.md`、`tools/fetch_ui_icons.ps1`。

`assets/ui/icons/project/` 的帽、裤、鞋、项链、戒指五个 SVG 为本项目原创，与 Lucide 文件分开管理。

## 统一人物开发资产

| 资产 | 来源与版本 | 许可和状态 | 本地位置及处理 |
| --- | --- | --- | --- |
| GD-Human skinned human / shirt / jeans / eyes | [Yni-Viar/gd-human-framework](https://github.com/Yni-Viar/gd-human-framework)，commit `cf0e05de95ddc2f5a371cb27eb4af72d016566d0` | 上游声明 CC0；基础模型逐文件来源链较弱，保留 `EVALUATION_CANDIDATE_NOT_COMMERCIAL_CLEARANCE` 标记，不能据此宣称正式商用清权 | `assets/third_party/characters/gd_human_delta_v1/` 保留原始 GLB、CC0 正文、hash、形变清单；未引入上游插件/Autoload/AGPL 代码 |
| MakeHuman 系统皮肤、棕色眼睛、short01/bob01/ponytail01、shoes01 | MakeHuman Community 官方系统资产包；各项官方 URL/原文件名/SHA-256 见目录 manifest | CC0，Data Collection AB / Joel Palmius / Jonas Hauquier 等；逐文件 MHCLO/MHMAT 的 2020-09 CC0 释放声明原样保留 | `assets/third_party/characters/makehuman_system_cc0/`；导入时 OBJ 缩放/摆位、发色参数和左右鞋分割由项目适配层实现 |

`characters/generated/human.glb` 派生自上述候选：`tools/prepare_character_asset.py` 在源模型局部 y<1.435m 处归零脸部形变残差，并加入覆盖区域顶点标识，保持原骨架、蒙皮和 UV。COLOR_0.R 为衣物/第一人称覆盖区域；本轮 COLOR_0.G 加入源 x<−0.34m 的右前臂/手部标签，使实体手机握持复用同一蒙皮网格和官方 CC0 皮肤，不再使用胶囊手指。派生前后 hash 见 `characters/generated/manifest.json`，仍继承候选来源限制。MicroDetail CC-BY 贴图、Humanizer AGPL 与 Configura 示例人物均未进入运行依赖。详见 `docs/CHARACTER_BACKEND_EVALUATION.md`。

2026-09-07 后续六项调整没有新增外部下载。窄边框手机及其重渲染物品图标、门铰链/手把、人物姿态与 UI 主题均由项目代码修改；现有第三方声明继续保留。
