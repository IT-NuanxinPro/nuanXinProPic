#!/bin/bash
# ========================================
# 批量扫描处理脚本
# ========================================
#
# 功能：扫描本地文件夹，自动识别一级/二级分类，批量处理所有图片
#       内部调用 local-process.sh 处理每个子目录
#
# 用法：
#   ./scripts/batch-process.sh <本地壁纸根目录> [系列]
#
# 参数：
#   本地壁纸根目录  包含 一级分类/二级分类 结构的目录
#   系列            desktop(默认) | mobile | avatar
#
# 示例：
#   ./scripts/batch-process.sh /Users/xxx/Pictures/wallpaper desktop
#   ./scripts/batch-process.sh /Users/xxx/Pictures/mobile-pics mobile
#
# 目录结构要求：
#   <根目录>/
#     ├── 动漫/           # 一级分类
#     │   ├── 原神/       # 二级分类（含图片）
#     │   └── 海贼王/
#     └── 风景/
#         └── 雪山/
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
LOCAL_PROCESS_SCRIPT="$PROJECT_ROOT/scripts/local-process.sh"

show_help() {
    echo -e "${BLUE}批量扫描处理脚本${NC}"
    echo ""
    echo "用法: $0 <本地壁纸根目录> [系列]"
    echo ""
    echo "参数:"
    echo "  本地壁纸根目录    包含一级/二级分类目录的根路径"
    echo "  系列              desktop(默认), mobile, avatar"
    echo ""
    echo "示例:"
    echo "  $0 /Users/nuanxinpro/Pictures/wallpaper desktop"
    echo ""
    echo "目录结构要求:"
    echo "  <根目录>/"
    echo "    ├── 一级分类1/"
    echo "    │   ├── 二级分类1/"
    echo "    │   │   └── *.jpg/png/webp"
    echo "    │   └── 二级分类2/"
    echo "    └── 一级分类2/"
    echo "        └── 二级分类/"
}

# 检查目录是否有图片
has_images() {
    local dir="$1"
    local count=$(find "$dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | wc -l)
    [ "$count" -gt 0 ]
}

# 统计目录中的图片数量
count_images() {
    local dir="$1"
    find "$dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | wc -l | tr -d ' '
}

main() {
    [ $# -lt 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ] && { show_help; exit 0; }

    local input_root="$1"
    local series="${2:-desktop}"

    [ ! -d "$input_root" ] && { echo -e "${RED}目录不存在: $input_root${NC}"; exit 1; }
    [ ! -f "$LOCAL_PROCESS_SCRIPT" ] && { echo -e "${RED}找不到处理脚本: $LOCAL_PROCESS_SCRIPT${NC}"; exit 1; }
    [[ ! "$series" =~ ^(desktop|mobile|avatar)$ ]] && { echo -e "${RED}无效系列: $series${NC}"; exit 1; }

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}批量扫描处理${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "扫描目录: ${GREEN}$input_root${NC}"
    echo -e "系列: ${GREEN}$series${NC}"
    echo ""

    # 收集所有需要处理的目录
    local tasks=()
    local total_images=0

    echo -e "${CYAN}扫描目录结构...${NC}"
    echo ""

    # 遍历一级分类
    for cat_l1_dir in "$input_root"/*/; do
        [ ! -d "$cat_l1_dir" ] && continue
        local cat_l1=$(basename "$cat_l1_dir")
        
        # 跳过隐藏目录
        [[ "$cat_l1" == .* ]] && continue

        # 遍历二级分类
        for cat_l2_dir in "$cat_l1_dir"/*/; do
            [ ! -d "$cat_l2_dir" ] && continue
            local cat_l2=$(basename "$cat_l2_dir")
            
            # 跳过隐藏目录
            [[ "$cat_l2" == .* ]] && continue

            # 检查是否有图片
            if has_images "$cat_l2_dir"; then
                local img_count=$(count_images "$cat_l2_dir")
                tasks+=("$cat_l2_dir|$cat_l1|$cat_l2|$img_count")
                total_images=$((total_images + img_count))
                echo -e "  ${GREEN}✓${NC} $cat_l1/$cat_l2 (${img_count}张)"
            fi
        done
    done

    echo ""
    echo -e "共发现 ${GREEN}${#tasks[@]}${NC} 个目录，${GREEN}${total_images}${NC} 张图片"
    echo ""

    if [ ${#tasks[@]} -eq 0 ]; then
        echo -e "${YELLOW}没有找到需要处理的图片${NC}"
        exit 0
    fi

    # 确认执行
    echo -e "${YELLOW}是否开始处理? (y/n)${NC}"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "已取消"
        exit 0
    fi

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}开始批量处理${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    local task_num=0
    local success_count=0
    local fail_count=0

    for task in "${tasks[@]}"; do
        task_num=$((task_num + 1))
        
        # 解析任务信息
        IFS='|' read -r dir cat_l1 cat_l2 img_count <<< "$task"
        
        echo -e "${BLUE}[$task_num/${#tasks[@]}]${NC} 处理 ${CYAN}$cat_l1/$cat_l2${NC} (${img_count}张)"
        echo ""

        # 调用 local-process.sh
        if "$LOCAL_PROCESS_SCRIPT" "$dir" "$series" "$cat_l1" "$cat_l2"; then
            success_count=$((success_count + 1))
            echo -e "${GREEN}✓ 完成${NC}"
        else
            fail_count=$((fail_count + 1))
            echo -e "${RED}✗ 失败${NC}"
        fi
        
        echo ""
        echo -e "${BLUE}----------------------------------------${NC}"
        echo ""
    done

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}处理完成${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "成功: ${GREEN}${success_count}${NC}"
    echo -e "失败: ${RED}${fail_count}${NC}"
    echo ""
}

main "$@"
