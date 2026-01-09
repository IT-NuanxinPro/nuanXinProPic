#!/usr/bin/env node
/**
 * 壁纸数据生成脚本（图床仓库版本）
 * 
 * 功能：扫描本地图片目录，生成 JSON 元数据文件
 * 格式与前端 wallpaper-gallery 完全一致
 * 
 * 用法：
 *   node scripts/generate-data.js
 *   CDN_BASE_URL=https://img.061129.xyz node scripts/generate-data.js
 * 
 * 环境变量：
 *   CDN_BASE_URL - CDN 基础 URL（可选，设置后图片路径会加上此前缀）
 * 
 * 输出目录：
 *   public/data/desktop/index.json
 *   public/data/desktop/动漫.json
 *   public/data/mobile/...
 *   public/data/avatar/...
 *   public/data/bing/...
 */

import { Buffer } from 'node:buffer'
import { execSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'
import { CHAR_MAP_ENCODE, VERSION_PREFIX } from './codec-config.js'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

/**
 * 自定义编码（Base64 + 字符映射 + 反转）
 * 与前端 codec.js 完全一致
 */
function encodeData(str) {
  const base64 = Buffer.from(str, 'utf-8').toString('base64')
  const mapped = base64.split('').map(c => CHAR_MAP_ENCODE[c] || c).join('')
  return VERSION_PREFIX + mapped.split('').reverse().join('')
}

// 配置
const CONFIG = {
  // CDN 基础 URL（从环境变量读取）
  CDN_BASE_URL: process.env.CDN_BASE_URL || '',

  // 本地目录（相对于脚本所在目录的上级）
  ROOT_DIR: path.resolve(__dirname, '..'),

  // 支持的图片格式
  IMAGE_EXTENSIONS: ['.jpg', '.jpeg', '.png', '.gif', '.webp'],

  // 输出路径
  OUTPUT_DIR: path.resolve(__dirname, '../public/data'),

  // 三大系列配置（与前端完全一致）
  SERIES: {
    desktop: {
      id: 'desktop',
      name: '电脑壁纸',
      wallpaperDir: 'wallpaper/desktop',
      thumbnailDir: 'thumbnail/desktop',
      previewDir: 'preview/desktop',
      outputFile: 'desktop.json',
      hasPreview: true,
    },
    mobile: {
      id: 'mobile',
      name: '手机壁纸',
      wallpaperDir: 'wallpaper/mobile',
      thumbnailDir: 'thumbnail/mobile',
      previewDir: 'preview/mobile',
      outputFile: 'mobile.json',
      hasPreview: true,
    },
    avatar: {
      id: 'avatar',
      name: '头像',
      wallpaperDir: 'wallpaper/avatar',
      thumbnailDir: 'thumbnail/avatar',
      outputFile: 'avatar.json',
      hasPreview: false,
    },
    bing: {
      id: 'bing',
      name: '每日Bing',
      metadataDir: 'bing/meta',
      outputFile: 'bing',
      isBing: true,
    },
  },
}

/**
 * 递归扫描目录获取所有图片文件
 * 支持二级分类文件夹结构：wallpaper/desktop/游戏/原神/xxx.jpg
 */
function scanDirectoryRecursive(dir, baseDir = dir) {
  const files = []

  if (!fs.existsSync(dir)) {
    return files
  }

  const entries = fs.readdirSync(dir, { withFileTypes: true })

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name)

    if (entry.isDirectory()) {
      files.push(...scanDirectoryRecursive(fullPath, baseDir))
    }
    else if (entry.isFile()) {
      const ext = path.extname(entry.name).toLowerCase()
      if (CONFIG.IMAGE_EXTENSIONS.includes(ext)) {
        const stats = fs.statSync(fullPath)
        const relativePath = path.relative(baseDir, fullPath)
        const pathParts = relativePath.split(path.sep)

        let category = '未分类'
        let subcategory = null

        if (pathParts.length >= 3) {
          // 二级分类结构: L1/L2/filename.jpg
          category = pathParts[0]
          const l2 = pathParts[1]
          // "通用" 表示没有二级分类，设为 null
          subcategory = l2 === '通用' ? null : l2
        }
        else if (pathParts.length === 2) {
          // 一级分类结构: L1/filename.jpg
          category = pathParts[0]
          subcategory = null
        }
        else {
          // 根目录文件
          category = extractCategoryFromFilename(entry.name)
          subcategory = null
        }

        files.push({
          name: entry.name,
          size: stats.size,
          mtime: stats.mtime,
          sha: '', // 与前端格式一致
          type: 'file',
          category,
          subcategory,
          relativePath,
          fullPath,
        })
      }
    }
  }

  return files
}

/**
 * 从文件名中提取分类（兼容旧的文件名格式）
 * 文件名格式: {分类}--{原文件名}.{ext}
 */
function extractCategoryFromFilename(filename) {
  const filenameNoExt = path.basename(filename, path.extname(filename))

  if (filenameNoExt.includes('--')) {
    const parts = filenameNoExt.split('--')
    if (parts.length >= 2 && parts[0].trim()) {
      return parts[0].trim()
    }
  }

  return '未分类'
}

/**
 * 获取图片分辨率信息
 */
function getImageDimensions(filePath) {
  if (process.env.SKIP_IMAGE_DIMENSIONS === 'true') {
    return null
  }

  try {
    let cmd = 'magick identify'
    try {
      execSync('magick --version', { stdio: 'ignore' })
    }
    catch {
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
  }
  catch {
    // ImageMagick 不可用
  }
  return null
}

/**
 * 根据分辨率生成标签（与前端完全一致）
 */
function getResolutionLabel(width, height) {
  const maxDim = Math.max(width, height)

  if (maxDim >= 15360) {
    return { label: '16K', type: 'danger' }
  }
  else if (maxDim >= 7680) {
    return { label: '8K', type: 'danger' }
  }
  else if (maxDim >= 5760) {
    return { label: '6K', type: 'warning' }
  }
  else if (maxDim >= 5120) {
    return { label: '5K+', type: 'danger' }
  }
  else if (maxDim >= 4096) {
    return { label: '4K+', type: 'warning' }
  }
  else if (maxDim >= 3840) {
    return { label: '4K', type: 'success' }
  }
  else if (maxDim >= 2048) {
    return { label: '2K', type: 'info' }
  }
  else if (maxDim >= 1920) {
    return { label: '超清', type: 'primary' }
  }
  else if (maxDim >= 1280) {
    return { label: '高清', type: 'secondary' }
  }
  else {
    return { label: '标清', type: 'secondary' }
  }
}

/**
 * 构建图片 URL（支持 CDN 前缀）
 * 路径编码方式与前端一致
 */
function buildImageUrl(relativePath, baseDir) {
  const cdnBase = CONFIG.CDN_BASE_URL
  // URL 编码路径（保留 /），与前端 encodeURIComponent 方式一致
  const encodedPath = relativePath.split('/').map(p => encodeURIComponent(p)).join('/')
  
  if (cdnBase) {
    return `${cdnBase}/${baseDir}/${encodedPath}`
  }
  // 无 CDN 时使用相对路径（与前端一致）
  return `/${baseDir}/${encodedPath.replace(/%2F/g, '/')}`
}

/**
 * 生成壁纸数据（格式与前端完全一致）
 */
function generateWallpaperData(files, seriesConfig) {
  return files.map((file, index) => {
    const ext = path.extname(file.name).replace('.', '').toUpperCase()
    const filenameNoExt = path.basename(file.name, path.extname(file.name))
    const pathParts = file.relativePath.split(path.sep)
    const isInSubfolder = pathParts.length > 1

    // 分类
    const category = file.category || extractCategoryFromFilename(file.name)
    const subcategory = file.subcategory || null

    // 构建路径
    const imagePath = buildImageUrl(file.relativePath, seriesConfig.wallpaperDir)
    
    let thumbnailPath, previewPath
    if (isInSubfolder) {
      const subdir = pathParts.slice(0, -1).join('/')
      thumbnailPath = buildImageUrl(`${subdir}/${filenameNoExt}.webp`, seriesConfig.thumbnailDir)
      previewPath = seriesConfig.hasPreview
        ? buildImageUrl(`${subdir}/${filenameNoExt}.webp`, seriesConfig.previewDir)
        : null
    }
    else {
      thumbnailPath = buildImageUrl(`${filenameNoExt}.webp`, seriesConfig.thumbnailDir)
      previewPath = seriesConfig.hasPreview
        ? buildImageUrl(`${filenameNoExt}.webp`, seriesConfig.previewDir)
        : null
    }

    // 获取分辨率
    let resolution = null
    const dimensions = getImageDimensions(file.fullPath)
    if (dimensions) {
      const labelInfo = getResolutionLabel(dimensions.width, dimensions.height)
      resolution = {
        width: dimensions.width,
        height: dimensions.height,
        label: labelInfo.label,
        type: labelInfo.type,
      }
    }

    // 构建数据对象（字段顺序与前端一致）
    const wallpaperData = {
      id: `${seriesConfig.id}-${index + 1}`,
      filename: file.name,
      category,
      path: imagePath,
      thumbnailPath,
      size: file.size,
      format: ext,
      createdAt: file.mtime.toISOString(),
      sha: file.sha || '', // 与前端格式一致
    }

    // 添加二级分类（仅当存在时）
    if (subcategory) {
      wallpaperData.subcategory = subcategory
    }

    // 自动生成 tags（与前端一致）
    const autoTags = [category]
    if (subcategory) {
      autoTags.push(subcategory)
    }
    wallpaperData.tags = autoTags

    if (previewPath) {
      wallpaperData.previewPath = previewPath
    }

    if (resolution) {
      wallpaperData.resolution = resolution
    }

    return wallpaperData
  })
}

/**
 * 按分类生成独立 JSON 文件（格式与前端完全一致）
 */
function generateCategorySplitData(wallpapers, seriesId, seriesConfig) {
  const seriesDir = path.join(CONFIG.OUTPUT_DIR, seriesId)
  if (!fs.existsSync(seriesDir)) {
    fs.mkdirSync(seriesDir, { recursive: true })
  }

  // 按分类分组
  const categoryGroups = {}
  wallpapers.forEach((wallpaper) => {
    const category = wallpaper.category
    if (!categoryGroups[category]) {
      categoryGroups[category] = []
    }
    categoryGroups[category].push(wallpaper)
  })

  // 生成分类索引（包含二级分类信息）
  const categories = Object.entries(categoryGroups).map(([categoryName, items]) => {
    const thumbnail = items[0]?.thumbnailPath || items[0]?.path || ''

    // 统计该分类下的二级分类
    const subcategoryMap = {}
    items.forEach((item) => {
      const subcat = item.subcategory || null
      if (!subcategoryMap[subcat]) {
        subcategoryMap[subcat] = 0
      }
      subcategoryMap[subcat]++
    })

    // 转换为数组格式
    const subcategories = Object.entries(subcategoryMap)
      .map(([name, count]) => ({
        name: name === 'null' ? null : name,
        count,
      }))
      .filter(s => s.name !== null)
      .sort((a, b) => b.count - a.count)

    return {
      id: categoryName.replace(/\s+/g, '-').toLowerCase(),
      name: categoryName,
      count: items.length,
      thumbnail,
      file: `${categoryName}.json`,
      ...(subcategories.length > 0 && { subcategories }),
    }
  })

  categories.sort((a, b) => b.count - a.count)

  const categoriesBlob = encodeData(JSON.stringify(categories))

  // index.json 格式与前端完全一致
  const indexData = {
    generatedAt: new Date().toISOString(),
    series: seriesId,
    seriesName: seriesConfig.name,
    total: wallpapers.length,
    categoryCount: categories.length,
    blob: categoriesBlob,
    schema: 2,
    env: process.env.NODE_ENV || 'production',
  }

  const indexPath = path.join(seriesDir, 'index.json')
  fs.writeFileSync(indexPath, JSON.stringify(indexData, null, 2))
  console.log(`  Generated: ${seriesId}/index.json`)

  // 为每个分类生成独立 JSON
  Object.entries(categoryGroups).forEach(([categoryName, items]) => {
    const blob = encodeData(JSON.stringify(items))
    const encryptedData = {
      generatedAt: new Date().toISOString(),
      series: seriesId,
      category: categoryName,
      total: items.length,
      blob,
      schema: 2,
    }

    const categoryPath = path.join(seriesDir, `${categoryName}.json`)
    fs.writeFileSync(categoryPath, JSON.stringify(encryptedData, null, 2))
    console.log(`  Generated: ${seriesId}/${categoryName}.json (${items.length} items)`)
  })

  return categories
}

/**
 * 生成传统单文件格式（向后兼容，与前端一致）
 */
function generateLegacyFile(wallpapers, seriesId, seriesConfig) {
  const blob = encodeData(JSON.stringify(wallpapers))

  const outputData = {
    generatedAt: new Date().toISOString(),
    series: seriesId,
    seriesName: seriesConfig.name,
    total: wallpapers.length,
    schema: 1,
    env: process.env.NODE_ENV || 'production',
    blob,
  }

  const outputPath = path.join(CONFIG.OUTPUT_DIR, seriesConfig.outputFile)
  fs.writeFileSync(outputPath, JSON.stringify(outputData, null, 2))
  console.log(`  Generated: ${seriesConfig.outputFile} (legacy format)`)
}

/**
 * 处理 Bing 系列（复制元数据）
 */
async function processBingSeries(seriesId, seriesConfig) {
  console.log('')
  console.log(`Processing series: ${seriesConfig.name} (${seriesId})`)
  console.log('-'.repeat(40))

  const bingOutputDir = path.join(CONFIG.OUTPUT_DIR, 'bing')
  const bingSrcDir = path.join(CONFIG.ROOT_DIR, seriesConfig.metadataDir)

  if (!fs.existsSync(bingOutputDir)) {
    fs.mkdirSync(bingOutputDir, { recursive: true })
  }

  if (!fs.existsSync(bingSrcDir)) {
    console.log(`  Bing metadata not found: ${bingSrcDir}`)
    return { seriesId, count: 0, wallpapers: [] }
  }

  // 复制所有 JSON 文件
  const files = fs.readdirSync(bingSrcDir).filter(f => f.endsWith('.json'))
  let totalItems = 0

  for (const file of files) {
    const srcPath = path.join(bingSrcDir, file)
    const destPath = path.join(bingOutputDir, file)
    fs.copyFileSync(srcPath, destPath)
    console.log(`  Copied: ${file}`)

    if (file === 'index.json') {
      try {
        const indexData = JSON.parse(fs.readFileSync(srcPath, 'utf-8'))
        totalItems = indexData.total || 0
      }
      catch {
        // 忽略
      }
    }
  }

  console.log(`  ✅ Copied ${files.length} files`)
  return { seriesId, count: totalItems, wallpapers: [] }
}

/**
 * 处理单个系列
 */
async function processSeries(seriesId, seriesConfig) {
  if (seriesConfig.isBing) {
    return processBingSeries(seriesId, seriesConfig)
  }

  console.log('')
  console.log(`Processing series: ${seriesConfig.name} (${seriesId})`)
  console.log('-'.repeat(40))

  const wallpaperDir = path.join(CONFIG.ROOT_DIR, seriesConfig.wallpaperDir)

  if (!fs.existsSync(wallpaperDir)) {
    console.log(`  Directory not found: ${wallpaperDir}`)
    return { seriesId, count: 0, wallpapers: [] }
  }

  // 扫描目录
  const files = scanDirectoryRecursive(wallpaperDir)
  console.log(`  Found ${files.length} image files`)

  if (files.length === 0) {
    return { seriesId, count: 0, wallpapers: [] }
  }

  // 生成数据
  const wallpapers = generateWallpaperData(files, seriesConfig)
  wallpapers.sort((a, b) => b.size - a.size)

  // 生成传统单文件（向后兼容）
  generateLegacyFile(wallpapers, seriesId, seriesConfig)

  // 生成分类 JSON
  generateCategorySplitData(wallpapers, seriesId, seriesConfig)

  // 分类统计
  const categoryStats = {}
  const subcategoryStats = {}
  wallpapers.forEach((w) => {
    categoryStats[w.category] = (categoryStats[w.category] || 0) + 1
    if (w.subcategory) {
      const key = `${w.category}/${w.subcategory}`
      subcategoryStats[key] = (subcategoryStats[key] || 0) + 1
    }
  })

  console.log('  Categories:')
  Object.entries(categoryStats)
    .sort((a, b) => b[1] - a[1])
    .forEach(([cat, count]) => {
      console.log(`    ${cat}: ${count}`)
    })

  // 显示二级分类统计
  if (Object.keys(subcategoryStats).length > 0) {
    console.log('  Subcategories:')
    Object.entries(subcategoryStats)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .forEach(([subcat, count]) => {
        console.log(`    ${subcat}: ${count}`)
      })
    if (Object.keys(subcategoryStats).length > 10) {
      console.log(`    ... and ${Object.keys(subcategoryStats).length - 10} more`)
    }
  }

  // 分辨率统计
  const resolutionStats = {}
  wallpapers.forEach((w) => {
    if (w.resolution) {
      resolutionStats[w.resolution.label] = (resolutionStats[w.resolution.label] || 0) + 1
    }
  })

  if (Object.keys(resolutionStats).length > 0) {
    console.log('  Resolutions:')
    Object.entries(resolutionStats)
      .sort((a, b) => b[1] - a[1])
      .forEach(([res, count]) => {
        console.log(`    ${res}: ${count}`)
      })
  }

  return { seriesId, count: wallpapers.length, wallpapers }
}

/**
 * 主函数
 */
async function main() {
  console.log('='.repeat(50))
  console.log('Wallpaper Data Generator (Image Repository)')
  console.log('='.repeat(50))
  
  if (CONFIG.CDN_BASE_URL) {
    console.log(`CDN Base URL: ${CONFIG.CDN_BASE_URL}`)
  } else {
    console.log('CDN Base URL: (not set, using relative paths)')
  }

  try {
    if (!fs.existsSync(CONFIG.OUTPUT_DIR)) {
      fs.mkdirSync(CONFIG.OUTPUT_DIR, { recursive: true })
    }

    const results = []
    for (const [seriesId, seriesConfig] of Object.entries(CONFIG.SERIES)) {
      const result = await processSeries(seriesId, seriesConfig)
      results.push(result)
    }

    console.log('')
    console.log('='.repeat(50))
    console.log('Generation Complete!')
    console.log('='.repeat(50))

    let totalCount = 0
    results.forEach((result) => {
      const config = CONFIG.SERIES[result.seriesId]
      console.log(`${config.name}: ${result.count} items`)
      totalCount += result.count
    })

    console.log('-'.repeat(50))
    console.log(`Total: ${totalCount} items`)
    console.log(`Output: ${CONFIG.OUTPUT_DIR}`)

    // 格式统计
    const formatStats = { jpg: 0, png: 0 }
    results.forEach((result) => {
      result.wallpapers.forEach((w) => {
        if (w.format === 'JPG' || w.format === 'JPEG')
          formatStats.jpg++
        else if (w.format === 'PNG')
          formatStats.png++
      })
    })

    if (formatStats.jpg > 0 || formatStats.png > 0) {
      console.log('')
      console.log('Format Statistics:')
      console.log(`  JPG: ${formatStats.jpg}`)
      console.log(`  PNG: ${formatStats.png}`)
    }

    console.log('')
  }
  catch (error) {
    console.error('Error generating data:', error)
    process.exit(1)
  }
}

main()
