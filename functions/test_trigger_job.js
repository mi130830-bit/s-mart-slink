const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Test Data
const TEST_JOB_ID = "TEST_CLOUD_TRIGGER_001";
const CUSTOMER_LINE_ID = "U247230c53167297a6ff573a583e5dd0f"; // Id of 'Ti'

async function run() {
    console.log("🚀 Starting Cloud Function Trigger Test...");

    const jobRef = db.collection('jobs').doc(TEST_JOB_ID);

    // 1. Create Initial Job (Pending)
    console.log("1️⃣  Creating Test Job (Pending)...");
    await jobRef.set({
        id: TEST_JOB_ID,
        status: 'pending',
        is_departure_approved: false,
        customer: {
            id: 1076,
            name: 'Test Customer (Ti)',
            // ⚠️ Access Token depends on 'line_user_id' being present here
            line_user_id: CUSTOMER_LINE_ID
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log("   ✅ Job Created.");

    // Wait a bit to ensure creation trigger finishes (if any)
    await new Promise(r => setTimeout(r, 3000));

    // 2. Update to 'shipping' (Should trigger Stage 2 msg)
    console.log("2️⃣  Updating to 'shipping' (Trigger Stage 2)...");
    await jobRef.update({
        status: 'shipping',
        driver_id: 999
    });
    console.log("   ✅ Updated. Check Line for '🚚 สินค้าของท่านกำลังเดินทาง...'");

    // Wait for notification to be reasonable
    await new Promise(r => setTimeout(r, 5000));

    // 3. Update to 'completed' (Should trigger Stage 3 msg)
    console.log("3️⃣  Updating to 'completed' (Trigger Stage 3)...");
    await jobRef.update({
        status: 'completed',
        completedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log("   ✅ Updated. Check Line for '📦 สินค้าจัดส่งถึงมือท่าน...'");

    // Cleanup
    await new Promise(r => setTimeout(r, 5000));
    console.log("🧹 Cleaning up test job...");
    await jobRef.delete();
    console.log("✅ Done.");
}

run();
