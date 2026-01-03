#!/usr/bin/env bash
# ========================================
# 恢复原图的时间戳
# ========================================
#
# 功能：从备份文件恢复文件的修改时间
#       前端项目 GitHub Actions 依赖此脚本
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
                    failed=$((failed + 1))
                fi
            else
                # Linux: touch -d
                if touch -d "@$timestamp" "$file_path" 2>/dev/null; then
                    success=$((success + 1))
                else
                    failed=$((failed + 1))
                fi
            fi
        fi

        # 每处理 100 个文件显示一次进度
        if [ $((count % 100)) -eq 0 ]; then
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
                if touch -t "$(date -r "$timestamp" "+%Y%m%d%H%M.%S")" "$file_path" 2>/dev/null; then
                    success=$((success + 1))
                else
                    failed=$((failed + 1))
                fi
            else
                if touch -d "@$timestamp" "$file_path" 2>/dev/null; then
                    success=$((success + 1))
                else
                    failed=$((failed + 1))
                fi
            fi
        fi

        # 每处理 100 个文件显示一次进度
        if [ $((count % 100)) -eq 0 ]; then
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
fi

# ========================================
# 方案 C: 智能回退 - 检测未备份的新文件
# ========================================

if [ "$DRY_RUN" = false ]; then
    echo ""
    echo "========================================"
    echo "🔍 验证备份完整性..."
    echo "========================================"
    echo ""

    missing_count=0
    missing_files=()

    # 检查所有现存文件是否都在备份中
    for series in desktop mobile avatar; do
        series_dir="$WALLPAPER_DIR/$series"

        if [ ! -d "$series_dir" ]; then
            continue
        fi

        # 查找所有图片文件
        while IFS= read -r file_path; do
            relative_path="${file_path#$series_dir/}"

            # 检查是否在备份文件中
            if ! grep -q "^$series|$relative_path|" "$BACKUP_FILE" 2>/dev/null; then
                missing_count=$((missing_count + 1))
                missing_files+=("$series/$relative_path")

                echo "⚠️  未在备份中找到: $series/$relative_path"

                # 尝试从 Git 历史恢复真实时间
                commit_date=$(git log -1 --format="%at" -- "$file_path" 2>/dev/null || echo "")

                if [ -n "$commit_date" ]; then
                    # 恢复时间戳
                    if [[ "$OSTYPE" == "darwin"* ]]; then
                        touch -t "$(date -r "$commit_date" "+%Y%m%d%H%M.%S")" "$file_path" 2>/dev/null && \
                            echo "   ✅ 已从 Git 历史恢复时间戳"
                    else
                        touch -d "@$commit_date" "$file_path" 2>/dev/null && \
                            echo "   ✅ 已从 Git 历史恢复时间戳"
                    fi
                else
                    echo "   ❌ Git 历史中未找到此文件，将使用当前时间"
                fi
            fi

        done < <(find "$series_dir" -type f \( \
            -iname "*.jpg" -o \
            -iname "*.jpeg" -o \
            -iname "*.png" -o \
            -iname "*.gif" -o \
            -iname "*.webp" \
        \))
    done

    echo ""

    if [ $missing_count -gt 0 ]; then
        echo "════════════════════════════════════════"
        echo "❌ 警告: 发现 $missing_count 个未备份的文件!"
        echo "════════════════════════════════════════"
        echo ""
        echo "这可能导致部分文件的时间戳不准确。"
        echo ""
        echo "建议操作："
        echo "1. 在图床仓库中运行: scripts/backup-timestamps.sh"
        echo "2. 提交更新后的 timestamps-backup-all.txt"
        echo "3. 确保 Git pre-commit hook 已正确安装"
        echo ""
        echo "未备份的文件列表："
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        echo ""

        # 在 CI 环境中，如果发现未备份文件则失败
        if [ -n "$CI" ]; then
            echo "⛔ CI 环境检测到未备份文件，构建失败!"
            echo "   请在图床仓库更新时间戳备份后重新触发构建"
            exit 1
        else
            echo "⚠️  本地环境警告: 已尝试从 Git 历史恢复时间戳"
            echo "   建议尽快运行备份脚本以避免将来的问题"
        fi
    else
        echo "✅ 所有文件都已在备份中，备份完整性验证通过!"
    fi

    echo ""
fi
