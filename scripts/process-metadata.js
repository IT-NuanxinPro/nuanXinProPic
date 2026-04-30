#!/usr/bin/env node
/**
 * 处理 metadata-pending 增量文件
 *
 * 功能：
 * 1. 读取 metadata-pending/*.json 文件
 * 2. 合并到 metadata/{series}.json
 * 3. 生成 data/{series}/index.json 和 data/{series}/{category}.json 供前端使用
 * 4. 清理已处理的 pending 文件
 *
 * 用法：
 *   node scripts/process-metadata.js <图床仓库路径> [新tag] [--force]
 *
 * 参数：
 *   --force  强制重新生成前端数据（即使没有新增图片）
 */

const fs = require('fs')
const path = require('path')
const { execSync } = require('child_process')

// 图床仓库根路径（在 main 中设置）
let imageRepoRoot = '.'

// 字符映射表（与前端 codec-config.js 一致）
const CHAR_MAP_ENCODE = {
  'A': 'Q', 'B': 'W', 'C': 'E', 'D': 'R', 'E': 'T',
  'F': 'Y', 'G': 'U', 'H': 'I', 'I': 'O', 'J': 'P',
  'K': 'A', 'L': 'S', 'M': 'D', 'N': 'F', 'O': 'G',
  'P': 'H', 'Q': 'J', 'R': 'K', 'S': 'L', 'T': 'Z',
  'U': 'X', 'V': 'C', 'W': 'V', 'X': 'B', 'Y': 'N',
  'Z': 'M',
  'a': 'q', 'b': 'w', 'c': 'e', 'd': 'r', 'e': 't',
  'f': 'y', 'g': 'u', 'h': 'i', 'i': 'o', 'j': 'p',
  'k': 'a', 'l': 's', 'm': 'd', 'n': 'f', 'o': 'g',
  'p': 'h', 'q': 'j', 'r': 'k', 's': 'l', 't': 'z',
  'u': 'x', 'v': 'c', 'w': 'v', 'x': 'b', 'y': 'n',
  'z': 'm',
  '0': '5', '1': '6', '2': '7', '3': '8', '4': '9',
  '5': '0', '6': '1', '7': '2', '8': '3', '9': '4',
  '+': '-', '/': '_', '=': '.'
}

const VERSION_PREFIX = 'v1.'
const LATEST_SLICE_SIZE = 40

function compareWallpapers(a, b) {
  const dateDiff = new Date(b.createdAt || 0) - new Date(a.createdAt || 0)
  if (dateDiff !== 0) {
    return dateDiff
  }

  return String(a.filename || '').localeCompare(String(b.filename || ''))
}

function formatDateTime(date = new Date()) {
  const pad = value => String(value).padStart(2, '0')

  return [
    date.getFullYear(),
    pad(date.getMonth() + 1),
    pad(date.getDate()),
  ].join('-') + ` ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
}

// 编码函数（与前端一致）
function encodeData(data) {
  const jsonStr = typeof data === 'string' ? data : JSON.stringify(data)
  const base64 = Buffer.from(jsonStr, 'utf-8').toString('base64')

  // 字符映射
  let mapped = ''
  for (const char of base64) {
    mapped += CHAR_MAP_ENCODE[char] || char
  }

  // 添加版本前缀 + 反转字符串
  return VERSION_PREFIX + mapped.split('').reverse().join('')
}

// 获取图片分辨率
function getImageDimensions(filePath) {
  if (!fs.existsSync(filePath)) {
    return null
  }

  try {
    // 尝试使用 ImageMagick 7 (magick) 或 ImageMagick 6 (identify)
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
  } catch {
    // ImageMagick 不可用或执行失败，静默忽略
  }
  return null
}

function getVideoMetadata(filePath) {
  if (!fs.existsSync(filePath)) {
    return null
  }

  try {
    const result = execSync(`ffprobe -v quiet -print_format json -show_format -show_streams "${filePath}"`, {
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'ignore'],
    }).trim()

    if (!result) {
      return null
    }

    const parsed = JSON.parse(result)
    const videoStream = Array.isArray(parsed.streams)
      ? parsed.streams.find(stream => stream.codec_type === 'video')
      : null

    const width = Number(videoStream?.width || 0)
    const height = Number(videoStream?.height || 0)
    const duration = Number(parsed.format?.duration || videoStream?.duration || 0)
    const size = Number(parsed.format?.size || 0)

    return {
      width: width > 0 ? width : null,
      height: height > 0 ? height : null,
      duration: Number.isFinite(duration) && duration > 0 ? Number(duration.toFixed(1)) : null,
      size: Number.isFinite(size) && size > 0 ? size : 0,
    }
  } catch {
    return null
  }
}

// 根据分辨率生成标签信息
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

// 获取媒体资源信息（分辨率、时长、文件大小）
function getMediaInfo(relativePath) {
  const filePath = path.join(imageRepoRoot, relativePath)

  if (!fs.existsSync(filePath)) {
    return { resolution: null, size: 0, duration: null, mediaType: 'image' }
  }

  const extension = path.extname(relativePath).toLowerCase()
  const isVideo = ['.mp4', '.webm', '.mov', '.m4v'].includes(extension)
  const stats = fs.statSync(filePath)
  const size = stats.size
  const dimensions = isVideo ? getVideoMetadata(filePath) : getImageDimensions(filePath)

  let resolution = null
  if (dimensions?.width && dimensions?.height) {
    const labelInfo = getResolutionLabel(dimensions.width, dimensions.height)
    resolution = {
      width: dimensions.width,
      height: dimensions.height,
      label: labelInfo.label,
      type: labelInfo.type
    }
  }

  return {
    resolution,
    size: dimensions?.size || size,
    duration: isVideo ? (dimensions?.duration || null) : null,
    mediaType: isVideo ? 'video' : 'image',
  }
}

function findActualImagePath(expectedRelativePath) {
  const expectedPath = path.join(imageRepoRoot, expectedRelativePath)
  if (fs.existsSync(expectedPath)) {
    return expectedRelativePath
  }

  const parts = expectedRelativePath.split('/')
  if (parts.length < 4) {
    return expectedRelativePath
  }

  const series = parts[1]
  const filename = parts[parts.length - 1]
  const seriesRoot = path.join(imageRepoRoot, 'wallpaper', series)
  if (!fs.existsSync(seriesRoot)) {
    return expectedRelativePath
  }

  const stack = [seriesRoot]
  while (stack.length > 0) {
    const currentDir = stack.pop()
    const entries = fs.readdirSync(currentDir, { withFileTypes: true })

    for (const entry of entries) {
      const fullPath = path.join(currentDir, entry.name)
      if (entry.isDirectory()) {
        stack.push(fullPath)
        continue
      }

      if (entry.isFile() && entry.name === filename) {
        return path.relative(imageRepoRoot, fullPath).replace(/\\/g, '/')
      }
    }
  }

  return expectedRelativePath
}

function reconcileMetadataImagePath(relativePath, imageData) {
  const actualRelativePath = findActualImagePath(relativePath)
  const absolutePath = path.join(imageRepoRoot, actualRelativePath)

  if (!fs.existsSync(absolutePath)) {
    return { relativePath, imageData, changed: false, missing: true }
  }

  if (actualRelativePath === relativePath) {
    return { relativePath, imageData, changed: false, missing: false }
  }

  const pathParts = actualRelativePath.split('/')
  const filename = pathParts[pathParts.length - 1]
  const category = pathParts[2] || imageData.category || '未分类'
  const subcategory = pathParts.length > 4 ? pathParts[3] : ''

  return {
    relativePath: actualRelativePath,
    imageData: {
      ...imageData,
      category,
      subcategory,
      filename,
    },
    changed: true,
    missing: false,
  }
}

function resolveDerivedAssetPath(projectRoot, series, subdir, filenameNoExt, type) {
  const extensionCandidates = type === 'preview' && series === 'video'
    ? ['.mp4', '.webm', '.mov', '.m4v']
    : ['.webp', '.png', '.jpg', '.jpeg']

  for (const ext of extensionCandidates) {
    const relativeAssetPath = subdir
      ? `${type}/${series}/${subdir}/${filenameNoExt}${ext}`
      : `${type}/${series}/${filenameNoExt}${ext}`
    const absoluteAssetPath = path.join(projectRoot, relativeAssetPath)

    if (fs.existsSync(absoluteAssetPath)) {
      return `/${relativeAssetPath}`.replace(/\\/g, '/')
    }
  }

  const fallbackPath = subdir
    ? `${type}/${series}/${subdir}/${filenameNoExt}${extensionCandidates[0]}`
    : `${type}/${series}/${filenameNoExt}${extensionCandidates[0]}`

  return `/${fallbackPath}`.replace(/\\/g, '/')
}

// 读取或初始化 metadata JSON
function loadMetadata(filePath) {
  if (fs.existsSync(filePath)) {
    try {
      return JSON.parse(fs.readFileSync(filePath, 'utf-8'))
    } catch (e) {
      console.warn(`  警告: 无法解析 ${filePath}，将创建新文件`)
    }
  }
  return {
    version: 2,
    series: path.basename(filePath, '.json'),
    lastUpdated: formatDateTime(),
    count: 0,
    images: {}
  }
}

// 保存 metadata JSON
function saveMetadata(filePath, data) {
  data.lastUpdated = formatDateTime()
  data.count = Object.keys(data.images).length
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf-8')
}

// 处理单个 pending 文件
function processPendingFile(pendingFile, metadataMap, newTag) {
  const content = fs.readFileSync(pendingFile, 'utf-8')
  const pending = JSON.parse(content)

  let processed = 0

  for (const image of pending.images || []) {
    const series = image.series
    if (!metadataMap[series]) {
      console.warn(`  警告: 未知的 series: ${series}`)
      continue
    }

    // 使用 relativePath 作为 key
    const key = image.relativePath

    // 检查是否已存在记录
    const existingImage = metadataMap[series].images[key]
    
    if (!existingImage) {
      // 图片不存在，创建新记录
      // 获取资源信息（分辨率 + 文件大小 + 视频时长）
      let imageInfo = {
        resolution: image.resolution,
        size: image.size || 0,
        duration: image.duration || null,
        mediaType: image.mediaType || 'image',
      }

      // 如果 pending 数据中没有提供完整信息，从文件读取
      if (!imageInfo.resolution || imageInfo.size === 0 || (imageInfo.mediaType === 'video' && imageInfo.duration == null)) {
        const fileInfo = getMediaInfo(key)
        if (!imageInfo.resolution) {
          imageInfo.resolution = fileInfo.resolution
        }
        if (imageInfo.size === 0) {
          imageInfo.size = fileInfo.size
        }
        if (imageInfo.duration == null) {
          imageInfo.duration = fileInfo.duration
        }
        imageInfo.mediaType = imageInfo.mediaType || fileInfo.mediaType
      }

      // 处理 AI 元数据：从 filename 提取 displayTitle
      const aiData = image.ai || {
        keywords: [],
        description: '',
        displayTitle: '',
        aiFilename: '',
        confidence: 0,
        model: 'none',
        analyzedAt: null
      }

      // 如果 AI 生成了 filename，提取标题和文件名
      if (aiData.filename) {
        // displayTitle：去掉扩展名的标题
        const filenameWithoutExt = aiData.filename.replace(/\.[^.]+$/, '')
        aiData.displayTitle = aiData.displayTitle || filenameWithoutExt

        // 保留 AI 建议的文件名（可能是数组，取第一个）
        aiData.aiFilename = Array.isArray(aiData.filename)
          ? aiData.filename[0]
          : aiData.filename

        // 清理临时字段
        delete aiData.filename
      }

      metadataMap[series].images[key] = {
        category: image.category,
        subcategory: image.subcategory || '',
        usage: image.usage || (series === 'video' ? image.category : undefined),
        topic: image.topic || (series === 'video' ? (image.subcategory || '通用') : undefined),
        filename: image.filename,
        createdAt: image.createdAt,
        cdnTag: newTag,
        size: imageInfo.size,
        format: image.format || 'jpg',
        resolution: imageInfo.resolution,
        duration: imageInfo.duration,
        mediaType: imageInfo.mediaType || 'image',
        ai: aiData
      }
      processed++
      console.log(`    + ${key}`)
    } else {
      // 图片已存在，检查是否需要合并 AI 数据
      const existingAI = existingImage.ai || {}
      const newAI = image.ai || {}
      
      // 判断是否需要更新 AI 数据（新数据更完整或置信度更高）
      const shouldUpdateAI = (
        // 现有数据没有 AI 分析结果
        !existingAI.analyzedAt ||
        existingAI.model === 'filename-inference' ||
        // 新数据有更高的置信度
        (newAI.confidence > existingAI.confidence) ||
        // 新数据有更完整的信息
        (newAI.description && !existingAI.description) ||
        (newAI.displayTitle && !existingAI.displayTitle)
      )
      
      if (shouldUpdateAI && newAI.keywords && newAI.keywords.length > 0) {
        // 合并 AI 数据
        const mergedAI = {
          ...existingAI,
          ...newAI
        }
        
        // 处理 AI filename 字段
        if (newAI.filename) {
          const filenameWithoutExt = newAI.filename.replace(/\.[^.]+$/, '')
          mergedAI.displayTitle = mergedAI.displayTitle || filenameWithoutExt
          mergedAI.aiFilename = Array.isArray(newAI.filename)
            ? newAI.filename[0]
            : newAI.filename
          delete mergedAI.filename
        }
        
        existingImage.ai = mergedAI
        processed++
        console.log(`    ↻ ${key} (合并 AI 数据)`)
      } else {
        console.log(`    跳过 ${key} (已存在，AI 数据无需更新)`)
      }
    }
  }

  return processed
}

// 生成前端数据文件（与 generate-data.js 格式兼容）
function generateFrontendData(metadataMap, dataDir, newTag) {
  const stats = {
    lastUpdated: formatDateTime(),
    cdnTag: newTag,
    series: {}
  }

  for (const [series, metadata] of Object.entries(metadataMap)) {
    // 确保系列目录存在
    const seriesDir = path.join(dataDir, series)
    if (!fs.existsSync(seriesDir)) {
      fs.mkdirSync(seriesDir, { recursive: true })
    }

    // 将 metadata 转换为前端需要的数组格式
    const wallpapers = []
    let index = 0

    const reconciledImages = {}
    for (const [relativePath, data] of Object.entries(metadata.images)) {
      const reconciled = reconcileMetadataImagePath(relativePath, data)
      if (reconciled.missing) {
        console.warn(`  跳过缺失原图: ${relativePath}`)
        continue
      }
      reconciledImages[reconciled.relativePath] = reconciled.imageData
    }
    metadata.images = reconciledImages

    for (const [relativePath, data] of Object.entries(metadata.images)) {
      // 解析路径获取前端需要的格式
      // relativePath: wallpaper/desktop/动漫/原神/xxx.jpg
      const parts = relativePath.split('/')
      const filename = parts.pop()
      const filenameNoExt = filename.replace(/\.[^.]+$/, '')
      const pathParts = parts.slice(2) // 去掉 wallpaper/series

      // 构建路径（保持与 generate-data.js 一致）
      const imagePath = `/${parts.join('/')}/${encodeURIComponent(filename).replace(/%2F/g, '/')}`
      const subdir = pathParts.length > 0 ? pathParts.join('/') : ''
      const mediaType = data.mediaType || (series === 'video' ? 'video' : 'image')
      const usage = series === 'video' ? (data.usage || pathParts[0] || data.category || 'desktop') : undefined
      const topic = series === 'video' ? (data.topic || pathParts[1] || data.subcategory || '通用') : undefined

      let thumbnailPath, previewPath
      if (subdir) {
        thumbnailPath = resolveDerivedAssetPath(imageRepoRoot, series, subdir, filenameNoExt, 'thumbnail')
        previewPath = series !== 'avatar' ? resolveDerivedAssetPath(imageRepoRoot, series, subdir, filenameNoExt, 'preview') : null
      } else {
        thumbnailPath = resolveDerivedAssetPath(imageRepoRoot, series, '', filenameNoExt, 'thumbnail')
        previewPath = series !== 'avatar' ? resolveDerivedAssetPath(imageRepoRoot, series, '', filenameNoExt, 'preview') : null
      }

      const wallpaperData = {
        id: `${series}-${++index}`,
        filename: filename,
        category: data.category || '未分类',
        path: imagePath,
        thumbnailPath: thumbnailPath,
        size: data.size || 0,
        format: (data.format || 'jpg').toUpperCase(),
        createdAt: data.createdAt,
        sha: '',
        cdnTag: data.cdnTag || newTag,
        mediaType,
        // AI 扩展字段
        keywords: data.ai?.keywords || [],
        description: data.ai?.description || '',
        displayTitle: data.ai?.displayTitle || ''
      }

      // 构建 tags 数组：包含分类 + AI 关键词（用于搜索）
      const tags = [data.category || '未分类']
      if (data.subcategory) {
        tags.push(data.subcategory)
      }
      // 添加 AI 关键词到 tags
      if (data.ai?.keywords && Array.isArray(data.ai.keywords)) {
        data.ai.keywords.forEach(kw => {
          if (!tags.includes(kw)) {
            tags.push(kw)
          }
        })
      }
      wallpaperData.tags = tags

      // 添加二级分类（仅当存在时）
      if (data.subcategory) {
        wallpaperData.subcategory = data.subcategory
      }

      if (series === 'video') {
        wallpaperData.usage = usage
        wallpaperData.topic = topic || '通用'
        wallpaperData.subcategory = topic || '通用'
        wallpaperData.duration = data.duration || null
      }

      // 添加预览图路径（avatar 不需要）
      if (previewPath) {
        wallpaperData.previewPath = previewPath
      }

      // 添加分辨率信息（仅当存在时）
      if (data.resolution) {
        wallpaperData.resolution = data.resolution
      }

      wallpapers.push(wallpaperData)
    }

    // 全局稳定排序：先按最新，再按文件名，避免首屏顺序抖动
    wallpapers.sort(compareWallpapers)

    // 按分类分组
    const categoryGroups = {}
    wallpapers.forEach(wallpaper => {
      const category = wallpaper.category
      if (!categoryGroups[category]) {
        categoryGroups[category] = []
      }
      categoryGroups[category].push(wallpaper)
    })

    // 生成分类索引
    const categories = Object.entries(categoryGroups).map(([categoryName, items]) => {
      const thumbnail = items[0]?.thumbnailPath || items[0]?.path || ''

      // 统计该分类下的二级分类
      const subcategoryMap = {}
      items.forEach(item => {
        const subcat = item.subcategory || null
        if (subcat) {
          subcategoryMap[subcat] = (subcategoryMap[subcat] || 0) + 1
        }
      })

      // 转换为数组格式
      const subcategories = Object.entries(subcategoryMap)
        .map(([name, count]) => ({ name, count }))
        .sort((a, b) => b.count - a.count)

      return {
        id: categoryName.replace(/\s+/g, '-').toLowerCase(),
        name: categoryName,
        count: items.length,
        thumbnail,
        file: `${categoryName}.json`,
        ...(subcategories.length > 0 && { subcategories })
      }
    }).sort((a, b) => b.count - a.count)

    // 写入分类索引文件
    const indexData = {
      generatedAt: formatDateTime(),
      series: series,
      seriesName: metadata.series || series,
      total: wallpapers.length,
      categoryCount: categories.length,
      blob: encodeData(JSON.stringify(categories)),
      schema: 2,
      env: 'production'
    }

    const indexPath = path.join(seriesDir, 'index.json')
    fs.writeFileSync(indexPath, JSON.stringify(indexData, null, 2))
    console.log(`  生成 ${series}/index.json`)

    // 生成全局最新切片，专门服务首屏稳定预热
    const latestItems = wallpapers.slice(0, LATEST_SLICE_SIZE)
    const latestData = {
      generatedAt: formatDateTime(),
      series: series,
      category: 'latest',
      total: latestItems.length,
      blob: encodeData(JSON.stringify(latestItems)),
      schema: 2
    }

    const latestPath = path.join(seriesDir, 'latest.json')
    fs.writeFileSync(latestPath, JSON.stringify(latestData, null, 2))
    console.log(`  生成 ${series}/latest.json (${latestItems.length} 张)`)

    // 为每个分类生成独立的 JSON 文件
    Object.entries(categoryGroups).forEach(([categoryName, items]) => {
      const categoryData = {
        generatedAt: formatDateTime(),
        series: series,
        category: categoryName,
        total: items.length,
        blob: encodeData(JSON.stringify(items)),
        schema: 2
      }

      const categoryPath = path.join(seriesDir, `${categoryName}.json`)
      fs.writeFileSync(categoryPath, JSON.stringify(categoryData, null, 2))
      console.log(`  生成 ${series}/${categoryName}.json (${items.length} 张)`)
    })

    // 同时生成传统单文件格式（向后兼容）
    const legacyData = {
      generatedAt: formatDateTime(),
      series: series,
      seriesName: metadata.series || series,
      total: wallpapers.length,
      schema: 1,
      env: 'production',
      blob: encodeData(JSON.stringify(wallpapers))
    }

    const legacyPath = path.join(dataDir, `${series}.json`)
    fs.writeFileSync(legacyPath, JSON.stringify(legacyData, null, 2))
    console.log(`  生成 ${series}.json (兼容格式, ${wallpapers.length} 张)`)

    stats.series[series] = {
      count: wallpapers.length,
      categories: categories.map(c => c.name)
    }
  }

  // 生成 stats.json（保留现有的 releases 历史）
  const statsPath = path.join(dataDir, '../stats.json')

  // 读取现有的 stats.json，保留 releases 和 total
  let existingStats = {}
  if (fs.existsSync(statsPath)) {
    try {
      existingStats = JSON.parse(fs.readFileSync(statsPath, 'utf-8'))
      console.log(`  读取现有 stats.json (${existingStats.releases?.length || 0} 条发布记录)`)
    } catch (e) {
      console.warn(`  警告: 无法解析现有 stats.json，将创建新文件`)
    }
  }

  // 合并数据：保留 releases，更新 total 和 series
  const mergedStats = {
    ...stats,
    total: {
      desktop: stats.series.desktop?.count || 0,
      mobile: stats.series.mobile?.count || 0,
      avatar: stats.series.avatar?.count || 0,
      video: stats.series.video?.count || 0,
      bing: existingStats.total?.bing || 0  // bing 不在此脚本处理，保留原值
    },
    releases: existingStats.releases || []
  }

  fs.writeFileSync(statsPath, JSON.stringify(mergedStats, null, 2))
  console.log(`  生成 stats.json (保留 ${mergedStats.releases.length} 条发布记录)`)

  return stats
}

// 主函数
async function main() {
  const args = process.argv.slice(2)
  const projectRoot = args[0] || '.'
  let newTag = args[1] || ''

  // 检查是否有 --force 参数（强制重新生成前端数据）
  const forceRegenerate = args.includes('--force')

  // 设置图床仓库根路径（用于分辨率计算）
  imageRepoRoot = projectRoot

  console.log('========================================')
  console.log('处理 metadata 增量')
  if (forceRegenerate) {
    console.log('（强制重新生成模式）')
  }
  console.log('========================================')
  console.log()

  const metadataDir = path.join(projectRoot, 'metadata')
  const pendingDir = path.join(projectRoot, 'metadata-pending')
  const dataDir = path.join(projectRoot, 'data')
  const timestampsFile = path.join(projectRoot, 'timestamps-backup-all.txt')

  // 如果没有传入 tag，从 /tmp/new_tag.txt 读取
  if (!newTag) {
    const tagFile = '/tmp/new_tag.txt'
    if (fs.existsSync(tagFile)) {
      newTag = fs.readFileSync(tagFile, 'utf-8').trim()
    } else {
      newTag = `v${Date.now()}`
    }
  }
  console.log(`使用 Tag: ${newTag}`)
  console.log()

  // 加载现有 metadata
  console.log('加载现有 metadata...')
  const metadataMap = {
    desktop: loadMetadata(path.join(metadataDir, 'desktop.json')),
    mobile: loadMetadata(path.join(metadataDir, 'mobile.json')),
    avatar: loadMetadata(path.join(metadataDir, 'avatar.json')),
    video: loadMetadata(path.join(metadataDir, 'video.json'))
  }

  let totalProcessed = 0

  // ========================================
  // 步骤 1: 处理 metadata-pending 文件（优先处理 AI 数据）
  // ========================================
  // 这会处理通过 Studio 上传的图片（带 AI 元数据）
  console.log('步骤 1: 处理 metadata-pending 文件...')

  if (!fs.existsSync(pendingDir)) {
    console.log('  metadata-pending 目录不存在，跳过')
  } else {
    // 获取 pending 文件列表
    const pendingFiles = fs.readdirSync(pendingDir)
      .filter(f => f.endsWith('.json'))
      .map(f => path.join(pendingDir, f))
      .sort() // 按时间顺序处理

    if (pendingFiles.length === 0) {
      console.log('  没有待处理的 pending 文件')
    } else {
      console.log(`  发现 ${pendingFiles.length} 个 pending 文件`)

      const processedFiles = []

      for (const pendingFile of pendingFiles) {
        console.log()
        console.log(`  处理: ${path.basename(pendingFile)}`)
        try {
          const count = processPendingFile(pendingFile, metadataMap, newTag)
          totalProcessed += count
          processedFiles.push(pendingFile)
        } catch (e) {
          console.error(`    错误: ${e.message}`)
        }
      }

      // 删除已处理的 pending 文件
      console.log()
      console.log('  清理 pending 文件...')
      for (const file of processedFiles) {
        fs.unlinkSync(file)
        console.log(`    删除 ${path.basename(file)}`)
      }
    }
  }

  console.log()

  // ========================================
  // 步骤 2: 从 timestamps-backup-all.txt 同步缺失的媒体资源
  // ========================================
  // 这会处理通过 Gitee 同步或其他方式直接添加的资源
  console.log('步骤 2: 从 timestamps 同步缺失的资源...')
  const syncedFromTimestamps = syncFromTimestamps(timestampsFile, metadataMap, newTag)
  totalProcessed += syncedFromTimestamps
  console.log(`  从 timestamps 同步了 ${syncedFromTimestamps} 个资源`)
  console.log()
  console.log(`共处理 ${totalProcessed} 个资源`)

  // 保存更新后的 metadata 并生成前端数据
  // 条件：有新增图片 OR 强制重新生成
  if (totalProcessed > 0 || forceRegenerate) {
    if (forceRegenerate && totalProcessed === 0) {
      console.log()
      console.log('强制重新生成前端数据（metadata 可能已更新）...')
    }

    // 生成前端数据
    console.log()
    console.log('生成前端数据...')
    generateFrontendData(metadataMap, dataDir, newTag)

    console.log()
    console.log('保存 metadata...')
    for (const [series, metadata] of Object.entries(metadataMap)) {
      const metaFile = path.join(metadataDir, `${series}.json`)
      saveMetadata(metaFile, metadata)
      console.log(`  保存 ${series}.json (${metadata.count} 张)`)
    }
  }

  // 输出处理数量
  fs.writeFileSync('/tmp/metadata_processed.txt', String(totalProcessed))

  console.log()
  console.log('========================================')
  console.log(`处理完成! 共处理 ${totalProcessed} 个资源`)
  console.log('========================================')
}

// 从 timestamps-backup-all.txt 同步缺失的图片到 metadata
function syncFromTimestamps(timestampsFile, metadataMap, defaultTag) {
  if (!fs.existsSync(timestampsFile)) {
    console.log('  timestamps-backup-all.txt 不存在，跳过同步')
    return 0
  }

  const content = fs.readFileSync(timestampsFile, 'utf-8')
  const lines = content.trim().split('\n').filter(Boolean)

  let synced = 0

  for (const line of lines) {
    // 格式兼容：
    // series|relativePath|timestamp|cdnTag
    // series|relativePath|timestamp
    // relativePath|timestamp (历史桌面图)
    const parts = line.split('|')
    if (parts.length < 2) continue

    let series = 'desktop'
    let relativePath = ''
    let timestamp = ''
    let cdnTag = defaultTag

    if (parts.length >= 4) {
      [series, relativePath, timestamp, cdnTag] = parts
    }
    else if (parts.length === 3) {
      [series, relativePath, timestamp] = parts
    }
    else if (parts.length === 2) {
      [relativePath, timestamp] = parts
    }

    // 只处理已知的 series
    if (!metadataMap[series]) continue

    // 构建完整路径 key
    const key = `wallpaper/${series}/${relativePath}`

    // 检查是否已存在于 metadata
    if (metadataMap[series].images[key]) continue

    // 解析分类信息
    const pathParts = relativePath.split('/')
    const filename = pathParts.pop()
    const category = pathParts[0] || '未分类'
    const subcategory = pathParts.length > 1 ? pathParts[1] : ''
    const isVideoSeries = series === 'video'
    // 图片系列沿用旧行为，视频系列保留“通用”二级目录
    const finalSubcategory = subcategory === '通用' && !isVideoSeries ? '' : subcategory

    // 从文件名提取关键词
    const keywords = extractKeywordsFromFilename(filename)

    // 获取资源信息（分辨率 + 文件大小 + 视频时长）
    const imageInfo = getMediaInfo(key)

    // 创建 metadata 记录
    metadataMap[series].images[key] = {
      category: category,
      subcategory: finalSubcategory,
      filename: filename,
      createdAt: formatDateTime(new Date(parseInt(timestamp) * 1000)),
      cdnTag: cdnTag || defaultTag,
      size: imageInfo.size,
      format: filename.split('.').pop()?.toLowerCase() || 'jpg',
      resolution: imageInfo.resolution,
      duration: imageInfo.duration,
      mediaType: imageInfo.mediaType,
      ...(isVideoSeries
        ? {
            usage: category,
            topic: finalSubcategory || '通用',
          }
        : {}),
      ai: {
        keywords: keywords,
        description: '',
        displayTitle: '',
        confidence: 0,
        model: 'filename-inference',
        analyzedAt: null
      }
    }

    synced++
    console.log(`    + [${series}] ${relativePath} (tag: ${cdnTag})`)
  }

  return synced
}

// 从文件名提取关键词
function extractKeywordsFromFilename(filename) {
  const nameWithoutExt = filename.replace(/\.[^.]+$/, '')
  const separators = /[-_\s、，,&]+/
  const parts = nameWithoutExt.split(separators)
    .map(s => s.trim())
    .filter(s => s.length > 0 && s.length < 20)
    .filter(s => !/^\d+$/.test(s))
    .filter(s => !/^(jpg|png|webp|gif|jpeg|mp4|webm|mov|m4v)$/i.test(s))
  return [...new Set(parts)]
}

module.exports = {
  findActualImagePath,
  generateFrontendData,
  reconcileMetadataImagePath,
}

if (require.main === module) {
  main().catch(e => {
    console.error('执行失败:', e)
    process.exit(1)
  })
}
