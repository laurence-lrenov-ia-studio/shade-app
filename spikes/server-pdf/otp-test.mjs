/* global fetch, AbortSignal */
import assert from 'node:assert/strict'
import { execFileSync, spawnSync } from 'node:child_process'
import { readFileSync } from 'node:fs'
import { setTimeout } from 'node:timers/promises'
import process from 'node:process'

// Never print bodies, codes or assertion values derived from codes.
const edge = 'http://127.0.0.1:54321/functions/v1/otp-spike'
const mailbox = 'http://127.0.0.1:54324'
const codes = []
const messages = []
const post = async data => {
  const response = await fetch(edge, { method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data), signal: AbortSignal.timeout(10000) })
  const result = await response.json()
  assert.ok(response.status === (data.action === 'issue' ? 201 : 200), 'Unexpected HTTP status')
  assert.equal(response.headers.get('cache-control'), 'no-store')
  return result
}
async function issue(options = {}) {
  const challenge = await post({ action: 'issue', ...options })
  assert.ok(!('code' in challenge), 'API must not return a code')
  const listing = await (await fetch(`${mailbox}/api/v1/messages`)).json()
  const item = listing.messages.find(item => item.Subject === `SHADE technical OTP ${challenge.id}`)
  assert.ok(Boolean(item), 'Message captured and listed in Mailpit')
  messages.push(item.ID)
  const message = await (await fetch(`${mailbox}/api/v1/message/${item.ID}`)).json()
  assert.ok(message.To.every(item => item.Address === 'recipient@shade.invalid'), 'Fictional recipient only')
  const code = /Code: (\d{6})/u.exec(message.Text)?.[1]
  assert.ok(Boolean(code), 'Six-digit code generated')
  codes.push(code)
  return { id: challenge.id, code }
}
const verify = async (challenge, code = challenge.code) =>
  (await post({ action: 'verify', id: challenge.id, code })).state

try {
  const ui = await fetch(mailbox)
  assert.ok(ui.ok && (await ui.text()).includes('Mailpit'), 'Mailpit web UI available')
  const correct = await issue()
  assert.equal(await verify(correct), 'valid')
  assert.equal(await verify(correct), 'invalid')
  const wrong = await issue()
  const wrongCode = ((Number(wrong.code) + 1) % 1000000).toString().padStart(6, '0')
  assert.equal(await verify(wrong, wrongCode), 'invalid')
  assert.equal(await verify(wrong), 'valid')
  const expired = await issue({ ttlMs: 1000 })
  await setTimeout(1100)
  assert.equal(await verify(expired), 'expired')
  const locked = await issue({ maxAttempts: 2 })
  const other = ((Number(locked.code) + 1) % 1000000).toString().padStart(6, '0')
  assert.equal(await verify(locked, other), 'invalid')
  assert.equal(await verify(locked, other), 'attempts_exceeded')
  assert.equal(await verify(locked), 'attempts_exceeded')
  const concurrent = await issue()
  const results = await Promise.all([verify(concurrent), verify(concurrent)])
  assert.deepEqual(results.sort(), ['invalid', 'valid'])
  const bad = await fetch(edge, { method: 'POST', body: '{' })
  assert.equal(bad.status, 400)
  const destination = await fetch(edge, { method: 'POST', body: JSON.stringify({
    action: 'issue', email: 'other@shade.invalid' }) })
  assert.equal(destination.status, 400)
  const audit = await post({ action: 'audit' })
  assert.ok(audit.events.length >= 10)
  assert.ok(audit.events.every(event => Object.keys(event).sort().join(',') === 'at,id,state'))
  const localLogs = ['supabase_edge_runtime_shade-pdf-spike', 'supabase_kong_shade-pdf-spike',
    'supabase_inbucket_shade-pdf-spike'].map(name => {
      const result = spawnSync('docker', ['logs', name], { encoding: 'utf8' })
      assert.equal(result.status, 0)
      return result.stdout + result.stderr
    }).join('\n')
  const files = execFileSync('git', ['ls-files', '--cached', '--others', '--exclude-standard'],
    { encoding: 'utf8' }).trim().split(/\r?\n/u)
  const content = files.map(path => readFileSync(path, 'utf8')).join('\n')
  for (const code of codes) {
    const pattern = new RegExp(`(?<![0-9])${code}(?![0-9])`, 'u')
    assert.ok(!pattern.test(localLogs), 'No issued code in container stdout logs')
    assert.ok(!pattern.test(JSON.stringify(audit)), 'No issued code in audit')
    assert.ok(!pattern.test(content), 'No issued code in versionable files')
  }
  process.stdout.write('PASS: generation; Mailpit capture/UI; valid; invalid; expired; attempts_exceeded; replay; concurrent single-use; invalid input; audit; no code in logs/files\n')
} finally {
  for (const id of messages) {
    const response = await fetch(`${mailbox}/api/v1/messages`, { method: 'DELETE',
      headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ IDs: [id] }) })
    assert.ok(response.ok, 'Delete only messages created by this test')
  }
  const listing = await (await fetch(`${mailbox}/api/v1/messages`)).json()
  assert.ok(!listing.messages.some(item => messages.includes(item.ID)), 'Test emails removed')
  process.stdout.write('PASS: test emails removed from Mailpit; no code written by test runner\n')
}
