#!/usr/bin/env node
/**
 * Bing 每日壁纸同步脚本 (Node.js 跨平台版本)
 *
 * 优化版：只同步元数据，不下载图片
 * - Bing 图片链接永久有效，无需本地存储
 * - 前端直接使用 Bing CDN URL
 *
 * 目录结构：
 * bing/
 * └── meta/                          # 元数据
 *     ├── index.json                 # 总索引
 *     ├── latest.json                # 最近 7 天
 *     ├── 2025.json                  # 年度数据
 *     └── 2024.json
 */

import fs from 'node:fs'
import https from 'node:https'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

// 配置
const CONFIG = {
  BING_API: 'https://www.bing.com/HPImageArchive.aspx',
  BING_BASE: 'https://cn.bing.com',
  ROOT_DIR: path.resolve(__dirname, '..'),
}

const BING_DIR = path.join(CONFIG.ROOT_DIR, 'bing')
const META_DIR = path.join(BING_DIR, 'meta')

// 颜色输出
const colors = {
  red: text => `\x1b[31m${text}\x1b[0m`,
  green: text => `\x1b[32m${text}\x1b[0m`,
  yellow: text => `\x1b[33m${text}\x1b[0m`,
  blue: text => `\x1b[34m${text}\x1b[0m`,
  cyan: text => `\x1b[36m${text}\x1b[0m`,
}

/**
 * HTTP GET 请求
 */
function httpGet(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      if (res.statusCode === 301 || res.statusCode === 302) {
        return httpGet(res.headers.location).then(resolve).catch(reject)
      }

      const chunks = []
      res.on('data', chunk => chunks.push(chunk))
      res.on('end', () => {
        const buffer = Buffer.concat(chunks)
        resolve({ buffer, statusCode: res.statusCode })
      })
      res.on('error', reject)
    }).on('error', reject)
  })
}

/**
 * 获取 Bing API 数据
 * 使用中国市场获取中文标题和描述
 */
async function fetchBingData(days) {
  const url = `${CONFIG.BING_API}?format=js&idx=0&n=${days}&mkt=zh-CN`
  const { buffer, statusCode } = await httpGet(url)

  if (statusCode !== 200) {
    throw new Error(`API returned ${statusCode}`)
  }

  return JSON.parse(buffer.toString('utf-8'))
}

/**
 * 处理单张图片元数据
 */
function processImage(image, idx) {
  // Bing API 返回的是美国时间的日期 (startdate 格式: YYYYMMDD)
  // 对于中国用户，需要 +1 天才是当天的壁纸
  // 例如：美国 1月5日 的壁纸，在中国是 1月6日 展示
  const startdate = image.startdate
  const apiDate = new Date(
    parseInt(startdate.slice(0, 4)),
    parseInt(startdate.slice(4, 6)) - 1,
    parseInt(startdate.slice(6, 8))
  )
  apiDate.setDate(apiDate.getDate() + 1) // +1 天转换为中国时间

  const year = apiDate.getFullYear()
  const month = String(apiDate.getMonth() + 1).padStart(2, '0')
  const day = String(apiDate.getDate()).padStart(2, '0')
  const dateFormatted = `${year}-${month}-${day}`

  console.log(`${colors.blue('[INFO]')} ${dateFormatted} (API: ${startdate}, idx=${idx}) - ${image.title}`)

  // 构建元数据
  const metadata = {
    date: dateFormatted,
    title: image.title,
    copyright: image.copyright,
    copyrightlink: image.copyrightlink,
    quiz: image.quiz,
    hsh: image.hsh,
    urlbase: image.urlbase,
  }

  // 检查是否已存在
  const yearFile = path.join(META_DIR, `${year}.json`)
  let isNew = true

  if (fs.existsSync(yearFile)) {
    const yearData = JSON.parse(fs.readFileSync(yearFile, 'utf-8'))
    isNew = !yearData.items.some(i => i.date === dateFormatted)
  }

  // 保存元数据
  saveToYearFile(year, metadata)

  if (isNew) {
    console.log(`       ${colors.green('✓ 新增')}`)
    return { success: true }
  } else {
    console.log(`       ${colors.yellow('已存在，更新元数据')}`)
    return { skipped: true }
  }
}

/**
 * 保存到年度数据文件
 */
function saveToYearFile(year, item) {
  const yearFile = path.join(META_DIR, `${year}.json`)

  let yearData
  if (fs.existsSync(yearFile)) {
    yearData = JSON.parse(fs.readFileSync(yearFile, 'utf-8'))

    // 检查是否已存在
    const existsIndex = yearData.items.findIndex(i => i.date === item.date)
    if (existsIndex >= 0) {
      // 更新现有条目
      yearData.items[existsIndex] = item
    } else {
      // 添加新条目
      yearData.items.push(item)
    }

    // 排序（日期降序）
    yearData.items.sort((a, b) => b.date.localeCompare(a.date))
    yearData.total = yearData.items.length
    yearData.updatedAt = new Date().toISOString()
  } else {
    yearData = {
      year: parseInt(year),
      total: 1,
      updatedAt: new Date().toISOString(),
      items: [item],
    }
  }

  fs.writeFileSync(yearFile, JSON.stringify(yearData, null, 2))
}

/**
 * 更新 index.json
 */
function updateIndexJson() {
  const indexFile = path.join(META_DIR, 'index.json')
  const years = []
  let total = 0

  // 遍历所有年度文件
  const files = fs.readdirSync(META_DIR).filter(f => /^20\d{2}\.json$/.test(f))

  for (const file of files) {
    const yearFile = path.join(META_DIR, file)
    const yearData = JSON.parse(fs.readFileSync(yearFile, 'utf-8'))
    years.push({
      year: yearData.year,
      count: yearData.total,
      file: file,
    })
    total += yearData.total
  }

  // 按年份降序
  years.sort((a, b) => b.year - a.year)

  const indexData = {
    generatedAt: new Date().toISOString(),
    series: 'bing',
    seriesName: 'Bing 每日',
    total,
    years,
  }

  fs.writeFileSync(indexFile, JSON.stringify(indexData, null, 2))
  console.log(`       index.json (total: ${total})`)
}

/**
 * 更新 latest.json
 */
function updateLatestJson() {
  const latestFile = path.join(META_DIR, 'latest.json')
  let allItems = []

  // 合并所有年度数据
  const files = fs.readdirSync(META_DIR).filter(f => /^20\d{2}\.json$/.test(f))

  for (const file of files) {
    const yearFile = path.join(META_DIR, file)
    const yearData = JSON.parse(fs.readFileSync(yearFile, 'utf-8'))
    allItems = allItems.concat(yearData.items)
  }

  // 排序并取最近 7 条
  allItems.sort((a, b) => b.date.localeCompare(a.date))
  const items = allItems.slice(0, 7)

  const latestData = {
    generatedAt: new Date().toISOString(),
    total: items.length,
    items,
  }

  fs.writeFileSync(latestFile, JSON.stringify(latestData, null, 2))
  console.log(`       latest.json (${items.length} items)`)
}

/**
 * 主函数
 */
async function main() {
  const days = parseInt(process.argv[2]) || 1

  console.log('========================================')
  console.log('  Bing 每日壁纸同步 (元数据模式)')
  console.log('========================================')
  console.log('')
  console.log(`${colors.cyan('模式:')} 只同步元数据，不下载图片`)
  console.log(`${colors.cyan('原因:')} Bing 图片链接永久有效`)
  console.log('')
  console.log(`${colors.blue('[INFO]')} 获取最近 ${days} 天的壁纸...`)
  console.log('')

  // 确保目录存在
  fs.mkdirSync(META_DIR, { recursive: true })

  try {
    // 获取 Bing 数据
    const bingData = await fetchBingData(days)

    if (!bingData.images || bingData.images.length === 0) {
      console.log(`${colors.red('[ERROR]')} 获取 Bing 数据失败`)
      process.exit(1)
    }

    console.log(`${colors.blue('[INFO]')} 获取到 ${bingData.images.length} 条数据`)
    console.log('')

    // 处理每条数据
    let success = 0
    let skip = 0

    for (let i = 0; i < bingData.images.length; i++) {
      const image = bingData.images[i]
      const idx = i // idx=0 是今天，idx=1 是昨天，以此类推
      const result = processImage(image, idx)
      if (result.success) success++
      else if (result.skipped) skip++
    }

    console.log('')
    console.log('========================================')
    console.log('  同步完成')
    console.log('========================================')
    console.log(`  ${colors.green('新增:')} ${success}`)
    console.log(`  ${colors.yellow('更新:')} ${skip}`)
    console.log('========================================')

    // 更新索引
    console.log('')
    console.log(`${colors.blue('[INFO]')} 更新索引...`)
    updateIndexJson()
    updateLatestJson()
    console.log(`${colors.green('[DONE]')} 索引更新完成`)

  } catch (e) {
    console.error(`${colors.red('[ERROR]')} ${e.message}`)
    process.exit(1)
  }
}

main()
