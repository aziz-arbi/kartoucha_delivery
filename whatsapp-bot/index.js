const admin = require('firebase-admin');
const qrcode = require('qrcode-terminal');
const { Client, LocalAuth } = require('whatsapp-web.js');
const crypto = require('crypto');
const path = require('path');

const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT;
if (serviceAccountPath) {
  const serviceAccount = require(path.resolve(serviceAccountPath));
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
} else {
  admin.initializeApp();
}

const db = admin.firestore();
const client = new Client({
  authStrategy: new LocalAuth({
    clientId: 'agareb-delivery',
    dataPath: process.env.WWEBJS_DATA_PATH || './.wwebjs_auth'
  }),
  puppeteer: {
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
  }
});

function normalizeTunisiaPhone(phone) {
  let value = String(phone || '').replace(/[^0-9]/g, '');
  if (value.startsWith('00')) value = value.substring(2);
  if (value.startsWith('216')) return value;
  if (value.length === 8) return `216${value}`;
  return value;
}

function generateCode() {
  return crypto.randomInt(100000, 1000000).toString();
}

function messageFor(name, code) {
  return [
    'Agareb Delivery',
    '',
    `Bonjour ${name || ''} 👋`,
    `Votre code de vérification est : ${code}`,
    '',
    'Ce code expire dans 10 minutes.',
    "Ne partagez jamais ce code avec quelqu'un."
  ].join('\n');
}

async function claimRegistration(ref) {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return null;
    const data = snap.data();
    if (data.verificationStatus !== 'pending') return null;
    const code = generateCode();
    const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + 10 * 60 * 1000);
    tx.update(ref, {
      verificationStatus: 'sending',
      verificationCode: code,
      verificationExpiresAt: expiresAt,
      verificationError: admin.firestore.FieldValue.delete()
    });
    return { data, code };
  });
}

async function processRegistration(doc) {
  const ref = doc.ref;
  const claimed = await claimRegistration(ref);
  if (!claimed) return;
  const { data, code } = claimed;
  const phone = normalizeTunisiaPhone(data.phone);
  try {
    if (!/^216\d{8}$/.test(phone)) throw new Error('Invalid Tunisia phone number');
    await client.sendMessage(`${phone}@c.us`, messageFor(data.name, code));
    await ref.update({
      verificationStatus: 'sent',
      verificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
      verificationError: admin.firestore.FieldValue.delete()
    });
    console.log(`Verification code sent to ${phone}`);
  } catch (error) {
    console.error(`Failed to send verification to ${phone}:`, error.message);
    await ref.update({
      verificationStatus: 'failed',
      verificationError: String(error.message || error),
      verificationFailedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  }
}

client.on('qr', (qr) => {
  console.log('\nScan this QR code with the WhatsApp account used by Agareb Delivery:\n');
  qrcode.generate(qr, { small: true });
});
client.on('authenticated', () => console.log('WhatsApp authenticated.'));
client.on('ready', async () => {
  console.log('WhatsApp verification service is ready.');
  const pending = await db.collection('pending_users').where('verificationStatus', '==', 'pending').get();
  for (const doc of pending.docs) await processRegistration(doc);
});
client.on('auth_failure', (message) => console.error('WhatsApp authentication failed:', message));
client.on('disconnected', (reason) => console.error('WhatsApp disconnected:', reason));

db.collection('pending_users').where('verificationStatus', '==', 'pending').onSnapshot(
  (snapshot) => {
    for (const change of snapshot.docChanges()) {
      if (change.type === 'added' || change.type === 'modified') {
        processRegistration(change.doc).catch((error) => console.error('Registration processing error:', error));
      }
    }
  },
  (error) => { console.error('Firestore listener error:', error); process.exitCode = 1; }
);

client.initialize();
