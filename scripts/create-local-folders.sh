#!/bin/bash

# 通用脚本：根据项目目录结构在本地创建空文件夹（只含一级和二级分类）
# 用法: 
#   ./scripts/create-local-folders.sh <源目录名> <本地目标路径>
#   源目录名: wallpaper 下的任意子目录名（如 mobile, avatar, desktop 等）
#
# 示例:
#   ./scripts/create-local-folders.sh mobile /Users/xxx/Pictures/wallpaper-mobile
#   ./scripts/create-local-folders.sh avatar /Users/xxx/Pictures/wallpaper-avatar

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 项目路径
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WALLPAPER_DIR="$PROJECT_ROOT/wallpaper"

# 获取可用的源目录列表
get_available_sources() {
    local sources=""
    for dir in "$WALLPAPER_DIR"/*/; do
        [ -d "$dir" ] || continue
        name=$(basename "$dir")
        [[ "$name" == .* ]] && continue
        sources="$sources $name"
    done
    echo $sources
}

# 显示帮助
show_help() {
    echo "用法: $0 <源目录名> <本地目标路径>"
    echo ""
    echo "可用的源目录:"
    for src in $(get_available_sources); do
        echo "  $src"
    done
    echo ""
    echo "示例:"
    echo "  $0 mobile /Users/xxx/Pictures/wallpaper-mobile"
}

# 参数检查
if [ $# -lt 2 ]; then
    echo -e "${RED}错误: 参数不足${NC}"
    show_help
    exit 1
fi

SOURCE_TYPE="$1"
TARGET_PATH="$2"
SOURCE_DIR="$WALLPAPER_DIR/$SOURCE_TYPE"

# 检查源目录是否存在
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}错误: 源目录不存在 - $SOURCE_DIR${NC}"
    echo ""
    echo "可用的源目录: $(get_available_sources)"
    exit 1
fi

echo "=========================================="
echo -e "${YELLOW}正在处理: $SOURCE_TYPE${NC}"
echo "源目录: $SOURCE_DIR"
echo "目标目录: $TARGET_PATH"
echo "=========================================="

# 创建目标根目录
mkdir -p "$TARGET_PATH"
echo -e "${GREEN}✓ 创建根目录: $TARGET_PATH${NC}"

# 遍历一级分类
for level1 in "$SOURCE_DIR"/*/; do
    [ -d "$level1" ] || continue
    level1_name=$(basename "$level1")
    [[ "$level1_name" == .* ]] && continue
    
    mkdir -p "$TARGET_PATH/$level1_name"
    echo -e "${GREEN}  ✓ 一级: $level1_name${NC}"
    
    # 遍历二级分类
    for level2 in "$level1"/*/; do
        [ -d "$level2" ] || continue
        level2_name=$(basename "$level2")
        [[ "$level2_name" == .* ]] && continue
        
        mkdir -p "$TARGET_PATH/$level1_name/$level2_name"
        echo -e "${GREEN}    ✓ 二级: $level2_name${NC}"
    done
done

echo ""
echo -e "${GREEN}完成！目录结构已创建到: $TARGET_PATH${NC}"
