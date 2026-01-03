# 暖心图床 — 免费永久图片托管 & 自动壁纸同步

![GitHub stars](https://img.shields.io/github/stars/IT-NuanxinPro/nuanXinProPic?style=social)
![GitHub forks](https://img.shields.io/github/forks/IT-NuanxinPro/nuanXinProPic?style=social)

## 项目简介

暖心图床是一个基于 GitHub 的个人图片托管服务，为博客写作、文档编写等场景提供稳定可靠的图片存储解决方案。通过 GitHub 的全球 CDN 加速，确保图片访问的快速响应。

### 特色功能

- 支持多种图片格式（PNG、JPG、GIF、WebP 等）
- 全球 CDN 加速访问
- 永久免费存储
- 安全可靠的备份机制
- 无限图片容量
- 简单易用的管理方式
- **自动同步壁纸** - 每日从 Gitee 增量同步精选壁纸
- **自动生成缩略图** - 同步时自动生成带双水印 WebP 格式缩略图（350px，75%），加速网页加载
- **自动生成预览图** - 同步时自动生成 WebP 格式预览图
  - Desktop: 1920px，78% 质量（无水印，适合大屏预览）
  - Mobile: 1080px，75% 质量（无水印，适合长屏，节省带宽）

## 使用指南

### 图片上传方式

1. **直接上传**
   - 克隆仓库到本地
   - 将图片文件添加到相应目录
   - 提交并推送更改

2. **通过 Issues 上传**
   - 打开 Issues 页面
   - 将图片拖拽到评论区
   - 等待自动生成图片链接

### 图片链接获取

上传成功后，可通过以下格式获取图片链接：

```
https://raw.githubusercontent.com/IT-NuanxinPro/nuanXinProPic/main/图片路径
```

## 目录结构

```
nuanXinProPic/
├── wallpaper/              # 壁纸原图目录
│   ├── desktop/            # 电脑壁纸（每日自动同步）
│   ├── mobile/             # 手机壁纸（手动管理）
│   └── avatar/             # 头像（手动管理）
├── thumbnail/              # 壁纸缩略图目录（WebP 格式，350px 宽，带双水印）
│   ├── desktop/            # 电脑壁纸缩略图
│   ├── mobile/             # 手机壁纸缩略图
│   └── avatar/             # 头像缩略图
├── preview/                # 壁纸预览图目录（WebP 格式，无水印）
│   ├── desktop/            # 电脑壁纸预览图（1920px，78%）
│   └── mobile/             # 手机壁纸预览图（1080px，75%，长屏优化）
├── blog/                   # 博客相关图片
├── docs/                   # 文档相关图片
├── projects/               # 项目相关图片
├── others/                 # 其他类型图片
├── scripts/                # 自动化脚本
│   ├── sync-wallpaper.sh       # Gitee 壁纸同步脚本
│   ├── local-process.sh        # 本地图片处理脚本
│   ├── batch-process.sh        # 批量处理脚本
│   ├── create-local-folders.sh # 生成本地空目录结构
│   ├── release.sh              # 发布脚本（commit+tag+push）
│   ├── backup-timestamps.sh    # 时间戳备份脚本（自动）
│   └── restore-timestamps.sh   # 时间戳恢复脚本（CI 使用）
├── docs/                   # 文档目录
│   └── 时间戳自动化系统.md # 时间戳管理详细文档
├── 时间戳快速指南.md       # 时间戳系统快速入门
├── timestamps-backup-all.txt # 文件时间戳备份（自动维护）
└── .github/
    └── workflows/
        └── sync-wallpaper.yml  # GitHub Actions 自动同步配置
```

## 三大系列说明

| 系列 | 目录 | 同步方式 | 说明 |
|------|------|----------|------|
| 电脑壁纸 | `wallpaper/desktop/` | 每日自动同步 | 从 Gitee 增量同步 |
| 手机壁纸 | `wallpaper/mobile/` | 手动上传 | 用户自行管理 |
| 头像 | `wallpaper/avatar/` | 手动上传 | 用户自行管理 |

## 壁纸自动同步

本项目通过 GitHub Actions 每日自动从 [Gitee/desktop_wallpaper](https://gitee.com/zhang--shuang/desktop_wallpaper) 同步精选壁纸。

### 同步配置

| 配置项 | 说明 |
|--------|------|
| **同步频率** | 每天 UTC 22:00（北京时间 6:00） |
| **同步策略** | 增量同步（只添加新文件，不删除已有文件） |
| **自动打 Tag** | 同步有变更时自动创建版本 tag（如 v1.0.5） |
| **原图目录** | `wallpaper/desktop/` |
| **缩略图目录** | `thumbnail/desktop/` |
| **缩略图格式** | WebP，宽度 350px，质量 75%，带双水印 |
| **预览图目录** | `preview/desktop/` |
| **预览图格式** | Desktop: WebP，1920px，78%（无水印）<br>Mobile: WebP，1080px，75%（无水印，长屏优化） |
| **水印配置** | 仅缩略图添加水印：文字"暖心"，40% 透明度，双水印（右下 -25° + 左下水平） |
| **缩略图水印** | 2% 字号，右下偏移 20x40，左下偏移 20x40 |
| **文件名格式** | `分类--名称.扩展名`（如：`动漫--原神_雷电将军.jpg`） |
| **时间戳保留** | 使用 `cp -p` 保留源文件修改时间，确保前端时间排序正确 |

### 自动版本管理

同步流程会自动管理版本号：

1. **检测变更** - 检查是否有新壁纸同步
2. **自动打 Tag** - 有变更时自动递增版本号（v1.0.x）
3. **触发前端** - 前端项目构建时自动获取最新 tag

```
每日 6:00 同步 → 检测变更 → 自动打 tag (v1.0.x) → 前端 8:00 构建时自动获取
```

### 本地图片处理

本地新增图片时，使用以下脚本处理：

```bash
# 1. 生成本地空目录结构（可选，用于整理本地图片）
./scripts/create-local-folders.sh mobile /Users/xxx/Pictures/wallpaper-mobile

# 2. 处理单个目录的图片
./scripts/local-process.sh ~/Pictures/new desktop 游戏 原神

# 3. 批量处理多个目录（目录结构：一级分类/二级分类/图片）
./scripts/batch-process.sh ~/Pictures/wallpaper-desktop desktop
```

### 本地手动发布

处理完图片后，使用便捷脚本一键发布：

```bash
# 一键发布（自动提交 + 打 tag + 推送）
./scripts/release.sh

# 或带自定义提交信息
./scripts/release.sh "feat: 添加圣诞节壁纸"
```

脚本会自动：
- 显示待提交的更改
- 计算新版本号 (v1.0.4 → v1.0.5)
- 提交代码并创建 tag
- 推送到远程仓库

## 时间戳自动化系统

本项目实现了完全自动化的文件时间戳管理系统，确保图片的上传时间在 Git 仓库和前端展示中保持准确。

### 核心功能

**方案 A: Git Hook 自动备份**
- ✅ 提交前自动运行备份脚本
- ✅ 自动将备份文件加入提交
- ✅ 100% 避免人为遗忘

**方案 C: 智能回退机制**
- ✅ CI 环境验证备份完整性
- ✅ 检测未备份的新文件
- ✅ 从 Git 历史自动恢复时间戳
- ✅ 多层保护确保数据准确

### 使用说明

日常添加图片时，**完全自动化，无需任何额外操作**：

```bash
# 1. 正常添加图片
cp new-image.jpg wallpaper/desktop/风景/

# 2. 正常提交
git add wallpaper/
git commit -m "add: 新增风景壁纸"

# ✨ Git Hook 自动运行:
#   → 扫描所有图片文件
#   → 备份时间戳
#   → 自动加入提交

# 3. 推送
git push
```

### 系统特性

- **完全自动化** - 零人工干预，零维护成本
- **多层保护** - Git Hook + 智能检测 + Git 回退
- **生产级可靠** - CI 环境强制验证
- **开箱即用** - 所有配置已完成

### 文档说明

- **快速入门**: `时间戳快速指南.md` - 包含使用指南、验证方法、故障排查
- **详细文档**: `docs/时间戳自动化系统.md` - 包含系统架构、技术细节、API 说明

### 备份统计

```
Desktop: 127 个文件 ✅
Mobile:  72 个文件 ✅
Avatar:  42 个文件 ✅
━━━━━━━━━━━━━━━━━━
总计:    241 个文件
```

备份文件: `timestamps-backup-all.txt` (自动维护，请勿手动编辑)

### 访问链接格式

**电脑壁纸原图**：
```
https://raw.githubusercontent.com/IT-NuanxinPro/nuanXinProPic/main/wallpaper/desktop/图片名称.jpg
```

**电脑壁纸缩略图**：
```
https://raw.githubusercontent.com/IT-NuanxinPro/nuanXinProPic/main/thumbnail/desktop/图片名称.webp
```

### 手动触发同步

除了每日自动同步，也可以在 GitHub 仓库的 **Actions** 页面手动触发 `Sync Wallpaper from Gitee` 工作流。

## 相关项目

- **Wallpaper Gallery** - 基于本图床的壁纸展示网站，访问 [我的 GitHub 主页](https://github.com/IT-NuanxinPro) 查看更多项目

## 贡献指南

欢迎提出问题和建议！如果您想为项目做出贡献，请：

1. Fork 本仓库
2. 创建您的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交您的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开一个 Pull Request

## 使用建议

- 建议上传图片时使用有意义的文件名
- 适当压缩图片以节省空间
- 遵循目录结构规范存放图片
- 定期清理不需要的图片

## 许可证

本项目采用 MIT 许可证 - 详情请参见 [LICENSE](LICENSE) 文件

## 联系方式

如有任何问题或建议，欢迎通过以下方式联系：

- 提交 [Issues](https://github.com/IT-NuanxinPro/nuanXinProPic/issues)
- GitHub 主页: [@IT-NuanxinPro](https://github.com/IT-NuanxinPro)

---

如果您觉得这个项目对您有帮助，欢迎点击右上角的 Star 按钮，感谢您的支持！
