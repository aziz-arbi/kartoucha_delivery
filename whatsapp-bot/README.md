# Agareb Delivery — Automatic WhatsApp Verification

This service removes the manual admin approval step from account registration.

Flow:
1. Flutter creates a pending_users document with verificationStatus = pending.
2. This Node.js service detects it.
3. The service generates a cryptographically random 6-digit code.
4. The code is stored in Firestore and sent to the user's WhatsApp number.
5. The user enters the code in Flutter.
6. Flutter creates the Firebase Auth account and user profile.

## Requirements
- Node.js 22+
- Firebase service-account JSON with Firestore access
- Dedicated WhatsApp account/number for Agareb Delivery
- Persistent server/VM
- Chromium/Puppeteer support

## Run locally
Set FIREBASE_SERVICE_ACCOUNT to the absolute path of the Firebase service-account JSON, then run npm install and npm start.

The first startup prints a WhatsApp QR code. Scan it from the WhatsApp account that will send verification messages. LocalAuth persists the session in .wwebjs_auth/.

## Production
Use a persistent Node.js host rather than a serverless function because the WhatsApp Web session must stay alive. Store the Firebase service-account secret and persisted WhatsApp authentication data securely.

Note: whatsapp-web.js is an unofficial WhatsApp Web client. WhatsApp can change its web client behavior or restrict unofficial automation. For production scale, the official WhatsApp Business Platform is the safer long-term option.
