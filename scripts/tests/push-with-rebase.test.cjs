const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { execFileSync } = require('node:child_process')
const { test } = require('node:test')

function git(cwd, ...args) {
  return execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim()
}

test('concurrent commit is preserved when a push needs rebase', t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'wallpaper-push-retry-'))
  t.after(() => fs.rmSync(root, { recursive: true, force: true }))
  const source = path.join(root, 'source')
  const remote = path.join(root, 'remote.git')
  const first = path.join(root, 'first')
  const second = path.join(root, 'second')
  fs.mkdirSync(source)
  git(source, 'init', '-q', '-b', 'main')
  git(source, 'config', 'user.name', 'Test')
  git(source, 'config', 'user.email', 'test@example.test')
  fs.writeFileSync(path.join(source, 'base.txt'), 'base')
  git(source, 'add', '.')
  git(source, 'commit', '-qm', 'base')
  git(root, 'clone', '--bare', source, remote)
  git(root, 'clone', remote, first)
  git(root, 'clone', remote, second)
  for (const checkout of [first, second]) {
    git(checkout, 'config', 'user.name', 'Test')
    git(checkout, 'config', 'user.email', 'test@example.test')
  }

  fs.writeFileSync(path.join(second, 'other.txt'), 'other')
  git(second, 'add', '.')
  git(second, 'commit', '-qm', 'other')
  git(second, 'push', 'origin', 'main')
  fs.writeFileSync(path.join(first, 'bing.txt'), 'bing')
  git(first, 'add', '.')
  git(first, 'commit', '-qm', 'bing')

  execFileSync('bash', [path.resolve('scripts/lib/push-with-rebase.sh')], {
    cwd: first, stdio: ['ignore', 'pipe', 'pipe']
  })
  assert.equal(git(first, 'rev-parse', 'HEAD'), git(remote, 'rev-parse', 'main'))
  assert.equal(fs.readFileSync(path.join(first, 'other.txt'), 'utf8'), 'other')
  assert.equal(fs.readFileSync(path.join(first, 'bing.txt'), 'utf8'), 'bing')
})
