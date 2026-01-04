#!/bin/bash
# ========================================
# Bing 每日壁纸同步脚本
# ========================================
#
# 目录结构：
# bing/
# ├── 2025/                          # 按年/月组织图片
# │   ├── 01/
# │   │   ├── 2025-01-01.jpg         # 4K UHD 原图
# │   │   ├── 2025-01-02.jpg
# │   │   └── ...
# │   └── 02/
# │
# └── meta/                          # 元数据
#     ├── index.json                 # 总索引
#     ├── latest.json                # 最近 7 天
#     ├── 2025.json                  # 年度数据
#     └── 2024.json
#
# 数据结构：
# {
#   "date": "2025-01-04",
#   "title": "冬日极光",
#   "copyright": "© John Doe",
#   "urlbase": "/th?id=OHR.xxx_EN-US123",  // Bing CDN，支持多分辨率
#   "path": "/bing/2025/01/2025-01-04.jpg" // 本地 4K 原图
# }
#
# Bing 分辨率（通过 urlbase 拼接）：
# - _UHD.jpg (4K)
# - _1920x1080.jpg (预览)
# - _400x240.jpg (缩略图)
# ========================================

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BING_API="https://www.bing.com/HPImageArchive.aspx"
BING_BASE="https://www.bing.com"

# 目录
BING_DIR="$ROOT_DIR/bing"
META_DIR="$BING_DIR/meta"

# ========================================
# 主函数
# ========================================
main() {
    echo "========================================"
    echo "  Bing 每日壁纸同步"
    echo "========================================"
    echo ""
    echo "目录结构: bing/{年}/{月}/{日期}.jpg"
    echo "元数据:   bing/meta/*.json"
    echo ""

    # 检查依赖
    check_dependencies

    # 确保目录存在
    mkdir -p "$META_DIR"

    # 获取参数（天数）
    local days=${1:-1}
    echo -e "${BLUE}[INFO]${NC} 获取最近 $days 天的壁纸..."
    echo ""

    # 获取 Bing 数据
    local bing_data=$(curl -s "${BING_API}?format=js&idx=0&n=${days}&mkt=zh-CN")

    if [ -z "$bing_data" ] || [ "$(echo "$bing_data" | jq -r '.images | length')" = "0" ]; then
        echo -e "${RED}[ERROR]${NC} 获取 Bing 数据失败"
        exit 1
    fi

    local count=$(echo "$bing_data" | jq '.images | length')
    echo -e "${BLUE}[INFO]${NC} 获取到 $count 张壁纸"
    echo ""

    # 处理每张壁纸
    local success=0
    local skip=0

    for ((i=0; i<count; i++)); do
        process_image "$bing_data" "$i" && ((success++)) || ((skip++))
    done

    echo ""
    echo "========================================"
    echo "  同步完成"
    echo "========================================"
    echo -e "  ${GREEN}新增:${NC} $success"
    echo -e "  ${YELLOW}跳过:${NC} $skip"
    echo "========================================"

    # 更新索引
    update_all_indexes
}

# ========================================
# 检查依赖
# ========================================
check_dependencies() {
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}[ERROR]${NC} 需要 curl"
        exit 1
    fi
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}[ERROR]${NC} 需要 jq"
        exit 1
    fi
}

# ========================================
# 处理单张图片
# ========================================
process_image() {
    local bing_data="$1"
    local index="$2"

    # 解析数据
    local image=$(echo "$bing_data" | jq -r ".images[$index]")
    local startdate=$(echo "$image" | jq -r '.startdate')
    local urlbase=$(echo "$image" | jq -r '.urlbase')
    local title=$(echo "$image" | jq -r '.title')
    local copyright=$(echo "$image" | jq -r '.copyright')
    local copyrightlink=$(echo "$image" | jq -r '.copyrightlink')
    local quiz=$(echo "$image" | jq -r '.quiz')
    local hsh=$(echo "$image" | jq -r '.hsh')

    # 解析日期 YYYYMMDD -> YYYY-MM-DD
    local year="${startdate:0:4}"
    local month="${startdate:4:2}"
    local day="${startdate:6:2}"
    local date_formatted="${year}-${month}-${day}"

    echo -e "${BLUE}[INFO]${NC} $date_formatted - $title"

    # 目录和文件
    local image_dir="$BING_DIR/$year/$month"
    local image_file="$image_dir/${date_formatted}.jpg"
    local image_path="/bing/$year/$month/${date_formatted}.jpg"

    mkdir -p "$image_dir"

    # 检查是否已存在
    if [ -f "$image_file" ]; then
        echo -e "       ${YELLOW}已存在，跳过下载${NC}"
        # 仍然更新元数据
        save_to_year_file "$year" "$date_formatted" "$title" "$copyright" "$copyrightlink" "$quiz" "$hsh" "$urlbase" "$image_path"
        return 1  # 返回 1 表示跳过
    fi

    # 下载 4K 原图
    local uhd_url="${BING_BASE}${urlbase}_UHD.jpg"

    if curl -s -f -o "$image_file" "$uhd_url"; then
        echo -e "       ${GREEN}✓ 下载成功${NC}"
        # 保存元数据
        save_to_year_file "$year" "$date_formatted" "$title" "$copyright" "$copyrightlink" "$quiz" "$hsh" "$urlbase" "$image_path"
        return 0
    else
        echo -e "       ${RED}✗ 下载失败${NC}"
        return 1
    fi
}

# ========================================
# 保存到年度数据文件
# ========================================
save_to_year_file() {
    local year="$1"
    local date="$2"
    local title="$3"
    local copyright="$4"
    local copyrightlink="$5"
    local quiz="$6"
    local hsh="$7"
    local urlbase="$8"
    local path="$9"

    local year_file="$META_DIR/${year}.json"

    # 创建数据项
    local item=$(jq -n \
        --arg date "$date" \
        --arg title "$title" \
        --arg copyright "$copyright" \
        --arg copyrightlink "$copyrightlink" \
        --arg quiz "$quiz" \
        --arg hsh "$hsh" \
        --arg urlbase "$urlbase" \
        --arg path "$path" \
        '{
            date: $date,
            title: $title,
            copyright: $copyright,
            copyrightlink: $copyrightlink,
            quiz: $quiz,
            hsh: $hsh,
            urlbase: $urlbase,
            path: $path
        }')

    if [ -f "$year_file" ]; then
        # 检查是否已存在
        local exists=$(jq --arg d "$date" '[.items[] | select(.date == $d)] | length' "$year_file")

        if [ "$exists" = "0" ]; then
            # 添加新条目并排序
            local temp=$(mktemp)
            jq --argjson item "$item" '
                .items += [$item] |
                .items |= sort_by(.date) | reverse |
                .total = (.items | length) |
                .updatedAt = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
            ' "$year_file" > "$temp"
            mv "$temp" "$year_file"
        fi
    else
        # 创建新文件
        jq -n \
            --arg year "$year" \
            --argjson item "$item" \
            '{
                year: ($year | tonumber),
                total: 1,
                updatedAt: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
                items: [$item]
            }' > "$year_file"
    fi
}

# ========================================
# 更新所有索引
# ========================================
update_all_indexes() {
    echo ""
    echo -e "${BLUE}[INFO]${NC} 更新索引..."

    update_index_json
    update_latest_json

    echo -e "${GREEN}[DONE]${NC} 索引更新完成"
}

# ========================================
# 更新 index.json（总索引）
# ========================================
update_index_json() {
    local index_file="$META_DIR/index.json"
    local years="[]"
    local total=0

    # 遍历所有年度文件
    for year_file in "$META_DIR"/20*.json; do
        if [ -f "$year_file" ]; then
            local year=$(jq -r '.year' "$year_file")
            local count=$(jq -r '.total' "$year_file")
            years=$(echo "$years" | jq --arg y "$year" --argjson c "$count" \
                '. += [{year: ($y | tonumber), count: $c, file: "\($y).json"}]')
            total=$((total + count))
        fi
    done

    # 按年份降序
    years=$(echo "$years" | jq 'sort_by(.year) | reverse')

    jq -n \
        --argjson years "$years" \
        --argjson total "$total" \
        '{
            generatedAt: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
            series: "bing",
            seriesName: "Bing 每日",
            total: $total,
            years: $years
        }' > "$index_file"

    echo "       index.json (total: $total)"
}

# ========================================
# 更新 latest.json（最近 7 天）
# ========================================
update_latest_json() {
    local latest_file="$META_DIR/latest.json"
    local all_items="[]"

    # 合并所有年度数据
    for year_file in "$META_DIR"/20*.json; do
        if [ -f "$year_file" ]; then
            all_items=$(echo "$all_items" | jq --slurpfile yf "$year_file" '. + $yf[0].items')
        fi
    done

    # 排序并取最近 7 条
    local items=$(echo "$all_items" | jq 'sort_by(.date) | reverse | .[0:7]')
    local count=$(echo "$items" | jq 'length')

    jq -n \
        --argjson items "$items" \
        --argjson count "$count" \
        '{
            generatedAt: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
            total: $count,
            items: $items
        }' > "$latest_file"

    echo "       latest.json ($count items)"
}

# 运行
main "$@"
