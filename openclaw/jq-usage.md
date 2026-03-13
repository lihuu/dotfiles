# jq 使用说明

本文档整理 `jq` 的常用安装方式、命令参数和 JSON 操作语法，方便在 `openclaw` 目录下编写和维护 JSON 处理脚本。

## 1. 如何安装

### macOS

如果使用 Homebrew：

```bash
brew install jq
```

安装完成后检查版本：

```bash
jq --version
```

### Ubuntu / Debian

```bash
sudo apt update
sudo apt install -y jq
```

### CentOS / RHEL

```bash
sudo yum install -y jq
```

如果是较新的系统，也可能使用：

```bash
sudo dnf install -y jq
```

### Arch Linux

```bash
sudo pacman -S jq
```

## 2. 常用参数

`jq` 的基本格式：

```bash
jq [选项] 'filter' input.json
```

常用参数如下：

- `-r`
  以原始字符串输出，去掉 JSON 字符串两边的引号

```bash
echo '{"name":"openclaw"}' | jq -r '.name'
```

输出：

```text
openclaw
```

- `-c`
  紧凑输出，每个 JSON 对象只占一行

```bash
echo '{"a":1,"b":2}' | jq -c '.'
```

- `-M`
  禁用彩色输出，适合重定向到文件或脚本环境

- `-S`
  按 key 排序输出

```bash
echo '{"b":2,"a":1}' | jq -S '.'
```

- `--arg name value`
  向 `jq` 中传入字符串变量

```bash
jq --arg version "1.0.0" '.version = $version' config.json
```

- `--argjson name value`
  向 `jq` 中传入 JSON 值，而不是普通字符串

```bash
jq --argjson enabled true '.enabled = $enabled' config.json
```

- `-n`
  不读取输入，直接构造 JSON

```bash
jq -n '{name:"openclaw", enabled:true}'
```

## 3. JSON 操作语法

`jq` 的核心是 `filter`。你可以把它理解成“如何从输入 JSON 中选择、变换、生成输出 JSON”的表达式。

### 3.1 读取字段

读取对象字段：

```bash
echo '{"name":"openclaw","port":8080}' | jq '.name'
```

读取嵌套字段：

```bash
echo '{"meta":{"version":"1.0.0"}}' | jq '.meta.version'
```

读取数组元素：

```bash
echo '{"ports":[8080,9090]}' | jq '.ports[0]'
```

### 3.2 同时读取多个字段

```bash
echo '{"name":"openclaw","port":8080}' | jq '{name, port}'
```

输出：

```json
{
  "name": "openclaw",
  "port": 8080
}
```

### 3.3 修改字段

把已有字段改掉：

```bash
echo '{"port":8080}' | jq '.port = 9090'
```

添加新字段：

```bash
echo '{"name":"openclaw"}' | jq '.enabled = true'
```

修改嵌套字段：

```bash
echo '{"meta":{"version":"1.0.0"}}' | jq '.meta.version = "1.1.0"'
```

### 3.4 删除字段

```bash
echo '{"name":"openclaw","debug":true}' | jq 'del(.debug)'
```

删除嵌套字段：

```bash
echo '{"meta":{"version":"1.0.0","tmp":1}}' | jq 'del(.meta.tmp)'
```

### 3.5 默认值处理

当字段可能不存在时，经常会用到 `//`：

```bash
echo '{}' | jq '.properties // {}'
```

含义：

- 如果 `.properties` 存在，就使用它
- 如果 `.properties` 不存在或为 `null`，就使用空对象 `{}`

这在给 JSON 追加字段时非常常见。

### 3.6 合并对象

使用 `+` 合并对象：

```bash
echo '{"a":1}' | jq '. + {"b":2}'
```

结果：

```json
{
  "a": 1,
  "b": 2
}
```

也可以用于合并某个子对象：

```bash
echo '{"properties":{"meta":{"type":"object"}}}' | jq '
  .properties = (.properties + {
    "version": {
      "type": "string"
    }
  })
'
```

### 3.7 管道语法

`|` 表示把前一个结果继续传给后面的表达式：

```bash
echo '{"schema":{"properties":{"meta":{"type":"object"}}}}' | jq '
  .schema
  | .properties
'
```

这和 Shell 里的管道类似，但处理的是 JSON 数据结构。

### 3.8 数组遍历

遍历数组中的每个元素：

```bash
echo '[{"name":"a"},{"name":"b"}]' | jq '.[]'
```

只取每个元素的 `name`：

```bash
echo '[{"name":"a"},{"name":"b"}]' | jq '.[].name'
```

### 3.9 条件判断

```bash
echo '{"enabled":true}' | jq 'if .enabled then "on" else "off" end'
```

### 3.10 构造新 JSON

```bash
echo '{"name":"openclaw","port":8080}' | jq '{
  serviceName: .name,
  listenPort: .port
}'
```

## 4. 当前脚本中的 jq 用法解释

当前脚本 [dump-openclaw-config-schema.sh](/Users/lihu/git/dotfiles/openclaw/dump-openclaw-config-schema.sh) 中的核心逻辑如下：

```sh
openclaw gateway call config.schema --json | jq '
  .schema
  | .properties = ((.properties // {}) + {
      "$schema": {
        "type": "string"
      }
    })
' > ./openclaw.schema.json
```

这里分成几步：

1. `.schema`
   从命令输出中取出 `schema` 字段

2. `.properties // {}`
   如果 `properties` 不存在，就先用空对象 `{}` 代替

3. `+ { "$schema": { "type": "string" } }`
   在原有 `properties` 的基础上追加一个新的 `$schema` 字段

4. `.properties = (...)`
   把合并后的对象重新写回 `properties`

最终就能保证生成的 `openclaw.schema.json` 在 `properties` 下包含：

```json
"$schema": {
  "type": "string"
}
```

## 5. 常用实战示例

### 从 JSON 中提取 schema

```bash
openclaw gateway call config.schema --json | jq '.schema'
```

### 输出到文件并格式化

```bash
openclaw gateway call config.schema --json | jq '.schema' > openclaw.schema.json
```

### 给 properties 新增字段

```bash
jq '
  .properties = ((.properties // {}) + {
    "$schema": {
      "type": "string"
    }
  })
' openclaw.schema.json
```

### 检查某个字段是否存在

```bash
jq '.properties["$schema"]' openclaw.schema.json
```

### 只输出某个字段的类型

```bash
jq -r '.properties["$schema"].type' openclaw.schema.json
```

## 6. 建议

- 对于脚本内使用，优先把 `jq` 表达式写成多行，便于维护
- 对于可能不存在的字段，优先使用 `//` 做兜底
- 对于对象追加字段，优先使用 `.field = ((.field // {}) + {...})` 这种写法
- 对于排障，先单独执行 `jq` 表达式确认输出，再放进脚本
