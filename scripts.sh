#!/bin/bash
# 微信公众号 AI 热点发布工具 - 辅助脚本集合
# 使用方法: source scripts.sh

# ============ 配置 ============
# 通过环境变量提供（推荐：使用 .env + `set -a; source .env; set +a`）

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "ERROR: missing command: $1" >&2
        return 1
    }
}

require_env() {
    local name=$1
    if [[ -z "${!name:-}" ]]; then
        echo "ERROR: missing env var: ${name}" >&2
        return 1
    fi
}

# ============ 公众号 API ============

# 获取 access_token
get_wechat_token() {
    require_cmd curl || return 1
    require_cmd jq || return 1
    require_env WECHAT_APPID || return 1
    require_env WECHAT_SECRET || return 1
    curl -s "https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=${WECHAT_APPID}&secret=${WECHAT_SECRET}" | jq -r '.access_token'
}

# 上传图片到公众号素材库（永久素材）
# 用法: upload_wechat_image <token> <image_path>
upload_wechat_image() {
    require_cmd curl || return 1
    local token=$1
    local image_path=$2
    curl -s -X POST "https://api.weixin.qq.com/cgi-bin/material/add_material?access_token=${token}&type=image" \
        -F "media=@${image_path}"
}

# 创建草稿
# 用法: create_draft <token> <json_file>
create_draft() {
    require_cmd curl || return 1
    local token=$1
    local json_file=$2
    curl -s -X POST "https://api.weixin.qq.com/cgi-bin/draft/add?access_token=${token}" \
        -H "Content-Type: application/json" \
        -d @"${json_file}"
}

# 发布草稿
# 用法: publish_draft <token> <media_id>
publish_draft() {
    require_cmd curl || return 1
    local token=$1
    local media_id=$2
    curl -s -X POST "https://api.weixin.qq.com/cgi-bin/freepublish/submit?access_token=${token}" \
        -H "Content-Type: application/json" \
        -d "{\"media_id\": \"${media_id}\"}"
}

# ============ Replicate 图片生成 ============

# 生成图片（Nano Banana Pro）
# 用法: generate_image <prompt> [aspect_ratio]
# aspect_ratio: "1:1", "16:9", "9:16", "4:3", "3:4"
generate_image() {
    require_cmd curl || return 1
    require_cmd jq || return 1
    require_env REPLICATE_API_KEY || return 1
    local prompt=$1
    local aspect_ratio=${2:-"16:9"}

    local body
    body=$(jq -n \
        --arg prompt "$prompt" \
        --arg aspect_ratio "$aspect_ratio" \
        '{input: {prompt: $prompt, aspect_ratio: $aspect_ratio}}')

    # 创建预测
    local response=$(curl -s -X POST "https://api.replicate.com/v1/models/google/nano-banana-pro/predictions" \
        -H "Authorization: Bearer ${REPLICATE_API_KEY}" \
        -H "Content-Type: application/json" \
        -H "Prefer: wait" \
        -d "$body")

    echo "$response"
}

# 等待并获取图片 URL
# 用法: wait_for_image <prediction_id>
wait_for_image() {
    require_cmd curl || return 1
    require_cmd jq || return 1
    require_env REPLICATE_API_KEY || return 1
    local prediction_id=$1
    local status="starting"
    local output=""

    while [[ "$status" != "succeeded" && "$status" != "failed" ]]; do
        sleep 2
        local response=$(curl -s "https://api.replicate.com/v1/predictions/${prediction_id}" \
            -H "Authorization: Bearer ${REPLICATE_API_KEY}")
        status=$(echo "$response" | jq -r '.status')
        output=$(echo "$response" | jq -r '.output[0] // .output // empty')
    done

    if [[ "$status" == "succeeded" ]]; then
        echo "$output"
    else
        echo "ERROR: Image generation failed"
        return 1
    fi
}

# 下载图片
# 用法: download_image <url> <output_path>
download_image() {
    require_cmd curl || return 1
    local url=$1
    local output_path=$2
    curl -fsSL -o "${output_path}" "${url}"
}

# ============ 完整流程 ============

# 生成封面图文件（本地临时文件）
# 用法: create_cover_file <prompt> <article_id>
create_cover_file() {
    require_cmd jq || return 1
    local prompt=$1
    local article_id=$2
    local tmp_file="/tmp/wechat_cover_${article_id}.png"

    echo "正在生成封面图..."
    local response=$(generate_image "${prompt}" "16:9")
    local image_url=$(echo "$response" | jq -r '.output[0] // .output // empty')

    if [[ -z "$image_url" || "$image_url" == "null" ]]; then
        # 可能需要等待
        local prediction_id=$(echo "$response" | jq -r '.id')
        image_url=$(wait_for_image "$prediction_id")
    fi

    if [[ -n "$image_url" && "$image_url" != "ERROR"* ]]; then
        echo "正在下载图片..."
        if ! download_image "$image_url" "$tmp_file"; then
            rm -f "$tmp_file"
            echo "ERROR: failed to download image" >&2
            return 1
        fi
        echo "$tmp_file"
        return 0
    fi

    if [[ -n "${DEFAULT_COVER_URL:-}" ]]; then
        echo "封面图生成失败，使用 DEFAULT_COVER_URL 下载兜底封面..."
        if ! download_image "$DEFAULT_COVER_URL" "$tmp_file"; then
            rm -f "$tmp_file"
            echo "ERROR: failed to download DEFAULT_COVER_URL" >&2
            return 1
        fi
        echo "$tmp_file"
        return 0
    fi

    echo "ERROR: Failed to generate cover and no DEFAULT_COVER_URL provided" >&2
    return 1
}

# 完整发布流程
# 用法: publish_article <title> <content_html> <cover_prompt> <digest>
publish_article() {
    require_cmd jq || return 1
    local title=$1
    local content_html=$2
    local cover_prompt=$3
    local digest=$4
    local article_id=$(date +%Y%m%d%H%M%S)
    local author=${WECHAT_AUTHOR:-"田威 AI"}

    echo "=== 开始发布流程 ==="

    # 1. 获取 token
    echo "1. 获取 access_token..."
    local token=$(get_wechat_token)
    if [[ -z "$token" || "$token" == "null" ]]; then
        echo "ERROR: 获取 token 失败"
        return 1
    fi

    # 2. 生成封面图
    echo "2. 生成封面图..."
    local cover_file
    if ! cover_file=$(create_cover_file "$cover_prompt" "$article_id"); then
        return 1
    fi
    echo "   封面图文件: $cover_file"

    # 3. 下载并上传封面到公众号
    echo "3. 上传封面到公众号素材库..."
    local media_response=$(upload_wechat_image "$token" "$cover_file")
    local thumb_media_id=$(echo "$media_response" | jq -r '.media_id')
    rm -f "$cover_file"

    if [[ -z "$thumb_media_id" || "$thumb_media_id" == "null" ]]; then
        echo "ERROR: 上传封面失败"
        echo "$media_response"
        return 1
    fi
    echo "   Media ID: $thumb_media_id"

    # 4. 创建草稿
    echo "4. 创建草稿..."
    local draft_json="/tmp/draft_${article_id}.json"
    jq -n \
        --arg title "$title" \
        --arg author "$author" \
        --arg digest "$digest" \
        --arg content "$content_html" \
        --arg thumb_media_id "$thumb_media_id" \
        '{
            articles: [{
                title: $title,
                author: $author,
                digest: $digest,
                content: $content,
                thumb_media_id: $thumb_media_id,
                need_open_comment: 1,
                only_fans_can_comment: 0
            }]
        }' > "$draft_json"

    local draft_response=$(create_draft "$token" "$draft_json")
    local draft_media_id=$(echo "$draft_response" | jq -r '.media_id')
    rm -f "$draft_json"

    if [[ -z "$draft_media_id" || "$draft_media_id" == "null" ]]; then
        echo "ERROR: 创建草稿失败"
        echo "$draft_response"
        return 1
    fi

    echo "=== 发布成功 ==="
    echo "草稿 Media ID: $draft_media_id"
    echo "请在公众号后台查看并发布"
}

echo "脚本已加载。可用函数:"
echo "  get_wechat_token        - 获取公众号 access_token"
echo "  generate_image          - 生成图片 (Nano Banana Pro)"
echo "  create_cover_file       - 生成封面图文件"
echo "  publish_article         - 完整发布流程"
