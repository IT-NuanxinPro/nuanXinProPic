# 暖心图床 — 免费永久图片托管 & 自动壁纸同步

![GitHub stars](https://img.shields.io/github/stars/IT-NuanxinPro/nuanXinProPic?style=social)
![GitHub forks](https://img.shields.io/github/forks/IT-NuanxinPro/nuanXinProPic?style=social)

## 项目简介

<!-- [DISABLED] R2 功能已暂停 -->
<!-- 暖心图床是一个基于 GitHub + Cloudflare R2 的个人图片托管服务，为博客写作、文档编写等场景提供稳定可靠的图片存储解决方案。 -->
暖心图床是一个基于 GitHub 的个人图片托管服务，为博客写作、文档编写等场景提供稳定可靠的图片存储解决方案。

### 特色功能

- 支持多种图片格式（PNG、JPG、GIF、WebP 等）
<!-- [DISABLED] R2 功能已暂停
- **Cloudflare R2 CDN 加速** - 主要图片托管
-->
- **jsDelivr 备用** - GitHub Release 自动回退
- 永久免费存储
- **自动同步壁纸** - 每日从 Gitee 增量同步精选壁纸
- **自动生成缩略图** - WebP 格式，350px，75% 质量，带双水印
- **自动生成预览图** - WebP 格式，无水印
  - Desktop: 1920px，78% 质量
  - Mobile: 1080px，75% 质量

## 目录结构

```
nuanXinProPic/
├── wallpaper/              # 壁纸原图目录
│   ├── desktop/            # 电脑壁纸（每日自动同步）
│   ├── mobile/             # 手机壁纸
│   └── avatar/             # 头像
├── thumbnail/              # 壁纸缩略图（WebP，带水印）
├── preview/                # 壁纸预览图（WebP，无水印）
├── bing/meta/              # Bing 每日壁纸元数据
├── scripts/                # 自动化脚本
├── timestamps-backup-all.txt  # 时间戳备份（自动维护）
└── .github/workflows/      # GitHub Actions 配置
```

## 四大系列

| 系列 | 目录 | 同步方式 | 说明 |
|------|------|----------|------|
| 电脑壁纸 | `wallpaper/desktop/` | 每日自动同步 | 从 Gitee 增量同步 |
| 手机壁纸 | `wallpaper/mobile/` | 手动上传 | 用户自行管理 |
| 头像 | `wallpaper/avatar/` | 手动上传 | 用户自行管理 |
| Bing 每日 | `bing/meta/` | 每日自动同步 | Bing 官方壁纸元数据 |

## 自动同步配置

| 配置项 | 说明 |
|--------|------|
| **同步频率** | 每天 UTC 22:00（北京时间 6:00） |
| **同步策略** | 增量同步（只添加新文件） |
| **自动打 Tag** | 同步有变更时自动创建版本 tag |
<!-- [DISABLED] R2 功能已暂停
| **R2 上传** | 自动上传到 Cloudflare R2 |
| **缓存清除** | 智能清除更新系列的 CDN 缓存 |
-->

## 本地图片处理

```bash
# 处理单个目录的图片
./scripts/local-process.sh ~/Pictures/new desktop 游戏 原神

# 批量处理多个目录
./scripts/batch-process.sh ~/Pictures/wallpaper-desktop desktop

# 一键发布
./scripts/release.sh
```

## 时间戳管理

时间戳备份文件 `timestamps-backup-all.txt` 自动维护，格式：
```
series|path|timestamp
desktop|动漫/二次元/xxx.jpg|1766324344
```

- 已有图片保持原时间戳
- 新增图片使用上海时区当前时间
- CI 自动提交时间戳更新

## Bing 每日壁纸

采用**纯元数据模式**，不下载图片，直接使用 Bing CDN 链接。

- 数据目录：`bing/meta/`
- 历史数据：2019年6月至今（2400+ 张）
- 图片来源：Bing 中国 CDN（cn.bing.com）

## 相关项目

- **Wallpaper Gallery** - 基于本图床的壁纸展示网站

## 许可证

MIT License

---

如果您觉得这个项目对您有帮助，欢迎点击 Star ⭐
