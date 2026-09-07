# AGENTS.md — Backrooms Godot 项目 Agent 协作与开发记录规则

> 本文件面向 Codex / Coding Agent。  
> 目标：让不同会话、不同 Agent 乃至不同账户都能仅凭仓库内容继续开发，并尽量把简单工作委派给 **GPT-5.6 Sol 子 Agent**，把高成本主 Agent 留给架构、整合和疑难问题。

---

## 1. 最高优先级原则

1. 开始任何开发任务前，先阅读本文件。
2. 再阅读项目的主要设计规格：
   - `docs/AGENT_GODOT_BACKROOMS_DEMO_PLAN.md`
   - 若路径不同，以仓库中实际存在的最新版设计文档为准。
3. 设计文档是玩法与产品需求的主要事实来源；现有旧代码、旧注释、旧开发记录与最新版设计冲突时，以最新版设计文档为准。
4. 不得自行改变核心玩法设定。遇到会明显改变玩家体验、存档结构、系统边界或世界观的未定义问题，应记录问题并询问用户。
5. 可以使用免费且开源的资产、插件和库，但必须遵守设计文档中的许可证与 `THIRD_PARTY_ASSETS.md` 管理规则。
6. 不要为了“快速完成”把关键系统永久硬编码在单个 Level 或 UI 场景中。

---

# 2. 开发记录必须自动维护

仓库必须维护：

```text
docs/
└── DEVELOPMENT.md
```

如果文件不存在，Agent 应自动创建。

**每一次产生实际代码、场景、Resource、配置、资产引用或架构变更的开发任务结束前，都必须更新 `docs/DEVELOPMENT.md`。用户不需要重复提醒。**

只进行讨论、解释、代码阅读且没有修改仓库时，不必写入开发记录。

---

## 2.1 DEVELOPMENT.md 的用途

它不是聊天摘要，而是项目的**跨会话工程记忆**。

新的 Agent 应当能够通过：

```text
AGENTS.md
设计规格
DEVELOPMENT.md
Git history
当前源码
```

理解项目当前状态，而不依赖以前的 Codex 会话。

因此禁止写：

> 今天做了很多背包相关工作。

应写：

> 实现 `InventoryGrid` 的 90° 旋转放置检测；加入 `ContainerInstance` 嵌套容器序列化；当前仍禁止循环嵌套；`tests/inventory/` 中加入旋转碰撞测试。

---

# 3. DEVELOPMENT.md 固定结构

优先保持以下结构：

```markdown
# Development Log

## Current Status
当前可运行版本、当前 Milestone、主要完成度。

## Implemented
已经真正实现并验证的系统。

## In Progress
已经开始但尚未完成的内容。

## Known Issues
已知 Bug、性能问题、临时方案。

## Architecture Decisions
会影响未来开发的重要技术决定，以及决定原因。

## Pending Design Questions
只有必须由用户决定的问题才放这里。

## Next Recommended Tasks
下一位 Agent 最适合继续处理的任务，按优先级排列。

## Session Log
按时间倒序或正序记录每次实际开发。
```

不要无限复制整个历史到每条 Session Log。长期稳定的信息应提升到前面的状态章节。

---

# 4. 每次开发结束时必须记录什么

至少记录：

```text
日期
任务目标
完成内容
新增/修改的关键文件
测试结果
未完成内容
已知问题
下一步
```

例如：

```markdown
### 2026-09-06 — Inventory Grid MVP

Goal:
实现二维异形物品放置与 90° 旋转。

Completed:
- 新增 InventoryGrid 数据结构。
- ItemShape 支持二维占格。
- 支持 90° 旋转。
- 拒绝重叠和越界放置。
- UI 可拖拽物品。

Key files:
- scripts/inventory/inventory_grid.gd
- scripts/items/item_shape.gd
- ui/inventory/inventory_grid_view.gd

Validation:
- 2×1、1×2、L 型测试物品通过放置测试。
- 越界与重叠检测正常。

Known issues:
- 尚未实现嵌套背包。
- 拖拽动画只是占位效果。

Next:
实现 ContainerInstance。
```

---

# 5. 不得伪造完成状态

只有真正满足以下至少一种条件时才能写入 `Implemented`：

- 已运行 Godot 并验证；
- 有自动测试证明；
- 有明确的静态验证结果，且功能不依赖运行时行为。

仅仅“代码已经写了”但尚未运行的内容应标记：

```text
IMPLEMENTED_UNVERIFIED
```

不能写成：

```text
DONE
```

如果 Godot、依赖或运行环境无法启动，也必须如实记录。

---

# 6. 主 Agent 与 Sol 子 Agent 的职责划分

如果当前 Codex 环境支持创建/调用子 Agent，**简单、局部、低风险任务优先委派给使用 GPT-5.6 Sol 的子 Agent**。

主 Agent负责：

- 理解用户最终目标；
- 阅读设计规格；
- 拆分任务；
- 系统架构；
- 跨模块修改；
- 重要数据模型；
- 高风险重构；
- 合并和审查子 Agent 结果；
- 运行最终验证；
- 更新 `DEVELOPMENT.md`；
- 向用户汇报。

Sol 子 Agent负责可独立验证的简单任务。

---

# 7. 应优先交给 Sol 子 Agent 的任务

典型包括但不限于：

```text
简单 Godot UI
设置页面
按钮/Slider/Toggle
InputMap 配置
简单 Resource 定义
单个 ItemDefinition
普通数据录入
手机联系人/聊天静态数据
普通房间模块
简单 Shader 调整
音频 Bus 配置
代码格式化
注释补充
重复性重构
测试用例补充
静态检查
寻找明显 Bug
文档同步
资源清单整理
许可证记录
简单场景连接
简单 signal wiring
```

如果一个任务可以被描述为：

> “修改少量明确文件，不需要重新决定整个系统架构，并且结果容易测试。”

优先考虑 Sol。

---

# 8. 不应轻易委派给简单子 Agent 的任务

以下任务默认由主 Agent处理，或由主 Agent明确设计方案后再把局部实现交给 Sol：

```text
InventoryInstance / ContainerInstance 核心模型
嵌套背包与循环引用处理
Save schema 与版本迁移
World Item Persistence
Level 0 RoomGraph
Chunk Streaming
Peripheral Shift
Observation System
Threshold / noclip 核心
第一人称完整身体架构
跨 Level 状态
实体 AI 总体架构
Faction / Knowledge / Quest 总体架构
大规模性能重构
会导致存档不兼容的修改
```

主 Agent可以先定义接口，再把其中独立模块交给 Sol。

---

# 9. 子 Agent 调用原则

不要为了“用了子 Agent”而调用子 Agent。

每次委派必须给出：

1. 明确任务；
2. 允许修改的文件/目录；
3. 禁止修改的边界；
4. 相关接口；
5. 验收标准；
6. 要求返回修改摘要和风险。

推荐形式：

```text
使用 GPT-5.6 Sol 子 Agent。

任务：
实现 SettingsMenu 中的沉浸 UI 开关。

允许修改：
- ui/settings/**
- scripts/settings/**

不要修改：
- Save schema
- PlayerStats
- Inventory
- Level scenes

接口：
SettingsManager.immersive_ui_enabled

验收：
1. 开关可以保存。
2. 重启后恢复。
3. 开启时隐藏 HUD 数值。
4. 不影响图标状态。

完成后只返回：
- 修改文件
- 实现摘要
- 测试结果
- 风险/未解决问题
```

---

# 10. 子 Agent 不拥有最终决定权

子 Agent 的输出视为**候选实现**。

主 Agent必须检查：

```text
是否符合设计文档
是否破坏已有接口
是否引入重复系统
是否产生明显性能问题
是否影响存档
是否真的通过测试
```

不能因为子 Agent 声称“完成”就直接记录为完成。

---

# 11. 尽量并行处理互不依赖的简单任务

如果环境支持并行子 Agent，可把互不修改同一核心文件的任务并行交给 Sol，例如：

```text
Sol A → Settings UI
Sol B → 手机静态 App 数据
Sol C → Level 0 普通房间模块
Sol D → Inventory 单元测试
```

但不要并行让多个 Agent 修改：

```text
SaveManager.gd
InventoryManager.gd
WorldState.gd
RoomGraph.gd
```

等核心共享文件，除非已经明确拆分接口。

---

# 12. 控制上下文与 Token 消耗

子 Agent只读取完成任务所必需的文件。

不要默认让每个 Sol 子 Agent重新阅读：

```text
整个仓库
完整设计文档
完整 DEVELOPMENT.md 历史
所有 Level 文件
```

主 Agent应给它提供必要上下文，并让它只打开相关章节和源码。

对于简单任务：

> 小上下文 + 明确接口 + 明确验收

优于：

> “阅读整个项目然后自己决定。”

---

# 13. 开始任务的标准流程

主 Agent每次开始实际开发时：

```text
1. 阅读 AGENTS.md
2. 阅读 DEVELOPMENT.md 的 Current Status / In Progress / Known Issues / Next Recommended Tasks
3. 阅读与当前任务有关的设计文档章节
4. 检查相关源码和 Git 状态
5. 判断任务：
   A. 主 Agent直接处理
   B. 拆分后部分交给 Sol
   C. 多个 Sol 并行
6. 编码
7. 运行测试 / Godot 验证
8. 审查结果
9. 更新 DEVELOPMENT.md
10. 向用户汇报
```

---

# 14. 中断与额度耗尽时的交接规则

如果预计无法在当前会话完成任务，**不要在上下文耗尽前继续盲目编码**。

优先停止在可恢复状态，并立即更新：

```text
DEVELOPMENT.md
```

写清：

```text
已经做到哪里
当前分支/文件状态
最后一个成功测试
当前报错
下一步具体操作
哪些文件不要重新实现
```

目标是让另一个 Codex 会话能够直接继续。

---

# 15. Git 提交建议

如果用户允许 Agent提交 Git：

- 一个逻辑功能尽量对应一个清晰 commit；
- 不把大量互不相关修改塞进同一 commit；
- commit message 描述功能，而不是“update”；
- `DEVELOPMENT.md` 应随相关功能一起提交。

例如：

```text
feat(inventory): add rotated grid placement
feat(phone): add offline app shell
feat(level0): add Manila Room knowledge unlock
fix(save): persist nested container contents
```

未经用户授权，不要擅自 push 到远程仓库、发布 Release 或部署。

---

# 16. DEVELOPMENT.md 不是设计文档的替代品

规则：

```text
AGENT_GODOT_BACKROOMS_DEMO_PLAN.md
    ↓
规定“应该做成什么”

DEVELOPMENT.md
    ↓
记录“现在实际上做到了什么”

源码 / 场景 / Resource
    ↓
代表“实际实现”
```

如果三者不一致：

1. 不要悄悄选择其中一个；
2. 判断是代码落后还是设计文档过期；
3. 明确记录冲突；
4. 核心玩法冲突时询问用户。

---

# 17. 禁止事项

Agent 不得：

- 为了节省时间删除用户明确要求的玩法；
- 未说明就把复杂系统改成假实现；
- 为了通过测试把测试删掉；
- 把 Debug workaround 当正式架构；
- 未经验证就在 DEVELOPMENT.md 写“完成”；
- 让简单 Sol 子 Agent自行重构整个项目；
- 让多个 Agent无协调修改同一核心系统；
- 依赖聊天历史保存唯一的重要工程信息；
- 把密码、API Key、Token 写入 DEVELOPMENT.md；
- 在开发记录中保存不必要的用户隐私信息。

---

# 18. 最终目标

本项目应做到：

> **任何新的 Codex 会话，在没有旧聊天上下文的情况下，只阅读仓库中的 AGENTS.md、设计文档、DEVELOPMENT.md 和相关源码，就能够安全继续开发。**

主 Agent负责保持架构一致性。

GPT-5.6 Sol 子 Agent负责消化大量明确、简单、可验证的工程工作。

`DEVELOPMENT.md` 负责让整个项目拥有独立于任何单次 AI 会话的长期工程记忆。
