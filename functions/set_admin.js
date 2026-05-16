const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

// 1. ใส่ UID ของคนที่จะเป็น Admin ตรงนี้!
const TARGET_UID = "M6tBsqaPm4OlVLtvbP7gpzE8VNF2"; 

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function forceMakeAdmin() {
  try {
    console.log(`กำลังยัดเยียดความเป็น Admin ให้ ${TARGET_UID}...`);

    // 1. ยัด Role ลงใน Token (Custom Claims)
    await admin.auth().setCustomUserClaims(TARGET_UID, { role: 'admin' });
    console.log("✅ Token Role: Admin เรียบร้อย");

    // 2. ยัด Role ลงใน Database (Firestore)
    await admin.firestore().collection("users").doc(TARGET_UID).set({
      role: 'admin',
      updatedAt: new Date(),
    }, { merge: true });
    console.log("✅ Database Role: Admin เรียบร้อย");

    console.log("🎉 เสร็จสิ้น! กรุณา Logout แล้ว Login ใหม่ในแอป");
    process.exit();
  } catch (error) {
    console.error("❌ เกิดข้อผิดพลาด:", error);
    process.exit(1);
  }
}

forceMakeAdmin();