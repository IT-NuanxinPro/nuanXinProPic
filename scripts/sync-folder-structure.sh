#!/bin/bash
# ========================================
# 同步文件夹结构到本地（不含图片）
# ========================================
#
# 功能：将图床的分类目录结构同步到本地文件夹
#       仅创建文件夹，不复制图片
#
# 用法：
#   ./scripts/sync-folder-structure.sh <本地基础路径>
#
# 示例：
#   ./scripts/sync-folder-structure.sh ~/Pictures/wallpaper-input
#   ./scripts/sync-folder-structure.sh /Users/xxx/Downloads/壁纸素材
#
# 执行后会在目标路径下创建：
#   <基础路径>/desktop/<一级分类>/<二级分类>/
#   <基础路径>/mobile/<一级分类>/<二级分类>/
#   <基础路径>/avatar/<一级分类>/<二级分类>/
#
# ========================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 获取脚本所在目录的上级目录（项目根目录）
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

show_help() {
    echo -e "${BLUE}同步文件夹结构脚本${NC}"
    echo ""
    echo "用法: $0 <本地基础路径>"
    echo ""
    echo "示例:"
    echo "  $0 ~/Pictures/wallpaper-input"
    echo "  $0 /Users/xxx/Downloads/壁纸素材"
    echo ""
    echo "执行后会在目标路径下创建:"
    echo "  <基础路径>/desktop/<一级分类>/<二级分类>/"
    echo "  <基础路径>/mobile/<一级分类>/<二级分类>/"
    echo "  <基础路径>/avatar/<一级分类>/<二级分类>/"
}

# 检查参数
if [ $# -lt 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

# 展开 ~ 路径
LOCAL_BASE="${1/#\~/$HOME}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}同步文件夹结构${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "源目录: ${GREEN}$PROJECT_ROOT/wallpaper${NC}"
echo -e "目标目录: ${GREEN}$LOCAL_BASE${NC}"
echo ""

# 统计
total_created=0
total_existed=0

# 遍历三个系列
for series in desktop mobile avatar; do
    echo -e "${CYAN}━━━ $series 系列 ━━━${NC}"

    series_source="$PROJECT_ROOT/wallpaper/$series"
    series_target="$LOCAL_BASE/$series"

    # 检查源目录是否存在
    if [ ! -d "$series_source" ]; then
        echo -e "  ${YELLOW}⚠ 源目录不存在: $series_source${NC}"
        continue
    fi

    # 创建系列根目录
    mkdir -p "$series_target"

    # 遍历一级分类
    for cat_l1_path in "$series_source"/*/; do
        [ ! -d "$cat_l1_path" ] && continue

        cat_l1=$(basename "$cat_l1_path")

        # 遍历二级分类
        for cat_l2_path in "$cat_l1_path"*/; do
            [ ! -d "$cat_l2_path" ] && continue

            cat_l2=$(basename "$cat_l2_path")
            target_dir="$series_target/$cat_l1/$cat_l2"

            if [ -d "$target_dir" ]; then
                echo -e "  ${YELLOW}→${NC} 已存在: $cat_l1/$cat_l2"
                ((total_existed++))
            else
                mkdir -p "$target_dir"
                echo -e "  ${GREEN}✓${NC} 创建: $cat_l1/$cat_l2"
                ((total_created++))
            fi
        done
    done

    echo ""
done

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}同步完成!${NC}"
echo -e "  新建文件夹: ${GREEN}$total_created${NC}"
echo -e "  已存在: ${YELLOW}$total_existed${NC}"
echo ""
echo -e "本地目录结构已就绪: ${CYAN}$LOCAL_BASE${NC}"
echo -e "你可以将新壁纸放入对应分类文件夹，然后使用 local-process.sh 处理"
