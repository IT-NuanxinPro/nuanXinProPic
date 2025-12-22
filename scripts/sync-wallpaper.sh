#!/usr/bin/env bash
# sync-wallpaper.sh
# 从 Gitee 仓库增量同步电脑壁纸到本地 wallpaper/desktop 目录
# 策略：增量同步（只添加新文件，不删除已有文件）
# 源文件格式：分类--名称.扩展名（已带分类前缀）
# 同时生成缩略图到 thumbnail/desktop 目录
# 同时生成预览图到 preview/desktop 目录（1920px 宽，用于模态框快速加载）
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

# 缩略图配置
THUMB_WIDTH=800
THUMB_QUALITY=85

# 预览图配置（用于模态框快速加载，比原图小但比缩略图清晰）
PREVIEW_WIDTH=1920
PREVIEW_QUALITY=90

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
echo "  Wallpaper Sync Script (Incremental)"
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
    echo -e "${GREEN}[INFO]${NC} ImageMagick v7 found (magick), will generate thumbnails and previews"
    GENERATE_THUMBNAILS=true
elif command -v convert &> /dev/null; then
    IMAGEMAGICK_CMD="convert"
    echo -e "${GREEN}[INFO]${NC} ImageMagick found (convert), will generate thumbnails and previews"
    GENERATE_THUMBNAILS=true
else
    echo -e "${YELLOW}[WARN]${NC} ImageMagick not found, thumbnails and previews will not be generated"
    GENERATE_THUMBNAILS=false
fi

# 统计变量
total_found=0
new_copied=0
skipped=0
thumbnails_generated=0
thumbnail_errors=0
previews_generated=0
preview_errors=0

# 用于存储分类统计的临时文件
CATEGORY_STATS_FILE="/tmp/category_stats_$$"
> "$CATEGORY_STATS_FILE"

echo ""
echo "Scanning source repository for images..."
echo ""

# 处理图片函数（增量模式）
process_image() {
    local file="$1"
    local filename
    filename=$(basename "$file")

    local target_file="$TARGET_DIR/$filename"

    # 生成缩略图文件名（统一使用 webp 格式）
    local filename_noext="${filename%.*}"
    local thumbnail_file="$THUMBNAIL_DIR/${filename_noext}.webp"
    local preview_file="$PREVIEW_DIR/${filename_noext}.webp"

    total_found=$((total_found + 1))

    # 提取分类用于统计
    local category="未分类"
    if [[ "$filename" == *"--"* ]]; then
        category="${filename%%--*}"
    fi

    # 增量检查：文件是否已存在
    if [ -f "$target_file" ]; then
        # 壁纸已存在，检查缩略图和预览图是否需要生成
        if [ "$GENERATE_THUMBNAILS" = true ]; then
            # 检查缩略图
            if [ ! -f "$thumbnail_file" ]; then
                echo -e "${YELLOW}[THUMB ONLY]${NC} $filename"
                if $IMAGEMAGICK_CMD "$file" \
                    -resize "${THUMB_WIDTH}x>" \
                    -quality "$THUMB_QUALITY" \
                    -strip \
                    "$thumbnail_file" 2>/dev/null; then
                    echo -e "${BLUE}[THUMB]${NC} ${filename_noext}.webp"
                    thumbnails_generated=$((thumbnails_generated + 1))
                else
                    echo -e "${RED}[THUMB ERROR]${NC} Failed to generate thumbnail for $filename"
                    thumbnail_errors=$((thumbnail_errors + 1))
                fi
            fi
            # 检查预览图
            if [ ! -f "$preview_file" ]; then
                echo -e "${YELLOW}[PREVIEW ONLY]${NC} $filename"
                if $IMAGEMAGICK_CMD "$file" \
                    -resize "${PREVIEW_WIDTH}x>" \
                    -quality "$PREVIEW_QUALITY" \
                    -strip \
                    "$preview_file" 2>/dev/null; then
                    echo -e "${BLUE}[PREVIEW]${NC} ${filename_noext}.webp"
                    previews_generated=$((previews_generated + 1))
                else
                    echo -e "${RED}[PREVIEW ERROR]${NC} Failed to generate preview for $filename"
                    preview_errors=$((preview_errors + 1))
                fi
            fi
            # 如果缩略图和预览图都存在，则跳过
            if [ -f "$thumbnail_file" ] && [ -f "$preview_file" ]; then
                skipped=$((skipped + 1))
            fi
        else
            skipped=$((skipped + 1))
        fi
        return
    fi

    # 复制原图
    echo -e "${CYAN}[$category]${NC} ${GREEN}[NEW]${NC} $filename"
    cp "$file" "$target_file"
    new_copied=$((new_copied + 1))

    # 记录分类统计（仅新增文件）
    echo "$category" >> "$CATEGORY_STATS_FILE"

    # 生成缩略图和预览图（仅新文件）
    if [ "$GENERATE_THUMBNAILS" = true ]; then
        # 生成缩略图
        if [ ! -f "$thumbnail_file" ]; then
            if $IMAGEMAGICK_CMD "$file" \
                -resize "${THUMB_WIDTH}x>" \
                -quality "$THUMB_QUALITY" \
                -strip \
                "$thumbnail_file" 2>/dev/null; then
                echo -e "${BLUE}[THUMB]${NC} ${filename_noext}.webp"
                thumbnails_generated=$((thumbnails_generated + 1))
            else
                echo -e "${RED}[THUMB ERROR]${NC} Failed to generate thumbnail for $filename"
                thumbnail_errors=$((thumbnail_errors + 1))
            fi
        fi
        # 生成预览图
        if [ ! -f "$preview_file" ]; then
            if $IMAGEMAGICK_CMD "$file" \
                -resize "${PREVIEW_WIDTH}x>" \
                -quality "$PREVIEW_QUALITY" \
                -strip \
                "$preview_file" 2>/dev/null; then
                echo -e "${BLUE}[PREVIEW]${NC} ${filename_noext}.webp"
                previews_generated=$((previews_generated + 1))
            else
                echo -e "${RED}[PREVIEW ERROR]${NC} Failed to generate preview for $filename"
                preview_errors=$((preview_errors + 1))
            fi
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
if [ "$thumbnail_errors" -gt 0 ]; then
    echo "  Thumbnail errors:        $thumbnail_errors"
fi
if [ "$preview_errors" -gt 0 ]; then
    echo "  Preview errors:          $preview_errors"
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
