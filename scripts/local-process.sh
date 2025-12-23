#!/bin/bash
# ========================================
# 本地图片处理脚本
# 用于手动处理本地图片，生成缩略图和预览图
# ========================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 项目根目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ========================================
# 配置
# ========================================

# 缩略图配置
THUMBNAIL_WIDTH=800
THUMBNAIL_QUALITY=85

# 预览图配置
PREVIEW_WIDTH=1920
PREVIEW_QUALITY=85

# 水印配置
WATERMARK_ENABLED=true
WATERMARK_TEXT="暖心"
WATERMARK_OPACITY=65
WATERMARK_POSITION="southeast"
WATERMARK_ANGLE=-30

# 预览图水印配置
PREVIEW_WATERMARK_SIZE_PERCENT=3
PREVIEW_WATERMARK_OFFSET_X=40
PREVIEW_WATERMARK_OFFSET_Y=80

# 缩略图水印配置
THUMB_WATERMARK_SIZE_PERCENT=4
THUMB_WATERMARK_OFFSET_X=20
THUMB_WATERMARK_OFFSET_Y=40

# ========================================
# 使用说明
# ========================================

show_help() {
    echo -e "${BLUE}本地图片处理脚本${NC}"
    echo ""
    echo "用法: $0 <输入文件夹> [系列类型]"
    echo ""
    echo "参数:"
    echo "  输入文件夹    包含待处理图片的文件夹路径"
    echo "  系列类型      可选: desktop(默认), mobile, avatar"
    echo ""
    echo "示例:"
    echo "  $0 ~/Pictures/new-wallpapers"
    echo "  $0 ~/Pictures/phone-wallpapers mobile"
    echo "  $0 ~/Pictures/avatars avatar"
    echo ""
    echo "说明:"
    echo "  - 支持 jpg, jpeg, png, webp 格式"
    echo "  - 原图复制到 wallpaper/<系列>/"
    echo "  - 缩略图生成到 thumbnail/<系列>/ (800px宽, webp格式, 带水印)"
    echo "  - 预览图生成到 preview/<系列>/ (1920px宽, webp格式, 带水印)"
    echo "  - avatar 系列不生成预览图"
}

# ========================================
# 检测中文字体
# ========================================

detect_chinese_font() {
    local font=""

    # macOS 字体优先级
    for f in "Heiti-SC-Medium" "PingFang-SC-Medium" "PingFang-SC-Regular" "Heiti-SC-Light"; do
        if convert -list font 2>/dev/null | grep -q "$f"; then
            font="$f"
            break
        fi
    done

    # Linux 字体备选
    if [ -z "$font" ]; then
        for f in "Noto-Sans-CJK-SC" "Noto-Sans-CJK-SC-Regular" "WenQuanYi-Micro-Hei"; do
            if convert -list font 2>/dev/null | grep -q "$f"; then
                font="$f"
                break
            fi
        done
    fi

    echo "$font"
}

# ========================================
# 处理单个图片
# ========================================

process_image() {
    local src_file="$1"
    local series="$2"
    local font="$3"

    local filename=$(basename "$src_file")
    local name="${filename%.*}"

    # 目标路径
    local wallpaper_dir="$SCRIPT_DIR/wallpaper/$series"
    local thumbnail_dir="$SCRIPT_DIR/thumbnail/$series"
    local preview_dir="$SCRIPT_DIR/preview/$series"

    # 确保目录存在
    mkdir -p "$wallpaper_dir" "$thumbnail_dir" "$preview_dir"

    # 1. 复制原图到 wallpaper 目录
    local dest_wallpaper="$wallpaper_dir/$filename"
    if [ ! -f "$dest_wallpaper" ]; then
        cp "$src_file" "$dest_wallpaper"
        echo -e "  ${GREEN}✓${NC} 原图: $filename"
    else
        echo -e "  ${YELLOW}→${NC} 原图已存在: $filename"
    fi

    # 2. 生成缩略图（带水印）
    local dest_thumbnail="$thumbnail_dir/${name}.webp"
    if [ ! -f "$dest_thumbnail" ]; then
        if [ "$WATERMARK_ENABLED" = true ] && [ -n "$font" ]; then
            # 计算缩略图水印大小
            local thumb_watermark_size=$((THUMBNAIL_WIDTH * THUMB_WATERMARK_SIZE_PERCENT / 100))

            convert "$src_file" \
                -resize "${THUMBNAIL_WIDTH}x>" \
                -quality "$THUMBNAIL_QUALITY" \
                -gravity "$WATERMARK_POSITION" \
                -font "$font" \
                -pointsize "$thumb_watermark_size" \
                -fill "rgba(255,255,255,${WATERMARK_OPACITY}%)" \
                -annotate ${WATERMARK_ANGLE}x${WATERMARK_ANGLE}+${THUMB_WATERMARK_OFFSET_X}+${THUMB_WATERMARK_OFFSET_Y} "$WATERMARK_TEXT" \
                "$dest_thumbnail" 2>/dev/null
            echo -e "  ${GREEN}✓${NC} 缩略图(水印): ${name}.webp"
        else
            convert "$src_file" \
                -resize "${THUMBNAIL_WIDTH}x>" \
                -quality "$THUMBNAIL_QUALITY" \
                "$dest_thumbnail" 2>/dev/null
            echo -e "  ${GREEN}✓${NC} 缩略图: ${name}.webp"
        fi
    else
        echo -e "  ${YELLOW}→${NC} 缩略图已存在: ${name}.webp"
    fi

    # 3. 生成预览图（仅 desktop 和 mobile）
    if [ "$series" != "avatar" ]; then
        local dest_preview="$preview_dir/${name}.webp"
        if [ ! -f "$dest_preview" ]; then
            if [ "$WATERMARK_ENABLED" = true ] && [ -n "$font" ]; then
                # 计算预览图水印大小
                local preview_watermark_size=$((PREVIEW_WIDTH * PREVIEW_WATERMARK_SIZE_PERCENT / 100))

                convert "$src_file" \
                    -resize "${PREVIEW_WIDTH}x>" \
                    -quality "$PREVIEW_QUALITY" \
                    -gravity "$WATERMARK_POSITION" \
                    -font "$font" \
                    -pointsize "$preview_watermark_size" \
                    -fill "rgba(255,255,255,${WATERMARK_OPACITY}%)" \
                    -annotate ${WATERMARK_ANGLE}x${WATERMARK_ANGLE}+${PREVIEW_WATERMARK_OFFSET_X}+${PREVIEW_WATERMARK_OFFSET_Y} "$WATERMARK_TEXT" \
                    "$dest_preview" 2>/dev/null
                echo -e "  ${GREEN}✓${NC} 预览图(水印): ${name}.webp"
            else
                convert "$src_file" \
                    -resize "${PREVIEW_WIDTH}x>" \
                    -quality "$PREVIEW_QUALITY" \
                    "$dest_preview" 2>/dev/null
                echo -e "  ${GREEN}✓${NC} 预览图: ${name}.webp"
            fi
        else
            echo -e "  ${YELLOW}→${NC} 预览图已存在: ${name}.webp"
        fi
    fi
}

# ========================================
# 主程序
# ========================================

main() {
    # 检查参数
    if [ $# -lt 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_help
        exit 0
    fi

    local input_dir="$1"
    local series="${2:-desktop}"

    # 验证输入目录
    if [ ! -d "$input_dir" ]; then
        echo -e "${RED}错误: 目录不存在: $input_dir${NC}"
        exit 1
    fi

    # 验证系列类型
    if [[ ! "$series" =~ ^(desktop|mobile|avatar)$ ]]; then
        echo -e "${RED}错误: 无效的系列类型: $series${NC}"
        echo "有效类型: desktop, mobile, avatar"
        exit 1
    fi

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}本地图片处理${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "输入目录: ${GREEN}$input_dir${NC}"
    echo -e "系列类型: ${GREEN}$series${NC}"
    echo ""

    # 检测字体
    local font=""
    if [ "$WATERMARK_ENABLED" = true ]; then
        font=$(detect_chinese_font)
        if [ -n "$font" ]; then
            echo -e "水印字体: ${GREEN}$font${NC}"
        else
            echo -e "${YELLOW}警告: 未找到中文字体，将跳过水印${NC}"
        fi
    fi
    echo ""

    # 查找图片文件
    local image_files=()
    while IFS= read -r -d '' file; do
        image_files+=("$file")
    done < <(find "$input_dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -print0 | sort -z)

    local total=${#image_files[@]}

    if [ $total -eq 0 ]; then
        echo -e "${YELLOW}未找到图片文件${NC}"
        exit 0
    fi

    echo -e "找到 ${GREEN}$total${NC} 张图片"
    echo ""

    # 处理每张图片
    local count=0
    for file in "${image_files[@]}"; do
        count=$((count + 1))
        echo -e "${BLUE}[$count/$total]${NC} $(basename "$file")"
        process_image "$file" "$series" "$font"
        echo ""
    done

    # 统计结果
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}处理完成!${NC}"
    echo ""
    echo "输出目录:"
    echo -e "  原图:   ${GREEN}wallpaper/$series/${NC}"
    echo -e "  缩略图: ${GREEN}thumbnail/$series/${NC}"
    if [ "$series" != "avatar" ]; then
        echo -e "  预览图: ${GREEN}preview/$series/${NC}"
    fi
    echo ""

    # 显示文件数量
    local wallpaper_count=$(ls -1 "$SCRIPT_DIR/wallpaper/$series" 2>/dev/null | wc -l | tr -d ' ')
    local thumbnail_count=$(ls -1 "$SCRIPT_DIR/thumbnail/$series" 2>/dev/null | wc -l | tr -d ' ')
    echo "当前总数:"
    echo -e "  原图:   ${GREEN}$wallpaper_count${NC} 张"
    echo -e "  缩略图: ${GREEN}$thumbnail_count${NC} 张"
    if [ "$series" != "avatar" ]; then
        local preview_count=$(ls -1 "$SCRIPT_DIR/preview/$series" 2>/dev/null | wc -l | tr -d ' ')
        echo -e "  预览图: ${GREEN}$preview_count${NC} 张"
    fi
}

main "$@"
