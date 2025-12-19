# 壁纸同步功能实现计划

## 任务背景
从 Gitee 仓库 (zhang--shuang/desktop_wallpaper) 定时同步壁纸到本 GitHub 图床项目。

## 需求确认
- **同步方式**: 定时自动同步（GitHub Actions）
- **冲突处理**: 跳过已存在的文件
- **目标目录**: wallpaper 子目录

## 技术方案
采用 GitHub Actions + Shallow Clone 方案：
1. 每天 UTC 0:00（北京时间 8:00）自动触发
2. Shallow clone Gitee 仓库获取最新图片
3. 遍历比对，仅复制不存在的新图片
4. 自动提交并推送到 GitHub

## 文件清单

### 新建文件
1. `.github/workflows/sync-wallpaper.yml` - GitHub Actions 工作流
2. `scripts/sync-wallpaper.sh` - 同步脚本
3. `wallpaper/.gitkeep` - 保持目录存在

## 使用说明

### 自动同步
- 每天北京时间 8:00 自动运行
- 有新图片时自动提交

### 手动触发
1. 进入 GitHub 仓库 → Actions
2. 选择 "Sync Wallpaper from Gitee"
3. 点击 "Run workflow"

### 本地测试
```bash
cd /path/to/nuanXinProPic
./scripts/sync-wallpaper.sh
```

## 注意事项
- 首次运行会同步所有61张图片
- 后续运行仅同步新增图片
- 同名文件会被跳过，不会覆盖
