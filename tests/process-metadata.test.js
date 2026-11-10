const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('fs')
const os = require('os')
const path = require('path')

const {
  generateFrontendData,
  reconcileMetadataImagePath,
} = require('../scripts/process-metadata.js')

test('reconcileMetadataImagePath rewrites stale metadata path to actual file location', () => {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'process-metadata-test-'))
  const actualDir = path.join(tempRoot, 'wallpaper', 'desktop', '通用')
  fs.mkdirSync(actualDir, { recursive: true })
  fs.writeFileSync(path.join(actualDir, '20260406200013.jpeg'), 'fake')

  const originalCwd = process.cwd()
  process.chdir(tempRoot)

  try {
    const result = reconcileMetadataImagePath(
      'wallpaper/desktop/萌宠/猫咪/20260406200013.jpeg',
      {
        category: '萌宠',
        subcategory: '猫咪',
        filename: '20260406200013.jpeg',
      }
    )

    assert.equal(result.changed, true)
    assert.equal(result.relativePath, 'wallpaper/desktop/通用/20260406200013.jpeg')
    assert.equal(result.imageData.category, '通用')
    assert.equal(result.imageData.subcategory, '')
    assert.equal(result.imageData.filename, '20260406200013.jpeg')
  } finally {
    process.chdir(originalCwd)
    fs.rmSync(tempRoot, { recursive: true, force: true })
  }
})

test('generateFrontendData skips metadata entries whose source image no longer exists', () => {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'process-metadata-test-'))
  const originalCwd = process.cwd()
  process.chdir(tempRoot)

  try {
    const dataDir = path.join(tempRoot, 'data')
    const metadataMap = {
      avatar: {
        series: 'avatar',
        images: {
          'wallpaper/avatar/动漫/通用/missing-image.png': {
            category: '动漫',
            subcategory: '',
            filename: 'missing-image.png',
            createdAt: '2026-04-08 10:00:00',
            cdnTag: 'v1.2.33',
            size: 123,
            format: 'png',
            ai: {
              keywords: ['动漫'],
              description: 'missing',
              displayTitle: 'Missing image',
            },
          },
        },
      },
    }

    generateFrontendData(metadataMap, dataDir, 'v1.2.33')

    assert.deepEqual(metadataMap.avatar.images, {})

    const latestData = JSON.parse(fs.readFileSync(path.join(dataDir, 'avatar', 'latest.json'), 'utf8'))
    assert.equal(latestData.total, 0)
  } finally {
    process.chdir(originalCwd)
    fs.rmSync(tempRoot, { recursive: true, force: true })
  }
})

test('generateFrontendData keeps R2-hosted video without a local source file', () => {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'process-metadata-test-'))
  const originalCwd = process.cwd()
  process.chdir(tempRoot)

  try {
    const dataDir = path.join(tempRoot, 'data')
    const relativePath = 'wallpaper/video/desktop/动漫/r2-only.mp4'
    const record = {
      category: 'desktop',
      subcategory: '动漫',
      filename: 'r2-only.mp4',
      createdAt: '2026-11-10 21:00:00',
      cdnTag: 'v1.5.1',
      storage: 'r2',
      size: 1024,
      format: 'mp4',
      duration: 10,
      mediaType: 'video',
      thumbnailPath: '/thumbnail/video/desktop/动漫/r2-only.webp',
      previewPath: '/preview/video/desktop/动漫/r2-only.mp4',
    }
    const metadataMap = {
      video: {
        series: 'video',
        images: { [relativePath]: record },
      },
    }

    generateFrontendData(metadataMap, dataDir, 'v1.5.1')

    assert.deepEqual(metadataMap.video.images, { [relativePath]: record })
    const latestData = JSON.parse(fs.readFileSync(path.join(dataDir, 'video', 'latest.json'), 'utf8'))
    assert.equal(latestData.total, 1)
  } finally {
    process.chdir(originalCwd)
    fs.rmSync(tempRoot, { recursive: true, force: true })
  }
})
