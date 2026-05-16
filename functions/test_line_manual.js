const admin = require('firebase-admin');
const axios = require('axios');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin (Not strictly needed if we just use Axios, but good for context)
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

// Token from index.js
const LINE_ACCESS_TOKEN = "MQ6XpVaw49U6pmJGbYMfy32tv0DVGQuVvhTQOUilbwgTBGroF19SUcsT9YVQe+EzJFUdgrHJMZCq0wznkxCosr3B6QUHIvKuPSIO/BFVzs6PpSJKcpuKrrT/GwLCJ6e+00EiwvpRUBoApSTc1uT+rwdB04t89/1O/w1cDnyilFU=";

async function sendLineMessage(lineUserId, message) {
    try {
        console.log(`📨 Sending to: ${lineUserId}`);
        await axios.post('https://api.line.me/v2/bot/message/push', {
            to: lineUserId,
            messages: [{ type: 'text', text: message }]
        }, {
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${LINE_ACCESS_TOKEN}`
            }
        });
        console.log(`✅ Message sent successfully!`);
    } catch (error) {
        console.error("❌ Failed to send Line:", error.response ? error.response.data : error.message);
    }
}

// Direct Test
const targetLineId = "U247230c53167297a6ff573a583e5dd0f"; // Customer 'Ti'
sendLineMessage(targetLineId, "ทดสอบจาก Cloud: ขอบคุณที่ใช้บริการครับ (Manual Test)");
