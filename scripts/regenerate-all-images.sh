#!/usr/bin/env bash
# ========================================
# 重新生成所有缩略图和预览图
# ========================================
#
# 功能：删除现有缩略图和预览图，根据原图重新生成
#       使用新的优化参数（更小的尺寸和质量）
#
# 用法：
#   ./scripts/regenerate-all-images.sh [--dry-run]
#
# 参数：
#   --dry-run  仅显示将要执行的操作，不实际删除和生成
#
# ========================================

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# 配置参数（直接定义，不从其他脚本读取）
THUMBNAIL_WIDTH=350
THUMBNAIL_QUALITY=75
PREVIEW_WIDTH=1920
PREVIEW_QUALITY=78
MOBILE_PREVIEW_WIDTH=1080
MOBILE_PREVIEW_QUALITY=75

DRY_RUN=false
AUTO_YES=false

# 解析参数
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        --yes|-y)
            AUTO_YES=true
            ;;
    esac
done

if [ "$DRY_RUN" = true ]; then
    echo "========================================"
    echo "[DRY-RUN 模式] 仅显示将要执行的操作"
    echo "========================================"
    echo ""
fi

echo "========================================"
echo "重新生成所有缩略图和预览图"
echo "========================================"
echo ""
echo "配置参数："
echo "  缩略图: ${THUMBNAIL_WIDTH}px @ ${THUMBNAIL_QUALITY}%"
echo "  桌面预览图: ${PREVIEW_WIDTH}px @ ${PREVIEW_QUALITY}%"
echo "  手机预览图: ${MOBILE_PREVIEW_WIDTH}px @ ${MOBILE_PREVIEW_QUALITY}%"
echo ""

# 统计现有文件
thumb_count=$(find thumbnail -type f \( -name "*.webp" -o -name "*.jpg" \) 2>/dev/null | wc -l | tr -d ' ')
preview_count=$(find preview -type f \( -name "*.webp" -o -name "*.jpg" \) 2>/dev/null | wc -l | tr -d ' ')

echo "现有文件统计："
echo "  缩略图: $thumb_count 个"
echo "  预览图: $preview_count 个"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] 将删除 thumbnail/ 目录下的所有图片"
    echo "[DRY-RUN] 将删除 preview/ 目录下的所有图片"
    echo ""
    echo "[DRY-RUN] 然后重新生成所有缩略图和预览图"
    echo ""
    echo "确认无误后，运行（不带 --dry-run）："
    echo "  ./scripts/regenerate-all-images.sh"
    exit 0
fi

# 确认操作
if [ "$AUTO_YES" = false ]; then
    echo "⚠️  警告：此操作将删除所有现有缩略图和预览图！"
    echo ""
    read -p "确认继续？[y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "操作已取消"
        exit 0
    fi
fi

echo ""
echo "========================================"
echo "开始重新生成"
echo "========================================"
echo ""

# 第1步：删除现有缩略图和预览图
echo "[1/3] 删除现有缩略图..."
rm -rf thumbnail/desktop thumbnail/mobile thumbnail/avatar
echo "✓ 缩略图已删除"

echo ""
echo "[2/3] 删除现有预览图..."
rm -rf preview/desktop preview/mobile
echo "✓ 预览图已删除"

# 第2步：重新生成
echo ""
echo "[3/3] 重新生成所有图片..."
echo "这可能需要几分钟，请耐心等待..."
echo ""

# 桌面壁纸
echo "处理桌面壁纸..."
desktop_count=0
shopt -s nullglob
for file in wallpaper/desktop/*/**/*.{jpg,png,webp,jpeg}; do
    [ -f "$file" ] || continue

    # 提取分类和文件名
    relative_path="${file#wallpaper/desktop/}"
    category=$(dirname "$relative_path")
    filename=$(basename "$file")
    name="${filename%.*}"

    # 生成缩略图
    thumb_dir="thumbnail/desktop/$category"
    mkdir -p "$thumb_dir"
    magick "$file" -resize "${THUMBNAIL_WIDTH}x>" -quality "$THUMBNAIL_QUALITY" "$thumb_dir/${name}.webp" 2>/dev/null

    # 生成预览图
    preview_dir="preview/desktop/$category"
    mkdir -p "$preview_dir"
    magick "$file" -resize "${PREVIEW_WIDTH}x>" -quality "$PREVIEW_QUALITY" -strip "$preview_dir/${name}.webp" 2>/dev/null

    desktop_count=$((desktop_count + 1))
    if [ $((desktop_count % 10)) -eq 0 ]; then
        echo "  已处理 $desktop_count 张桌面壁纸..."
    fi
done
echo "✓ 桌面壁纸处理完成: $desktop_count 张"

# 手机壁纸
echo ""
echo "处理手机壁纸..."
mobile_count=0
for file in wallpaper/mobile/*/**/*.{jpg,png,webp,jpeg}; do
    [ -f "$file" ] || continue

    # 提取分类和文件名
    relative_path="${file#wallpaper/mobile/}"
    category=$(dirname "$relative_path")
    filename=$(basename "$file")
    name="${filename%.*}"

    # 生成缩略图
    thumb_dir="thumbnail/mobile/$category"
    mkdir -p "$thumb_dir"
    magick "$file" -resize "${THUMBNAIL_WIDTH}x>" -quality "$THUMBNAIL_QUALITY" "$thumb_dir/${name}.webp" 2>/dev/null

    # 生成预览图
    preview_dir="preview/mobile/$category"
    mkdir -p "$preview_dir"
    magick "$file" -resize "${MOBILE_PREVIEW_WIDTH}x>" -quality "$MOBILE_PREVIEW_QUALITY" -strip "$preview_dir/${name}.webp" 2>/dev/null

    mobile_count=$((mobile_count + 1))
    if [ $((mobile_count % 10)) -eq 0 ]; then
        echo "  已处理 $mobile_count 张手机壁纸..."
    fi
done
echo "✓ 手机壁纸处理完成: $mobile_count 张"

# 头像（只有缩略图）
echo ""
echo "处理头像..."
avatar_count=0
for file in wallpaper/avatar/*/**/*.{jpg,png,webp,jpeg}; do
    [ -f "$file" ] || continue

    # 提取分类和文件名
    relative_path="${file#wallpaper/avatar/}"
    category=$(dirname "$relative_path")
    filename=$(basename "$file")
    name="${filename%.*}"

    # 生成缩略图
    thumb_dir="thumbnail/avatar/$category"
    mkdir -p "$thumb_dir"
    magick "$file" -resize "${THUMBNAIL_WIDTH}x>" -quality "$THUMBNAIL_QUALITY" "$thumb_dir/${name}.webp" 2>/dev/null

    avatar_count=$((avatar_count + 1))
    if [ $((avatar_count % 10)) -eq 0 ]; then
        echo "  已处理 $avatar_count 张头像..."
    fi
done
echo "✓ 头像处理完成: $avatar_count 张"

echo ""
echo "========================================"
echo "重新生成完成！"
echo "========================================"
echo ""
echo "统计结果："
echo "  桌面壁纸: $desktop_count 张"
echo "  手机壁纸: $mobile_count 张"
echo "  头像: $avatar_count 张"
echo "  总计: $((desktop_count + mobile_count + avatar_count)) 张"
echo ""

# 显示优化效果
echo "优化效果预估："
new_thumb_count=$(find thumbnail -type f \( -name "*.webp" -o -name "*.jpg" \) 2>/dev/null | wc -l | tr -d ' ')
new_preview_count=$(find preview -type f \( -name "*.webp" -o -name "*.jpg" \) 2>/dev/null | wc -l | tr -d ' ')

if [ $new_thumb_count -gt 0 ]; then
    avg_thumb_size=$(find thumbnail -type f \( -name "*.webp" -o -name "*.jpg" \) -exec ls -l {} \; | awk '{sum+=$5; count++} END {printf "%.0f", sum/count/1024}')
    echo "  平均缩略图大小: ${avg_thumb_size} KB (优化前: 31-65 KB)"
fi

if [ $new_preview_count -gt 0 ]; then
    avg_preview_size=$(find preview -type f \( -name "*.webp" -o -name "*.jpg" \) -exec ls -l {} \; | awk '{sum+=$5; count++} END {printf "%.0f", sum/count/1024}')
    echo "  平均预览图大小: ${avg_preview_size} KB (优化前: 163-248 KB)"
fi

echo ""
echo "✅ 所有图片已重新生成！"
echo ""
echo "下一步："
echo "  1. 验证图片质量（随机查看几张）"
echo "  2. 提交到 Git 仓库"
echo "  3. 推送到远程，触发前端重新构建"
