#!/bin/bash
# ========================================
# 本地图片处理脚本（支持二级分类）
# ========================================
#
# 功能：批量处理图片，生成缩略图和预览图，自动添加水印
#
# 用法：
#   ./scripts/local-process.sh <输入文件夹> [系列] [一级分类] [二级分类]
#
# 示例：
#   ./scripts/local-process.sh ~/Pictures/new desktop 游戏 原神
#   ./scripts/local-process.sh ~/Pictures/new mobile 动漫
#   ./scripts/local-process.sh ~/Pictures/new avatar 萌系
#
# ========================================
# 注意事项
# ========================================
#
# 1. 分类说明
#    - 可以使用任意分类名称，脚本会自动创建对应目录
#    - 常用一级分类：动漫、游戏、风景、插画、人像、国风、萌系 等
#    - 二级分类可选，默认为"通用"
#
# 2. 新增分类
#    - 脚本会自动创建 wallpaper/thumbnail/preview 目录
#    - 如需在前端显示，需运行 generate-data 脚本重新生成数据
#
# 3. 输出目录结构
#    wallpaper/<系列>/<一级分类>/<二级分类>/xxx.jpg   (原图)
#    thumbnail/<系列>/<一级分类>/<二级分类>/xxx.webp  (缩略图)
#    preview/<系列>/<一级分类>/<二级分类>/xxx.webp    (预览图)
#
# ========================================
# Windows 用户使用说明
# ========================================
#
# 1. 安装 Git for Windows（包含 Git Bash）
#    下载地址: https://git-scm.com/download/win
#
# 2. 安装 Scoop 包管理器（在 PowerShell 中执行）
#    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
#    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
#
# 3. 安装 ImageMagick
#    scoop install imagemagick
#
# 4. 打开 Git Bash，进入项目目录运行脚本
#    cd /d/Projects/nuanXinProPic
#    ./scripts/local-process.sh /d/Pictures/new desktop 游戏 原神
#
# 注意：Windows 路径格式
#    - 使用 /d/xxx 代替 D:\xxx
#    - 使用 /c/Users/xxx 代替 C:\Users\xxx
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

# 配置（优化后：降低尺寸和质量以提升加载速度）
THUMBNAIL_WIDTH=350      # 从 550 → 350（降低36%尺寸）
THUMBNAIL_QUALITY=75     # 从 85 → 75（WebP格式下质量75已足够清晰）
PREVIEW_WIDTH=1920       # 保持1920宽度（桌面弹窗预览）
PREVIEW_QUALITY=78       # 从 90 → 78（降低质量，减小30%文件大小）
MOBILE_PREVIEW_WIDTH=1080  # 保持1080宽度（手机壁纸预览）
MOBILE_PREVIEW_QUALITY=75  # 从 85 → 75（降低质量）

WATERMARK_ENABLED=true
WATERMARK_TEXT="暖心"
WATERMARK_OPACITY=40
WATERMARK_POSITION="southeast"
WATERMARK_ANGLE=-25
WATERMARK_SECOND_POSITION="southwest"
WATERMARK_SECOND_ANGLE=0

PREVIEW_WATERMARK_SIZE_PERCENT=2
PREVIEW_WATERMARK_OFFSET_X=40
PREVIEW_WATERMARK_OFFSET_Y=80
THUMB_WATERMARK_SIZE_PERCENT=1.5
THUMB_WATERMARK_OFFSET_X=20
THUMB_WATERMARK_OFFSET_Y=40

# 一级分类白名单
VALID_CATEGORIES_L1=(
  "动漫" "插画" "风景" "人像" "游戏" "国风"
  "水豚噜噜" "意境" "吉伊猫" "萌系" "影视" "宠物"
  "写真" "IP形象" "搞怪"
  "美女" "明星" "汽车" "动物" "植物" "建筑" "科技" "艺术"
  "体育" "节日" "摄影" "城市" "自然" "星空" "海洋" "萌宠"
  "美食" "创意" "简约" "复古" "赛博朋克" "情侣" "闺蜜" "卡通" "文字"
  "其他"
)

# 二级分类白名单（用函数实现，兼容 bash 3.2）
get_l2_categories() {
    local cat_l1="$1"
    case "$cat_l1" in
        "游戏") echo "原神,崩坏,英雄联盟,王者荣耀,艾尔登法环,塞尔达,最终幻想,赛博朋克2077,只狼,黑神话悟空,明日方舟,碧蓝航线,少女前线,战双帕弥什,绝区零" ;;
        "动漫") echo "蜡笔小新,海绵宝宝,春物雪乃,鬼灭之刃,间谍过家家,神奇宝贝,疯狂动物城,蕾姆,罪恶王冠,紫罗兰永恒花园,百炼成神,刀剑神域,新世纪福音战士,斗破苍穹,完美世界,水豚噜噜" ;;
        "插画") echo "风景,人物,抽象,科幻,奇幻" ;;
        "吉伊猫") echo "小八,乌萨奇,小熊" ;;
        "水豚噜噜") echo "" ;;
        *) echo "" ;;
    esac
}

DEFAULT_CATEGORY_L1="其他"
DEFAULT_CATEGORY_L2="通用"

# 自动检测 ImageMagick 命令（兼容 Windows/Mac/Linux）
detect_imagemagick_cmd() {
    # Windows 上优先使用 magick（避免与系统 convert.exe 冲突）
    if command -v magick &>/dev/null; then
        echo "magick"
    elif command -v convert &>/dev/null; then
        # 检查是否是 ImageMagick 的 convert（而非 Windows 系统的）
        if convert --version 2>&1 | grep -q "ImageMagick"; then
            echo "convert"
        elif command -v magick &>/dev/null; then
            echo "magick"
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

show_help() {
    echo -e "${BLUE}本地图片处理脚本（二级分类）${NC}"
    echo ""
    echo "用法: $0 <输入文件夹> [系列] [一级分类] [二级分类]"
    echo ""
    echo "参数:"
    echo "  输入文件夹    包含待处理图片的文件夹路径"
    echo "  系列          desktop(默认), mobile, avatar"
    echo "  一级分类      如: 动漫, 游戏, 风景"
    echo "  二级分类      如: 原神, 蜡笔小新 (可选，默认 通用)"
    echo ""
    echo "示例:"
    echo "  $0 ~/Pictures/new desktop 游戏 原神"
    echo "  $0 ~/Pictures/new desktop 动漫 蜡笔小新"
    echo "  $0 ~/Pictures/new mobile 风景"
    echo ""
    echo "输出结构:"
    echo "  wallpaper/<系列>/<一级分类>/<二级分类>/xxx.jpg"
}

is_valid_category_l1() {
    local category="$1"
    for valid_cat in "${VALID_CATEGORIES_L1[@]}"; do
        [ "$category" = "$valid_cat" ] && return 0
    done
    return 1
}

is_valid_category_l2() {
    local cat_l1="$1"
    local cat_l2="$2"
    local l2_list
    l2_list=$(get_l2_categories "$cat_l1")
    [ -z "$l2_list" ] && return 1
    local OLD_IFS="$IFS"
    IFS=','
    for valid_l2 in $l2_list; do
        if [ "$cat_l2" = "$valid_l2" ]; then
            IFS="$OLD_IFS"
            return 0
        fi
    done
    IFS="$OLD_IFS"
    return 1
}

detect_chinese_font() {
    for f in "Heiti-SC-Medium" "PingFang-SC-Medium" "Noto-Sans-CJK-SC" "Microsoft-YaHei" "SimHei"; do
        $IMAGEMAGICK_CMD -list font 2>/dev/null | grep -q "$f" && echo "$f" && return
    done
}

process_image() {
    local src_file="$1"
    local series="$2"
    local cat_l1="$3"
    local cat_l2="$4"
    local font="$5"

    local filename=$(basename "$src_file")
    local name="${filename%.*}"

    # 目标路径（二级分类结构）
    local wallpaper_dir="$PROJECT_ROOT/wallpaper/$series/$cat_l1/$cat_l2"
    local thumbnail_dir="$PROJECT_ROOT/thumbnail/$series/$cat_l1/$cat_l2"
    local preview_dir="$PROJECT_ROOT/preview/$series/$cat_l1/$cat_l2"

    mkdir -p "$wallpaper_dir" "$thumbnail_dir"
    [ "$series" != "avatar" ] && mkdir -p "$preview_dir"

    # 复制原图
    local dest_wallpaper="$wallpaper_dir/$filename"
    if [ ! -f "$dest_wallpaper" ]; then
        cp "$src_file" "$dest_wallpaper"
        echo -e "  ${GREEN}✓${NC} 原图: $cat_l1/$cat_l2/$filename"
    else
        echo -e "  ${YELLOW}→${NC} 已存在: $cat_l1/$cat_l2/$filename"
    fi

    # 生成缩略图
    local dest_thumbnail="$thumbnail_dir/${name}.webp"
    if [ ! -f "$dest_thumbnail" ]; then
        local thumb_size=$(echo "scale=0; $THUMBNAIL_WIDTH * $THUMB_WATERMARK_SIZE_PERCENT / 100" | bc)
        if [ "$WATERMARK_ENABLED" = true ] && [ -n "$font" ]; then
            $IMAGEMAGICK_CMD "$src_file" -resize "${THUMBNAIL_WIDTH}x>" -quality "$THUMBNAIL_QUALITY" \
                -gravity "$WATERMARK_POSITION" -font "$font" -pointsize "$thumb_size" \
                -fill "rgba(255,255,255,${WATERMARK_OPACITY}%)" \
                -annotate ${WATERMARK_ANGLE}x${WATERMARK_ANGLE}+${THUMB_WATERMARK_OFFSET_X}+40 "$WATERMARK_TEXT" \
                -gravity "$WATERMARK_SECOND_POSITION" \
                -annotate 0x0+20+40 "$WATERMARK_TEXT" \
                "$dest_thumbnail" 2>/dev/null
        else
            $IMAGEMAGICK_CMD "$src_file" -resize "${THUMBNAIL_WIDTH}x>" -quality "$THUMBNAIL_QUALITY" "$dest_thumbnail" 2>/dev/null
        fi
        echo -e "  ${GREEN}✓${NC} 缩略图"
    fi

    # 生成预览图（desktop 和 mobile 预览图都不加水印）
    if [ "$series" != "avatar" ]; then
        local preview_width=$PREVIEW_WIDTH
        [ "$series" = "mobile" ] && preview_width=$MOBILE_PREVIEW_WIDTH

        local dest_preview="$preview_dir/${name}.webp"
        if [ ! -f "$dest_preview" ]; then
            # 预览图不加水印，直接生成
            $IMAGEMAGICK_CMD "$src_file" -resize "${preview_width}x>" -quality "$PREVIEW_QUALITY" "$dest_preview" 2>/dev/null
            echo -e "  ${GREEN}✓${NC} 预览图"
        fi
    fi
}

main() {
    [ $# -lt 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ] && { show_help; exit 0; }

    local input_dir="$1"
    local series="${2:-desktop}"
    local cat_l1="${3:-$DEFAULT_CATEGORY_L1}"
    local cat_l2="${4:-$DEFAULT_CATEGORY_L2}"

    [ ! -d "$input_dir" ] && { echo -e "${RED}目录不存在: $input_dir${NC}"; exit 1; }
    [[ ! "$series" =~ ^(desktop|mobile|avatar)$ ]] && { echo -e "${RED}无效系列: $series${NC}"; exit 1; }
    
    if ! is_valid_category_l1 "$cat_l1"; then
        echo -e "${YELLOW}提示: '$cat_l1' 是新的一级分类，将自动创建目录${NC}"
    fi

    if [ "$cat_l2" != "$DEFAULT_CATEGORY_L2" ] && ! is_valid_category_l2 "$cat_l1" "$cat_l2"; then
        echo -e "${YELLOW}提示: '$cat_l2' 是新的二级分类，将自动创建目录${NC}"
    fi

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}本地图片处理（二级分类）${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "输入: ${GREEN}$input_dir${NC}"
    echo -e "系列: ${GREEN}$series${NC}"
    echo -e "分类: ${CYAN}$cat_l1 / $cat_l2${NC}"
    echo ""

    local font=""
    [ "$WATERMARK_ENABLED" = true ] && font=$(detect_chinese_font)

    local image_files=()
    while IFS= read -r -d '' file; do
        image_files+=("$file")
    done < <(find "$input_dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -print0 | sort -z)

    [ ${#image_files[@]} -eq 0 ] && { echo -e "${YELLOW}未找到图片${NC}"; exit 0; }

    echo -e "找到 ${GREEN}${#image_files[@]}${NC} 张图片"
    echo ""

    local count=0
    for file in "${image_files[@]}"; do
        count=$((count + 1))
        echo -e "${BLUE}[$count/${#image_files[@]}]${NC} $(basename "$file")"
        process_image "$file" "$series" "$cat_l1" "$cat_l2" "$font"
        echo ""
    done

    echo -e "${GREEN}处理完成!${NC}"
    echo "输出: wallpaper/$series/$cat_l1/$cat_l2/"
}

main "$@"
