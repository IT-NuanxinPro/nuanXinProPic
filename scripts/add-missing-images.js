#!/usr/bin/env node
/**
 * 手动添加缺失的 6 张图片到 metadata
 */

const fs = require('fs')
const path = require('path')
const { execSync } = require('child_process')

// 要添加的 6 张图片信息
const missingImages = [
  {
    filename: '夜色泳池蕾塞.png',
    timestamp: 1768843486,
    tag: 'v1.1.41',
    keywords: ['夜色', '泳池', '蕾塞', '少女', '插画', '唯美'],
    description: '夜色泳池边的蕾塞少女插画',
    displayTitle: '夜色泳池蕾塞'
  },
  {
    filename: '林荫光影下戴眼镜的辫发少女.png',
    timestamp: 1768843486,
    tag: 'v1.1.41',
    keywords: ['林荫', '光影', '眼镜', '辫发', '少女', '清新', '文艺'],
    description: '林荫光影下戴眼镜的辫发少女',
    displayTitle: '林荫光影下戴眼镜的辫发少女'
  },
  {
    filename: '漆皮靴酷飒少女天台闲坐.png',
    timestamp: 1768843486,
    tag: 'v1.1.41',
    keywords: ['漆皮靴', '酷飒', '少女', '天台', '闲坐', '个性', '时尚'],
    description: '穿漆皮靴的酷飒少女在天台闲坐',
    displayTitle: '漆皮靴酷飒少女天台闲坐'
  },
  {
    filename: '粉发花环少女与眠猫.png',
    timestamp: 1768843486,
    tag: 'v1.1.41',
    keywords: ['粉发', '花环', '少女', '猫咪', '温馨', '治愈', '可爱'],
    description: '戴花环的粉发少女与睡眠的猫咪',
    displayTitle: '粉发花环少女与眠猫'
  },
  {
    filename: '蓝蝶轻倚的卷发少女_多花.png',
    timestamp: 1768843486,
    tag: 'v1.1.41',
    keywords: ['蓝蝶', '卷发', '少女', '花朵', '唯美', '梦幻', '浪漫'],
    description: '蓝色蝴蝶轻倚的卷发少女与繁花',
    displayTitle: '蓝蝶轻倚的卷发少女'
  },
  {
    filename: '霓虹电梯里的金发二次元少女.png',
    timestamp: 1768899389,
    tag: 'v1.1.42',
    keywords: ['霓虹', '电梯', '金发', '二次元', '少女', '赛博朋克', '科技感'],
    description: '霓虹灯光电梯里的金发二次元少女',
    displayTitle: '霓虹电梯里的金发二次元少女'
  }
]

// 获取图片分辨率
function getImageDimensions(filePath) {
  if (!fs.existsSync(filePath)) {
    console.log(`  文件不存在: ${filePath}`)
    return null
  }

  try {
    let cmd = 'magick identify'
    try {
      execSync('magick --version', { stdio: 'ignore' })
    } catch {
      cmd = 'identify'
    }

    const result = execSync(`${cmd} -format "%w %h" "${filePath}"`, {
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'ignore'],
    }).trim()

    const [width, height] = result.split(' ').map(Number)
    if (width > 0 && height > 0) {
      return { width, height }
    }
  } catch (e) {
    console.log(`  无法获取分辨率: ${e.message}`)
  }
  return null
}

// 根据分辨率生成标签
function getResolutionLabel(width, height) {
  const maxDim = Math.max(width, height)

  if (maxDim >= 15360) {
    return { label: '16K', type: 'danger' }
  } else if (maxDim >= 7680) {
    return { label: '8K', type: 'danger' }
  } else if (maxDim >= 5120) {
    return { label: '5K+', type: 'danger' }
  } else if (maxDim >= 4096) {
    return { label: '4K+', type: 'warning' }
  } else if (maxDim >= 3840) {
    return { label: '4K', type: 'success' }
  } else if (maxDim >= 2048) {
    return { label: '2K', type: 'info' }
  } else if (maxDim >= 1920) {
    return { label: '超清', type: 'primary' }
  } else if (maxDim >= 1280) {
    return { label: '高清', type: 'secondary' }
  } else {
    return { label: '标清', type: 'secondary' }
  }
}

// 从文件名提取关键词
function extractKeywordsFromFilename(filename) {
  const nameWithoutExt = filename.replace(/\.[^.]+$/, '')
  const separators = /[-_\s、，,&]+/
  const parts = nameWithoutExt.split(separators)
    .map(s => s.trim())
    .filter(s => s.length > 0 && s.length < 20)
    .filter(s => !/^\d+$/.test(s))
    .filter(s => !/^(jpg|png|webp|gif|jpeg)$/i.test(s))
  return [...new Set(parts)]
}

function main() {
  const projectRoot = process.argv[2] || '.'
  const metadataFile = path.join(projectRoot, 'metadata/desktop.json')

  console.log('========================================')
  console.log('添加缺失的 6 张图片到 metadata')
  console.log('========================================')
  console.log()

  // 读取现有 metadata
  if (!fs.existsSync(metadataFile)) {
    console.error('错误: metadata/desktop.json 不存在')
    process.exit(1)
  }

  const metadata = JSON.parse(fs.readFileSync(metadataFile, 'utf-8'))
  console.log(`当前 desktop 图片数量: ${metadata.count}`)
  console.log()

  let added = 0

  for (const img of missingImages) {
    const relativePath = `插画/通用/${img.filename}`
    const key = `wallpaper/desktop/${relativePath}`
    const fullPath = path.join(projectRoot, key)

    console.log(`处理: ${img.filename}`)

    // 检查是否已存在
    if (metadata.images[key]) {
      console.log(`  ⏭️  已存在，跳过`)
      console.log()
      continue
    }

    // 检查文件是否存在
    if (!fs.existsSync(fullPath)) {
      console.log(`  ❌ 文件不存在: ${fullPath}`)
      console.log()
      continue
    }

    // 获取文件大小
    const stats = fs.statSync(fullPath)
    const size = stats.size

    // 获取分辨率
    const dimensions = getImageDimensions(fullPath)
    let resolution = null
    if (dimensions) {
      const labelInfo = getResolutionLabel(dimensions.width, dimensions.height)
      resolution = {
        width: dimensions.width,
        height: dimensions.height,
        label: labelInfo.label,
        type: labelInfo.type
      }
      console.log(`  📐 分辨率: ${dimensions.width}x${dimensions.height} (${labelInfo.label})`)
    }

    // 使用预定义的关键词
    const keywords = img.keywords || extractKeywordsFromFilename(img.filename)
    const description = img.description || ''
    const displayTitle = img.displayTitle || img.filename.replace(/\.[^.]+$/, '')
    
    console.log(`  🏷️  关键词: ${keywords.join(', ')}`)
    console.log(`  📝 描述: ${description}`)

    // 创建 metadata 记录
    metadata.images[key] = {
      category: '插画',
      subcategory: '',
      filename: img.filename,
      createdAt: new Date(img.timestamp * 1000).toISOString(),
      cdnTag: img.tag,
      size: size,
      format: 'png',
      resolution: resolution,
      ai: {
        keywords: keywords,
        description: description,
        displayTitle: displayTitle,
        confidence: 0.8,
        model: 'manual-annotation',
        analyzedAt: new Date().toISOString()
      }
    }

    added++
    console.log(`  ✅ 已添加`)
    console.log()
  }

  // 更新 count 和 lastUpdated
  metadata.count = Object.keys(metadata.images).length
  metadata.lastUpdated = new Date().toISOString()

  // 保存 metadata
  fs.writeFileSync(metadataFile, JSON.stringify(metadata, null, 2), 'utf-8')

  console.log('========================================')
  console.log(`✅ 完成! 新增 ${added} 张图片`)
  console.log(`📊 当前总数: ${metadata.count} 张`)
  console.log('========================================')
}

main()
