#!/usr/bin/env bash
# ========================================
# 自动备份所有系列的文件时间戳
# ========================================
#
# 功能：扫描 wallpaper 目录下所有图片文件，备份其修改时间
#       支持 desktop、mobile、avatar 三个系列
#
# 用法：
#   ./scripts/backup-timestamps.sh          # 默认：使用文件修改时间
#   ./scripts/backup-timestamps.sh --now    # 新文件使用当前时间
#
# 参数：
#   --now    新文件（不在备份记录中的）使用当前时间，而非文件修改时间
#            适用于：收藏的图片上传时，想用上传时间而非原始时间
#
# 输出：
#   timestamps-backup-all.txt (格式: series|relative_path|timestamp|first_tag)
#   - first_tag: 文件首次上传时的 Git tag (用于 CDN 缓存优化)
#
# ========================================

set -e

# 解析参数
USE_NOW_FOR_NEW=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --now)
            USE_NOW_FOR_NEW=true
            shift
            ;;
        -h|--help)
            echo "用法: $0 [--now]"
            echo ""
            echo "参数:"
            echo "  --now    新文件使用当前时间（而非文件修改时间）"
            echo ""
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            echo "使用 -h 或 --help 查看帮助"
            exit 1
            ;;
    esac
done

# 当前时间戳（用于 --now 模式）
CURRENT_TIMESTAMP=$(date +%s)

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WALLPAPER_DIR="$PROJECT_ROOT/wallpaper"
BACKUP_FILE="$PROJECT_ROOT/timestamps-backup-all.txt"
OLD_BACKUP_FILE="$PROJECT_ROOT/timestamps-backup-all.txt.old"

echo "========================================"
echo "备份文件时间戳"
echo "========================================"
echo ""

if [ "$USE_NOW_FOR_NEW" = true ]; then
    echo "🕐 模式: 新文件使用当前时间"
    echo ""
fi

# 获取当前最新 tag
CURRENT_TAG=$(git tag -l 'v*' --sort=-version:refname | head -1 2>/dev/null || echo "v1.0.0")
echo "📦 当前 tag: $CURRENT_TAG"
echo ""

# 保存旧备份文件用于查找已有的 first_tag
existing_tags_count=0
if [ -f "$BACKUP_FILE" ]; then
    echo "📂 读取现有备份文件..."
    cp "$BACKUP_FILE" "$OLD_BACKUP_FILE"
    existing_tags_count=$(wc -l < "$OLD_BACKUP_FILE" | tr -d ' ')
    echo "   找到 $existing_tags_count 个已记录的文件"
    echo ""
fi

# 从旧备份中查找 first_tag 的函数
get_existing_tag() {
    local series="$1"
    local path="$2"
    if [ -f "$OLD_BACKUP_FILE" ]; then
        grep "^$series|$path|" "$OLD_BACKUP_FILE" 2>/dev/null | cut -d'|' -f4 | head -1
    fi
}

# 从旧备份中查找时间戳的函数
get_existing_timestamp() {
    local series="$1"
    local path="$2"
    if [ -f "$OLD_BACKUP_FILE" ]; then
        grep "^$series|$path|" "$OLD_BACKUP_FILE" 2>/dev/null | cut -d'|' -f3 | head -1
    fi
}

# 检查文件是否是新文件（不在旧备份中）
is_new_file() {
    local series="$1"
    local path="$2"
    if [ -f "$OLD_BACKUP_FILE" ]; then
        if grep -q "^$series|$path|" "$OLD_BACKUP_FILE" 2>/dev/null; then
            return 1  # 不是新文件
        fi
    fi
    return 0  # 是新文件
}

# 临时文件(避免写入一半时出错)
TEMP_FILE="$BACKUP_FILE.tmp"
> "$TEMP_FILE"

count=0
series_count_desktop=0
series_count_mobile=0
series_count_avatar=0
series_count_video=0

# 遍历四个系列 (desktop/mobile/avatar/video)
for series in desktop mobile avatar video; do
    series_dir="$WALLPAPER_DIR/$series"

    if [ ! -d "$series_dir" ]; then
        echo "⚠️  系列目录不存在，跳过: $series"
        echo ""
        continue
    fi

    echo "📸 处理系列: $series"

    # 查找所有图片文件并排序(保证顺序稳定)
    series_files=0
    new_files=0
    while IFS= read -r file_path; do
        # 获取相对路径
        relative_path="${file_path#$series_dir/}"

        # 判断是否是新文件
        if is_new_file "$series" "$relative_path"; then
            is_new=true
            new_files=$((new_files + 1))
        else
            is_new=false
        fi

        # 获取时间戳
        if [ "$is_new" = true ] && [ "$USE_NOW_FOR_NEW" = true ]; then
            # 新文件 + --now 模式：使用当前时间
            timestamp="$CURRENT_TIMESTAMP"
        else
            # 已有文件：使用文件修改时间
            if [[ "$OSTYPE" == "darwin"* ]]; then
                timestamp=$(stat -f "%m" "$file_path")
            else
                timestamp=$(stat -c "%Y" "$file_path")
            fi
        fi

        # 获取或设置 first_tag
        existing_tag=$(get_existing_tag "$series" "$relative_path")
        if [ -n "$existing_tag" ]; then
            # 使用已记录的 first_tag
            first_tag="$existing_tag"
        else
            # 新文件,使用当前 tag
            first_tag="$CURRENT_TAG"
        fi

        # 写入临时文件 (格式: series|relative_path|timestamp|first_tag)
        echo "$series|$relative_path|$timestamp|$first_tag" >> "$TEMP_FILE"

        count=$((count + 1))
        series_files=$((series_files + 1))

        # 根据系列更新计数
        case $series in
            desktop) series_count_desktop=$((series_count_desktop + 1)) ;;
            mobile) series_count_mobile=$((series_count_mobile + 1)) ;;
            avatar) series_count_avatar=$((series_count_avatar + 1)) ;;
            video) series_count_video=$((series_count_video + 1)) ;;
        esac

    done < <(find "$series_dir" -type f \( \
        -iname "*.jpg" -o \
        -iname "*.jpeg" -o \
        -iname "*.png" -o \
        -iname "*.gif" -o \
        -iname "*.webp" -o \
        -iname "*.mp4" -o \
        -iname "*.webm" -o \
        -iname "*.mov" -o \
        -iname "*.m4v" \
    \) | sort)

    echo "   找到 $series_files 个文件"
    if [ "$USE_NOW_FOR_NEW" = true ] && [ $new_files -gt 0 ]; then
        echo "   其中 $new_files 个新文件使用当前时间"
    fi
    echo ""
done

# 原子替换(避免写入失败导致备份文件损坏)
if [ $count -eq 0 ]; then
    echo "⚠️  警告: 未找到任何图片文件!"
    rm -f "$TEMP_FILE"
    exit 1
fi

mv "$TEMP_FILE" "$BACKUP_FILE"

# 清理临时文件
rm -f "$OLD_BACKUP_FILE"

echo "========================================"
echo "✅ 备份完成!"
echo "========================================"
echo "Desktop: $series_count_desktop 个文件"
echo "Mobile:  $series_count_mobile 个文件"
echo "Avatar:  $series_count_avatar 个文件"
echo "Video:   $series_count_video 个文件"
echo "总计:    $count 个文件"
echo ""
echo "备份文件: $BACKUP_FILE"
echo ""