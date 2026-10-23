import { createServer } from 'node:http'
import { renderPdf } from './render.mjs'

// Local test adapter only. No user input, authentication or production endpoint.
export function createTestServer() {
  return createServer(async (request, response) => {
    const headers = { 'Cache-Control': 'no-store' }
    if (request.method !== 'GET' || request.url !== '/test.pdf') {
      response.writeHead(404, headers).end()
      return
    }
    try {
      const bytes = await renderPdf({
        text: 'Texte dynamique : génération serveur fictive',
        date: new Date().toISOString(),
        id: 'TEST-0001',
      })
      response.writeHead(200, {
        ...headers,
        'Content-Type': 'application/pdf',
        'Content-Disposition': 'attachment; filename="technical-test.pdf"',
      }).end(bytes)
    } catch {
      response.writeHead(500, headers).end()
    }
  })
}
