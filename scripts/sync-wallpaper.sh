#!/usr/bin/env bash
# sync-wallpaper.sh
# 从 Gitee 仓库同步壁纸到本地 wallpaper 目录
# 策略：全量覆盖（删除现有文件后重新同步）
# 支持分类目录：游戏、动漫、风景、其他
# 同时生成缩略图到 thumbnail 目录

set -e

# Gitee 仓库配置
GITEE_OWNER="zhang--shuang"
GITEE_REPO="desktop_wallpaper"
GITEE_BRANCH="master"

# 本地目录配置
TEMP_DIR="/tmp/desktop_wallpaper_sync"
TEMP_ZIP="/tmp/desktop_wallpaper.zip"
TARGET_DIR="wallpaper"
THUMBNAIL_DIR="thumbnail"

# 缩略图配置
THUMB_WIDTH=400
THUMB_QUALITY=80

# 重试配置
MAX_RETRIES=3
RETRY_DELAY=5

# 支持的图片格式（用于 find 命令）
IMAGE_PATTERN=".*\.\(jpg\|jpeg\|png\|gif\|webp\|JPG\|JPEG\|PNG\|GIF\|WEBP\)$"

# 分类目录
CATEGORY_GAME="游戏"
CATEGORY_ANIME="动漫"
CATEGORY_SCENERY="风景"
CATEGORY_OTHER="其他"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "=========================================="
echo "  Wallpaper Sync Script (Full Overwrite)"
echo "  With Category Support"
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

# 清理临时目录和文件
cleanup_temp() {
    rm -rf "$TEMP_DIR"
    rm -f "$TEMP_ZIP"
}
cleanup_temp

# 使用 git clone 下载（ZIP 解压中文文件名有编码问题）
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

# 全量覆盖：删除现有目录
echo ""
echo -e "${YELLOW}[INFO]${NC} Removing existing directories for full overwrite..."
rm -rf "$TARGET_DIR"
rm -rf "$THUMBNAIL_DIR"

# 重新创建目录
mkdir -p "$TARGET_DIR"
mkdir -p "$THUMBNAIL_DIR"

# 检查 ImageMagick 是否可用
if command -v magick &> /dev/null; then
    IMAGEMAGICK_CMD="magick"
    echo -e "${GREEN}[INFO]${NC} ImageMagick v7 found (magick), will generate thumbnails"
    GENERATE_THUMBNAILS=true
elif command -v convert &> /dev/null; then
    IMAGEMAGICK_CMD="convert"
    echo -e "${GREEN}[INFO]${NC} ImageMagick found (convert), will generate thumbnails"
    GENERATE_THUMBNAILS=true
else
    echo -e "${YELLOW}[WARN]${NC} ImageMagick not found, thumbnails will not be generated"
    GENERATE_THUMBNAILS=false
fi

# 统计变量
total_found=0
copied=0
thumbnails_generated=0
thumbnail_errors=0
count_game=0
count_anime=0
count_scenery=0
count_other=0
count_uncategorized=0

echo ""
echo "Scanning and copying images with categories..."
echo ""

# 处理图片函数
process_image() {
    local file="$1"
    local category="$2"
    local filename
    filename=$(basename "$file")

    # 如果有分类，添加分类前缀
    local target_filename
    if [ -n "$category" ]; then
        target_filename="${category}--${filename}"
    else
        target_filename="$filename"
    fi

    local target_file="$TARGET_DIR/$target_filename"

    # 生成缩略图文件名（统一使用 webp 格式）
    local target_filename_noext="${target_filename%.*}"
    local thumbnail_file="$THUMBNAIL_DIR/${target_filename_noext}.webp"

    total_found=$((total_found + 1))

    # 复制原图
    if [ -n "$category" ]; then
        echo -e "${CYAN}[$category]${NC} ${GREEN}[COPY]${NC} $filename"
    else
        echo -e "${GREEN}[COPY]${NC} $filename"
    fi
    cp "$file" "$target_file"
    copied=$((copied + 1))

    # 生成缩略图
    if [ "$GENERATE_THUMBNAILS" = true ]; then
        if $IMAGEMAGICK_CMD "$file" \
            -resize "${THUMB_WIDTH}x>" \
            -quality "$THUMB_QUALITY" \
            -strip \
            "$thumbnail_file" 2>/dev/null; then
            echo -e "${BLUE}[THUMB]${NC} ${target_filename_noext}.webp"
            thumbnails_generated=$((thumbnails_generated + 1))
        else
            echo -e "${RED}[THUMB ERROR]${NC} Failed to generate thumbnail for $filename"
            thumbnail_errors=$((thumbnail_errors + 1))
        fi
    fi
}

# 处理分类目录
process_category() {
    local category_name="$1"
    local category_dir="$TEMP_DIR/$category_name"

    if [ -d "$category_dir" ]; then
        echo ""
        echo -e "${CYAN}=== Processing category: $category_name ===${NC}"

        # 使用 find 来遍历文件，避免 glob 问题
        while IFS= read -r -d '' file; do
            process_image "$file" "$category_name"

            # 更新分类计数
            case "$category_name" in
                "$CATEGORY_GAME") count_game=$((count_game + 1)) ;;
                "$CATEGORY_ANIME") count_anime=$((count_anime + 1)) ;;
                "$CATEGORY_SCENERY") count_scenery=$((count_scenery + 1)) ;;
                "$CATEGORY_OTHER") count_other=$((count_other + 1)) ;;
            esac
        done < <(find "$category_dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) -print0 2>/dev/null)
    fi
}

# 处理各分类目录
process_category "$CATEGORY_GAME"
process_category "$CATEGORY_ANIME"
process_category "$CATEGORY_SCENERY"
process_category "$CATEGORY_OTHER"

# 处理根目录中的图片（未分类）
echo ""
echo -e "${CYAN}=== Processing uncategorized images ===${NC}"
while IFS= read -r -d '' file; do
    process_image "$file" ""
    count_uncategorized=$((count_uncategorized + 1))
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
echo "  Total images found:      $total_found"
echo "  Images copied:           $copied"
echo "  Thumbnails generated:    $thumbnails_generated"
if [ "$thumbnail_errors" -gt 0 ]; then
    echo "  Thumbnail errors:        $thumbnail_errors"
fi
echo ""
echo "  Category breakdown:"
[ "$count_game" -gt 0 ] && echo "    $CATEGORY_GAME: $count_game"
[ "$count_anime" -gt 0 ] && echo "    $CATEGORY_ANIME: $count_anime"
[ "$count_scenery" -gt 0 ] && echo "    $CATEGORY_SCENERY: $count_scenery"
[ "$count_other" -gt 0 ] && echo "    $CATEGORY_OTHER: $count_other"
[ "$count_uncategorized" -gt 0 ] && echo "    未分类: $count_uncategorized"
echo "=========================================="

# 设置输出变量供 GitHub Actions 使用
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "total_images=$copied" >> "$GITHUB_OUTPUT"
    echo "thumbnails=$thumbnails_generated" >> "$GITHUB_OUTPUT"
fi

# 返回是否有图片
if [ "$copied" -gt 0 ]; then
    exit 0
else
    echo ""
    echo "No images found to sync."
    exit 0
fi
