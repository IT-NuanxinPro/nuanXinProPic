#!/usr/bin/env bash
# ========================================
# 备份所有原图的时间戳
# ========================================
#
# 功能：保存 wallpaper/desktop 目录下所有文件的修改时间
#       以便后续恢复
#
# 用法：
#   ./scripts/backup-timestamps.sh
#
# 输出：
#   timestamps-backup.txt（时间戳备份文件）
#
# ========================================

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WALLPAPER_DIR="$PROJECT_ROOT/wallpaper/desktop"
BACKUP_FILE="$PROJECT_ROOT/timestamps-backup.txt"

echo "========================================"
echo "备份原图时间戳"
echo "========================================"
echo ""
echo "目录: $WALLPAPER_DIR"
echo "输出: $BACKUP_FILE"
echo ""

# 清空备份文件
> "$BACKUP_FILE"

count=0

# 遍历所有原图，保存时间戳
while IFS= read -r -d '' file; do
    # 获取相对路径
    relative_path="${file#$WALLPAPER_DIR/}"

    # 获取文件的修改时间（Unix 时间戳）
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        timestamp=$(stat -f "%m" "$file")
    else
        # Linux
        timestamp=$(stat -c "%Y" "$file")
    fi

    # 保存：相对路径|时间戳
    echo "${relative_path}|${timestamp}" >> "$BACKUP_FILE"

    count=$((count + 1))

    # 每处理 10 个文件显示一次进度
    if [ $((count % 10)) -eq 0 ]; then
        echo "已处理 $count 个文件..."
    fi

done < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) -print0 2>/dev/null)

echo ""
echo "========================================"
echo "备份完成!"
echo "========================================"
echo "共备份 $count 个文件的时间戳"
echo "备份文件: $BACKUP_FILE"
echo ""
echo "文件格式示例:"
head -3 "$BACKUP_FILE"
