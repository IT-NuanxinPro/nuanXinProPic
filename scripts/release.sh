#!/bin/bash
# ========================================
# 本地发布脚本：提交更改并自动打 tag
# 用法: ./scripts/release.sh [commit message]
# ========================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 开始发布流程...${NC}"

# 检查是否有未提交的更改
if [ -z "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}⚠️  没有检测到更改，无需发布${NC}"
    exit 0
fi

# 获取提交信息
if [ -n "$1" ]; then
    COMMIT_MSG="$1"
else
    COMMIT_MSG="chore: update wallpapers [$(date +'%Y-%m-%d')]"
fi

# 获取最新的 tag 并计算新版本号
LATEST_TAG=$(git tag -l 'v1.*' --sort=-version:refname | head -1)

if [ -z "$LATEST_TAG" ]; then
    NEW_TAG="v1.0.1"
else
    VERSION=${LATEST_TAG#v}
    IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"
    NEW_PATCH=$((PATCH + 1))
    NEW_TAG="v${MAJOR}.${MINOR}.${NEW_PATCH}"
fi

echo -e "${BLUE}📦 版本号: ${LATEST_TAG:-无} → ${NEW_TAG}${NC}"

# 显示将要提交的更改
echo -e "\n${YELLOW}📋 将要提交的更改:${NC}"
git status --short

# 确认
echo ""
read -p "确认提交并创建 tag ${NEW_TAG}? (y/N) " -n 1 -r
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
git tag -a "$NEW_TAG" -m "Release $NEW_TAG - $(date +'%Y-%m-%d')"

# 推送
echo -e "${BLUE}🚀 推送到远程...${NC}"
git push
git push origin "$NEW_TAG"

echo -e "\n${GREEN}✅ 发布成功!${NC}"
echo -e "${GREEN}   提交: ${COMMIT_MSG}${NC}"
echo -e "${GREEN}   标签: ${NEW_TAG}${NC}"
echo -e "\n${YELLOW}💡 前端项目下次构建时会自动使用 ${NEW_TAG}${NC}"
