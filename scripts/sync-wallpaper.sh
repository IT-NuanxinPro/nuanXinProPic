#!/bin/bash
# sync-wallpaper.sh
# 从 Gitee 仓库同步壁纸到本地 wallpaper 目录
# 仅复制不存在的新图片，跳过已存在的文件

# 配置
GITEE_REPO="https://gitee.com/zhang--shuang/desktop_wallpaper.git"
TEMP_DIR="/tmp/desktop_wallpaper_sync"
TARGET_DIR="wallpaper"

# 支持的图片格式
IMAGE_EXTENSIONS=("jpg" "jpeg" "png" "gif" "webp" "JPG" "JPEG" "PNG" "GIF" "WEBP")

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "  Wallpaper Sync Script"
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

# 确保目标目录存在
mkdir -p "$TARGET_DIR"

# 统计变量
total_found=0
new_copied=0
skipped=0

echo ""
echo "Scanning for images..."
echo ""

# 遍历临时目录中的图片
for ext in "${IMAGE_EXTENSIONS[@]}"; do
    shopt -s nullglob
    for file in "$TEMP_DIR"/*."$ext"; do
        # 检查文件是否存在
        [ -e "$file" ] || continue

        filename=$(basename "$file")
        target_file="$TARGET_DIR/$filename"

        total_found=$((total_found + 1))

        if [ -f "$target_file" ]; then
            echo -e "${YELLOW}[SKIP]${NC} $filename (already exists)"
            skipped=$((skipped + 1))
        else
            echo -e "${GREEN}[COPY]${NC} $filename"
            cp "$file" "$target_file"
            new_copied=$((new_copied + 1))
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
echo "  Total images found: $total_found"
echo "  New images copied:  $new_copied"
echo "  Skipped (existed):  $skipped"
echo "=========================================="

# 设置输出变量供 GitHub Actions 使用
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "new_images=$new_copied" >> "$GITHUB_OUTPUT"
fi

# 返回是否有新图片（用于判断是否需要提交）
if [ "$new_copied" -gt 0 ]; then
    exit 0
else
    echo ""
    echo "No new images to sync."
    exit 0
fi
