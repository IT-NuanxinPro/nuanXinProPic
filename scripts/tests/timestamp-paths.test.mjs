import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import vm from 'node:vm'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { createRequire } from 'node:module'
import { parseTimestamp, reconcileTimestamps } from '../lib/timestamps.mjs'

const require = createRequire(import.meta.url)
const { syncFromTimestamps } = require('../process-metadata.js')
const scripts = path.dirname(path.dirname(fileURLToPath(import.meta.url)))
const line = 'mobile|人像/氛围感/图片||...[3].jpg|1700000000|v1.2.3'
function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'pic-timestamp-test-'))
  t.after(() => fs.rmSync(root, { recursive: true, force: true }))
  return root
}

test('timestamp parser preserves pipes and brackets in modern and legacy paths', () => {
  assert.deepEqual(parseTimestamp(line), {
    series: 'mobile', relativePath: '人像/氛围感/图片||...[3].jpg', timestamp: 1700000000, tag: 'v1.2.3'
  })
  assert.deepEqual(parseTimestamp('avatar|动漫/图片||[1].png|1700000001'), {
    series: 'avatar', relativePath: '动漫/图片||[1].png', timestamp: 1700000001, tag: ''
  })
  assert.deepEqual(parseTimestamp('旧目录/图片||[2].jpg|1700000002'), {
    series: 'desktop', relativePath: '旧目录/图片||[2].jpg', timestamp: 1700000002, tag: ''
  })
  assert.equal(parseTimestamp('mobile|图.jpg|not-a-time|v1'), null)
})

test('generator loader and metadata sync retain exact timestamp paths and first tags', async t => {
  const root = fixture(t)
  const timestampFile = path.join(root, 'timestamps-backup-all.txt')
  fs.writeFileSync(timestampFile, line + '\n' +
    'mobile|人像/氛围感/图片||...[3].jpg|1800000000|v2.0.0\n' +
    '旧目录/图[1].jpg|1700000001\n')
  const source = fs.readFileSync(path.join(scripts, 'generate-data.js'), 'utf8')
  const loader = source.slice(source.indexOf('function loadTimestampBackup('), source.indexOf('/**\n * 保存新增图片'))
  const context = vm.createContext({ fs, path, parseTimestamp, console: { log() {} } })
  const load = vm.runInContext(loader + '\nloadTimestampBackup', context)
  const result = load(root)
  assert.equal(result.timestampMap.get('mobile|人像/氛围感/图片||...[3].jpg'), 1700000000000)
  assert.equal(result.tagMap.get('mobile|人像/氛围感/图片||...[3].jpg'), 'v1.2.3')
  assert.equal(result.timestampMap.get('desktop|旧目录/图[1].jpg'), 1700000001000)
  const metadata = { mobile: { images: {} }, desktop: { images: {} } }
  assert.equal(await syncFromTimestamps(timestampFile, metadata, 'v9.0.0'), 2)
  assert.equal(metadata.mobile.images['wallpaper/mobile/人像/氛围感/图片||...[3].jpg'].cdnTag, 'v1.2.3')
  assert.equal(metadata.desktop.images['wallpaper/desktop/旧目录/图[1].jpg'].cdnTag, 'v9.0.0')
})

test('update command handles relative roots, duplicate records and repeated runs without counting old paths as new', t => {
  const root = fixture(t)
  const imageRepo = path.join(root, 'image repo')
  const image = path.join(imageRepo, 'wallpaper/mobile/人像/氛围感/图片||...[3].jpg')
  fs.mkdirSync(path.dirname(image), { recursive: true })
  fs.writeFileSync(image, 'test image')
  fs.writeFileSync(path.join(imageRepo, 'timestamps-backup-all.txt'), line + '\n' +
    'mobile|人像/氛围感/图片||...[3].jpg|1800000000|v2.0.0\n' +
    'video|desktop/动漫/历史.mp4|1700000000|v1.0.0\n')
  const env = { ...process.env, NEW_TAG_FILE: path.join(root, 'new-tag'), FAILED_IMAGES_FILE: path.join(root, 'none') }
  const command = path.join(scripts, 'update-timestamps.sh')
  const first = JSON.parse(execFileSync('bash', [command, 'image repo', 'v3.0.0'], { cwd: root, env, encoding: 'utf8' }))
  assert.equal(first.missing, 0)
  assert.equal(first.duplicates, 1)
  const output = fs.readFileSync(path.join(imageRepo, 'timestamps-backup-all.txt'), 'utf8')
  assert.ok(output.includes(line))
  assert.ok(output.includes('video|desktop/动漫/历史.mp4|1700000000|v1.0.0'))
  const second = JSON.parse(execFileSync('bash', [command, 'image repo', 'v3.0.1'], { cwd: root, env, encoding: 'utf8' }))
  assert.equal(second.changed, false)
  assert.equal(second.missing, 0)
  assert.deepEqual(reconcileTimestamps(imageRepo, { tag: 'v3.0.1', fix: true }), { changed: false, missing: 0, duplicates: 0, orphans: 0 })
})
