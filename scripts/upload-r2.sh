#!/usr/bin/env bash
# ========================================
# Cloudflare R2 上传脚本
# ========================================
#
# 功能：将壁纸文件增量同步到 Cloudflare R2 存储桶
#
# 用法：
#   ./scripts/upload-r2.sh                    # 增量同步
#   ./scripts/upload-r2.sh --full             # 全量同步
#   ./scripts/upload-r2.sh --dry-run          # 预览模式（不实际上传）
#
# 环境变量（必需）：
#   CLOUDFLARE_ACCOUNT_ID    - Cloudflare 账户 ID
#   CLOUDFLARE_R2_ACCESS_KEY - R2 Access Key
#   CLOUDFLARE_R2_SECRET_KEY - R2 Secret Key
#
# 环境变量（可选）：
#   R2_BUCKET_NAME           - 存储桶名称（默认: wallpaper-images）
#
# ========================================

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置
R2_BUCKET="${R2_BUCKET_NAME:-wallpaper-images}"
R2_ENDPOINT="https://${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com"

# 要同步的目录
SYNC_DIRS=("wallpaper" "thumbnail" "preview" "bing/meta")

# 解析参数
FULL_SYNC=false
DRY_RUN=false
for arg in "$@"; do
    case $arg in
        --full)
            FULL_SYNC=true
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
    esac
done

echo "=========================================="
echo "  Cloudflare R2 Upload Script"
echo "=========================================="
echo ""

# 检查必需的环境变量
if [ -z "$CLOUDFLARE_ACCOUNT_ID" ]; then
    echo -e "${RED}[ERROR]${NC} CLOUDFLARE_ACCOUNT_ID is not set"
    exit 1
fi

if [ -z "$CLOUDFLARE_R2_ACCESS_KEY" ]; then
    echo -e "${RED}[ERROR]${NC} CLOUDFLARE_R2_ACCESS_KEY is not set"
    exit 1
fi

if [ -z "$CLOUDFLARE_R2_SECRET_KEY" ]; then
    echo -e "${RED}[ERROR]${NC} CLOUDFLARE_R2_SECRET_KEY is not set"
    exit 1
fi

# 配置 AWS CLI
echo -e "${BLUE}[INFO]${NC} Configuring AWS CLI for R2..."
export AWS_ACCESS_KEY_ID="$CLOUDFLARE_R2_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$CLOUDFLARE_R2_SECRET_KEY"
export AWS_DEFAULT_REGION="auto"

# 检查 AWS CLI 是否可用
if ! command -v aws &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} AWS CLI is not installed"
    exit 1
fi

echo -e "${GREEN}[INFO]${NC} R2 Endpoint: $R2_ENDPOINT"
echo -e "${GREEN}[INFO]${NC} R2 Bucket: $R2_BUCKET"
echo -e "${GREEN}[INFO]${NC} Mode: $([ "$FULL_SYNC" = true ] && echo "Full Sync" || echo "Incremental Sync")"
echo -e "${GREEN}[INFO]${NC} Dry Run: $([ "$DRY_RUN" = true ] && echo "Yes" || echo "No")"
echo ""

# 统计变量
total_files=0
total_size=0
uploaded_dirs=""

# 同步单个目录
sync_directory() {
    local dir="$1"
    local s3_path="s3://$R2_BUCKET/$dir/"
    
    if [ ! -d "$dir" ]; then
        echo -e "${YELLOW}[SKIP]${NC} Directory not found: $dir"
        return
    fi
    
    echo -e "${CYAN}[SYNC]${NC} $dir/ -> $s3_path"
    
    # 构建 aws s3 sync 命令
    local sync_cmd="aws s3 sync \"$dir/\" \"$s3_path\" --endpoint-url \"$R2_ENDPOINT\""
    
    # 添加选项
    if [ "$DRY_RUN" = true ]; then
        sync_cmd="$sync_cmd --dryrun"
    fi
    
    # 排除隐藏文件
    sync_cmd="$sync_cmd --exclude \".*\" --exclude \"*/.*\""
    
    # 执行同步
    local output
    if output=$(eval "$sync_cmd" 2>&1); then
        # 统计上传的文件
        local file_count
        file_count=$(echo "$output" | grep -c "upload:" || echo "0")
        
        if [ "$file_count" -gt 0 ]; then
            echo -e "${GREEN}[OK]${NC} Uploaded $file_count files from $dir/"
            total_files=$((total_files + file_count))
            uploaded_dirs="$uploaded_dirs $dir"
        else
            echo -e "${BLUE}[OK]${NC} No new files in $dir/"
        fi
    else
        echo -e "${RED}[ERROR]${NC} Failed to sync $dir/"
        echo "$output"
        return 1
    fi
}

# 计算目录大小
calculate_size() {
    local dir="$1"
    if [ -d "$dir" ]; then
        du -sh "$dir" 2>/dev/null | cut -f1
    else
        echo "0"
    fi
}

# 同步所有目录
echo "Starting sync..."
echo ""

for dir in "${SYNC_DIRS[@]}"; do
    sync_directory "$dir" || true
done

# 计算总大小
echo ""
echo "Calculating sizes..."
for dir in "${SYNC_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        size=$(calculate_size "$dir")
        echo -e "  $dir: $size"
    fi
done

# 输出统计
echo ""
echo "=========================================="
echo "  Upload Complete!"
echo "=========================================="
echo "  Total files uploaded: $total_files"
echo "  Directories synced:  ${SYNC_DIRS[*]}"
if [ -n "$uploaded_dirs" ]; then
    echo "  Updated directories: $uploaded_dirs"
fi
echo "=========================================="

# 设置 GitHub Actions 输出
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "uploaded_files=$total_files" >> "$GITHUB_OUTPUT"
    echo "uploaded_dirs=$uploaded_dirs" >> "$GITHUB_OUTPUT"
fi

# 返回更新的目录列表（用于 Cache Purge）
if [ -n "$uploaded_dirs" ]; then
    echo ""
    echo -e "${GREEN}[INFO]${NC} Updated directories:$uploaded_dirs"
fi
