# .ai/AGENTS.md

## Scope

本目录用于 `Codex ↔ Gemini` 文档协作协议的项目内状态层。

## Rules

- 所有任务状态必须落在 `.ai/tasks/current/`
- 每个文件只承担单一职责
- 文件只保存当前状态快照，不保存聊天历史或推理过程
- 结构化字段优先，禁止自由散文式记录
- 任务完成后，相关状态应归档到 `.ai/tasks/archive/`

## Current Repository Notes

- 这是一个 dotfiles 仓库，优先保持最小改动
- 根级 `AGENTS.md` 仍然是仓库全局规则入口
- `.ai/` 只负责当前协议层的状态同步

