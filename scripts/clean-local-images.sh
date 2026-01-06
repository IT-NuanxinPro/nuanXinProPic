#!/bin/bash
# ========================================
# 清理本地文件夹中的图片（保留目录结构）
# ========================================
#
# 功能：删除指定目录下的所有图片文件
#       保留目录结构，便于后续继续使用
#
# 用法：
#   ./scripts/clean-local-images.sh <本地基础路径> [系列]
#
# 参数：
#   本地基础路径  包含 desktop/mobile/avatar 的目录
#   系列          可选，指定清理某个系列：desktop | mobile | avatar | all(默认)
#
# 示例：
#   ./scripts/clean-local-images.sh ~/Pictures/wallpaper          # 清理全部
#   ./scripts/clean-local-images.sh ~/Pictures/wallpaper desktop  # 只清理 desktop
#   ./scripts/clean-local-images.sh ~/Pictures/wallpaper mobile   # 只清理 mobile
#
# ========================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

show_help() {
    echo -e "${BLUE}清理本地图片脚本${NC}"
    echo ""
    echo "用法: $0 <本地基础路径> [系列]"
    echo ""
    echo "参数:"
    echo "  本地基础路径  包含 desktop/mobile/avatar 的目录"
    echo "  系列          可选: desktop | mobile | avatar | all(默认)"
    echo ""
    echo "示例:"
    echo "  $0 ~/Pictures/wallpaper          # 清理全部"
    echo "  $0 ~/Pictures/wallpaper desktop  # 只清理 desktop"
}

# 检查参数
if [ $# -lt 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

# 展开 ~ 路径
LOCAL_BASE="${1/#\~/$HOME}"
SERIES="${2:-all}"

# 验证路径
if [ ! -d "$LOCAL_BASE" ]; then
    echo -e "${RED}错误: 目录不存在: $LOCAL_BASE${NC}"
    exit 1
fi

# 确定要清理的系列
if [ "$SERIES" = "all" ]; then
    SERIES_LIST=("desktop" "mobile" "avatar")
else
    if [[ ! "$SERIES" =~ ^(desktop|mobile|avatar)$ ]]; then
        echo -e "${RED}错误: 无效的系列: $SERIES${NC}"
        echo "有效值: desktop | mobile | avatar | all"
        exit 1
    fi
    SERIES_LIST=("$SERIES")
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}清理本地图片${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "目标目录: ${GREEN}$LOCAL_BASE${NC}"
echo -e "清理系列: ${CYAN}${SERIES_LIST[*]}${NC}"
echo ""

# 统计
total_deleted=0
total_size=0

# 先统计将要删除的文件
echo -e "${YELLOW}即将删除以下图片文件:${NC}"
echo ""

for series in "${SERIES_LIST[@]}"; do
    series_path="$LOCAL_BASE/$series"

    if [ ! -d "$series_path" ]; then
        echo -e "  ${YELLOW}⚠ 目录不存在: $series_path${NC}"
        continue
    fi

    # 统计该系列下的图片
    count=$(find "$series_path" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.bmp" \) 2>/dev/null | wc -l | tr -d ' ')

    if [ "$count" -gt 0 ]; then
        # 计算大小
        size=$(find "$series_path" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.bmp" \) -exec du -ch {} + 2>/dev/null | tail -1 | cut -f1)
        echo -e "  ${CYAN}$series${NC}: ${GREEN}$count${NC} 个文件 (${size})"

        # 显示前5个文件作为预览
        echo -e "    示例文件:"
        find "$series_path" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | head -5 | while read -r file; do
            echo -e "      - $(basename "$file")"
        done
        [ "$count" -gt 5 ] && echo -e "      ... 还有 $((count - 5)) 个文件"
    else
        echo -e "  ${CYAN}$series${NC}: ${YELLOW}无图片${NC}"
    fi
done

echo ""
echo -e "${YELLOW}⚠ 警告: 此操作不可恢复！${NC}"
read -p "确认删除以上图片文件? (y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}已取消${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}正在删除...${NC}"

# 执行删除
for series in "${SERIES_LIST[@]}"; do
    series_path="$LOCAL_BASE/$series"

    if [ ! -d "$series_path" ]; then
        continue
    fi

    echo -e "${CYAN}━━━ $series 系列 ━━━${NC}"

    # 查找并删除图片
    deleted=0
    while IFS= read -r -d '' file; do
        rm -f "$file"
        echo -e "  ${RED}✗${NC} 删除: $(basename "$file")"
        ((deleted++))
    done < <(find "$series_path" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.bmp" \) -print0 2>/dev/null)

    echo -e "  共删除: ${GREEN}$deleted${NC} 个文件"
    ((total_deleted += deleted))
    echo ""
done

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}清理完成!${NC}"
echo -e "  总共删除: ${GREEN}$total_deleted${NC} 个图片文件"
echo -e "  目录结构: ${CYAN}已保留${NC}"
echo ""
echo -e "你可以继续向这些文件夹添加新壁纸"
