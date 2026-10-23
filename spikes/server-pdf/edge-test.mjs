/* global fetch, AbortSignal */
import process from 'node:process'
import assert from 'node:assert/strict'
import { Buffer } from 'node:buffer'
import { createHash } from 'node:crypto'
import { mkdir, writeFile } from 'node:fs/promises'
import { performance } from 'node:perf_hooks'
import { URL } from 'node:url'
import { PDFDocument } from 'pdf-lib'

// Fixed loopback destination: this test cannot target a remote project.
const url = 'http://127.0.0.1:54321/functions/v1/pdf-spike'
const output = new URL('./output/', import.meta.url)
await mkdir(output, { recursive: true })
const metrics = []
for (const suffix of ['A', 'B']) {
  const fixture = { text: `Texte fictif Edge ${suffix}`, date: '2026-10-23',
    id: suffix === 'A' ? 'TEST-EDGE-0001' : 'TEST-EDGE-0002' }
  const start = performance.now()
  const response = await fetch(url, { method: 'POST',
    headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(fixture),
    signal: AbortSignal.timeout(60000) })
  assert.equal(response.status, 200)
  assert.equal(response.headers.get('content-type'), 'application/pdf')
  assert.equal(response.headers.get('cache-control'), 'no-store')
  const bytes = Buffer.from(await response.arrayBuffer())
  assert.equal(bytes.subarray(0, 5).toString(), '%PDF-')
  assert.equal((await PDFDocument.load(bytes)).getPageCount(), 1)
  const sha256 = createHash('sha256').update(bytes).digest('hex')
  assert.equal(response.headers.get('x-pdf-sha256'), sha256)
  assert.match(response.headers.get('server-timing'), /^pdf;dur=\d+\.\d+$/u)
  metrics.push({ fixture: suffix, totalMs: performance.now() - start,
    serverTiming: response.headers.get('server-timing'), bytes: bytes.length, sha256 })
  await writeFile(new URL(`edge-${suffix}.pdf`, output), bytes)
}
for (const body of ['{}', 'null', '{']) {
  const response = await fetch(url, { method: 'POST', body })
  assert.equal(response.status, 400)
  assert.deepEqual(await response.json(), { error: 'Invalid technical fixture' })
}
assert.equal((await fetch(url)).status, 405)
await writeFile(new URL('edge-results.json', output), JSON.stringify(metrics, null, 2))
// Test output only; no document payload or secret logged.
process.stdout.write(`${JSON.stringify(metrics, null, 2)}\nEdge HTTP checks: OK\n`)
