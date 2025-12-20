#!/bin/bash
# sync-wallpaper.sh
# 从 Gitee 仓库同步壁纸到本地 wallpaper 目录
# 策略：全量覆盖（删除现有文件后重新同步）
# 同时生成缩略图到 thumbnail 目录

# 配置
GITEE_REPO="https://gitee.com/zhang--shuang/desktop_wallpaper.git"
TEMP_DIR="/tmp/desktop_wallpaper_sync"
TARGET_DIR="wallpaper"
THUMBNAIL_DIR="thumbnail"

# 缩略图配置
THUMB_WIDTH=400
THUMB_QUALITY=80

# 支持的图片格式
IMAGE_EXTENSIONS=("jpg" "jpeg" "png" "gif" "webp" "JPG" "JPEG" "PNG" "GIF" "WEBP")

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "=========================================="
echo "  Wallpaper Sync Script (Full Overwrite)"
echo "=========================================="
echo ""

# 清理临时目录
if [ -d "$TEMP_DIR" ]; then
    echo "Cleaning up previous temp directory..."
    rm -rf "$TEMP_DIR"
fi

# Shallow clone Gitee 仓库
echo "Cloning Gitee repository (shallow)..."
git clone --depth 1 "$GITEE_REPO" "$TEMP_DIR"

if [ $? -ne 0 ]; then
    echo -e "${RED}[ERROR]${NC} Failed to clone repository"
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

# 检查 ImageMagick 是否可用（兼容 v6 的 convert 和 v7 的 magick）
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

echo ""
echo "Scanning and copying images..."
echo ""

# 遍历临时目录中的图片
for ext in "${IMAGE_EXTENSIONS[@]}"; do
    shopt -s nullglob
    for file in "$TEMP_DIR"/*."$ext"; do
        # 检查文件是否存在
        [ -e "$file" ] || continue

        filename=$(basename "$file")
        target_file="$TARGET_DIR/$filename"

        # 生成缩略图文件名（统一使用 webp 格式）
        filename_noext="${filename%.*}"
        thumbnail_file="$THUMBNAIL_DIR/${filename_noext}.webp"

        total_found=$((total_found + 1))

        # 复制原图
        echo -e "${GREEN}[COPY]${NC} $filename"
        cp "$file" "$target_file"
        copied=$((copied + 1))

        # 生成缩略图
        if [ "$GENERATE_THUMBNAILS" = true ]; then
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
    done
    shopt -u nullglob
done

# 清理临时目录
echo ""
echo "Cleaning up temp directory..."
rm -rf "$TEMP_DIR"

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
echo "=========================================="

# 设置输出变量供 GitHub Actions 使用
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "total_images=$copied" >> "$GITHUB_OUTPUT"
    echo "thumbnails=$thumbnails_generated" >> "$GITHUB_OUTPUT"
fi

# 返回是否有图片（用于判断是否需要提交）
if [ "$copied" -gt 0 ]; then
    exit 0
else
    echo ""
    echo "No images found to sync."
    exit 0
fi
