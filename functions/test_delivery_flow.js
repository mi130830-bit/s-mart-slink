const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

// Initialize Firebase Admin
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// 🎯 Target Customer Phone
const TARGET_PHONE = "0851377402";

async function simulateFlow() {
    console.log(`🔍 Searching for customer with phone: ${TARGET_PHONE}...`);

    // 1. Find Customer
    // Try 'users' collection first (S-Link App Users)
    let userSnapshot = await db.collection("users").where("phoneNumber", "==", TARGET_PHONE).get();

    // Try 'customers' collection (POS Customers) if not found
    if (userSnapshot.empty) {
        console.log("⚠️ Not found in 'users', trying 'customers'...");
        userSnapshot = await db.collection("customers").where("phone", "==", TARGET_PHONE).get();
    }

    if (userSnapshot.empty) {
        console.error("❌ Customer not found! Please check the phone number.");
        process.exit(1);
    }

    const userDoc = userSnapshot.docs[0];
    const userData = userDoc.data();
    const userId = userDoc.id;

    // Check Line User ID
    const lineUserId = userData.line_user_id || userData.lineUserId;
    console.log(`✅ Found Customer: ${userData.name || userData.firstName} (${userId})`);
    console.log(`📱 Line User ID: ${lineUserId ? lineUserId : "❌ NOT FOUND"}`);

    if (!lineUserId) {
        console.error("❌ Cannot test Line OA: This user has no Line User ID linked.");
        // process.exit(1); // Continue anyway to test Admin alerts
    }

    // 2. Create Job (Stage 1: Payment/Order Received -> Job Created)
    console.log("\n🚀 [Stage 1] Creating Job (Simulating Payment/Order)...");

    const jobData = {
        customer: {
            name: userData.name || `${userData.firstName} ${userData.lastName}`,
            address: userData.address || userData.shippingAddress || "123 Test Road",
            phone: userData.phone || userData.phoneNumber || TARGET_PHONE,
            line_user_id: lineUserId,
            id: userId
        },
        status: "pending",
        job_type: "delivery",
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        is_departure_approved: false,
        items: [
            { name: "สินค้าทดสอบ (Simulation)", quantity: 1, price: 100 }
        ],
        total_amount: 100
    };

    const jobRef = await db.collection("jobs").add(jobData);
    console.log(`✅ Job Created: ${jobRef.id}`);
    console.log("⏳ Waiting 10 seconds for Line OA notification...");

    await new Promise(r => setTimeout(r, 10000));

    // 3. Update Job (Stage 2: Release Car / Dispatch)
    console.log("\n🚀 [Stage 2] Approving Departure (Simulating Dispatch)...");

    await jobRef.update({
        status: "shipping",
        is_departure_approved: true,
        driver_id: "SIMULATED_DRIVER",
        driver_name: "พี่สมชาย (จำลอง)",
        delivery_team: [{ name: "พี่สมชาย (จำลอง)", role: "driver" }]
    });

    console.log("✅ Job Updated to 'shipping' + Approved");
    console.log("⏳ Waiting 10 seconds for Line OA notification...");

    await new Promise(r => setTimeout(r, 10000));

    // 4. Close Job (Stage 3: Completed)
    console.log("\n🚀 [Stage 3] Completing Job (Simulating Delivery Success)...");

    await jobRef.update({
        status: "completed",
        completed_at: admin.firestore.FieldValue.serverTimestamp(),
        proof_photo_url: "https://via.placeholder.com/300.png?text=Proof+of+Delivery"
    });

    console.log("✅ Job Updated to 'completed'");
    console.log("🎉 Simulation Finished! Please check Line OA on the device.");

    process.exit(0);
}

simulateFlow().catch(console.error);
