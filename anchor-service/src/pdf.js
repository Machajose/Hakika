/**
 * Builds the certificate PDF with a QR code. Layout is intentionally simple - make it pretty later.
 * Uses only the built-in PDF fonts (no font files needed).
 */
const { PDFDocument, StandardFonts, rgb } = require("pdf-lib");
const QRCode = require("qrcode");

const TITLES = {
  CLEARANCE: "CERTIFICATE OF CLEARANCE",
  TRANSCRIPT: "OFFICIAL ACADEMIC TRANSCRIPT",
  DEGREE: "DEGREE CERTIFICATE",
  STUDENT_STATUS: "LETTER OF STUDENT STATUS",
};

// Standard PDF fonts only support basic Latin characters; replace anything else so generation never crashes.
const safe = (s) => String(s).normalize("NFKD").replace(/[^\x20-\x7E]/g, "?");

async function buildCertificatePdf({ institution, docId, docType, regNo, name, program, issuedOn, verifyUrl, approvals = [] }) {
  const pdf = await PDFDocument.create();
  pdf.setTitle(`${docType} - ${regNo}`);
  pdf.setProducer("MUT-Verify (prototype)");
  const page = pdf.addPage([595.28, 841.89]); // A4
  const { width } = page.getSize();
  const bold = await pdf.embedFont(StandardFonts.HelveticaBold);
  const reg = await pdf.embedFont(StandardFonts.Helvetica);
  const navy = rgb(0.06, 0.2, 0.4);
  const grey = rgb(0.35, 0.35, 0.35);

  const center = (text, y, size, font, color = rgb(0, 0, 0)) => {
    const t = safe(text);
    page.drawText(t, { x: (width - font.widthOfTextAtSize(t, size)) / 2, y, size, font, color });
  };

  page.drawRectangle({ x: 25, y: 25, width: width - 50, height: 841.89 - 50, borderColor: navy, borderWidth: 2 });
  center(institution.toUpperCase(), 770, 18, bold, navy);
  center("Innovation for Prosperity", 750, 11, reg, grey);
  center(TITLES[docType] || docType, 700, 20, bold);
  center("PROTOTYPE - DEMONSTRATION DOCUMENT - NOT AN OFFICIAL RECORD", 680, 8, bold, rgb(0.7, 0.1, 0.1));

  center("This is to certify that", 630, 12, reg, grey);
  center(name, 600, 22, bold, navy);
  center(`Registration No: ${regNo}`, 575, 12, reg);
  center(`Programme: ${program}`, 555, 12, reg);

  let y = 515;
  if (approvals.length) {
    center("has been cleared by the following offices:", y, 12, reg, grey);
    y -= 25;
    for (const a of approvals) {
      center(`${a.office}  -  ${a.status}  (${a.date})`, y, 11, reg);
      y -= 18;
    }
  }

  center(`Issued on: ${issuedOn}`, 330, 11, reg);
  center(`Document ID: ${docId}`, 314, 9, reg, grey);

  const qrPng = await QRCode.toBuffer(verifyUrl, { errorCorrectionLevel: "M", margin: 1, width: 360 });
  const img = await pdf.embedPng(qrPng);
  page.drawImage(img, { x: (width - 130) / 2, y: 160, width: 130, height: 130 });
  center("Scan to verify this document is genuine", 140, 10, bold, navy);
  center("IMPORTANT: after scanning, check that the name and details shown on the", 118, 8, reg, grey);
  center("verification page match this document exactly.", 107, 8, reg, grey);

  return Buffer.from(await pdf.save());
}

module.exports = { buildCertificatePdf };
