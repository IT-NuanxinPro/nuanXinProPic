#!/bin/bash
# sync-wallpaper.sh
# 从 Gitee 仓库同步壁纸到本地 wallpaper 目录
# 策略：全量覆盖（删除现有文件后重新同步）
# 同时生成缩略图到 thumbnail 目录

# Gitee 仓库配置
GITEE_OWNER="zhang--shuang"
GITEE_REPO="desktop_wallpaper"
GITEE_BRANCH="master"

# 本地目录配置
TEMP_DIR="/tmp/desktop_wallpaper_sync"
TEMP_ZIP="/tmp/desktop_wallpaper.zip"
TARGET_DIR="wallpaper"
THUMBNAIL_DIR="thumbnail"

# 缩略图配置
THUMB_WIDTH=400
THUMB_QUALITY=80

# 重试配置
MAX_RETRIES=3
RETRY_DELAY=5

# 支持的图片格式
IMAGE_EXTENSIONS=("jpg" "jpeg" "png" "gif" "webp" "JPG" "JPEG" "PNG" "GIF" "WEBP")

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "=========================================="
echo "  Wallpaper Sync Script (Full Overwrite)"
echo "=========================================="
echo ""

# 检查是否有 Gitee Token
if [ -n "$GITEE_TOKEN" ]; then
    echo -e "${GREEN}[INFO]${NC} Gitee token detected, using authenticated requests"
    # 带认证的 URL
    GITEE_ZIP_URL="https://gitee.com/${GITEE_OWNER}/${GITEE_REPO}/repository/archive/${GITEE_BRANCH}.zip"
    GITEE_CLONE_URL="https://oauth2:${GITEE_TOKEN}@gitee.com/${GITEE_OWNER}/${GITEE_REPO}.git"
    CURL_AUTH_HEADER="PRIVATE-TOKEN: ${GITEE_TOKEN}"
else
    echo -e "${YELLOW}[WARN]${NC} No Gitee token, using anonymous requests (may be rate limited)"
    GITEE_ZIP_URL="https://gitee.com/${GITEE_OWNER}/${GITEE_REPO}/repository/archive/${GITEE_BRANCH}.zip"
    GITEE_CLONE_URL="https://gitee.com/${GITEE_OWNER}/${GITEE_REPO}.git"
    CURL_AUTH_HEADER=""
fi

# 清理临时目录和文件
cleanup_temp() {
    rm -rf "$TEMP_DIR"
    rm -f "$TEMP_ZIP"
}
cleanup_temp

# 下载函数：优先使用 ZIP 下载（更可靠），失败则尝试 git clone
download_source() {
    local success=false

    # 方法1：下载 ZIP 包（推荐）
    echo -e "${BLUE}[METHOD 1]${NC} Downloading ZIP archive..."
    for ((i=1; i<=MAX_RETRIES; i++)); do
        echo -e "${BLUE}[ATTEMPT $i/$MAX_RETRIES]${NC} Downloading..."

        # 构建 curl 命令
        local curl_cmd="curl -fsSL --connect-timeout 30 --max-time 300"
        if [ -n "$CURL_AUTH_HEADER" ]; then
            curl_cmd="$curl_cmd -H \"$CURL_AUTH_HEADER\""
        fi
        curl_cmd="$curl_cmd -o \"$TEMP_ZIP\" \"$GITEE_ZIP_URL\""

        if eval $curl_cmd 2>&1; then
            # 验证是否为有效的 ZIP 文件
            if file "$TEMP_ZIP" | grep -q "Zip archive"; then
                echo -e "${GREEN}[SUCCESS]${NC} ZIP downloaded"
                mkdir -p "$TEMP_DIR"
                # 解压 ZIP（Gitee ZIP 包含一个根目录）
                if unzip -q "$TEMP_ZIP" -d "$TEMP_DIR" 2>&1; then
                    # 找到解压后的实际目录
                    EXTRACTED_DIR=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -1)
                    if [ -n "$EXTRACTED_DIR" ]; then
                        # 将内容移动到 TEMP_DIR 根目录
                        mv "$EXTRACTED_DIR"/* "$TEMP_DIR"/ 2>/dev/null || true
                        rm -rf "$EXTRACTED_DIR"
                    fi
                    echo -e "${GREEN}[SUCCESS]${NC} ZIP extracted"
                    success=true
                    break
                else
                    echo -e "${YELLOW}[FAILED]${NC} Failed to extract ZIP"
                fi
            else
                echo -e "${YELLOW}[FAILED]${NC} Downloaded file is not a valid ZIP (may be 403/404 error page)"
                # 显示文件内容以便调试
                head -c 200 "$TEMP_ZIP" 2>/dev/null || true
                echo ""
            fi
        else
            echo -e "${YELLOW}[FAILED]${NC} Download attempt $i failed"
        fi

        rm -f "$TEMP_ZIP"
        rm -rf "$TEMP_DIR"

        if [ $i -lt $MAX_RETRIES ]; then
            echo "Waiting ${RETRY_DELAY}s before retry..."
            sleep $RETRY_DELAY
        fi
    done

    # 方法2：如果 ZIP 下载失败，尝试 git clone
    if [ "$success" = false ]; then
        echo ""
        echo -e "${BLUE}[METHOD 2]${NC} Trying git clone as fallback..."
        for ((i=1; i<=MAX_RETRIES; i++)); do
            echo -e "${BLUE}[ATTEMPT $i/$MAX_RETRIES]${NC} Cloning..."

            if git clone --depth 1 "$GITEE_CLONE_URL" "$TEMP_DIR" 2>&1; then
                echo -e "${GREEN}[SUCCESS]${NC} Clone completed"
                success=true
                break
            else
                echo -e "${YELLOW}[FAILED]${NC} Clone attempt $i failed"
                rm -rf "$TEMP_DIR"

                if [ $i -lt $MAX_RETRIES ]; then
                    echo "Waiting ${RETRY_DELAY}s before retry..."
                    sleep $RETRY_DELAY
                fi
            fi
        done
    fi

    if [ "$success" = false ]; then
        echo -e "${RED}[ERROR]${NC} Failed to download source after all attempts"
        return 1
    fi
    return 0
}

# 执行下载
if ! download_source; then
    exit 1
fi

# 全量覆盖：删除现有目录
echo ""
echo -e "${YELLOW}[INFO]${NC} Removing existing directories for full overwrite..."
rm -rf "$TARGET_DIR"
rm -rf "$THUMBNAIL_DIR"

# 重新创建目录
mkdir -p "$TARGET_DIR"
mkdir -p "$THUMBNAIL_DIR"

# 检查 ImageMagick 是否可用（兼容 v6 的 convert 和 v7 的 magick）
if command -v magick &> /dev/null; then
    IMAGEMAGICK_CMD="magick"
    echo -e "${GREEN}[INFO]${NC} ImageMagick v7 found (magick), will generate thumbnails"
    GENERATE_THUMBNAILS=true
elif command -v convert &> /dev/null; then
    IMAGEMAGICK_CMD="convert"
    echo -e "${GREEN}[INFO]${NC} ImageMagick found (convert), will generate thumbnails"
    GENERATE_THUMBNAILS=true
else
    echo -e "${YELLOW}[WARN]${NC} ImageMagick not found, thumbnails will not be generated"
    GENERATE_THUMBNAILS=false
fi

# 统计变量
total_found=0
copied=0
thumbnails_generated=0
thumbnail_errors=0

echo ""
echo "Scanning and copying images..."
echo ""

# 遍历临时目录中的图片
for ext in "${IMAGE_EXTENSIONS[@]}"; do
    shopt -s nullglob
    for file in "$TEMP_DIR"/*."$ext"; do
        # 检查文件是否存在
        [ -e "$file" ] || continue

        filename=$(basename "$file")
        target_file="$TARGET_DIR/$filename"

        # 生成缩略图文件名（统一使用 webp 格式）
        filename_noext="${filename%.*}"
        thumbnail_file="$THUMBNAIL_DIR/${filename_noext}.webp"

        total_found=$((total_found + 1))

        # 复制原图
        echo -e "${GREEN}[COPY]${NC} $filename"
        cp "$file" "$target_file"
        copied=$((copied + 1))

        # 生成缩略图
        if [ "$GENERATE_THUMBNAILS" = true ]; then
            if $IMAGEMAGICK_CMD "$file" \
                -resize "${THUMB_WIDTH}x>" \
                -quality "$THUMB_QUALITY" \
                -strip \
                "$thumbnail_file" 2>/dev/null; then
                echo -e "${BLUE}[THUMB]${NC} ${filename_noext}.webp"
                thumbnails_generated=$((thumbnails_generated + 1))
            else
                echo -e "${RED}[THUMB ERROR]${NC} Failed to generate thumbnail for $filename"
                thumbnail_errors=$((thumbnail_errors + 1))
            fi
        fi
    done
    shopt -u nullglob
done

# 清理临时目录
echo ""
echo "Cleaning up temp directory..."
cleanup_temp

# 输出统计
echo ""
echo "=========================================="
echo "  Sync Complete!"
echo "=========================================="
echo "  Total images found:      $total_found"
echo "  Images copied:           $copied"
echo "  Thumbnails generated:    $thumbnails_generated"
if [ "$thumbnail_errors" -gt 0 ]; then
echo "  Thumbnail errors:        $thumbnail_errors"
fi
echo "=========================================="

# 设置输出变量供 GitHub Actions 使用
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "total_images=$copied" >> "$GITHUB_OUTPUT"
    echo "thumbnails=$thumbnails_generated" >> "$GITHUB_OUTPUT"
fi

# 返回是否有图片（用于判断是否需要提交）
if [ "$copied" -gt 0 ]; then
    exit 0
else
    echo ""
    echo "No images found to sync."
    exit 0
fi
