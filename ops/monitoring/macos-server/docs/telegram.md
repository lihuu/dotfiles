# Telegram 配置说明

这套方案里的 Telegram 通知走 Alertmanager 原生 `telegram_configs`，不需要额外 bridge。

## 1. 创建 Bot

在 Telegram 里找到 `@BotFather`，依次执行：

```text
/start
/newbot
```

按提示设置：

- Bot 名称
- Bot username

创建完成后，`@BotFather` 会返回一段 token，格式类似：

```text
123456789:AAExampleToken
```

把它填到 `.env`：

```bash
TELEGRAM_BOT_TOKEN=123456789:AAExampleToken
```

## 2. 获取 Chat ID

有两种常见方式。

### 发给你自己的私聊

1. 在 Telegram 中找到你刚创建的 bot
2. 给它发送一条消息，比如 `/start`
3. 执行：

```bash
curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates"
```

返回 JSON 里会有：

```json
{
  "message": {
    "chat": {
      "id": 123456789
    }
  }
}
```

这个 `id` 就是你的 `TELEGRAM_CHAT_ID`。

### 发到群组

1. 把 bot 拉进目标群组
2. 给群里发送一条消息
3. 再执行一次：

```bash
curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates"
```

群组的 `chat.id` 通常是负数，例如：

```text
-1001234567890
```

把它填到 `.env`：

```bash
TELEGRAM_CHAT_ID=-1001234567890
```

## 3. 写入环境变量

```bash
TELEGRAM_BOT_TOKEN=123456789:AAExampleToken
TELEGRAM_CHAT_ID=123456789
```

如果你同时也想启用 Bark，再额外填写：

```bash
BARK_DEVICE_KEY=你的_bark_key
```

## 4. 重载服务

```bash
cd /Users/lihu/git/dotfiles/ops/monitoring/macos-server
./start.sh
```

## 5. 验证

检查 Alertmanager 当前 receivers：

```bash
curl -s http://127.0.0.1:9093/api/v2/status
```

检查渲染后的配置里是否包含 `telegram_configs`：

```bash
rg -n "telegram_configs|bot_token|chat_id" /Users/lihu/git/dotfiles/ops/monitoring/macos-server/.rendered
```

## 6. 常见问题

- 收不到消息，但 `getUpdates` 有结果：
  - 先确认 `TELEGRAM_CHAT_ID` 是最新值
  - 群组场景注意 chat id 往往是负数
- Bot 在群里没有权限：
  - 有些群需要先允许 bot 发言
- `getUpdates` 为空：
  - 先手动给 bot 或群组发送一条消息，再重试
- Alertmanager 启动失败：
  - 通常是 `TELEGRAM_CHAT_ID` 不是纯数字，或者 token 格式有误
