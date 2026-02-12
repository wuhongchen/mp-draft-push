# wechat-ai-publisher (Skill)

自动采集 AI 热点，撰写公众号文章，生成配图并发布到微信公众号草稿箱。

本仓库已移除所有硬编码的密钥/Token/本地路径；你需要通过环境变量自行配置（见下文）。

## 安装

把整个目录放到你的 Skills 目录下（任选其一）：

- `~/.codex/skills/wechat-ai-publisher/`
- `$CODEX_HOME/skills/wechat-ai-publisher/`
- `~/.claude/skills/wechat-ai-publisher/`（Claude Code / Cloud Code）
- `~/.gemini/skills/wechat-ai-publisher/`（Gemini：建议约定此路径，具体以你的工具为准）
- `~/.openclaw/workspace/skills/wechat-ai-publisher/`（OpenClaw 默认 workspace）
- `~/.openclaw/skills/wechat-ai-publisher/`（OpenClaw 全局 skills）

## 配置

1) 复制配置模板：

```bash
cp .env.example .env
```

2) 在 `.env` 填入以下变量：

- `WECHAT_APPID` / `WECHAT_SECRET`：公众号后台获取（用于换取 `access_token`）。
- `REPLICATE_API_KEY`：用于生成配图（Replicate）。
- `WECHAT_AUTHOR`（可选）：文章作者字段（默认：`田威 AI`）。
- `DEFAULT_COVER_URL`（可选）：图片生成失败时的兜底封面 URL。

3) 让环境变量生效（示例）：

```bash
set -a
source .env
set +a
```

## 依赖

辅助脚本 `scripts.sh` 需要以下命令可用：

- `bash`, `curl`, `jq`

Skill 运行环境（采集内容）依赖你已配置好对应工具/API：

- `mcp__tavily__tavily-search` / `mcp__tavily__tavily-extract`
- `mcp__exa__web_search_exa`

本仓库不包含这些服务的 API Key，你需要在自己的 Agent/IDE/CLI 工具里按其官方方式配置。

## 使用（辅助脚本）

> 注意：`scripts.sh` 只是便捷脚本；Skill 本体逻辑在 `SKILL.md`。

示例文章（科普/护理/科技风格）：`examples/nursing-tech-article.md`

加载脚本：

```bash
source ./scripts.sh
```

常用函数：

- `get_wechat_token`
- `generate_image "<prompt>" ["16:9"]`
- `upload_to_r2 <local_path> <remote_path>`
- `publish_article "<title>" "<content_html>" "<cover_prompt>" "<digest>"`

参数建议：`content_html` 尽量从文件读取，避免 shell 引号/换行转义问题：

```bash
content_html=$(cat ./content.html)
publish_article "标题" "$content_html" "封面图 prompt" "摘要"
```

## 安全说明

- 不要把 `.env` 提交到仓库；本仓库已通过 `.gitignore` 忽略它。
- 任何线上发布前，建议在公众号后台/接口调用白名单中配置好服务器 IP（如有要求）。

## OpenClaw：每天定时发布（24 小时循环）

OpenClaw 自带 Cron（需要你的 OpenClaw Gateway 常驻运行）。

推荐做法：把「默认配置」固定在 Skill 里，Cron 只负责每天触发一次；当你想改主题/风格/口吻时，再在触发消息里追加说明即可。

默认配置（可在 `SKILL.md` 里改）：

- 主题：AI工具
- 风格：github
- 配图：封面 + 3 张
- 作者：田威 AI

示例：每天 09:00（上海时区）触发一次发布（使用默认配置）：

```bash
openclaw cron add \
  --name "wechat-ai-daily" \
  --cron "0 9 * * *" \
  --tz "Asia/Shanghai" \
  --session isolated \
  --message "发布AI热点；不要提问，直接执行"
```

临时覆盖默认配置（只要把需求“说出来”即可）：

```bash
openclaw cron add \
  --name "wechat-ai-daily" \
  --cron "0 9 * * *" \
  --tz "Asia/Shanghai" \
  --session isolated \
  --message "发布AI热点；主题=护理；风格=purple；配图=仅封面；写得更科普一些；不要提问，直接执行"
```

查看/管理：

```bash
openclaw cron list
openclaw cron delete --name "wechat-ai-daily"
```
