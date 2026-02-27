# mp-draft-push (Skill)

> 最小化微信公众号发布技能：接收**现成的文章内容**，上传封面图，发布到草稿箱。

不负责内容采集、AI 写作或图片生成，只做"最后一公里"。

---

## 目录结构

```
wechat-ai-publisher/
├── SKILL.md          # 技能定义（AI 助手读取）
├── scripts.sh        # 辅助脚本（bash/zsh 均可用）
├── .env.example      # 环境变量模板
├── styles.json       # 微信公众号 HTML 内联样式参考
└── examples/
    └── nursing-tech-article.md   # 示例文章
```

---

## 安装

将整个目录放到 AI 工具的 Skills 目录下：

| AI 工具 | Skills 路径 |
|---------|------------|
| Codex | `~/.codex/skills/wechat-publisher/` |
| Claude Code | `~/.claude/skills/wechat-publisher/` |
| Gemini | `~/.gemini/skills/wechat-publisher/` |
| OpenClaw | `~/.openclaw/workspace/skills/wechat-publisher/` |

---

## 配置

```bash
cp .env.example .env
# 编辑 .env 填入凭证
set -a; source .env; set +a
```

| 变量 | 必填 | 说明 |
|------|------|------|
| `WECHAT_APPID` | ✅ | 公众号后台 AppID |
| `WECHAT_SECRET` | ✅ | 公众号后台 AppSecret |
| `WECHAT_AUTHOR` | ❌ | 文章作者字段（默认：`koo AI`） |
| `DEFAULT_COVER_URL` | ❌ | 无封面图时的兜底图片 URL |

> AppID 和 AppSecret 在**微信公众号后台 → 设置与开发 → 基本配置**中获取。

---

## 依赖

```bash
brew install jq   # 如未安装
# bash curl 通常 macOS 已自带
```

---

## 使用方式

### 方式一：通过 AI 助手触发（推荐）

触发词：**"发布文章"、"发布到草稿箱"、"publish to draft"**

对话示例：

> 帮我发布这篇文章到草稿箱：
> - 标题：XXX
> - 摘要：XXX
> - 封面图：/path/to/cover.png
> - 正文 HTML：`<p>内容</p>`

### 方式二：直接调用脚本

```bash
source ./scripts.sh

# 1. 获取 token
TOKEN=$(get_wechat_token)

# 2. 上传封面图（返回 media_id）
upload_wechat_image "$TOKEN" "/path/to/cover.png"

# 3. 创建草稿（draft.json 见下方格式）
create_draft "$TOKEN" "/path/to/draft.json"
```

**draft.json 格式**：

```json
{
  "articles": [{
    "title": "文章标题",
    "author": "koo AI",
    "digest": "文章摘要",
    "content": "<section style=\"...\">正文 HTML</section>",
    "thumb_media_id": "上一步上传封面图返回的 media_id",
    "need_open_comment": 1,
    "only_fans_can_comment": 0
  }]
}
```

> **注意**：`thumb_media_id` 是必填字段，不能为空字符串。

---

## 注意事项

- `.env` 已加入 `.gitignore`，不会被提交到仓库
- 文章内图片只能使用微信返回的 `mmbiz.qpic.cn` 域名 URL
- HTML 样式必须全部内联，微信会过滤 `<style>` 标签
- 标题最多 64 字节（约 21 个中文字符）
- `access_token` 有效期 2 小时，每次调用脚本都会重新获取

---

## 安全说明

- 不要将 `.env` 提交到版本库
- 建议在公众号后台配置 IP 白名单（如有要求）
