import fs from 'node:fs'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { pathToFileURL } from 'node:url'

const SERIES = ['desktop', 'mobile', 'avatar']
const IMAGE = /\.(?:jpe?g|png|webp)$/i
const emptyCounts = () => Object.fromEntries(SERIES.map(series => [series, 0]))

export function parseTimestamp(line) {
  const parts = line.replace(/\r$/, '').split('|')
  if (parts.length < 2) return null
  let tag = ''
  if (!/^\d+$/.test(parts.at(-1))) tag = parts.pop()
  const rawTimestamp = parts.pop()
  const knownSeries = ['desktop', 'mobile', 'avatar', 'video', 'bing']
  const series = knownSeries.includes(parts[0]) ? parts.shift() : 'desktop'
  const relativePath = parts.join('|')
  if (!/^\d+$/.test(rawTimestamp) || !relativePath) return null
  const timestamp = Number(rawTimestamp)
  if (!Number.isSafeInteger(timestamp)) return null
  return { series, relativePath, timestamp, tag }
}

function serialize(record) {
  return [record.series, record.relativePath, record.timestamp, ...(record.tag ? [record.tag] : [])].join('|')
}
function key(record) { return record.series + '|' + record.relativePath }

export function scanStaticImages(root) {
  root = path.resolve(root)
  const files = new Map()
  function walk(directory, series, relative = '') {
    if (!fs.existsSync(directory)) return
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const name = relative ? relative + '/' + entry.name : entry.name
      if (entry.isDirectory()) walk(path.join(directory, entry.name), series, name)
      else if (entry.isFile() && IMAGE.test(entry.name)) {
        if (/[\r\n]/.test(name)) throw new Error('图片路径包含换行，无法安全保存时间戳')
        files.set(series + '|' + name, { series, relativePath: name })
      }
    }
  }
  for (const series of SERIES) walk(path.join(root, 'wallpaper', series), series)
  return files
}

export function reconcileTimestamps(root, { tag, fix = false, removeOrphans = true, failedPaths = new Set(), now = Math.floor(Date.now() / 1000) } = {}) {
  root = path.resolve(root)
  if (!tag || /[|\r\n]/.test(tag)) throw new Error('必须提供有效版本标签')
  const file = path.join(root, 'timestamps-backup-all.txt')
  const before = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : ''
  const actual = scanStaticImages(root)
  const records = new Map()
  const preserved = []
  let duplicates = 0, orphans = 0
  for (const line of before.split('\n').filter(Boolean)) {
    const record = parseTimestamp(line)
    if (!record) throw new Error('存在无法解析的时间戳记录，停止修改')
    if (!SERIES.includes(record.series)) { preserved.push(line); continue }
    if (removeOrphans && !actual.has(key(record))) { orphans++; continue }
    const previous = records.get(key(record))
    if (previous) {
      duplicates++
      if (record.timestamp < previous.timestamp) records.set(key(record), record)
    } else records.set(key(record), record)
  }
  let missing = 0
  for (const [identity, record] of actual) {
    const fullPath = 'wallpaper/' + record.series + '/' + record.relativePath
    if (records.has(identity) || failedPaths.has(fullPath)) continue
    records.set(identity, { ...record, timestamp: now, tag })
    missing++
  }
  const after = [...records.values()].map(serialize).concat(preserved).join('\n') + (records.size || preserved.length ? '\n' : '')
  const changed = after !== before
  if (fix && changed) {
    const temporary = file + '.tmp'
    fs.writeFileSync(temporary, after)
    fs.renameSync(temporary, file)
  }
  return { changed, missing, duplicates, orphans }
}

export function releaseStatistics(root, newTag) {
  root = path.resolve(root)
  const git = (...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 }).trimEnd()
  git('rev-parse', '--verify', newTag + '^{commit}')
  const tags = git('tag', '--merged', newTag, '--list', 'v*', '--sort=-version:refname').split('\n').filter(Boolean)
  const index = tags.indexOf(newTag)
  if (index < 0) throw new Error('发布版本不是已存在的版本标签')
  const previousTag = tags[index + 1] || null
  const actual = scanStaticImages(root)
  const total = emptyCounts(), added = emptyCounts()
  for (const record of actual.values()) total[record.series]++
  const changed = previousTag
    ? git('diff', '--name-only', '-z', '--diff-filter=A', '-M', previousTag, newTag, '--', 'wallpaper/')
    : git('ls-tree', '-r', '--name-only', '-z', newTag, '--', 'wallpaper/')
  for (const name of new Set(changed.split('\0').filter(Boolean))) {
    const [, series, ...parts] = name.split('/')
    if (!SERIES.includes(series) || !IMAGE.test(name)) continue
    if (actual.has(series + '|' + parts.join('/'))) added[series]++
  }
  return { previousTag, total, added }
}

if (process.argv[1] && import.meta.url === pathToFileURL(fs.realpathSync(process.argv[1])).href) {
  try {
    const [command, root = '.', tag] = process.argv.slice(2)
    if (command === 'stats') console.log(JSON.stringify(releaseStatistics(root, tag)))
    else if (command === 'update' || command === 'verify') {
      const failedFile = process.env.FAILED_IMAGES_FILE || '/tmp/failed_images_list.txt'
      const failedPaths = new Set(fs.existsSync(failedFile) ? fs.readFileSync(failedFile, 'utf8').split('\n').filter(Boolean) : [])
      const fix = command === 'update' || process.argv.includes('--fix')
      const result = reconcileTimestamps(root, { tag, fix, removeOrphans: command === 'verify', failedPaths })
      console.log(JSON.stringify(result))
      if (result.changed && !fix) process.exitCode = 1
    } else throw new Error('未知时间戳命令')
  } catch (error) {
    console.error(error.message)
    process.exitCode = 1
  }
}
