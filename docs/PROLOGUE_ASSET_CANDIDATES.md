# M2 序章写实 3D 模型候选清单

状态：候选与采用清单；`ADOPTED_GRAPHICS_VERIFIED` 表示资产已经导入正式场景或近景道具，并在 Godot 图形运行截图中检查；`DOWNLOADED_UNVERIFIED` 仍只表示已下载并校验文件完整性。  
检索与获取日期：2026-09-07。

## 选型基线

- 场景已确定为 **2000–2010 年、地域模糊的普通城市租住小公寓**，目标为 1080p60 的克制写实表现。
- 目标是 photoreal / PBR；明确 low-poly、卡通或高度风格化的套件不入选。
- 首选 [Poly Haven 资产许可页](https://polyhaven.com/license) 所覆盖的 CC0 模型。其官方说明允许商业用途、修改和再分发，且不要求署名；仍建议在项目资产账本中保留作者与来源。
- OpenGameArt 候选以各自资产页的许可声明为准，下载后还需保存页面快照或许可文本，并核对压缩包内容与页面描述一致。

## 优先候选

### 1. Metal Office Desk（书桌）— 推荐

- 状态：`ADOPTED_GRAPHICS_VERIFIED`（已置入序章公寓并完成图形截图检查）
- 页面：[Poly Haven / Metal Office Desk](https://polyhaven.com/a/metal_office_desk)
- 作者：Ulan Cabanilla
- 许可：[Poly Haven CC0 统一许可](https://polyhaven.com/license)；资产页也标注 `CC0 License`。
- 已下载：1K glTF、BIN、glTF 引用的 1K JPG Diffuse / Normal GL / ARM，位于 `assets/third_party/polyhaven/models/metal_office_desk/`；逐文件 URL、API MD5、SHA-256 和字节数见同目录 `manifest.json`。
- 页面数据：宽约 2 m，约 7K tris，8K 资产。
- 用途与取舍：磨损灰色金属双抽屉办公桌，很适合廉价租住公寓中的旧书桌；写实度、年代感和实时面数都合适。工业/单位家具气质略强，可用桌面杂物弱化。
- Godot：1K glTF 与引用材质已实际导入 `levels/prologue/apartment.tscn`；场景构建时校正摆位与比例，并已在公寓图形截图中检查。近景交互碰撞仍由项目场景逻辑负责。

### 2. Plastic Monobloc Chair 01（廉价椅）— 推荐

- 状态：`ADOPTED_GRAPHICS_VERIFIED`（已置入序章公寓并完成图形截图检查）
- 页面：[Poly Haven / Plastic Monobloc Chair 01](https://polyhaven.com/a/plastic_monobloc_chair_01)
- 作者：Kuutti Siitonen
- 许可：[Poly Haven CC0 统一许可](https://polyhaven.com/license)；资产页标注 `CC0 License`。
- 已下载：1K glTF、BIN、glTF 引用的 1K JPG Diffuse / Normal GL / ARM，位于 `assets/third_party/polyhaven/models/plastic_monobloc_chair_01/`；逐文件 URL、API MD5、SHA-256 和字节数见同目录 `manifest.json`。
- 页面数据：高约 0.9 m，约 3K tris，4K 资产。
- 用途与取舍：带磨损污渍的白色塑料一体椅，便宜、地域中性、时代跨度大，很符合普通出租屋。缺点是偏户外/临时家具，但这种错置感也能强化拮据生活气息。
- Godot：1K glTF 与引用材质已实际导入 `levels/prologue/apartment.tscn`，公寓内使用两个实例；摆位、比例和材质已在图形截图中检查。

### 3. Modern Wooden Cabinet（鞋柜 / 玄关收纳）— 有条件推荐

- 状态：`CANDIDATE_UNIMPORTED`
- 页面：[Poly Haven / Modern Wooden Cabinet](https://polyhaven.com/a/modern_wooden_cabinet)
- 作者：Patrik Pangerl
- 许可：[Poly Haven CC0 统一许可](https://polyhaven.com/license)；资产页标注 `CC0 License`。
- 下载形式：Blend、glTF、USD、FBX、ZIP；1K/2K/4K/8K 纹理档位，含 AO、ARM、Diffuse、Normal GL/DX、Roughness。页面显示 8K ZIP 约 49.99 MB。
- 页面数据：宽约 2.4 m，约 25K tris，8K 时约 16.8 px/cm。
- 用途与取舍：可裁成低矮玄关鞋柜或卧室收纳柜，PBR 完整。造型偏 2015 年后的现代设计，且 2.4 m 太宽；若年代锁定 2000–2010，应缩短/简化门板或继续找更普通的板式鞋柜。
- Godot：glTF 可直接导入；建议使用 2K/4K 版本，并在 DCC 中拆分柜门（若需要交互）和制作简化碰撞。

### 4. Modern Ceiling Lamp 01（吸顶/吊灯）— 有条件推荐

- 状态：`CANDIDATE_UNIMPORTED`
- 页面：[Poly Haven / Modern Ceiling Lamp 01](https://polyhaven.com/a/modern_ceiling_lamp_01)
- 作者：James Ray Cock
- 许可：[Poly Haven CC0 统一许可](https://polyhaven.com/license)；资产页标注 `CC0 License`。
- 下载形式：资产页提供模型下载器；贴图含 AO、ARM、Diffuse、多个 Mask、Metal、Normal GL/DX、Roughness，页面显示约 7.41 MB。
- 页面数据：高约 1 m，约 6K tris，8K 资产。
- 用途与取舍：玻璃球形吊灯写实、资源轻，能用于起居区或床边上方。它不是贴顶式廉价吸顶灯，造型略精致；若空间层高低或年代要求严格，只作为备选。
- Godot：优先 glTF；玻璃材质和发光需在 Godot 中重建/调校，实际照明仍使用独立 Light3D。

### 5. Desk Lamp Arm 01（书桌灯）— 推荐作补充灯具

- 状态：`ADOPTED_GRAPHICS_VERIFIED`（已置入序章公寓并完成图形截图检查）
- 页面：[Poly Haven / Desk Lamp Arm 01](https://polyhaven.com/a/desk_lamp_arm_01)
- 作者：Kuutti Siitonen（建模与贴图）、Yann Kervran（绑定）
- 许可：[Poly Haven CC0 统一许可](https://polyhaven.com/license)；资产页标注 `CC0 License`。
- 已下载：1K glTF、BIN、glTF 引用的 1K JPG Diffuse / Normal GL / ARM，位于 `assets/third_party/polyhaven/models/desk_lamp_arm_01/`；逐文件 URL、API MD5、SHA-256 和字节数见同目录 `manifest.json`。未下载非 glTF 依赖的 Mask 与独立预览图。
- 页面数据：高约 0.9 m，约 26K tris，8K 资产，带绑定。
- 用途与取舍：夹桌式弹簧臂工作灯贴合书桌和 2000 年代普通居住环境，细节足够近看。26K tris 对普通道具偏高，且绑定导入可能增加复杂度；静态使用应烘焙姿态并去除骨架。
- Godot：1K glTF 已作为静态书桌灯实例导入 `levels/prologue/apartment.tscn`；缩放、姿态和材质已在公寓图形截图中检查。当前没有把绑定用于玩法动画。

### 6. Bed（床）— 结构合适，材质需重点复核

- 状态：`CANDIDATE_UNIMPORTED`
- 页面：[OpenGameArt / Bed](https://opengameart.org/content/bed)
- 作者：Colorado Stark
- 许可：资产页标注 CC0，并声明模型发布到 Public Domain；通用许可原文可同时存档 [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)。
- 下载形式：`Bed.zip`（页面显示约 25.9 MB）；床体和床架两部分；Diffuse、Normal、Specular，TGA 2048×2048。
- 页面数据：8,189 triangles。
- 用途与取舍：面数合理、贴图齐全，轮廓偏古典但不是卡通 low-poly。它使用旧式 Specular 工作流而非金属度 PBR，且年代/地域中性程度需看实际预览；应先小样导入再决定是否重做床品材质。
- Godot：压缩包具体网格格式页面未明确，标记为未知；预计需要 Blender 打开/转换为 glTF，并把 Specular 材质转换到 Godot 的 PBR 参数。

### 7. Door（普通室内门）— 推荐作结构原型

- 状态：`CANDIDATE_UNIMPORTED`
- 页面：[OpenGameArt / Door](https://opengameart.org/content/door-1)
- 作者：NotionHD
- 许可：资产页标注 CC0，并明确允许使用、复制、修改和商业分发且无需署名；通用许可原文：[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)。
- 下载形式：`door.blend`，页面显示约 891 KB；门把手为门的子物体并使用独立材质。
- 页面数据：真实尺寸建模（英制）；三角面数与纹理规格未知。
- 用途与取舍：普通室内门轮廓与可分离把手适合作为序章交互门原型，地域指向弱。页面没有证明它含高质量 PBR 贴图，因此只能列为“结构推荐”，最终写实表现可能需要项目自有材质。
- Godot：需用 Blender 导出 glTF 2.0；导出前校正为米制、设置门轴铰链原点，并核对法线和碰撞。

## 替补候选

### 8. Smartphone（手机）— 仅年代确定后的临时替补

- 状态：`CANDIDATE_UNIMPORTED`
- 页面：[OpenGameArt / Smartphone](https://opengameart.org/content/smartphone-1)
- 作者：Brian MacIntosh（BMacZero）
- 许可：页面标注 CC0；通用许可原文：[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)。页面讨论记录称作者已从纹理中移除品牌标识。
- 下载形式：OBJ、Blend、去品牌 PNG 纹理及 PSD；页面列出具体文件。
- 页面数据：300 tris，1024×1024 摄影纹理。
- 用途与取舍：外观接近较早期智能手机，年代定在 2009–2010 之后时可用作临时道具。面数和纹理都偏低，近景 photoreal 不足；如序章要拿起查看手机，应继续找更高质量、无商标的 PBR 模型。
- Godot：OBJ 可导入，但建议在 Blender 中去除无关品牌残留、补粗糙度/法线并导出 glTF。

## 明确不采用

- Poly Haven `Classic Laptop`：虽然是 CC0、14K tris、4K 且质量高，但其米色机身、DOS 屏幕、轨迹球和软盘驱动器明显属于更早年代，不适合建议中的 2000–2010 普通公寓。除非用户把年代改到 1980–1990 年代，否则不下载。
- OpenGameArt `Low Poly Doors Asset`、`3D Interior Home Assets` 与 `Bed (low poly)`：许可清晰，但页面明确定位 low-poly，和 photoreal / PBR 要求冲突。

## 尚未找到合格模型的槽位

- **杯子、日常电脑包、可近景查看的无品牌手机、普通大型笔记本电脑**：本轮没有找到同时满足“官方/原作者页、明确可商用许可、写实 PBR、时代合适”的候选，因此不拿质量或许可不明的下载站条目凑数。
- **真正普通的 2000–2010 板式鞋柜、贴顶吸顶灯**：现有候选造型略新或用途需要改造。年代确认后应以这些槽位为下一轮定向检索目标。

## 已采用的公寓与近景道具材质

以下四组 Poly Haven CC0 材质状态均为 `ADOPTED_GRAPHICS_VERIFIED`。逐文件官方 URL、API MD5、本地 SHA-256、字节数和本地路径保存在各目录 `manifest.json`，并已在 Godot 图形运行截图中检查。

- **Wood Floor**：公寓木地板；作者 Dimitrios Savva；[来源页](https://polyhaven.com/a/wood_floor)；本地 `assets/third_party/polyhaven/textures/wood_floor/`。
- **White Plaster 02**：公寓、通勤段与抵达区墙面；作者 Rob Tuytel；[来源页](https://polyhaven.com/a/white_plaster_02)；本地 `assets/third_party/polyhaven/textures/white_plaster_02/`。
- **Fabric Pattern 07**：床品、电脑包、钥匙、背包近景 UI 与布艺材质；作者 Rob Tuytel；[来源页](https://polyhaven.com/a/fabric_pattern_07)；本地 `assets/third_party/polyhaven/textures/fabric_pattern_07/`。采用官方 `col_1` 变体。
- **Brown Leather**：钱包、电脑包与背包近景 UI 皮革材质；作者 Rob Tuytel；[来源页](https://polyhaven.com/a/brown_leather)；本地 `assets/third_party/polyhaven/textures/brown_leather/`。

## Level 0 有限落地区材质

以下三组均为 Poly Haven CC0，状态为 `ADOPTED_GRAPHICS_VERIFIED`。已下载 2K JPG Diffuse、1K JPG Normal GL 和 1K JPG ARM；逐文件官方 URL、API MD5、本地 SHA-256、字节数和本地路径见各目录的 `manifest.json`。Decrepit Wallpaper 与 Dirty Carpet 已用于有限落地区，Terrazzo Tiles 已用于公寓公共走廊及通勤段；均已在 Godot 图形截图中检查。

### Decrepit Wallpaper（旧米黄色墙纸基底）

- 页面：[Poly Haven / Decrepit Wallpaper](https://polyhaven.com/a/decrepit_wallpaper)
- 作者：Rob Tuytel；发布日期：2024-10-01。
- 本地：`assets/third_party/polyhaven/textures/decrepit_wallpaper/`
- 取舍：没有华丽图案或强烈周期花纹，褪色、剥落和污渍适合 L0 黄纸基调。原图破损信息较多，落地时应降低法线强度、控制 UV 比例和颜色度，避免把整片空间做成高反差废墟。

### Dirty Carpet（低对比细纹旧地毯）

- 页面：[Poly Haven / Dirty Carpet](https://polyhaven.com/a/dirty_carpet)
- 作者：Rohit Seervi；发布日期：2023-11-07。
- 本地：`assets/third_party/polyhaven/textures/dirty_carpet/`
- 取舍：橄榄棕色、褪色、细微条纹和压平绒面符合旧办公/公共空间地毯，纹样克制。素材物理宽度约 0.6 m，铺大面积时需检查接缝重复；只用于小范围落地区或通过宏观污渍打散重复。

### Terrazzo Tiles（公共走廊水磨石地砖）

- 页面：[Poly Haven / Terrazzo Tiles](https://polyhaven.com/a/terrazzo_tiles)
- 作者：Amal Kumar；发布日期：2025-05-06。
- 本地：`assets/third_party/polyhaven/textures/terrazzo_tiles/`
- 取舍：暖棕底、细小多色骨料和低调方格缝适合普通公共走廊；比装饰性强的花砖更地域中性。材质原本偏干净且有抛光感，Godot 中应降低高光并加入轻微使用痕迹，与 L0 陈旧感对齐。

## 下载前核验清单

1. 在下载当日重新打开资产页与许可页，记录 URL、作者、许可、版本/发布日期和下载格式；将许可证据纳入 `THIRD_PARTY_ASSETS.md` 流程。
2. 首选 glTF/GLB 和 2K–4K PBR 贴图；不要默认使用 8K，以免序章小空间产生不必要显存压力。
3. 检查真实尺寸、坐标轴、材质通道、透明/玻璃、法线方向、可交互物体枢轴、碰撞体与静态网格面数。
4. 对电子产品检查商标、UI 图标和摄影纹理中的第三方标识；CC0 模型许可并不自动消除商标风险。
5. 只有实际导入 Godot、检查材质与性能后，才能把 `CANDIDATE_UNIMPORTED` 改为已采用状态。
