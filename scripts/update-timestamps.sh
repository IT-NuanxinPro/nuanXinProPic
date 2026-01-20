#!/bin/bash
# ========================================
# 更新时间戳脚本（优化版）
# ========================================
#
# 功能：为新增图片添加时间戳记录
#       格式: series|相对路径|时间戳(秒)|first_tag
#
# 优化：使用 Git diff 快速检测新增文件，避免全量扫描
#
# 用法：
#   ./scripts/update-timestamps.sh <图床仓库路径> [新tag]
#
# ========================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 基于时间戳文件检测新增图片（最可靠的方式）
# 扫描 wallpaper 目录，找出不在时间戳文件中的图片
get_new_images_by_scan() {
    local project_root="$1"
    local backup_file="$2"
    
    for series in desktop mobile avatar; do
        local wallpaper_dir="$project_root/wallpaper/$series"
        [ ! -d "$wallpaper_dir" ] && continue

        while IFS= read -r -d '' img; do
            local rel_path="${img#$wallpaper_dir/}"
            local key="${series}|${rel_path}"

            # 检查是否已有记录
            if ! grep -q "^${key}|" "$backup_file" 2>/dev/null; then
                echo "wallpaper/$series/$rel_path"
            fi
        done < <(find "$wallpaper_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -print0)
    done
}

main() {
    local project_root="${1:-.}"
    local new_tag="${2:-}"

    local backup_file="$project_root/timestamps-backup-all.txt"
    local timestamp=$(date +%s)

    cd "$project_root"

    # 如果没有传入 tag，计算下一个版本号
    if [ -z "$new_tag" ]; then
        local latest_tag=$(git tag -l 'v*' --sort=-version:refname | head -1)
        if [ -z "$latest_tag" ]; then
            new_tag="v1.0.1"
        else
            local version=${latest_tag#v}
            IFS='.' read -r major minor patch <<< "$version"
            local new_patch=$((patch + 1))
            new_tag="v${major}.${minor}.${new_patch}"
        fi
    fi

    echo -e "${BLUE}更新时间戳文件...${NC}"
    echo -e "  Tag: ${GREEN}$new_tag${NC}"

    # 直接扫描 wallpaper 目录，找出不在时间戳文件中的图片
    local new_files=()

    echo -e "  ${BLUE}扫描新增图片...${NC}"
    while IFS= read -r file; do
        if [ -n "$file" ]; then
            new_files+=("$file")
            echo -e "    发现: $file"
        fi
    done < <(get_new_images_by_scan "$project_root" "$backup_file")

    echo -e "  ${BLUE}检测到 ${#new_files[@]} 个新文件${NC}"

    local count=0
    local skipped=0

    for file in "${new_files[@]}"; do
        # 解析路径: wallpaper/desktop/动漫/xxx.jpg
        local rel_to_wallpaper="${file#wallpaper/}"  # desktop/动漫/xxx.jpg
        local series="${rel_to_wallpaper%%/*}"        # desktop
        local rest="${rel_to_wallpaper#*/}"           # 动漫/xxx.jpg
        local key="${series}|${rest}"

        # 再次检查是否已有记录（防止重复）
        if ! grep -q "^${key}|" "$backup_file" 2>/dev/null; then
            echo "${key}|${timestamp}|${new_tag}" >> "$backup_file"
            count=$((count + 1))
            echo -e "    ${GREEN}+${NC} $key -> $new_tag"
        else
            skipped=$((skipped + 1))
            echo -e "    ${YELLOW}跳过${NC} $key (已存在记录)"
        fi
    done

    echo -e "  新增 ${GREEN}${count}${NC} 条时间戳记录"
    [ "$skipped" -gt 0 ] && echo -e "  跳过 ${YELLOW}${skipped}${NC} 条已存在记录"

    # 输出新 tag 供后续脚本使用
    echo "$new_tag" > /tmp/new_tag.txt

    cd - > /dev/null
}

main "$@"
