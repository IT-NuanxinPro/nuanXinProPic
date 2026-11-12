const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { spawnSync } = require('node:child_process')
const { test } = require('node:test')

const pictureRoot = path.resolve(__dirname, '../..')
const workflowRoot = path.resolve(pictureRoot, '../wallpaper-gallery-workflow')
const metadataScripts = [pictureRoot, workflowRoot].map(root => path.join(root, 'scripts/process-metadata.js'))

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'static-video-boundary-'))
  t.after(() => fs.rmSync(root, { recursive: true, force: true }))
  return root
}

function write(root, name, value) {
  const file = path.join(root, name)
  fs.mkdirSync(path.dirname(file), { recursive: true })
  fs.writeFileSync(file, typeof value === 'string' ? value : JSON.stringify(value))
}

function initialize(root) {
  for (const series of ['desktop', 'mobile', 'avatar']) {
    write(root, `metadata/${series}.json`, { series, images: {} })
  }
  write(root, 'metadata/video.json', { images: { 'wallpaper/video/desktop/topic/cloud.mp4': { storage: 'r2', id: 'stable-video', unknown: true } }, future: 'keep' })
  write(root, 'data/video.json', { blob: 'published-video', schema: 1, future: true })
  write(root, 'data/video/latest.json', { blob: 'published-latest', schema: 2 })
  write(root, 'stats.json', {
    total: { desktop: 9, mobile: 8, avatar: 7, video: 42, bing: 55, future: 88 },
    series: { video: { count: 42, opaque: true }, bing: { count: 55 }, future: { count: 88 }, desktop: { custom: 'keep' } },
    releases: [{ tag: 'v1.0.0', opaque: true }], custom: { untouched: true },
  })
  write(root, 'timestamps-backup-all.txt', 'video|desktop/topic/local.mp4|1700000000|v1.0.0\n')
}

function run(command, args, root, env = {}) {
  return spawnSync(command, args, { cwd: root, encoding: 'utf8', env: { ...process.env, ...env } })
}

function metadataRunner(root, script) {
  // 只重定向旧脚本的临时交接文件，所有处理逻辑使用原脚本。
  write(root, 'metadata-runner.cjs', fs.readFileSync(script, 'utf8').replaceAll('/tmp/metadata_processed.txt', path.join(root, 'processed.txt')))
  return path.join(root, 'metadata-runner.cjs')
}

for (const script of metadataScripts) {
  test(`${path.basename(path.dirname(path.dirname(script)))} force generation preserves published video and unrelated stats`, t => {
    const root = fixture(t)
    initialize(root)
    const preserved = ['metadata/video.json', 'data/video.json', 'data/video/latest.json']
      .map(file => [file, fs.readFileSync(path.join(root, file), 'utf8')])
    const result = run(process.execPath, [metadataRunner(root, script), root, 'v1.0.1', '--force'], root)
    assert.equal(result.status, 0, result.stderr)
    for (const [file, content] of preserved) assert.equal(fs.readFileSync(path.join(root, file), 'utf8'), content, file)
    const stats = JSON.parse(fs.readFileSync(path.join(root, 'stats.json')))
    assert.equal(stats.total.video, 42)
    assert.equal(stats.total.bing, 55)
    assert.equal(stats.total.future, 88)
    assert.deepEqual(stats.series.video, { count: 42, opaque: true })
    assert.deepEqual(stats.series.bing, { count: 55 })
    assert.deepEqual(stats.custom, { untouched: true })
    assert.equal(stats.series.desktop.custom, 'keep')
    assert.equal(stats.total.desktop, 0)
    assert.equal(JSON.parse(fs.readFileSync(path.join(root, 'data/desktop.json'))).total, 0)
  })

  for (const series of ['video', 'future-series']) {
    test(`${path.basename(path.dirname(path.dirname(script)))} rejects ${series} pending without consuming the file`, t => {
      const root = fixture(t)
      initialize(root)
      const pending = { images: [{ series, relativePath: `wallpaper/${series}/new.mp4`, filename: 'new.mp4' }] }
      write(root, 'metadata-pending/one.json', pending)
      const result = run(process.execPath, [metadataRunner(root, script), root, 'v1.0.1'], root)
      assert.notEqual(result.status, 0, result.stdout)
      assert.deepEqual(JSON.parse(fs.readFileSync(path.join(root, 'metadata-pending/one.json'))), pending)
      assert.match(result.stderr, /series|系列/)
    })
  }

  test(`${path.basename(path.dirname(path.dirname(script)))} continues consuming valid static AI metadata`, t => {
    const root = fixture(t)
    initialize(root)
    write(root, 'wallpaper/desktop/topic/image.png', 'fixture')
    write(root, 'metadata-pending/static.json', { images: [{ series: 'desktop', relativePath: 'wallpaper/desktop/topic/image.png', category: 'topic', filename: 'image.png', createdAt: '2026-11-12 12:00:00', size: 7, resolution: { width: 1, height: 1 }, ai: { keywords: ['fixture'], description: 'keep AI' } }] })
    const result = run(process.execPath, [metadataRunner(root, script), root, 'v1.0.1'], root)
    assert.equal(result.status, 0, result.stderr)
    assert.equal(fs.existsSync(path.join(root, 'metadata-pending/static.json')), false)
    const metadata = JSON.parse(fs.readFileSync(path.join(root, 'metadata/desktop.json')))
    assert.equal(metadata.images['wallpaper/desktop/topic/image.png'].ai.description, 'keep AI')
    assert.equal(JSON.parse(fs.readFileSync(path.join(root, 'data/desktop.json'))).total, 1)
  })

  for (const failure of ['corrupt stats', 'JSON output failure', 'metadata save failure']) {
    test(`${path.basename(path.dirname(path.dirname(script)))} retains pending after ${failure} and recovers on retry`, t => {
      const root = fixture(t)
      initialize(root)
      write(root, 'wallpaper/desktop/topic/image.png', 'fixture')
      const pending = { images: [{ series: 'desktop', relativePath: 'wallpaper/desktop/topic/image.png', category: 'topic', filename: 'image.png', createdAt: '2026-11-12 12:00:00', size: 7, resolution: { width: 1, height: 1 }, ai: { keywords: ['fixture'], description: 'must survive failure' } }] }
      write(root, 'metadata-pending/recover.json', pending)
      const originalStats = fs.readFileSync(path.join(root, 'stats.json'), 'utf8')
      let blockedFile
      if (failure === 'corrupt stats') write(root, 'stats.json', '{broken json')
      else {
        blockedFile = failure === 'JSON output failure' ? 'data/desktop/latest.json' : 'metadata/mobile.json'
        fs.rmSync(path.join(root, blockedFile), { force: true })
        fs.mkdirSync(path.join(root, blockedFile), { recursive: true })
      }

      const runner = metadataRunner(root, script)
      const failed = run(process.execPath, [runner, root, 'v1.0.1'], root)
      assert.notEqual(failed.status, 0, failed.stdout)
      assert.equal(fs.existsSync(path.join(root, 'metadata-pending/recover.json')), true, 'pending was deleted before durable outputs succeeded')
      assert.deepEqual(JSON.parse(fs.readFileSync(path.join(root, 'metadata-pending/recover.json'))), pending)

      if (failure === 'corrupt stats') write(root, 'stats.json', originalStats)
      else {
        fs.rmdirSync(path.join(root, blockedFile))
        if (failure === 'metadata save failure') write(root, blockedFile, { series: 'mobile', images: {} })
      }
      const recovered = run(process.execPath, [runner, root, 'v1.0.1'], root)
      assert.equal(recovered.status, 0, recovered.stderr)
      assert.equal(fs.existsSync(path.join(root, 'metadata-pending/recover.json')), false)
      const desktop = JSON.parse(fs.readFileSync(path.join(root, 'metadata/desktop.json')))
      assert.equal(Object.keys(desktop.images).length, 1)
      assert.equal(desktop.images['wallpaper/desktop/topic/image.png'].ai.description, 'must survive failure')
      assert.equal(JSON.parse(fs.readFileSync(path.join(root, 'data/desktop.json'))).total, 1)
      assert.equal(JSON.parse(fs.readFileSync(path.join(root, 'metadata/mobile.json'))).count, 0, 'retry must finish metadata persistence even when the pending image was saved in the first attempt')
      assert.equal(JSON.parse(fs.readFileSync(path.join(root, 'stats.json'))).total.video, 42)
    })
  }
}

test('standalone data scan keeps video output and does not add video timestamps', t => {
  const root = fixture(t)
  initialize(root)
  write(root, 'package.json', { type: 'module' })
  for (const name of ['generate-data.js', 'codec-config.js']) {
    write(root, `scripts/${name}`, fs.readFileSync(path.join(pictureRoot, 'scripts', name), 'utf8'))
  }
  write(root, 'wallpaper/video/desktop/topic/local.mp4', 'fixture-video')
  write(root, 'wallpaper/desktop/topic/picture.png', 'fixture-picture')
  write(root, 'public/data/video.json', { stable: 'existing-video' })
  write(root, 'public/data/video/latest.json', { stable: 'existing-latest' })
  const result = run(process.execPath, [path.join(root, 'scripts/generate-data.js')], root, { SKIP_IMAGE_DIMENSIONS: 'true', SKIP_VIDEO_METADATA: 'true' })
  assert.equal(result.status, 0, result.stderr)
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(root, 'public/data/video.json'))), { stable: 'existing-video' })
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(root, 'public/data/video/latest.json'))), { stable: 'existing-latest' })
  assert.equal(JSON.parse(fs.readFileSync(path.join(root, 'public/data/desktop.json'))).total, 1)
  assert.equal(fs.readFileSync(path.join(root, 'timestamps-backup-all.txt'), 'utf8').split('\n').filter(line => line.startsWith('video|')).length, 1)
})

function binary(root, name, content) {
  write(root, `bin/${name}`, `#!/usr/bin/env bash\n${content}\n`)
  fs.chmodSync(path.join(root, 'bin', name), 0o755)
}

for (const full of [false, true]) {
  test(`R2 ${full ? 'full' : 'normal'} upload excludes all video objects`, t => {
    const root = fixture(t)
    for (const dir of ['wallpaper', 'thumbnail', 'preview']) {
      write(root, `${dir}/desktop/static.webp`, 'static')
      write(root, `${dir}/video/cloud.mp4`, 'video')
    }
    binary(root, 'aws', 'node "$R2_FAKE" "$@"')
    write(root, 'fake-aws.cjs', `const fs = require('node:fs'); const path = require('node:path'); const a = process.argv.slice(2); const source = a[2]; const excludes = a.flatMap((v,i) => v === '--exclude' ? [a[i+1]] : []); for (const group of ['desktop','video']) { if (group === 'video' && excludes.includes('video/*')) continue; for (const item of fs.readdirSync(path.join(source, group))) fs.appendFileSync(process.env.R2_LOG, source + group + '/' + item + '\\n'); } console.log('upload: fixture');`)
    const result = run('bash', [path.join(pictureRoot, 'scripts/upload-r2.sh'), ...(full ? ['--full'] : [])], root, {
      PATH: `${path.join(root, 'bin')}:${process.env.PATH}`, R2_FAKE: path.join(root, 'fake-aws.cjs'), R2_LOG: path.join(root, 'uploads.txt'),
      CLOUDFLARE_ACCOUNT_ID: 'fixture', CLOUDFLARE_R2_ACCESS_KEY: 'fixture', CLOUDFLARE_R2_SECRET_KEY: 'fixture',
    })
    assert.equal(result.status, 0, result.stderr)
    const uploads = fs.readFileSync(path.join(root, 'uploads.txt'), 'utf8')
    assert.match(uploads, /desktop\/static.webp/)
    assert.doesNotMatch(uploads, /video\//)
  })
}

for (const rejectPush of [true, false]) {
test(`rollback preserves mixed video releases when push is ${rejectPush ? 'rejected' : 'accepted'}`, t => {
  const root = fixture(t)
  initialize(root)
  const initialStats = JSON.parse(fs.readFileSync(path.join(root, 'stats.json')))
  initialStats.releases.push({ tag: 'v1.0.1', added: { desktop: 1, video: 3, bing: 2, future: 7 }, publisher: 'tester', opaque: 'keep' })
  write(root, 'stats.json', initialStats)
  write(root, 'timestamps-backup-all.txt', 'desktop|topic/old.png|1700000000|v1.0.1\nvideo|desktop/topic/cloud.mp4|1700000000|v1.0.1\nbing|daily.jpg|1700000000|v1.0.1\n')
  write(root, 'wallpaper/desktop/topic/old.png', 'fixture')
  binary(root, 'git', `case "$1" in\n tag) if [ "$2" = '-l' ]; then printf 'v1.0.1\\nv1.0.0\\n'; fi ;;\n push) printf '%s\\n' "$*" >> "$GIT_LOG"; exit ${rejectPush ? 17 : 0} ;;\nesac`)
  binary(root, 'gh', 'echo release >> "$GIT_LOG"')
  write(root, 'rollback.sh', fs.readFileSync(path.join(workflowRoot, 'scripts/rollback.sh'), 'utf8').replaceAll('/tmp/rollback_result.txt', path.join(root, 'rollback-result.txt')))
  const result = run('bash', [path.join(root, 'rollback.sh'), root, 'v1.0.1'], root, { PATH: `${path.join(root, 'bin')}:${process.env.PATH}`, GIT_LOG: path.join(root, 'git.txt') })
  if (rejectPush) assert.notEqual(result.status, 0, result.stdout)
  else assert.equal(result.status, 0, result.stderr)
  const stats = JSON.parse(fs.readFileSync(path.join(root, 'stats.json')))
  assert.equal(stats.total.video, 42)
  assert.equal(stats.total.bing, 55)
  assert.equal(stats.total.future, 88)
  assert.deepEqual(stats.releases.find(release => release.tag === 'v1.0.1'), { tag: 'v1.0.1', added: { video: 3, bing: 2, future: 7 }, publisher: 'tester', opaque: 'keep' })
  assert.match(fs.readFileSync(path.join(root, 'timestamps-backup-all.txt'), 'utf8'), /^video\|/m)
  assert.match(fs.readFileSync(path.join(root, 'timestamps-backup-all.txt'), 'utf8'), /^bing\|/m)
  assert.equal(fs.readFileSync(path.join(root, 'git.txt'), 'utf8').trim(), 'push')
  if (rejectPush) assert.doesNotMatch(result.stdout, /回滚成功/)
})
}

for (const nodeFallback of [false, true]) {
test(`release stats retains other series and history using ${nodeFallback ? 'Node fallback' : 'jq'}`, t => {
  const root = fixture(t)
  initialize(root)
  const initialStats = JSON.parse(fs.readFileSync(path.join(root, 'stats.json')))
  initialStats.releases = Array.from({ length: 51 }, (_, index) => ({ tag: `v0.0.${index}`, added: { video: 1 }, opaque: true }))
  write(root, 'stats.json', initialStats)
  // 仅替换临时交接文件路径，避免依赖机器上其他任务的 /tmp 状态。
  write(root, 'publish.sh', fs.readFileSync(path.join(workflowRoot, 'scripts/publish-release.sh'), 'utf8').replaceAll('/tmp/new_tag.txt', path.join(root, 'tag.txt')))
  write(root, 'tag.txt', 'v1.0.1')
  binary(root, 'git', 'if [ "$1" = status ]; then echo " M stats.json"; elif [ "$1" = push ]; then exit 17; fi')
  binary(root, 'gh', 'echo published > "$RELEASE_LOG"')
  if (nodeFallback) {
    for (const name of ['bash', 'date', 'cat']) fs.symlinkSync(`/bin/${name}`, path.join(root, 'bin', name))
    for (const name of ['grep', 'wc', 'tr']) fs.symlinkSync(`/usr/bin/${name}`, path.join(root, 'bin', name))
    fs.symlinkSync(process.execPath, path.join(root, 'bin/node'))
  }
  const result = run('bash', [path.join(root, 'publish.sh'), root, 'fixture', 'tester'], root, { PATH: nodeFallback ? path.join(root, 'bin') : `${path.join(root, 'bin')}:${process.env.PATH}`, RELEASE_LOG: path.join(root, 'released') })
  assert.notEqual(result.status, 0)
  const stats = JSON.parse(fs.readFileSync(path.join(root, 'stats.json')))
  assert.equal(stats.total.video, 42)
  assert.equal(stats.total.bing, 55)
  assert.equal(stats.total.bing, 55)
  assert.equal(stats.total.future, 88)
  assert.equal(stats.releases.length, 52)
  assert.deepEqual(stats.releases.at(-1), { tag: 'v0.0.50', added: { video: 1 }, opaque: true })
  assert.equal(fs.existsSync(path.join(root, 'released')), false)
})
}

function workflowSteps() {
  const source = fs.readFileSync(path.join(pictureRoot, '.github/workflows/sync-all.yml'), 'utf8')
  return [...source.matchAll(/^      - name: (.+)\n([\s\S]*?)(?=^      - name: |$(?![\s\S]))/gm)].flatMap(match => {
    const script = match[2].match(/^        run: \|\n((?:^          .*\n|^\s*\n)*)/m)?.[1]
    return script ? [{ name: match[1], script: script.replace(/^          /gm, '').replace(/\$\{\{[^}]+\}\}/g, '1') }] : []
  })
}

test('sync-all metadata push rejection stops external stages', t => {
  const root = fixture(t)
  initialize(root)
  write(root, 'scripts/upload-r2.sh', fs.readFileSync(path.join(pictureRoot, 'scripts/upload-r2.sh'), 'utf8'))
  write(root, 'wallpaper/desktop/static.png', 'fixture')
  binary(root, 'git', 'if [ "$1" = status ]; then echo " M data/desktop.json"; elif [ "$1" = push ]; then exit 17; fi')
  binary(root, 'aws', 'echo r2 >> "$EXTERNAL_LOG"')
  binary(root, 'pip', 'exit 0')
  binary(root, 'gh', 'echo release >> "$EXTERNAL_LOG"')
  const names = ['Commit metadata and data updates', 'Upload to Cloudflare R2', 'Create Release']
  const script = workflowSteps().filter(step => names.includes(step.name)).map(step => step.script).join('\n')
  const result = run('bash', ['-e', '-o', 'pipefail', '-c', script], root, {
    PATH: `${path.join(root, 'bin')}:${process.env.PATH}`, EXTERNAL_LOG: path.join(root, 'external.txt'), GITHUB_OUTPUT: path.join(root, 'out'),
    CLOUDFLARE_ACCOUNT_ID: 'fixture', CLOUDFLARE_R2_ACCESS_KEY: 'fixture', CLOUDFLARE_R2_SECRET_KEY: 'fixture',
  })
  assert.notEqual(result.status, 0, result.stdout)
  assert.equal(fs.existsSync(path.join(root, 'external.txt')), false, 'R2/Release ran before rejected metadata push')
})

test('sync-all JSON mirror keeps published video objects untouched', t => {
  const root = fixture(t)
  initialize(root)
  write(root, 'data/desktop.json', { total: 1 })
  write(root, 'data/bing/latest.json', { total: 1 })
  binary(root, 'aws', 'node "$R2_FAKE" "$@"')
  write(root, 'fake-aws.cjs', `const fs = require('node:fs'); const path = require('node:path'); const a = process.argv.slice(2); const excluded = a.flatMap((v,i) => v === '--exclude' ? [a[i+1]] : []); const log = f => fs.appendFileSync(process.env.R2_LOG, f+'\\n'); if(a[1] === 'cp') log(a[2]); else { function walk(d) { for(const entry of fs.readdirSync(d,{withFileTypes:true})) { const f = path.join(d,entry.name); if(entry.isDirectory()) walk(f); else { const rel = path.relative(a[2],f); if (!excluded.some(e => new RegExp('^'+e.replaceAll('.','\\\\.').replaceAll('*','.*')+'$').test(rel))) log(f); } } } walk(a[2]); }`)
  const step = workflowSteps().find(step => step.name === 'Upload JSON data to R2')
  const result = run('bash', ['-e', '-o', 'pipefail', '-c', step.script], root, {
    PATH: `${path.join(root, 'bin')}:${process.env.PATH}`, R2_FAKE: path.join(root, 'fake-aws.cjs'), R2_LOG: path.join(root, 'uploads'), CLOUDFLARE_ACCOUNT_ID: 'fixture',
  })
  assert.equal(result.status, 0, result.stderr)
  const uploads = fs.readFileSync(path.join(root, 'uploads'), 'utf8')
  assert.match(uploads, /data\/desktop.json/)
  assert.doesNotMatch(uploads, /data\/video/)
})

test('sync-all stats keeps video totals and rejects failed stats push', t => {
  const root = fixture(t)
  initialize(root)
  for (const series of ['desktop', 'mobile', 'avatar']) write(root, `wallpaper/${series}/one.jpg`, 'fixture')
  binary(root, 'git', 'if [ "$1" = push ]; then exit 17; fi')
  const step = workflowSteps().find(step => step.name === 'Update stats.json')
  const result = run('bash', ['-e', '-o', 'pipefail', '-c', step.script], root, { PATH: `${path.join(root, 'bin')}:${process.env.PATH}` })
  assert.notEqual(result.status, 0, result.stdout)
  const stats = JSON.parse(fs.readFileSync(path.join(root, 'stats.json')))
  assert.equal(stats.total.video, 42)
  assert.equal(stats.total.bing, 55)
  assert.equal(stats.total.future, 88)
  assert.deepEqual(stats.series.video, { count: 42, opaque: true })
})

test('tag recovery cannot report success for a local tag whose push is rejected', t => {
  const root = fixture(t)
  write(root, 'create-tag.sh', fs.readFileSync(path.join(workflowRoot, 'scripts/create-tag.sh'), 'utf8').replaceAll('/tmp/new_tag.txt', path.join(root, 'tag.txt')))
  binary(root, 'git', 'if [ "$1" = tag ]; then echo "v1.0.1"; elif [ "$1" = push ]; then exit 17; fi')
  const result = run('bash', [path.join(root, 'create-tag.sh'), root], root, { PATH: `${path.join(root, 'bin')}:${process.env.PATH}` })
  assert.notEqual(result.status, 0, result.stdout)
  assert.equal(fs.existsSync(path.join(root, 'tag.txt')), false)
})

test('failed R2 upload exits before reporting completion', t => {
  const root = fixture(t)
  write(root, 'wallpaper/desktop/static.png', 'fixture')
  binary(root, 'aws', 'exit 17')
  const result = run('bash', [path.join(pictureRoot, 'scripts/upload-r2.sh')], root, {
    PATH: `${path.join(root, 'bin')}:${process.env.PATH}`, CLOUDFLARE_ACCOUNT_ID: 'fixture', CLOUDFLARE_R2_ACCESS_KEY: 'fixture', CLOUDFLARE_R2_SECRET_KEY: 'fixture',
  })
  assert.notEqual(result.status, 0)
  assert.doesNotMatch(result.stdout, /Upload Complete!/)
})
