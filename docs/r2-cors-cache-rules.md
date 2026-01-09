# R2 CORS 和缓存规则配置

本文档说明如何配置 Cloudflare R2 的 CORS 策略和缓存规则。

## CORS 配置

### 为什么需要 CORS

前端网站 `wallpaper.061129.xyz` 需要从 `img.061129.xyz` 加载图片和 JSON 数据。由于是跨域请求，需要配置 CORS 允许访问。

### CORS 策略 JSON

```json
[
  {
    "AllowedOrigins": [
      "https://wallpaper.061129.xyz",
      "http://localhost:5173",
      "http://localhost:3000",
      "http://127.0.0.1:5173",
      "http://127.0.0.1:3000"
    ],
    "AllowedMethods": [
      "GET",
      "HEAD"
    ],
    "AllowedHeaders": [
      "*"
    ],
    "ExposeHeaders": [
      "Content-Length",
      "Content-Type",
      "ETag"
    ],
    "MaxAgeSeconds": 86400
  }
]
```

### 配置步骤

1. 进入 Cloudflare Dashboard > R2 > `wallpaper-images` 存储桶
2. 点击 **设置** 标签
3. 找到 **CORS 策略** 部分
4. 点击 **添加 CORS 策略**
5. 粘贴上面的 JSON 配置
6. 点击 **保存**

### 验证 CORS

```bash
# 测试 preflight 请求
curl -X OPTIONS https://img.061129.xyz/data/desktop/index.json \
  -H "Origin: https://wallpaper.061129.xyz" \
  -H "Access-Control-Request-Method: GET" \
  -v

# 应该返回:
# Access-Control-Allow-Origin: https://wallpaper.061129.xyz
# Access-Control-Allow-Methods: GET, HEAD
```

---

## 缓存规则配置

### 缓存策略说明

| 资源类型 | 路径 | 缓存时间 | 说明 |
|---------|------|---------|------|
| 图片文件 | `/wallpaper/*`, `/thumbnail/*`, `/preview/*` | 1 年 | 图片内容不变，长期缓存 |
| JSON 数据 | `/data/*`, `/bing/meta/*` | 5 分钟 | 数据会更新，短期缓存 |

### 方法 1: 使用 Cloudflare Cache Rules（推荐）

1. 进入 Cloudflare Dashboard > 你的域名 > **缓存** > **Cache Rules**
2. 点击 **创建规则**

#### 规则 1: 图片长缓存

- **规则名称**: `R2 Images Long Cache`
- **匹配条件**: 
  ```
  (http.host eq "img.061129.xyz" and starts_with(http.request.uri.path, "/wallpaper/")) or
  (http.host eq "img.061129.xyz" and starts_with(http.request.uri.path, "/thumbnail/")) or
  (http.host eq "img.061129.xyz" and starts_with(http.request.uri.path, "/preview/"))
  ```
- **缓存状态**: 符合缓存条件
- **边缘 TTL**: 
  - 覆盖源站: 1 年 (31536000 秒)
- **浏览器 TTL**:
  - 覆盖源站: 1 年 (31536000 秒)

#### 规则 2: JSON 短缓存

- **规则名称**: `R2 JSON Short Cache`
- **匹配条件**: 
  ```
  (http.host eq "img.061129.xyz" and starts_with(http.request.uri.path, "/data/")) or
  (http.host eq "img.061129.xyz" and starts_with(http.request.uri.path, "/bing/meta/"))
  ```
- **缓存状态**: 符合缓存条件
- **边缘 TTL**: 
  - 覆盖源站: 1 分钟 (60 秒)
- **浏览器 TTL**:
  - 覆盖源站: 5 分钟 (300 秒)

### 方法 2: 使用 Transform Rules 设置响应头

如果 Cache Rules 不够灵活，可以使用 Transform Rules 直接设置 Cache-Control 头。

1. 进入 **规则** > **Transform Rules** > **修改响应头**
2. 创建规则

#### 规则: 图片 Cache-Control

- **规则名称**: `R2 Images Cache-Control`
- **匹配条件**: 
  ```
  (http.host eq "img.061129.xyz" and http.request.uri.path matches "^/(wallpaper|thumbnail|preview)/")
  ```
- **操作**: 设置静态响应头
  - **Header name**: `Cache-Control`
  - **Value**: `public, max-age=31536000, immutable`

#### 规则: JSON Cache-Control

- **规则名称**: `R2 JSON Cache-Control`
- **匹配条件**: 
  ```
  (http.host eq "img.061129.xyz" and http.request.uri.path matches "^/(data|bing/meta)/")
  ```
- **操作**: 设置静态响应头
  - **Header name**: `Cache-Control`
  - **Value**: `public, max-age=300, s-maxage=60`

### 验证缓存配置

```bash
# 测试图片缓存头
curl -I https://img.061129.xyz/wallpaper/desktop/动漫/原神/雷电将军.jpg

# 应该返回:
# Cache-Control: public, max-age=31536000, immutable
# CF-Cache-Status: HIT (或 MISS 首次请求)

# 测试 JSON 缓存头
curl -I https://img.061129.xyz/data/desktop/index.json

# 应该返回:
# Cache-Control: public, max-age=300, s-maxage=60
# Content-Type: application/json
```

---

## 后期防盗链配置（可选）

如果发现图片被大量盗链，可以通过以下方式限制:

### 方法 1: Transform Rules + Referer 检查

1. 进入 **规则** > **Transform Rules** > **修改请求头**
2. 创建规则检查 Referer

```
# 匹配条件
(http.host eq "img.061129.xyz") and 
(not http.referer contains "wallpaper.061129.xyz") and 
(not http.referer contains "localhost") and
(http.referer ne "")
```

### 方法 2: Cloudflare Worker（更灵活）

创建 Worker 代理 R2 请求，可以实现:
- Referer 白名单检查
- 请求频率限制
- 自定义错误页面

Worker 示例代码见 `scripts/r2-worker.js`（后续创建）。

---

## 常见问题

### Q: 缓存规则不生效

A: 
1. 检查规则顺序，优先级高的规则在前
2. 清除浏览器缓存后重试
3. 使用 `curl -I` 检查响应头

### Q: JSON 更新后前端看不到新数据

A: 
1. 检查 Cache Purge 是否成功执行
2. 等待边缘缓存 TTL 过期（最多 1 分钟）
3. 浏览器可能有本地缓存，强制刷新（Ctrl+Shift+R）

### Q: 图片加载慢

A: 
1. 首次请求会较慢（MISS），后续请求会从边缘缓存返回（HIT）
2. 检查 CF-Cache-Status 头确认缓存状态
3. 考虑使用 Cloudflare 的 Argo Smart Routing（付费功能）
