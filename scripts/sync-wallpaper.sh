#!/usr/bin/env bash
# sync-wallpaper.sh
# 从 Gitee 仓库增量同步电脑壁纸到本地 wallpaper/desktop 目录
# 策略：增量同步（只添加新文件，不删除已有文件）
# 源文件格式：L1分类--L2分类_名称.扩展名（如：动漫--原神_雷电将军.jpg）
# 目标结构：wallpaper/desktop/L1/L2/名称.扩展名
# 同时生成缩略图到 thumbnail/desktop/L1/L2/ 目录
# 同时生成预览图到 preview/desktop/L1/L2/ 目录
# 注意：手机壁纸(mobile)和头像(avatar)由用户手动管理

set -e

# Gitee 仓库配置
GITEE_OWNER="zhang--shuang"
GITEE_REPO="desktop_wallpaper"
GITEE_BRANCH="master"

# 本地目录配置（仅同步 desktop 子目录）
TEMP_DIR="/tmp/desktop_wallpaper_sync"
TARGET_DIR="wallpaper/desktop"
THUMBNAIL_DIR="thumbnail/desktop"
PREVIEW_DIR="preview/desktop"

# 已知的一级分类（用于匹配）
KNOWN_L1_CATEGORIES="动漫|游戏|影视|风景|人像|插画|IP形象|国风"

# 排除列表（这些文件已经存在但名字不同，跳过同步）
# 格式：Gitee文件名的核心部分（_后面的部分）
EXCLUDE_CORE_NAMES="白色翅膀|蘑菇人对战"

# 获取L2分类的函数
get_l2_categories() {
    local l1="$1"
    case "$l1" in
        "动漫") echo "原神|蜡笔小新|海贼王|名侦探柯南|鬼灭之刃|间谍过家家|春物雪乃|刀剑神域|新世纪福音战士|紫罗兰永恒花园|罪恶王冠|蕾姆|神奇宝贝|完美世界|斗破苍穹|百炼成神" ;;
        "游戏") echo "原神|崩坏|艾尔登法环|英雄联盟" ;;
        "影视") echo "疯狂动物城|海绵宝宝|漫威" ;;
        "风景") echo "雪山|海滨|城市|天空|日落|湖泊|花卉|森林|星空" ;;
        "人像") echo "氛围感|清新|日系" ;;
        "插画") echo "二次元|国风|创意" ;;
        "IP形象") echo "水豚噜噜|线条小狗|乌萨奇|小八" ;;
        *) echo "" ;;
    esac
}

# 缩略图配置
THUMB_WIDTH=550
THUMB_QUALITY=85

# 预览图配置
PREVIEW_WIDTH=1920
PREVIEW_QUALITY=90

# 水印配置
WATERMARK_ENABLED=true
WATERMARK_TEXT="暖心"
WATERMARK_OPACITY=40
WATERMARK_POSITION="southeast"
WATERMARK_ANGLE=-25
WATERMARK_SECOND_POSITION="southwest"
WATERMARK_SECOND_ANGLE=0

# 预览图水印配置
PREVIEW_WATERMARK_SIZE_PERCENT=2
PREVIEW_WATERMARK_OFFSET_X=40
PREVIEW_WATERMARK_OFFSET_Y=80
PREVIEW_WATERMARK_OFFSET_X_LEFT=40
PREVIEW_WATERMARK_OFFSET_Y_LEFT=80

# 缩略图水印配置
THUMB_WATERMARK_SIZE_PERCENT=2
THUMB_WATERMARK_OFFSET_X=20
THUMB_WATERMARK_OFFSET_Y=40
THUMB_WATERMARK_OFFSET_X_LEFT=20
THUMB_WATERMARK_OFFSET_Y_LEFT=40

# 重试配置
MAX_RETRIES=3
RETRY_DELAY=5

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "=========================================="
echo "  Wallpaper Sync Script (Folder Structure)"
echo "=========================================="
echo ""

# 检查是否有 Gitee Token
if [ -n "$GITEE_TOKEN" ]; then
    echo -e "${GREEN}[INFO]${NC} Gitee token detected, using authenticated requests"
    GITEE_CLONE_URL="https://oauth2:${GITEE_TOKEN}@gitee.com/${GITEE_OWNER}/${GITEE_REPO}.git"
else
    echo -e "${YELLOW}[WARN]${NC} No Gitee token, using anonymous requests (may be rate limited)"
    GITEE_CLONE_URL="https://gitee.com/${GITEE_OWNER}/${GITEE_REPO}.git"
fi

# 清理临时目录
cleanup_temp() {
    rm -rf "$TEMP_DIR"
}
cleanup_temp

# 使用 git clone 下载
download_source() {
    echo -e "${BLUE}[INFO]${NC} Cloning repository..."
    for i in $(seq 1 $MAX_RETRIES); do
        echo -e "${BLUE}[ATTEMPT $i/$MAX_RETRIES]${NC} Cloning..."
        if git clone --depth 1 "$GITEE_CLONE_URL" "$TEMP_DIR" 2>&1; then
            echo -e "${GREEN}[SUCCESS]${NC} Clone completed"
            return 0
        else
            echo -e "${YELLOW}[FAILED]${NC} Clone attempt $i failed"
            rm -rf "$TEMP_DIR"
            if [ "$i" -lt "$MAX_RETRIES" ]; then
                echo "Waiting ${RETRY_DELAY}s before retry..."
                sleep $RETRY_DELAY
            fi
        fi
    done
    echo -e "${RED}[ERROR]${NC} Failed to download source after all attempts"
    return 1
}

# 执行下载
if ! download_source; then
    exit 1
fi

# 确保目标目录存在
mkdir -p "$TARGET_DIR"
mkdir -p "$THUMBNAIL_DIR"
mkdir -p "$PREVIEW_DIR"

# 检查 ImageMagick 是否可用
if command -v magick &> /dev/null; then
    IMAGEMAGICK_CMD="magick"
    echo -e "${GREEN}[INFO]${NC} ImageMagick v7 found"
    GENERATE_THUMBNAILS=true
elif command -v convert &> /dev/null; then
    IMAGEMAGICK_CMD="convert"
    echo -e "${GREEN}[INFO]${NC} ImageMagick found (convert)"
    GENERATE_THUMBNAILS=true
else
    echo -e "${YELLOW}[WARN]${NC} ImageMagick not found"
    GENERATE_THUMBNAILS=false
fi

# 检查水印功能
if [ "$WATERMARK_ENABLED" = true ] && [ "$GENERATE_THUMBNAILS" = true ]; then
    PREVIEW_WATERMARK_FONT_SIZE=$((PREVIEW_WIDTH * PREVIEW_WATERMARK_SIZE_PERCENT / 100))
    THUMB_WATERMARK_FONT_SIZE=$((THUMB_WIDTH * THUMB_WATERMARK_SIZE_PERCENT / 100))
    # 使用 awk 计算小数
    WATERMARK_ALPHA=$(awk "BEGIN {printf \"%.2f\", $WATERMARK_OPACITY / 100}")
    WATERMARK_COLOR="rgba(255,255,255,$WATERMARK_ALPHA)"

    WATERMARK_FONT=""
    if [ "$(uname)" = "Darwin" ]; then
        for font in "Heiti-SC-Medium" "PingFang-SC-Medium" "PingFang-SC-Regular"; do
            if $IMAGEMAGICK_CMD -list font 2>/dev/null | grep -qi "$font"; then
                WATERMARK_FONT="$font"
                break
            fi
        done
        [ -z "$WATERMARK_FONT" ] && WATERMARK_FONT="Heiti-SC-Medium"
    elif [ "$(uname)" = "Linux" ]; then
        for font in "Noto-Sans-CJK-SC-Medium" "Noto-Sans-CJK-SC" "WenQuanYi-Micro-Hei"; do
            if $IMAGEMAGICK_CMD -list font 2>/dev/null | grep -qi "$font"; then
                WATERMARK_FONT="$font"
                break
            fi
        done
        [ -z "$WATERMARK_FONT" ] && WATERMARK_FONT="Noto-Sans-CJK-SC-Medium"
    else
        WATERMARK_FONT="Microsoft-YaHei-Bold"
    fi
    echo -e "${GREEN}[INFO]${NC} Watermark enabled: \"$WATERMARK_TEXT\" (font: $WATERMARK_FONT)"
fi

# 统计变量
total_found=0
new_copied=0
skipped=0
thumbnails_generated=0
previews_generated=0
watermarks_added=0

# 分类统计
CATEGORY_STATS_FILE="/tmp/category_stats_$$"
> "$CATEGORY_STATS_FILE"

echo ""
echo "Scanning source repository for images..."
echo ""

# 解析文件名，提取分类信息
# 格式：L1分类--L2分类_名称.扩展名（如：动漫--原神_雷电将军.jpg）
# 返回：L1 L2 新文件名
parse_filename() {
    local filename="$1"
    local filename_noext="${filename%.*}"
    local ext="${filename##*.}"
    
    local l1="未分类"
    local l2="通用"
    local newname="$filename"
    
    # 检查是否包含 -- 分隔符
    if [[ "$filename_noext" == *"--"* ]]; then
        # 提取 L1 分类（-- 前面的部分）
        local prefix="${filename_noext%%--*}"
        local rest="${filename_noext#*--}"
        
        # 验证 L1 是否是已知分类
        if echo "$prefix" | grep -qE "^($KNOWN_L1_CATEGORIES)$"; then
            l1="$prefix"
            
            # 尝试提取 L2 分类（第一个 _ 前面的部分）
            if [[ "$rest" == *"_"* ]]; then
                local potential_l2="${rest%%_*}"
                local remaining="${rest#*_}"
                
                # 检查是否是已知的 L2 分类
                local l2_pattern
                l2_pattern=$(get_l2_categories "$l1")
                if [ -n "$l2_pattern" ] && echo "$potential_l2" | grep -qE "^($l2_pattern)$"; then
                    l2="$potential_l2"
                    newname="${remaining}.${ext}"
                else
                    # L2 不匹配，整个 rest 作为文件名，L2 设为通用
                    l2="通用"
                    newname="${rest}.${ext}"
                fi
            else
                # 没有 _，整个 rest 作为文件名
                newname="${rest}.${ext}"
            fi
        fi
    fi
    
    echo "$l1|$l2|$newname"
}

# 提取文件名核心部分（用于匹配）
# 格式：动漫--原神_雷电将军.jpg → 雷电将军
# 格式：雷电将军.jpg → 雷电将军
get_core_name() {
    local filename="$1"
    local filename_noext="${filename%.*}"
    
    # 如果包含 _，取最后一个 _ 后面的部分
    if [[ "$filename_noext" == *"_"* ]]; then
        echo "${filename_noext##*_}"
    else
        # 如果包含 --，取 -- 后面的部分
        if [[ "$filename_noext" == *"--"* ]]; then
            echo "${filename_noext#*--}"
        else
            echo "$filename_noext"
        fi
    fi
}

# 检查文件是否已存在（通过核心名匹配）
file_exists_in_target() {
    local filename="$1"
    local core_name
    core_name=$(get_core_name "$filename")
    
    # 检查是否在排除列表中
    if echo "$core_name" | grep -qE "($EXCLUDE_CORE_NAMES)"; then
        echo -e "${YELLOW}[EXCLUDE]${NC} $filename (在排除列表中)" >&2
        return 0  # 视为已存在，跳过
    fi
    
    # 递归搜索 wallpaper/desktop 目录，查找包含核心名的文件
    if find "$TARGET_DIR" -type f \( -iname "*${core_name}.*" -o -iname "*${core_name}_*" -o -iname "*_${core_name}.*" \) 2>/dev/null | grep -q .; then
        return 0  # 存在
    fi
    return 1  # 不存在
}

# 生成预览图函数（desktop 不加水印，与 mobile 保持一致）
generate_preview() {
    local source_file="$1"
    local output_file="$2"

    mkdir -p "$(dirname "$output_file")"

    # desktop 预览图不加水印，直接生成
    $IMAGEMAGICK_CMD "$source_file" \
        -resize "${PREVIEW_WIDTH}x>" \
        -quality "$PREVIEW_QUALITY" \
        -strip \
        "$output_file" 2>/dev/null
}

# 生成缩略图函数（带水印）
generate_thumbnail() {
    local source_file="$1"
    local output_file="$2"
    
    mkdir -p "$(dirname "$output_file")"
    
    if [ "$WATERMARK_ENABLED" = true ]; then
        if $IMAGEMAGICK_CMD "$source_file" \
            -resize "${THUMB_WIDTH}x>" \
            -font "$WATERMARK_FONT" \
            -pointsize "$THUMB_WATERMARK_FONT_SIZE" \
            -fill "$WATERMARK_COLOR" \
            -gravity "$WATERMARK_POSITION" \
            -annotate ${WATERMARK_ANGLE}x${WATERMARK_ANGLE}+${THUMB_WATERMARK_OFFSET_X}+${THUMB_WATERMARK_OFFSET_Y} "$WATERMARK_TEXT" \
            -gravity "$WATERMARK_SECOND_POSITION" \
            -annotate ${WATERMARK_SECOND_ANGLE}x${WATERMARK_SECOND_ANGLE}+${THUMB_WATERMARK_OFFSET_X_LEFT}+${THUMB_WATERMARK_OFFSET_Y_LEFT} "$WATERMARK_TEXT" \
            -quality "$THUMB_QUALITY" \
            -strip \
            "$output_file" 2>/dev/null; then
            return 0
        fi
    fi
    
    # 无水印版本
    $IMAGEMAGICK_CMD "$source_file" \
        -resize "${THUMB_WIDTH}x>" \
        -quality "$THUMB_QUALITY" \
        -strip \
        "$output_file" 2>/dev/null
}

# 处理图片函数
process_image() {
    local file="$1"
    local original_filename
    original_filename=$(basename "$file")
    
    total_found=$((total_found + 1))
    
    # 解析文件名，获取分类信息
    local parsed
    parsed=$(parse_filename "$original_filename")
    local l1=$(echo "$parsed" | cut -d'|' -f1)
    local l2=$(echo "$parsed" | cut -d'|' -f2)
    local newname=$(echo "$parsed" | cut -d'|' -f3)
    local newname_noext="${newname%.*}"
    
    # 增量检查：递归搜索是否已存在同名文件
    if file_exists_in_target "$newname"; then
        skipped=$((skipped + 1))
        return
    fi
    
    # 构建目标路径
    local target_subdir="$TARGET_DIR/$l1/$l2"
    local thumb_subdir="$THUMBNAIL_DIR/$l1/$l2"
    local preview_subdir="$PREVIEW_DIR/$l1/$l2"
    
    local target_file="$target_subdir/$newname"
    local thumbnail_file="$thumb_subdir/${newname_noext}.webp"
    local preview_file="$preview_subdir/${newname_noext}.webp"
    
    # 创建目录
    mkdir -p "$target_subdir"
    
    # 复制原图（保留时间戳 -p 参数）
    echo -e "${CYAN}[$l1/$l2]${NC} ${GREEN}[NEW]${NC} $newname"
    cp -p "$file" "$target_file"
    new_copied=$((new_copied + 1))
    
    # 记录分类统计
    echo "$l1/$l2" >> "$CATEGORY_STATS_FILE"
    
    # 生成缩略图和预览图
    if [ "$GENERATE_THUMBNAILS" = true ]; then
        if generate_thumbnail "$file" "$thumbnail_file"; then
            echo -e "${BLUE}[THUMB]${NC} $l1/$l2/${newname_noext}.webp"
            thumbnails_generated=$((thumbnails_generated + 1))
        fi
        if generate_preview "$file" "$preview_file"; then
            echo -e "${BLUE}[PREVIEW]${NC} $l1/$l2/${newname_noext}.webp"
            previews_generated=$((previews_generated + 1))
        fi
    fi
}

# 处理源仓库根目录中的所有图片
echo -e "${BLUE}[INFO]${NC} Processing images from source repository..."
while IFS= read -r -d '' file; do
    process_image "$file"
done < <(find "$TEMP_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) -print0 2>/dev/null)

# 清理临时目录
echo ""
echo "Cleaning up temp directory..."
cleanup_temp

# 输出统计
echo ""
echo "=========================================="
echo "  Sync Complete!"
echo "=========================================="
echo "  Total images in source:  $total_found"
echo "  New images copied:       $new_copied"
echo "  Skipped (existing):      $skipped"
echo "  Thumbnails generated:    $thumbnails_generated"
echo "  Previews generated:      $previews_generated"
if [ "$WATERMARK_ENABLED" = true ]; then
    echo "  Watermarks added:        $watermarks_added"
fi

# 显示新增文件的分类统计
if [ "$new_copied" -gt 0 ]; then
    echo ""
    echo "  New images by category:"
    sort "$CATEGORY_STATS_FILE" | uniq -c | sort -rn | while read -r count cat_name; do
        echo "    $cat_name: $count"
    done
fi

echo "=========================================="

# 清理临时统计文件
rm -f "$CATEGORY_STATS_FILE"

# 设置输出变量供 GitHub Actions 使用
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "new_images=$new_copied" >> "$GITHUB_OUTPUT"
    echo "thumbnails=$thumbnails_generated" >> "$GITHUB_OUTPUT"
    echo "previews=$previews_generated" >> "$GITHUB_OUTPUT"
    echo "watermarks=$watermarks_added" >> "$GITHUB_OUTPUT"
fi

# 返回是否有新增
if [ "$new_copied" -gt 0 ]; then
    echo ""
    echo -e "${GREEN}[INFO]${NC} $new_copied new images synced!"
    exit 0
else
    echo ""
    echo -e "${BLUE}[INFO]${NC} No new images to sync."
    exit 0
fi
