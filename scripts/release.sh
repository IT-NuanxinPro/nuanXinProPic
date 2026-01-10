#!/bin/bash
# ========================================
# 发布脚本 (增强版)
# ========================================
#
# 功能：一键完成 git add + commit + tag + push + GitHub Release
#       自动递增版本号 (v1.0.x)
#       自动统计壁纸数量并生成 Release 说明
#
# 用法：
#   ./scripts/release.sh [提交信息]
#
# 参数：
#   提交信息  可选，默认为 "chore: update wallpapers [日期]"
#
# 示例：
#   ./scripts/release.sh                          # 使用默认提交信息
#   ./scripts/release.sh "feat: 新增动漫壁纸"      # 自定义提交信息
#
# 依赖：
#   - gh CLI (GitHub 官方命令行工具)
#   - 安装: brew install gh
#   - 认证: gh auth login
#
# ========================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 开始发布流程...${NC}"

# 检查 gh CLI 是否安装
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ 未检测到 gh CLI${NC}"
    echo -e "${YELLOW}请先安装: brew install gh${NC}"
    echo -e "${YELLOW}然后认证: gh auth login${NC}"
    exit 1
fi

# 检查是否已认证
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ gh CLI 未认证${NC}"
    echo -e "${YELLOW}请先运行: gh auth login${NC}"
    exit 1
fi

# 检查是否有未提交的更改
if [ -z "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}⚠️  没有检测到更改，无需发布${NC}"
    exit 0
fi

# 获取提交信息
if [ -n "$1" ]; then
    COMMIT_MSG="$1"
else
    COMMIT_MSG="chore: update wallpapers [$(TZ='Asia/Shanghai' date +'%Y-%m-%d')]"
fi

# ========================================
# 统计当前壁纸数量
# ========================================
echo -e "${BLUE}📊 统计壁纸数量...${NC}"

# 优先使用时间戳文件 (性能提升 47.6%)
TIMESTAMP_FILE="timestamps-backup-all.txt"

if [ -f "$TIMESTAMP_FILE" ]; then
    echo -e "${GREEN}  ⚡ 使用时间戳文件 (快速模式)${NC}"
    DESKTOP_NOW=$(grep '^desktop|' "$TIMESTAMP_FILE" 2>/dev/null | wc -l | tr -d ' ')
    MOBILE_NOW=$(grep '^mobile|' "$TIMESTAMP_FILE" 2>/dev/null | wc -l | tr -d ' ')
    AVATAR_NOW=$(grep '^avatar|' "$TIMESTAMP_FILE" 2>/dev/null | wc -l | tr -d ' ')

    # 数据验证: 如果时间戳文件为空或数据异常,回退到目录扫描
    TOTAL_FROM_FILE=$((DESKTOP_NOW + MOBILE_NOW + AVATAR_NOW))
    if [ "$TOTAL_FROM_FILE" -eq 0 ]; then
        echo -e "${YELLOW}  ⚠️  时间戳文件数据异常，回退到目录扫描${NC}"
        DESKTOP_NOW=$(find wallpaper/desktop -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null | wc -l | tr -d ' ')
        MOBILE_NOW=$(find wallpaper/mobile -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null | wc -l | tr -d ' ')
        AVATAR_NOW=$(find wallpaper/avatar -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null | wc -l | tr -d ' ')
    fi
else
    echo -e "${YELLOW}  ⚠️  时间戳文件不存在，使用目录扫描${NC}"
    DESKTOP_NOW=$(find wallpaper/desktop -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null | wc -l | tr -d ' ')
    MOBILE_NOW=$(find wallpaper/mobile -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null | wc -l | tr -d ' ')
    AVATAR_NOW=$(find wallpaper/avatar -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null | wc -l | tr -d ' ')
fi

echo -e "${GREEN}  🖥️  Desktop: ${DESKTOP_NOW}${NC}"
echo -e "${GREEN}  📱 Mobile: ${MOBILE_NOW}${NC}"
echo -e "${GREEN}  👤 Avatar: ${AVATAR_NOW}${NC}"

# 获取远程最新 tag
echo -e "${BLUE}📡 获取远程 tag...${NC}"
git fetch --tags --quiet

# 获取最新的 tag 并计算新版本号
LATEST_TAG=$(git tag -l 'v*' --sort=-version:refname | head -1)

if [ -z "$LATEST_TAG" ]; then
    NEW_TAG="v1.0.1"
    # 首次发布，没有历史数据
    DESKTOP_PREV=0
    MOBILE_PREV=0
    AVATAR_PREV=0
else
    VERSION=${LATEST_TAG#v}
    IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"
    NEW_PATCH=$((PATCH + 1))
    NEW_TAG="v${MAJOR}.${MINOR}.${NEW_PATCH}"

    # ========================================
    # 获取上个版本的统计数据
    # ========================================
    echo -e "${BLUE}📊 计算增量 (对比 ${LATEST_TAG})...${NC}"

    # 优化: 使用 git show 读取上个版本的时间戳文件 (无需切换分支)
    if git rev-parse --verify "$LATEST_TAG" &>/dev/null; then
        # 尝试从上个 tag 读取时间戳文件
        PREV_TIMESTAMP_CONTENT=$(git show "${LATEST_TAG}:${TIMESTAMP_FILE}" 2>/dev/null)

        if [ -n "$PREV_TIMESTAMP_CONTENT" ]; then
            echo -e "${GREEN}  ⚡ 从 ${LATEST_TAG} 读取时间戳文件${NC}"
            DESKTOP_PREV=$(echo "$PREV_TIMESTAMP_CONTENT" | grep '^desktop|' | wc -l | tr -d ' ')
            MOBILE_PREV=$(echo "$PREV_TIMESTAMP_CONTENT" | grep '^mobile|' | wc -l | tr -d ' ')
            AVATAR_PREV=$(echo "$PREV_TIMESTAMP_CONTENT" | grep '^avatar|' | wc -l | tr -d ' ')
        else
            echo -e "${YELLOW}  ⚠️  ${LATEST_TAG} 无时间戳文件，使用 0 作为基准${NC}"
            DESKTOP_PREV=0
            MOBILE_PREV=0
            AVATAR_PREV=0
        fi
    else
        echo -e "${YELLOW}  ⚠️  无法读取 ${LATEST_TAG}，将使用当前数量作为增量${NC}"
        DESKTOP_PREV=0
        MOBILE_PREV=0
        AVATAR_PREV=0
    fi
fi

# 计算增量
DESKTOP_DIFF=$((DESKTOP_NOW - DESKTOP_PREV))
MOBILE_DIFF=$((MOBILE_NOW - MOBILE_PREV))
AVATAR_DIFF=$((AVATAR_NOW - AVATAR_PREV))

# 格式化增量显示（正数加+号）
format_diff() {
    if [ "$1" -gt 0 ]; then
        echo "+$1"
    elif [ "$1" -lt 0 ]; then
        echo "$1"
    else
        echo "-"
    fi
}

DESKTOP_DIFF_STR=$(format_diff $DESKTOP_DIFF)
MOBILE_DIFF_STR=$(format_diff $MOBILE_DIFF)
AVATAR_DIFF_STR=$(format_diff $AVATAR_DIFF)

echo -e "${GREEN}  🖥️  Desktop: ${DESKTOP_PREV} → ${DESKTOP_NOW} (${DESKTOP_DIFF_STR})${NC}"
echo -e "${GREEN}  📱 Mobile: ${MOBILE_PREV} → ${MOBILE_NOW} (${MOBILE_DIFF_STR})${NC}"
echo -e "${GREEN}  👤 Avatar: ${AVATAR_PREV} → ${AVATAR_NOW} (${AVATAR_DIFF_STR})${NC}"

echo -e "${BLUE}📦 版本号: ${LATEST_TAG:-无} → ${NEW_TAG}${NC}"

# 显示将要提交的更改
echo -e "\n${YELLOW}📋 将要提交的更改:${NC}"
git status --short

# 确认
echo ""
read -p "确认提交并创建 tag ${NEW_TAG} 及 GitHub Release? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}❌ 已取消${NC}"
    exit 1
fi

# 添加所有更改
echo -e "\n${BLUE}📥 添加更改...${NC}"
git add .

# 提交
echo -e "${BLUE}💾 提交更改...${NC}"
git commit -m "$COMMIT_MSG"

# 创建 tag
echo -e "${BLUE}🏷️  创建 tag: ${NEW_TAG}${NC}"
git tag -a "$NEW_TAG" -m "Release $NEW_TAG - $(TZ='Asia/Shanghai' date +'%Y-%m-%d')"

# 推送
echo -e "${BLUE}🚀 推送到远程...${NC}"
git push
git push origin "$NEW_TAG"

# ========================================
# 创建 GitHub Release
# ========================================
echo -e "${BLUE}📦 创建 GitHub Release...${NC}"

TODAY=$(TZ='Asia/Shanghai' date +'%Y-%m-%d')

# 生成 Release 内容
BODY="## 📅 壁纸同步 - $TODAY

### 📊 统计
| 系列 | 总数 | 本次增量 |
|------|------|----------|
| 🖥️ Desktop | $DESKTOP_NOW | $DESKTOP_DIFF_STR |
| 📱 Mobile | $MOBILE_NOW | $MOBILE_DIFF_STR |
| 👤 Avatar | $AVATAR_NOW | $AVATAR_DIFF_STR |

### 📝 提交信息
\`\`\`
$COMMIT_MSG
\`\`\`

---
*手动发布 by $(whoami)*"

# 创建 Release
gh release create "$NEW_TAG" \
    --title "🎨 壁纸同步 - $TODAY ($NEW_TAG)" \
    --notes "$BODY" \
    --latest

echo -e "\n${GREEN}✅ 发布成功!${NC}"
echo -e "${GREEN}   提交: ${COMMIT_MSG}${NC}"
echo -e "${GREEN}   标签: ${NEW_TAG}${NC}"
echo -e "${GREEN}   Release: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/releases/tag/${NEW_TAG}${NC}"
echo -e "\n${YELLOW}💡 前端项目下次构建时会自动使用 ${NEW_TAG}${NC}"
