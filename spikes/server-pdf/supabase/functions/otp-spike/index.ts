/* global Deno */
import { createOtpService } from './otp.mjs'
import { sendViaMailpit } from './mailpit.mjs'

const service = createOtpService({ send: sendViaMailpit })
// Serialize within this one worker: no overlapping validation can consume twice.
let queue = Promise.resolve()
Deno.serve((request: Request) => {
  const handle = async () => {
    const headers = { 'Cache-Control': 'no-store' }
    const reply = (body: object, status = 200) => Response.json(body, { status, headers })
    if (request.method !== 'POST') return reply({ error: 'POST required' }, 405)
    try {
      const body = await request.text()
      if (body.length > 1024) return reply({ error: 'Invalid input' }, 400)
      const data = JSON.parse(body)
      if (!data || typeof data !== 'object') return reply({ error: 'Invalid input' }, 400)
      if (data.action === 'issue') {
        if (Object.keys(data).some(key => !['action', 'ttlMs', 'maxAttempts'].includes(key))) {
          return reply({ error: 'Invalid input' }, 400)
        }
        return reply(await service.issue({ ttlMs: data.ttlMs, maxAttempts: data.maxAttempts }), 201)
      }
      if (data.action === 'verify' && typeof data.id === 'string' &&
          /^[a-f0-9-]{36}$/u.test(data.id) && typeof data.code === 'string' && data.code.length <= 32) {
        return reply(await service.verify(data.id, data.code))
      }
      // Local diagnostics only: ids, timestamps and states; no code, hash or key.
      if (data.action === 'audit') return reply({ events: service.audit() })
      return reply({ error: 'Invalid input' }, 400)
    } catch (error) {
      return reply({ error: error instanceof TypeError || error instanceof SyntaxError ?
        'Invalid input' : 'Local operation failed' },
      error instanceof TypeError || error instanceof SyntaxError ? 400 : 503)
    }
  }
  const result = queue.then(handle)
  queue = result.then(() => undefined, () => undefined)
  return result
})
