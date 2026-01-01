#!/usr/bin/env bash
# ========================================
# 备份所有系列的时间戳（desktop + mobile + avatar）
# ========================================

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_FILE="$PROJECT_ROOT/timestamps-backup-all.txt"

echo "========================================"
echo "备份所有壁纸时间戳"
echo "========================================"
echo ""

# 清空备份文件
> "$BACKUP_FILE"

total_count=0

# 处理三个系列
for series in desktop mobile avatar; do
    WALLPAPER_DIR="$PROJECT_ROOT/wallpaper/$series"

    if [ ! -d "$WALLPAPER_DIR" ]; then
        echo "⚠️  目录不存在: $WALLPAPER_DIR"
        continue
    fi

    echo "处理: $series"
    count=0

    while IFS= read -r -d '' file; do
        # 获取相对路径
        relative_path="${file#$WALLPAPER_DIR/}"

        # 获取文件的修改时间（Unix 时间戳）
        if [[ "$OSTYPE" == "darwin"* ]]; then
            timestamp=$(stat -f "%m" "$file")
        else
            timestamp=$(stat -c "%Y" "$file")
        fi

        # 保存：系列|相对路径|时间戳
        echo "${series}|${relative_path}|${timestamp}" >> "$BACKUP_FILE"

        count=$((count + 1))
        total_count=$((total_count + 1))
    done < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) -print0 2>/dev/null)

    echo "  ✅ $series: $count 个文件"
done

echo ""
echo "========================================"
echo "备份完成!"
echo "========================================"
echo "共备份 $total_count 个文件的时间戳"
echo "备份文件: $BACKUP_FILE"
echo ""
echo "文件格式示例:"
head -3 "$BACKUP_FILE"
