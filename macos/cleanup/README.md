# macOS Cleanup

这个目录只放 macOS 上“可以直接清除”的维护脚本。

## `report-application-support-orphans.sh`

扫描 `~/Library/Application Support` 的顶层目录，输出疑似卸载残留报告。

### 规则

- 先用当前已安装的 `.app` 名称做匹配
- 没有匹配上的目录，按大小和最近修改时间打分
- 默认只报告 `MEDIUM` / `HIGH` 候选
- 这是启发式报告，不会自动删除，也可能把仍在使用的共享目录列入候选，需要人工确认

### 用法

```bash
bash macos/cleanup/report-application-support-orphans.sh
```

可通过环境变量调整阈值：

```bash
AGE_THRESHOLD_DAYS=120 SIZE_THRESHOLD_MB=10 bash macos/cleanup/report-application-support-orphans.sh
```

## `clean-chrome-default-safe.sh`

只处理 Chrome 的 `Default` profile，默认是预览模式，不会删除任何内容。

### 会删除

- `Cache`
- `Code Cache`
- `GPUCache`
- `DawnCache`
- `ShaderCache`
- `GrShaderCache`
- `Media Cache`
- `IndexedDB` 中单个目录体积大于等于 `100MB` 的条目

### 不会删除

- `Cookies`
- `Login Data`
- `Bookmarks`
- `History`
- `Local Storage`
- `Session Storage`
- `Preferences`
- 任何非 `Default` profile

### 用法

```bash
bash macos/cleanup/clean-chrome-default-safe.sh
bash macos/cleanup/clean-chrome-default-safe.sh --apply
```

建议先退出 Chrome，再执行 `--apply`。
