/* global Deno */
import { renderPdf } from '../_shared/render.mjs'

// Local-only technical endpoint. Deliberately no SDK, database or Storage calls.
Deno.serve(async (request: Request) => {
  const headers = { 'Cache-Control': 'no-store' }
  if (request.method !== 'POST') {
    return new Response('Method not allowed', { status: 405, headers })
  }
  let data
  try {
    data = await request.json()
    // Restrict to the two known fictional fixtures used by the local test.
    if (!data || Object.keys(data).sort().join(',') !== 'date,id,text' ||
      !['TEST-EDGE-0001', 'TEST-EDGE-0002'].includes(data.id) ||
      data.date !== '2026-10-23' ||
      !['Texte fictif Edge A', 'Texte fictif Edge B'].includes(data.text)) {
      throw new TypeError('Invalid technical fixture')
    }
  } catch {
    return Response.json({ error: 'Invalid technical fixture' }, { status: 400, headers })
  }
  try {
    const start = performance.now()
    const bytes = await renderPdf(data)
    const renderMs = performance.now() - start
    const digest = await crypto.subtle.digest('SHA-256', bytes)
    const sha256 = Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, '0')).join('')
    return new Response(bytes, {
      headers: {
        ...headers,
        'Content-Type': 'application/pdf',
        'X-PDF-SHA256': sha256,
        'Server-Timing': `pdf;dur=${renderMs.toFixed(3)}`,
      },
    })
  } catch {
    return Response.json({ error: 'PDF generation failed' }, { status: 500, headers })
  }
})
