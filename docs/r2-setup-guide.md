# Cloudflare R2 存储桶配置指南

本文档详细说明如何配置 Cloudflare R2 存储桶用于壁纸图床。

## 前置条件

- Cloudflare 账户（免费版即可）
- 已有域名托管在 Cloudflare（如 `061129.xyz`）

## 步骤 1: 创建 R2 存储桶

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. 左侧菜单选择 **R2 对象存储**
3. 点击 **创建存储桶**
4. 输入存储桶名称: `wallpaper-images`
5. 位置选择: **自动** 或 **亚太地区**（推荐）
6. 点击 **创建存储桶**

## 步骤 2: 配置公开访问

1. 进入刚创建的 `wallpaper-images` 存储桶
2. 点击 **设置** 标签
3. 找到 **公开访问** 部分
4. 点击 **允许访问**
5. 选择 **自定义域名**（推荐）或 **R2.dev 子域名**

### 绑定自定义域名（推荐）

1. 在 **公开访问** 部分，点击 **连接域名**
2. 输入域名: `img.061129.xyz`
3. Cloudflare 会自动配置 DNS 记录
4. 等待 SSL 证书生成（通常几分钟）
5. 验证: 访问 `https://img.061129.xyz` 应该返回 XML 错误（正常，因为没有 index 文件）

## 步骤 3: 创建 R2 API Token

1. 返回 R2 概览页面
2. 点击右上角 **管理 R2 API 令牌**
3. 点击 **创建 API 令牌**
4. 配置权限:
   - **令牌名称**: `wallpaper-sync`
   - **权限**: 对象读写
   - **指定存储桶**: 选择 `wallpaper-images`
   - **TTL**: 永不过期（或根据需要设置）
5. 点击 **创建 API 令牌**
6. **重要**: 复制并保存以下信息（只显示一次）:
   - **Access Key ID**: 类似 `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
   - **Secret Access Key**: 类似 `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
   - **Endpoint**: `https://<account_id>.r2.cloudflarestorage.com`

## 步骤 4: 获取 Cloudflare 账户信息

### 获取 Account ID

1. 在 Cloudflare Dashboard 首页
2. 右侧边栏可以看到 **账户 ID**
3. 或者在 R2 页面的 URL 中: `https://dash.cloudflare.com/<account_id>/r2`

### 获取 Zone ID（用于 Cache Purge）

1. 进入你的域名（如 `061129.xyz`）
2. 右侧边栏 **API** 部分可以看到 **区域 ID**

### 创建 Cache Purge API Token

1. 进入 **我的个人资料** > **API 令牌**
2. 点击 **创建令牌**
3. 选择 **自定义令牌**
4. 配置:
   - **令牌名称**: `cache-purge`
   - **权限**: 
     - 区域 > 缓存清除 > 清除
   - **区域资源**: 
     - 包括 > 特定区域 > `061129.xyz`
5. 点击 **继续以显示摘要** > **创建令牌**
6. 复制并保存 API Token

## 步骤 5: 配置 GitHub Secrets

在 `nuanXinProPic` 仓库中添加以下 Secrets:

| Secret 名称 | 值 | 说明 |
|------------|-----|------|
| `CLOUDFLARE_ACCOUNT_ID` | 你的账户 ID | 用于 R2 Endpoint |
| `CLOUDFLARE_R2_ACCESS_KEY` | R2 Access Key ID | R2 API 认证 |
| `CLOUDFLARE_R2_SECRET_KEY` | R2 Secret Access Key | R2 API 认证 |
| `CF_ZONE_ID` | 区域 ID | 用于 Cache Purge |
| `CF_API_TOKEN` | Cache Purge Token | 用于清除缓存 |

### 添加 Secret 步骤

1. 进入仓库 **Settings** > **Secrets and variables** > **Actions**
2. 点击 **New repository secret**
3. 输入名称和值
4. 点击 **Add secret**

## 验证配置

### 测试 R2 访问

```bash
# 测试域名是否可访问
curl -I https://img.061129.xyz

# 应该返回类似:
# HTTP/2 200
# content-type: application/xml
```

### 测试 AWS CLI 连接

```bash
# 配置 AWS CLI
export AWS_ACCESS_KEY_ID=你的_R2_ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=你的_R2_SECRET_KEY

# 列出存储桶内容
aws s3 ls s3://wallpaper-images/ \
  --endpoint-url https://你的账户ID.r2.cloudflarestorage.com

# 测试上传
echo "test" > test.txt
aws s3 cp test.txt s3://wallpaper-images/test.txt \
  --endpoint-url https://你的账户ID.r2.cloudflarestorage.com

# 验证可访问
curl https://img.061129.xyz/test.txt

# 清理测试文件
aws s3 rm s3://wallpaper-images/test.txt \
  --endpoint-url https://你的账户ID.r2.cloudflarestorage.com
```

## 常见问题

### Q: 域名绑定后访问返回 403

A: 检查存储桶是否已启用公开访问，以及域名 DNS 是否正确指向 R2。

### Q: 上传中文文件名失败

A: AWS CLI 默认支持 UTF-8，确保终端编码正确。如果仍有问题，可以先 URL 编码文件名。

### Q: Cache Purge 返回 403

A: 检查 API Token 是否有 Cache Purge 权限，以及 Zone ID 是否正确。

## 下一步

配置完成后，继续执行:
1. 配置 CORS 策略（任务 2.1）
2. 配置 Cache Rules（任务 2.2）
3. 更新 GitHub Actions 工作流（任务 5）
