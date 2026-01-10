#!/usr/bin/env bash
# ========================================
# Cloudflare Cache Purge 脚本
# ========================================
# [DISABLED] 2024-01 缓存清除功能已暂停使用（图床项目不再使用 R2）
# 如需恢复，删除下方 : <<'DISABLED' 和文件末尾的 DISABLED 即可
# ========================================
#
# 功能：智能清除 Cloudflare CDN 缓存
#       只清除实际更新的系列，避免无谓缓存击穿
#
# 用法：
#   ./scripts/purge-cache.sh                      # 清除所有 JSON 缓存
#   ./scripts/purge-cache.sh desktop mobile       # 只清除指定系列
#   ./scripts/purge-cache.sh --all                # 清除所有缓存（包括图片）
#
# 环境变量（必需）：
#   CF_ZONE_ID    - Cloudflare Zone ID
#   CF_API_TOKEN  - Cloudflare API Token（需要 Cache Purge 权限）
#
# 环境变量（可选）：
#   CDN_DOMAIN    - CDN 域名（默认: img.061129.xyz）
#
# ========================================

echo "[DISABLED] 缓存清除功能已暂停，如需恢复请编辑此脚本"
exit 0

: <<'DISABLED'
set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置
CDN_DOMAIN="${CDN_DOMAIN:-img.061129.xyz}"
CF_API_BASE="https://api.cloudflare.com/client/v4"

# 所有系列
ALL_SERIES=("desktop" "mobile" "avatar" "bing")

# 解析参数
PURGE_ALL=false
SERIES_TO_PURGE=()

for arg in "$@"; do
    case $arg in
        --all)
            PURGE_ALL=true
            ;;
        desktop|mobile|avatar|bing)
            SERIES_TO_PURGE+=("$arg")
            ;;
    esac
done

# 如果没有指定系列，默认清除所有
if [ ${#SERIES_TO_PURGE[@]} -eq 0 ]; then
    SERIES_TO_PURGE=("${ALL_SERIES[@]}")
fi

echo "=========================================="
echo "  Cloudflare Cache Purge Script"
echo "=========================================="
echo ""

# 检查必需的环境变量
if [ -z "$CF_ZONE_ID" ]; then
    echo -e "${RED}[ERROR]${NC} CF_ZONE_ID is not set"
    exit 1
fi

if [ -z "$CF_API_TOKEN" ]; then
    echo -e "${RED}[ERROR]${NC} CF_API_TOKEN is not set"
    exit 1
fi

echo -e "${GREEN}[INFO]${NC} CDN Domain: $CDN_DOMAIN"
echo -e "${GREEN}[INFO]${NC} Zone ID: ${CF_ZONE_ID:0:8}..."
echo -e "${GREEN}[INFO]${NC} Series to purge: ${SERIES_TO_PURGE[*]}"
echo ""

# 构建要清除的 URL 列表
build_purge_urls() {
    local urls=()
    
    for series in "${SERIES_TO_PURGE[@]}"; do
        case $series in
            desktop|mobile|avatar)
                # 清除系列索引
                urls+=("https://$CDN_DOMAIN/data/$series/index.json")
                
                # 清除分类 JSON（常见分类）
                # 注意：这里只列出常见分类，实际可能需要动态获取
                local categories
                case $series in
                    desktop)
                        categories=("动漫" "游戏" "影视" "风景" "人像" "插画" "IP形象" "国风" "未分类")
                        ;;
                    mobile)
                        categories=("动漫" "游戏" "风景" "人像" "插画" "未分类")
                        ;;
                    avatar)
                        categories=("动漫" "游戏" "可爱" "未分类")
                        ;;
                esac
                
                for cat in "${categories[@]}"; do
                    # URL 编码中文
                    local encoded_cat
                    encoded_cat=$(printf '%s' "$cat" | jq -sRr @uri)
                    urls+=("https://$CDN_DOMAIN/data/$series/$encoded_cat.json")
                done
                ;;
            bing)
                # Bing 系列
                urls+=("https://$CDN_DOMAIN/data/bing/index.json")
                urls+=("https://$CDN_DOMAIN/data/bing/latest.json")
                urls+=("https://$CDN_DOMAIN/bing/meta/index.json")
                urls+=("https://$CDN_DOMAIN/bing/meta/latest.json")
                
                # 年度数据（最近几年）
                local current_year
                current_year=$(date +%Y)
                for year in $(seq $((current_year - 2)) $current_year); do
                    urls+=("https://$CDN_DOMAIN/data/bing/$year.json")
                    urls+=("https://$CDN_DOMAIN/bing/meta/$year.json")
                done
                ;;
        esac
    done
    
    # 输出 JSON 数组
    printf '%s\n' "${urls[@]}" | jq -R . | jq -s .
}

# 清除缓存
purge_cache() {
    local urls_json="$1"
    
    echo -e "${CYAN}[PURGE]${NC} Sending purge request..."
    
    local response
    response=$(curl -s -X POST "$CF_API_BASE/zones/$CF_ZONE_ID/purge_cache" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"files\": $urls_json}")
    
    # 检查响应
    local success
    success=$(echo "$response" | jq -r '.success')
    
    if [ "$success" = "true" ]; then
        echo -e "${GREEN}[OK]${NC} Cache purged successfully"
        return 0
    else
        local errors
        errors=$(echo "$response" | jq -r '.errors[]?.message // "Unknown error"')
        echo -e "${RED}[ERROR]${NC} Failed to purge cache: $errors"
        return 1
    fi
}

# 清除所有缓存（包括图片）
purge_all_cache() {
    echo -e "${YELLOW}[WARN]${NC} Purging ALL cache (including images)..."
    
    local response
    response=$(curl -s -X POST "$CF_API_BASE/zones/$CF_ZONE_ID/purge_cache" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{"purge_everything": true}')
    
    local success
    success=$(echo "$response" | jq -r '.success')
    
    if [ "$success" = "true" ]; then
        echo -e "${GREEN}[OK]${NC} All cache purged successfully"
        return 0
    else
        local errors
        errors=$(echo "$response" | jq -r '.errors[]?.message // "Unknown error"')
        echo -e "${RED}[ERROR]${NC} Failed to purge all cache: $errors"
        return 1
    fi
}

# 主逻辑
if [ "$PURGE_ALL" = true ]; then
    purge_all_cache
else
    # 构建 URL 列表
    echo "Building URL list..."
    urls_json=$(build_purge_urls)
    
    # 显示要清除的 URL 数量
    url_count=$(echo "$urls_json" | jq 'length')
    echo -e "${BLUE}[INFO]${NC} URLs to purge: $url_count"
    
    # Cloudflare API 每次最多清除 30 个 URL
    # 如果超过，需要分批
    if [ "$url_count" -gt 30 ]; then
        echo -e "${YELLOW}[WARN]${NC} More than 30 URLs, splitting into batches..."
        
        # 分批处理
        batch_num=0
        while true; do
            start=$((batch_num * 30))
            batch=$(echo "$urls_json" | jq ".[$start:$((start + 30))]")
            batch_count=$(echo "$batch" | jq 'length')
            
            if [ "$batch_count" -eq 0 ]; then
                break
            fi
            
            echo ""
            echo -e "${CYAN}[BATCH $((batch_num + 1))]${NC} Purging $batch_count URLs..."
            purge_cache "$batch" || true
            
            batch_num=$((batch_num + 1))
            
            # 避免 API 限流
            if [ "$batch_count" -eq 30 ]; then
                sleep 1
            fi
        done
    else
        purge_cache "$urls_json"
    fi
fi

echo ""
echo "=========================================="
echo "  Cache Purge Complete!"
echo "=========================================="
DISABLED
