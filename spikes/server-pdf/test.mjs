/* global fetch */
import { Buffer } from 'node:buffer'
import { TextDecoder } from 'node:util'
import { URL } from 'node:url'
import assert from 'node:assert/strict'
import { test } from 'node:test'
import { once } from 'node:events'
import { mkdir, writeFile } from 'node:fs/promises'
import { webcrypto } from 'node:crypto'
import { PDFDocument } from 'pdf-lib'
import { createTestServer } from './server.mjs'
import { renderPdf } from './render.mjs'

test('local HTTP generation, valid PDF, SHA-256 and rejected route', async () => {
  const server = createTestServer()
  server.listen(0, '127.0.0.1')
  await once(server, 'listening')
  try {
    const url = `http://127.0.0.1:${server.address().port}`
    const response = await fetch(`${url}/test.pdf`)
    assert.equal(response.status, 200)
    assert.equal(response.headers.get('content-type'), 'application/pdf')
    assert.equal(response.headers.get('cache-control'), 'no-store')
    const bytes = new Uint8Array(await response.arrayBuffer())
    assert.equal(new TextDecoder().decode(bytes.slice(0, 5)), '%PDF-')
    assert.equal((await PDFDocument.load(bytes)).getPageCount(), 1)
    const digest = await webcrypto.subtle.digest('SHA-256', bytes)
    const hex = Buffer.from(digest).toString('hex')
    assert.match(hex, /^[a-f0-9]{64}$/u)
    assert.equal((await fetch(`${url}/missing`)).status, 404)
    assert.equal((await fetch(`${url}/test.pdf`, { method: 'POST' })).status, 404)
    const output = new URL('./output/', import.meta.url)
    await mkdir(output, { recursive: true })
    await writeFile(new URL('technical-test.pdf', output), bytes)
    await writeFile(new URL('technical-test.sha256', output), `${hex}\n`)
  } finally {
    await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()))
  }
})

test('structured input changes the rendered bytes; invalid text rejected', async () => {
  const fixture = { text: 'Échantillon technique', date: '2026-10-23', id: 'TEST-0002' }
  const first = await renderPdf(fixture)
  const second = await renderPdf({ ...fixture, text: 'Autre texte fictif' })
  assert.notDeepEqual(first, second)
  await assert.rejects(renderPdf({ ...fixture, text: '\n' }), TypeError)
  await assert.rejects(renderPdf({ ...fixture, text: 'x'.repeat(71) }), TypeError)
})
