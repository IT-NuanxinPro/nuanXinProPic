#!/usr/bin/env bash
# ========================================
# 重新生成 desktop 预览图（无水印）
# ========================================
#
# 用途：删除现有的 desktop 预览图，然后从原图重新生成（不带水印）
#
# 用法：
#   ./scripts/regenerate-desktop-previews.sh [--dry-run]
#
# 参数：
#   --dry-run  仅显示将要处理的文件，不实际执行
#
# ========================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WALLPAPER_DIR="$PROJECT_ROOT/wallpaper/desktop"
PREVIEW_DIR="$PROJECT_ROOT/preview/desktop"

# 预览图配置
PREVIEW_WIDTH=1920
PREVIEW_QUALITY=90

# 检查参数
DRY_RUN=false
if [ "$1" = "--dry-run" ]; then
    DRY_RUN=true
    echo -e "${YELLOW}[DRY-RUN 模式] 仅显示将要执行的操作${NC}"
    echo ""
fi

# 自动检测 ImageMagick 命令
detect_imagemagick_cmd() {
    if command -v magick &>/dev/null; then
        echo "magick"
    elif command -v convert &>/dev/null; then
        if convert --version 2>&1 | grep -q "ImageMagick"; then
            echo "convert"
        else
            echo ""
        fi
    else
        echo ""
    fi
}

IMAGEMAGICK_CMD=$(detect_imagemagick_cmd)

if [ -z "$IMAGEMAGICK_CMD" ]; then
    echo -e "${RED}错误: 未找到 ImageMagick${NC}"
    echo ""
    echo "请先安装 ImageMagick:"
    echo "  macOS:   brew install imagemagick"
    echo "  Windows: scoop install imagemagick"
    echo "  Ubuntu:  sudo apt install imagemagick"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}重新生成 Desktop 预览图（无水印）${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "原图目录:   ${GREEN}$WALLPAPER_DIR${NC}"
echo -e "预览图目录: ${GREEN}$PREVIEW_DIR${NC}"
echo -e "预览宽度:   ${CYAN}${PREVIEW_WIDTH}px${NC}"
echo -e "输出质量:   ${CYAN}${PREVIEW_QUALITY}%${NC}"
echo ""

# 检查原图目录是否存在
if [ ! -d "$WALLPAPER_DIR" ]; then
    echo -e "${RED}错误: 原图目录不存在: $WALLPAPER_DIR${NC}"
    exit 1
fi

# 统计
total_found=0
regenerated=0
failed=0

# 第一步：删除现有的预览图目录
if [ "$DRY_RUN" = false ]; then
    echo -e "${YELLOW}[1/2] 删除现有预览图目录...${NC}"
    if [ -d "$PREVIEW_DIR" ]; then
        rm -rf "$PREVIEW_DIR"
        echo -e "${GREEN}✓${NC} 已删除: $PREVIEW_DIR"
    else
        echo -e "${CYAN}→${NC} 预览图目录不存在，跳过删除"
    fi
    echo ""
else
    echo -e "${YELLOW}[DRY-RUN] 将删除: $PREVIEW_DIR${NC}"
    echo ""
fi

# 第二步：重新生成预览图
echo -e "${YELLOW}[2/2] 从原图重新生成预览图...${NC}"
echo ""

# 遍历所有原图
while IFS= read -r -d '' wallpaper_file; do
    total_found=$((total_found + 1))

    # 获取相对路径（相对于 wallpaper/desktop/）
    relative_path="${wallpaper_file#$WALLPAPER_DIR/}"

    # 获取文件名（不含扩展名）
    filename=$(basename "$wallpaper_file")
    name="${filename%.*}"

    # 获取目录路径（L1/L2）
    dir_path=$(dirname "$relative_path")

    # 构建预览图路径
    preview_file="$PREVIEW_DIR/$dir_path/${name}.webp"

    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN]${NC} $relative_path -> preview/desktop/$dir_path/${name}.webp"
        regenerated=$((regenerated + 1))
        continue
    fi

    # 创建目录
    mkdir -p "$(dirname "$preview_file")"

    # 生成预览图（无水印）
    if $IMAGEMAGICK_CMD "$wallpaper_file" \
        -resize "${PREVIEW_WIDTH}x>" \
        -quality "$PREVIEW_QUALITY" \
        -strip \
        "$preview_file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $dir_path/${name}.webp"
        regenerated=$((regenerated + 1))
    else
        echo -e "${RED}✗${NC} 失败: $relative_path"
        failed=$((failed + 1))
    fi

done < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) -print0 2>/dev/null)

# 输出统计
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}处理完成!${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "  找到原图:     ${GREEN}$total_found${NC}"
echo -e "  成功生成:     ${GREEN}$regenerated${NC}"
if [ "$failed" -gt 0 ]; then
    echo -e "  失败:         ${RED}$failed${NC}"
fi
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}这是 DRY-RUN 模式，未实际执行任何操作${NC}"
    echo -e "确认无误后，运行不带 --dry-run 参数的命令:"
    echo -e "  ${CYAN}./scripts/regenerate-desktop-previews.sh${NC}"
else
    echo -e "${GREEN}所有 desktop 预览图已重新生成（无水印）${NC}"
    echo ""
    echo -e "下一步操作:"
    echo -e "  1. 检查预览图效果: ${CYAN}open preview/desktop${NC}"
    echo -e "  2. 提交更改: ${CYAN}git add preview/desktop && git commit -m 'chore: 重新生成 desktop 预览图（去除水印）'${NC}"
    echo -e "  3. 推送远程: ${CYAN}git push${NC}"
fi
