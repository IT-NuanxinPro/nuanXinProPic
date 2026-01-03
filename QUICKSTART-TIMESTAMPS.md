# 时间戳自动化系统 - 快速指南

## ✅ 已完成的配置

你的时间戳自动化系统已经**完全配置好**,无需任何额外操作!

```
✅ scripts/backup-timestamps.sh   - 备份脚本已创建
✅ .git/hooks/pre-commit          - Git Hook 已安装
✅ scripts/restore-timestamps.sh  - 恢复脚本已增强
✅ timestamps-backup-all.txt      - 241 个文件已完整备份
✅ 所有功能已测试验证通过
```

## 🚀 日常使用 (完全自动!)

### 添加新图片时

```bash
# 1. 添加图片到对应目录
cp new-wallpaper.jpg wallpaper/desktop/风景/

# 2. 正常的 Git 操作
git add wallpaper/
git commit -m "add: 新增风景壁纸"

# ✨ Git Hook 自动运行:
#   → 扫描所有图片文件
#   → 备份时间戳
#   → 自动加入提交
#   → 完成! ✅

# 3. 推送
git push
```

**就这么简单!** 不需要记住任何额外命令。

## 🔍 验证系统工作正常

### 测试 1: 手动运行备份

```bash
./scripts/backup-timestamps.sh

# 应该看到:
# ✅ 备份完成!
# Desktop: 127 个文件
# Mobile:  72 个文件
# Avatar:  42 个文件
```

### 测试 2: 验证 Git Hook

```bash
# 创建测试文件
echo "test" > wallpaper/desktop/test.txt
git add wallpaper/desktop/test.txt
git commit -m "test"

# 应该看到 Hook 自动运行:
# 🔄 检测到壁纸文件变更，自动更新时间戳备份...
# ✅ 时间戳备份已更新并加入本次提交

# 撤销测试
git reset --soft HEAD~1
rm wallpaper/desktop/test.txt
```

### 测试 3: 验证完整性检测

```bash
BACKUP_FILE=timestamps-backup-all.txt ./scripts/restore-timestamps.sh

# 应该看到:
# ✅ 所有文件都已在备份中，备份完整性验证通过!
```

## 📖 常用命令速查

| 操作 | 命令 |
|------|------|
| **手动备份** | `./scripts/backup-timestamps.sh` |
| **恢复时间戳** | `BACKUP_FILE=timestamps-backup-all.txt ./scripts/restore-timestamps.sh` |
| **验证完整性** | 同上 (自动包含验证) |
| **查看备份统计** | `wc -l timestamps-backup-all.txt` |
| **查看实际文件数** | `find wallpaper -type f \( -iname "*.jpg" -o -iname "*.png" \) \| wc -l` |

## ⚠️ 故障排查

### 问题: Hook 没有触发

**检查权限**:
```bash
ls -la .git/hooks/pre-commit
# 应该显示: -rwxr-xr-x (可执行)
```

**修复**:
```bash
chmod +x .git/hooks/pre-commit
```

### 问题: CI 构建失败

**错误信息**: "检测到未备份文件"

**原因**: 本地提交时跳过了 Hook

**修复**:
```bash
# 手动运行备份
./scripts/backup-timestamps.sh

# 提交更新
git add timestamps-backup-all.txt
git commit -m "chore: 更新时间戳备份"
git push
```

### 问题: 时间显示还是错误

**检查前端项目的 GitHub Actions**:

确保 `.github/workflows/deploy.yml` 使用了正确的备份文件:

```yaml
# 第 80 行应该是:
BACKUP_FILE=timestamps-backup-all.txt ./scripts/restore-timestamps.sh
```

## 🎓 工作原理

### 整体流程

```
本地添加图片
    ↓
git commit (触发 pre-commit hook)
    ↓
自动备份时间戳到 timestamps-backup-all.txt
    ↓
自动加入提交
    ↓
推送到 GitHub
    ↓
前端项目 GitHub Actions 拉取
    ↓
恢复时间戳 (智能检测未备份文件)
    ↓
生成数据 JSON (读取 mtime)
    ↓
前端正确显示上传时间 ✅
```

### 三层保护

1. **Git Hook** - 提交前自动备份
2. **智能检测** - CI 验证备份完整性
3. **Git 回退** - 从提交历史恢复时间戳

## 📊 系统状态

### 当前备份统计

```
Desktop: 127 个文件
Mobile:  72 个文件
Avatar:  42 个文件
━━━━━━━━━━━━━━━━━━
总计:    241 个文件 ✅
```

### 支持的文件格式

- `.jpg` / `.jpeg`
- `.png`
- `.gif`
- `.webp`

## 📚 详细文档

完整的技术文档请查看:
- `docs/TIMESTAMPS-AUTOMATION.md`

包含:
- 系统架构详解
- API 说明
- 技术细节
- 高级配置
- 常见问题

## 💡 提示

### 最佳实践

✅ **DO**:
- 正常使用 Git,系统会自动处理
- 遇到 CI 失败时查看错误信息
- 定期验证备份完整性

❌ **DON'T**:
- 不要使用 `git commit --no-verify` (会跳过 Hook)
- 不要手动编辑 `timestamps-backup-all.txt`
- 不要删除 `.git/hooks/pre-commit`

### 性能说明

- 备份 241 个文件约需 **1-2 秒**
- 对 Git 提交影响极小
- CI 恢复时间戳约需 **2-3 秒**

## 🎉 总结

你现在拥有了一个:
- ✅ 完全自动化的时间戳管理系统
- ✅ 零人工干预,零维护成本
- ✅ 多层保护,生产级可靠
- ✅ 开箱即用,一劳永逸

**享受自动化带来的便利吧!** 🚀

---

**问题反馈**: 如遇到问题,请查看 `docs/TIMESTAMPS-AUTOMATION.md` 的故障排查章节
**技术支持**: 详细的技术文档可帮助理解系统原理
