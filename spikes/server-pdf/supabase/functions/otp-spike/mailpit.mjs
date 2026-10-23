/* global fetch, AbortSignal */
// Only this adapter knows the email provider. Never accepts an arbitrary URL/address.
export async function sendViaMailpit({ id, code }) {
  const response = await fetch('http://supabase_inbucket_shade-pdf-spike:8025/api/v1/send', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      From: { Email: 'sender@shade.invalid', Name: 'Technical spike' },
      To: [{ Email: 'recipient@shade.invalid' }],
      Subject: `SHADE technical OTP ${id}`,
      Text: `Technical test only. Code: ${code}`,
    }),
    signal: AbortSignal.timeout(5000),
  })
  if (!response.ok) throw new Error('Mailpit unavailable')
}
