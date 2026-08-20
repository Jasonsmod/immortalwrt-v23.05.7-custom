# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

**核心语言要求**：全程**默认使用中文**进行所有回复、解释、代码注释和沟通，禁止主动使用英文，除非用户明确要求使用英文。每次回复最后都使用 >Z先生<结尾

## 0. 自动化文档维护 (README.md)

**每次项目新增 / 修改 / 修复完成后，必须自动执行以下流程：**

### 0.1 写入变更记录（强制）

将本次改动简述追加到 `README.md`，使用固定格式： `[YYYY-MM-DD] 类型：新增/修改/修复 | 模块：xxx | 内容：xxx`

### 0.2 长度阈值管理（强制）

- **设定阈值**：`README.md` 最大安全行数 = **300 行**。
- **检查逻辑**：写入新记录前，先统计文件总行数。
- **自动精简规则（超过阈值时触发）**：
  1. **必须保留**：项目主框架、技术栈、所有接口参数、模块进度、核心功能、设计图。
  2. **必须删除**：超过 30 天的旧变更记录（仅保留最近 5-10 条）、重复注释、废弃说明、非关键日志。
  3. **压缩描述**：将过细的实现细节转换为高层级的逻辑概括。
- **精简后再写入新记录**，确保文件体积始终可控。

### 0.3 模块开发进度标注（强制）

所有功能模块 / 代码模块标题后，必须标注统一进度标签： `✅ 已完成` | `🔄 开发中` | `⏸️ 暂停中` | `❌ 未开始` | `⚠️ 待修复`

------

## 1. 开发前强制流程：软件设计框架

**任何编码开始前，必须先输出完整软件设计框架。** 框架必须包含：

- **项目整体架构**：分层 / 模块化结构描述。
- **核心技术栈**：前端 / 后端 / 数据库 / 关键依赖。
- **功能模块清单**：带上进度占位标签。
- **接口设计清单**：名称 + 请求方式 + 入参 + 出参。
- **数据结构**：核心数据结构或数据库表结构。
- **核心业务流程**：关键逻辑的时序或流程说明。
-  **输出框架并由用户确认无误后，方可开始编码。**

------

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
