#!/usr/bin/env bash
# ========================================
# 恢复原图的时间戳
# ========================================
#
# 功能：从备份文件恢复文件的修改时间
#
# 用法：
#   ./scripts/restore-timestamps.sh [--dry-run]
#   BACKUP_FILE=timestamps-backup-all.txt ./scripts/restore-timestamps.sh
#
# 参数：
#   --dry-run  仅显示将要恢复的文件，不实际执行
#
# 环境变量：
#   BACKUP_FILE  指定备份文件路径（默认: timestamps-backup.txt）
#
# ========================================

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WALLPAPER_DIR="$PROJECT_ROOT/wallpaper"

# 使用环境变量指定的备份文件，或默认值
BACKUP_FILE="${BACKUP_FILE:-$PROJECT_ROOT/timestamps-backup.txt}"

DRY_RUN=false
if [ "$1" = "--dry-run" ]; then
    DRY_RUN=true
    echo "[DRY-RUN 模式] 仅显示将要执行的操作"
    echo ""
fi

echo "========================================"
echo "恢复原图时间戳"
echo "========================================"
echo ""

if [ ! -f "$BACKUP_FILE" ]; then
    echo "错误: 备份文件不存在: $BACKUP_FILE"
    exit 1
fi

total_lines=$(wc -l < "$BACKUP_FILE" | tr -d ' ')
echo "备份文件: $BACKUP_FILE"
echo "共 $total_lines 个文件需要恢复"
echo ""

count=0
success=0
failed=0
not_found=0

# 检测备份文件格式（是否包含 series 字段）
first_line=$(head -1 "$BACKUP_FILE")
field_count=$(echo "$first_line" | awk -F'|' '{print NF}')

if [ "$field_count" -eq 3 ]; then
    # 新格式: series|relative_path|timestamp
    echo "检测到新格式备份文件（包含系列信息）"
    echo ""

    while IFS='|' read -r series relative_path timestamp; do
        count=$((count + 1))

        file_path="$WALLPAPER_DIR/$series/$relative_path"

        # 检查文件是否存在
        if [ ! -f "$file_path" ]; then
            not_found=$((not_found + 1))
            echo "[跳过] 文件不存在: $series/$relative_path"
            continue
        fi

        if [ "$DRY_RUN" = true ]; then
            # 转换时间戳为可读格式
            if [[ "$OSTYPE" == "darwin"* ]]; then
                readable_time=$(date -r "$timestamp" "+%Y-%m-%d %H:%M:%S")
            else
                readable_time=$(date -d "@$timestamp" "+%Y-%m-%d %H:%M:%S")
            fi
            echo "[DRY-RUN] $series/$relative_path -> $readable_time"
            success=$((success + 1))
        else
            # 恢复时间戳
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS: touch -t [[CC]YY]MMDDhhmm[.SS]
                if touch -t "$(date -r "$timestamp" "+%Y%m%d%H%M.%S")" "$file_path" 2>/dev/null; then
                    success=$((success + 1))
                else
                    echo "[失败] $series/$relative_path"
                    failed=$((failed + 1))
                fi
            else
                # Linux: touch -d
                if touch -d "@$timestamp" "$file_path" 2>/dev/null; then
                    success=$((success + 1))
                else
                    echo "[失败] $series/$relative_path"
                    failed=$((failed + 1))
                fi
            fi
        fi

        # 每处理 20 个文件显示一次进度
        if [ $((count % 20)) -eq 0 ]; then
            echo "进度: $count/$total_lines"
        fi

    done < "$BACKUP_FILE"
else
    # 旧格式: relative_path|timestamp（仅 desktop）
    echo "检测到旧格式备份文件（仅 desktop 系列）"
    echo ""

    DESKTOP_DIR="$WALLPAPER_DIR/desktop"

    while IFS='|' read -r relative_path timestamp; do
        count=$((count + 1))

        file_path="$DESKTOP_DIR/$relative_path"

        # 检查文件是否存在
        if [ ! -f "$file_path" ]; then
            not_found=$((not_found + 1))
            echo "[跳过] 文件不存在: $relative_path"
            continue
        fi

        if [ "$DRY_RUN" = true ]; then
            # 转换时间戳为可读格式
            if [[ "$OSTYPE" == "darwin"* ]]; then
                readable_time=$(date -r "$timestamp" "+%Y-%m-%d %H:%M:%S")
            else
                readable_time=$(date -d "@$timestamp" "+%Y-%m-%d %H:%M:%S")
            fi
            echo "[DRY-RUN] $relative_path -> $readable_time"
            success=$((success + 1))
        else
            # 恢复时间戳
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS: touch -t [[CC]YY]MMDDhhmm[.SS]
                if touch -t "$(date -r "$timestamp" "+%Y%m%d%H%M.%S")" "$file_path" 2>/dev/null; then
                    success=$((success + 1))
                else
                    echo "[失败] $relative_path"
                    failed=$((failed + 1))
                fi
            else
                # Linux: touch -d
                if touch -d "@$timestamp" "$file_path" 2>/dev/null; then
                    success=$((success + 1))
                else
                    echo "[失败] $relative_path"
                    failed=$((failed + 1))
                fi
            fi
        fi

        # 每处理 10 个文件显示一次进度
        if [ $((count % 10)) -eq 0 ]; then
            echo "进度: $count/$total_lines"
        fi

    done < "$BACKUP_FILE"
fi

echo ""
echo "========================================"
echo "处理完成!"
echo "========================================"
echo "总计: $total_lines"
echo "成功: $success"
if [ $failed -gt 0 ]; then
    echo "失败: $failed"
fi
if [ $not_found -gt 0 ]; then
    echo "文件不存在: $not_found"
fi

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "这是 DRY-RUN 模式，未实际执行任何操作"
    echo "确认无误后，运行:"
    echo "  ./scripts/restore-timestamps.sh"
else
    echo ""
    echo "时间戳已恢复!"
fi
