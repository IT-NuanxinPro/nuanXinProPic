#!/usr/bin/env bash
# ========================================
# 自动备份所有系列的文件时间戳
# ========================================
#
# 功能：扫描 wallpaper 目录下所有图片文件，备份其修改时间
#       支持 desktop、mobile、avatar 三个系列
#
# 用法：
#   ./scripts/backup-timestamps.sh
#
# 输出：
#   timestamps-backup-all.txt (格式: series|relative_path|timestamp|first_tag)
#   - first_tag: 文件首次上传时的 Git tag (用于 CDN 缓存优化)
#
# ========================================

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WALLPAPER_DIR="$PROJECT_ROOT/wallpaper"
BACKUP_FILE="$PROJECT_ROOT/timestamps-backup-all.txt"
OLD_BACKUP_FILE="$PROJECT_ROOT/timestamps-backup-all.txt.old"

echo "========================================"
echo "备份文件时间戳"
echo "========================================"
echo ""

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

# 临时文件(避免写入一半时出错)
TEMP_FILE="$BACKUP_FILE.tmp"
> "$TEMP_FILE"

count=0
series_count_desktop=0
series_count_mobile=0
series_count_avatar=0

# 遍历三个系列
for series in desktop mobile avatar; do
    series_dir="$WALLPAPER_DIR/$series"

    if [ ! -d "$series_dir" ]; then
        echo "⚠️  系列目录不存在，跳过: $series"
        echo ""
        continue
    fi

    echo "📸 处理系列: $series"

    # 查找所有图片文件并排序(保证顺序稳定)
    series_files=0
    while IFS= read -r file_path; do
        # 获取相对路径
        relative_path="${file_path#$series_dir/}"

        # 获取时间戳
        if [[ "$OSTYPE" == "darwin"* ]]; then
            timestamp=$(stat -f "%m" "$file_path")
        else
            timestamp=$(stat -c "%Y" "$file_path")
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
        esac

    done < <(find "$series_dir" -type f \( \
        -iname "*.jpg" -o \
        -iname "*.jpeg" -o \
        -iname "*.png" -o \
        -iname "*.gif" -o \
        -iname "*.webp" \
    \) | sort)

    echo "   找到 $series_files 个文件"
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
echo "总计:    $count 个文件"
echo ""
echo "备份文件: $BACKUP_FILE"
echo ""
