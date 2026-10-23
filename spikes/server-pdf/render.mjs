import { PDFDocument, StandardFonts } from 'pdf-lib'

// Pure renderer: no HTTP, Node APIs, database, storage or frontend imports.
export async function renderPdf({ text, date, id }) {
  for (const value of [text, date, id]) {
    if (typeof value !== 'string' || value.length < 1 || value.length > 70 ||
        /[^\x20-\x7e\u00c0-\u00ff]/u.test(value)) {
      throw new TypeError('Expected short, printable Latin text')
    }
  }
  const pdf = await PDFDocument.create()
  const font = await pdf.embedFont(StandardFonts.Helvetica)
  const page = pdf.addPage([595.28, 841.89])
  const lines = ['TEST TECHNIQUE PDF - DONNEES FICTIVES', text,
    `Date : ${date}`, `Identifiant fictif : ${id}`]
  lines.forEach((line, index) => {
    page.drawText(line, { x: 48, y: 780 - index * 32, size: 11, font })
  })
  return pdf.save()
}
