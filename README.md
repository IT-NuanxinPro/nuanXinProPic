# 暖心图床 — GitHub + R2 图片/视频托管与壁纸数据源

![GitHub stars](https://img.shields.io/github/stars/IT-NuanxinPro/nuanXinProPic?style=social)
![GitHub forks](https://img.shields.io/github/forks/IT-NuanxinPro/nuanXinProPic?style=social)

## 项目简介

暖心图床是 Wallpaper Gallery 的内容源仓库，负责统一管理图片、视频、预览图、缩略图、元数据与前端消费用分片数据。
当前资源分发采用：

- 图片：GitHub + jsDelivr
- 动态壁纸视频：Cloudflare R2 + `img.061129.xyz`
- 前端消费数据：仓库内 `data/` 与 `bing/meta/`

### 特色功能

- 支持多种图片格式（PNG、JPG、GIF、WebP 等）
- 支持多种视频格式（MP4、WebM、MOV、M4V）
- **Cloudflare R2 CDN 加速** - 动态壁纸视频资源主分发
- **jsDelivr 备用** - GitHub Release 自动回退
- 永久免费存储
- **自动同步壁纸** - 每日从 Gitee 增量同步精选壁纸
- **自动生成缩略图** - WebP 格式，350px，75% 质量，带双水印
- **自动生成预览图** - WebP 格式，无水印
  - Desktop: 1920px，78% 质量
  - Mobile: 1080px，75% 质量
- **动态壁纸数据导出** - 为前端生成 `data/video/`、`data/video.json` 与视频元数据
- **视频资源优化脚本** - 提供首帧预览生成、循环播放优化与视频元数据提取

## 目录结构

```
nuanXinProPic/
├── wallpaper/              # 壁纸原图目录
│   ├── desktop/            # 电脑壁纸（每日自动同步）
│   ├── mobile/             # 手机壁纸
│   ├── avatar/             # 头像
│   └── video/              # 动态壁纸视频资源
├── thumbnail/              # 壁纸缩略图（WebP，带水印）
├── preview/                # 壁纸预览图（WebP，无水印）
├── metadata/               # 图片元数据（AI 分析结果）
│   ├── desktop.json        # 电脑壁纸元数据
│   ├── mobile.json         # 手机壁纸元数据
│   ├── avatar.json         # 头像元数据
│   └── video.json          # 动态壁纸元数据
├── metadata-pending/       # 待处理的元数据（上传系统生成）
├── data/                   # 前端分片数据（按分类）
│   ├── desktop/            # 电脑壁纸分类数据
│   ├── mobile/             # 手机壁纸分类数据
│   ├── avatar/             # 头像分类数据
│   └── video/              # 动态壁纸分类数据
├── bing/meta/              # Bing 每日壁纸元数据
├── scripts/                # 自动化脚本
├── stats.json              # 壁纸统计和发布历史
├── timestamps-backup-all.txt  # 时间戳备份（自动维护）
└── .github/workflows/      # GitHub Actions 配置
```

## 五大系列

| 系列 | 目录 | 同步方式 | 说明 |
|------|------|----------|------|
| 电脑壁纸 | `wallpaper/desktop/` | 每日自动同步 | 从 Gitee 增量同步 |
| 动态壁纸 | `wallpaper/video/` | 手动维护 / 工作流处理 | 视频资源、预览图、缩略图与元数据 |
| 手机壁纸 | `wallpaper/mobile/` | 手动上传 | 用户自行管理 |
| 头像 | `wallpaper/avatar/` | 手动上传 | 用户自行管理 |
| Bing 每日 | `bing/meta/` | 每日自动同步 | Bing 官方壁纸元数据 |

## 自动同步配置

| 配置项 | 说明 |
|--------|------|
| **同步频率** | 每天 UTC 22:00（北京时间 6:00） |
| **同步策略** | 增量同步（只添加新文件） |
| **自动打 Tag** | 同步有变更时自动创建版本 tag |
| **R2 上传** | 可通过工作流或脚本同步到 Cloudflare R2 |
| **缓存清除** | 由前端部署与资源版本号共同控制刷新 |

## 本地图片处理

```bash
# 处理单个目录的图片
./scripts/local-process.sh ~/Pictures/new desktop 游戏 原神

# 批量处理多个目录
./scripts/batch-process.sh ~/Pictures/wallpaper-desktop desktop

# 一键发布
./scripts/release.sh
```

## 动态壁纸处理

```bash
# 为单个视频生成首帧预览图和缩略图
./scripts/process-video.sh wallpaper/video/desktop/通用/demo.mp4

# 压缩并优化视频循环播放体验
./scripts/optimize-video-loop.sh wallpaper/video/desktop/动漫/demo.mp4

# 上传全部资源到 R2
./scripts/upload-r2.sh
```

说明：

- `wallpaper/video/` 保存原始视频
- `preview/video/` 保存 1080p 预览视频
- `thumbnail/video/` 保存视频列表缩略图
- 前端动态壁纸视频资源默认从 `https://img.061129.xyz` 读取

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

## 相关前端数据

图床仓库会生成并维护前端直接消费的数据：

- `data/desktop/*`
- `data/mobile/*`
- `data/avatar/*`
- `data/video/*`
- `data/*.json`
- `bing/meta/*`

其中：

- `data/video/` 与 `metadata/video.json` 共同驱动动态壁纸专区
- `wallpaper-gallery` 部署阶段会直接复制这些文件，而不是运行时实时拼接

## 相关项目

- **Wallpaper Gallery** - 基于本图床的壁纸展示网站

## 许可证

MIT License

---

如果您觉得这个项目对您有帮助，欢迎点击 Star ⭐
