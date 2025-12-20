# 暖心图床

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
- **自动同步壁纸** - 每日从 Gitee 全量同步精选壁纸
- **自动生成缩略图** - 同步时自动生成 WebP 格式缩略图，加速网页加载

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
├── wallpaper/     # 自动同步的壁纸原图（每日全量更新）
├── thumbnail/     # 自动生成的壁纸缩略图（WebP 格式，400px 宽）
├── blog/          # 博客相关图片
├── docs/          # 文档相关图片
├── projects/      # 项目相关图片
├── others/        # 其他类型图片
├── scripts/       # 自动化脚本
│   └── sync-wallpaper.sh  # 壁纸同步脚本
└── .github/
    └── workflows/
        └── sync-wallpaper.yml  # GitHub Actions 自动同步配置
```

## 壁纸自动同步

本项目通过 GitHub Actions 每日自动从 [Gitee/desktop_wallpaper](https://gitee.com/zhang--shuang/desktop_wallpaper) 同步精选壁纸。

### 同步配置

| 配置项 | 说明 |
|--------|------|
| **同步频率** | 每天 UTC 0:00（北京时间 8:00） |
| **同步策略** | 全量覆盖（删除旧文件后重新同步） |
| **原图目录** | `wallpaper/` |
| **缩略图目录** | `thumbnail/` |
| **缩略图格式** | WebP，宽度 400px，质量 80% |

### 访问链接格式

**原图**：
```
https://raw.githubusercontent.com/IT-NuanxinPro/nuanXinProPic/main/wallpaper/图片名称.jpg
```

**缩略图**：
```
https://raw.githubusercontent.com/IT-NuanxinPro/nuanXinProPic/main/thumbnail/图片名称.webp
```

### 手动触发同步

除了每日自动同步，也可以在 GitHub 仓库的 **Actions** 页面手动触发 `Sync Wallpaper from Gitee` 工作流。

## 相关项目

- [Wallpaper Gallery](https://github.com/IT-NuanxinPro/wallpaper-gallery) - 基于本图床的壁纸展示网站

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
