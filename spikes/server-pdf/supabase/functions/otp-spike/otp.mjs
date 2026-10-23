/* global crypto, TextEncoder */
// Technical in-memory prototype only: no database, filesystem or Auth.
export function createOtpService({ send, now = Date.now }) {
  const records = new Map()
  const journal = []
  const key = crypto.subtle.generateKey({ name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify'])
  const encoder = new TextEncoder()
  const payload = (id, code) => encoder.encode(`${id}:${code}`)
  const event = (id, state) => {
    journal.push({ id, state, at: new Date(now()).toISOString() })
    if (journal.length > 200) journal.shift()
  }
  function randomCode() {
    const values = new Uint32Array(1)
    // Rejection sampling avoids modulo bias for the six-digit space.
    do { crypto.getRandomValues(values) } while (values[0] >= 4294000000)
    return (values[0] % 1000000).toString().padStart(6, '0')
  }
  return {
    async issue({ ttlMs = 60000, maxAttempts = 3 } = {}) {
      if (!Number.isInteger(ttlMs) || ttlMs < 1000 || ttlMs > 60000 ||
          !Number.isInteger(maxAttempts) || maxAttempts < 1 || maxAttempts > 3) {
        throw new TypeError('Invalid technical configuration')
      }
      for (const [id, record] of records) {
        if (now() > record.expiresAt + 60000) records.delete(id)
      }
      if (records.size >= 100) throw new RangeError('Technical capacity reached')
      const id = crypto.randomUUID()
      const code = randomCode()
      const digest = await crypto.subtle.sign('HMAC', await key, payload(id, code))
      try {
        await send({ id, code })
      } catch {
        event(id, 'delivery_failed')
        throw new Error('Local delivery failed')
      }
      const expiresAt = now() + ttlMs
      records.set(id, { digest, expiresAt, maxAttempts, attempts: 0, state: 'pending' })
      event(id, 'issued')
      return { id, expiresAt, maxAttempts }
    },
    async verify(id, code) {
      const record = records.get(id)
      const finish = state => { event(id, state); return { state } }
      if (!record) return finish('invalid')
      if (record.state === 'valid') return finish('invalid') // Single use, including replay.
      if (record.state === 'attempts_exceeded') return finish('attempts_exceeded')
      if (now() >= record.expiresAt) {
        record.state = 'expired'
        return finish('expired')
      }
      record.attempts += 1
      const matches = typeof code === 'string' && /^\d{6}$/u.test(code) &&
        await crypto.subtle.verify('HMAC', await key, record.digest, payload(id, code))
      if (now() >= record.expiresAt) {
        record.state = 'expired'
      } else if (matches) {
        record.state = 'valid'
      } else if (record.attempts >= record.maxAttempts) {
        record.state = 'attempts_exceeded'
      } else {
        return finish('invalid')
      }
      return finish(record.state)
    },
    audit() { return journal.map(entry => ({ ...entry })) },
  }
}
