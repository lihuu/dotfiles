## 一些有用的脚本

- `inspect-fileproviderd.sh`: 检查 `fileproviderd` 正在服务的 File Provider 域、最近日志和可选的短时 `fs_usage` 采样
- `daily-summary.sh`: 每日工作总结材料收集器。纯 shell 预检查 dotfiles 仓库当日是否有 git 提交或未提交改动，无改动则输出 `NO_CHANGES` 并退出（零 token 跳过信号）；有改动时收集 git 提交历史、未提交改动和 zcode 对话历史，输出结构化 Markdown 到 stdout。实际的"大模型总结 + 写入 Obsidian"由 ZCode 内置 cron 每天 18:00 触发完成。手动运行：

  ```bash
  bash scripts/daily-summary.sh                            # 检查今天
  SUMMARY_DATE=2026-07-23 bash scripts/daily-summary.sh    # 测试历史日期
  ```