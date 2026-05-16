/**
 * Import SDK V2
 */
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { setGlobalOptions } = require("firebase-functions/v2");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getAuth } = require("firebase-admin/auth");
// ✅ เพิ่ม Timestamp เข้ามาเพื่อใช้กำหนดวันหมดอายุ
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");

initializeApp();

// ✅ ปรับจูน Cost: ใช้ RAM น้อยสุด (128MiB) และจำกัดจำนวน Instance
setGlobalOptions({
    region: "asia-southeast1",
    memory: "128MiB",    // ประหยัดสุดๆ งานแจ้งเตือนใช้แค่นี้เหลือเฟือ
    maxInstances: 10,    // ป้องกันค่าใช้จ่ายบานปลายถ้ามีบั๊ก Loop
    concurrency: 80      // รับงานได้หลายชิ้นพร้อมกัน
});

const ANDROID_CHANNEL_ID = "opsmate_alert_channel_v3";
const SOUND_NAME = "sounda";

const https = require('https');

// 🕒 ฟังก์ชันเช็คเวลาทำการ (07:00 - 17:00 น. เวลาไทย)
function isWorkingHour() {
    const now = new Date();
    const thaiTime = new Date(now.toLocaleString("en-US", { timeZone: "Asia/Bangkok" }));
    const hour = thaiTime.getHours();
    const minute = thaiTime.getMinutes();

    // นอกเวลา = 17.01 - 06.59
    if (hour < 7) return false;
    if (hour > 17) return false;
    if (hour === 17 && minute >= 1) return false;

    return true;
}

// =========================================================
// 1. onJobCreated: แจ้ง Driver และ Admin เมื่อมีงานจัดส่งใหม่ (ทุกคนได้ยิน)
// =========================================================
exports.onJobCreated = onDocumentCreated("jobs/{jobId}", async (event) => {
    const job = event.data.data();
    const jobId = event.data.id;

    if (!job) return null;

    const isPickup = job.job_type === 'pickup' || job.job_type === 'customer_pickup';

    let notifTitle = "📦 มีงานจัดส่งใหม่!";
    let notifBody = `ลูกค้า: ${job.customer.name}\nที่อยู่: ${job.customer.address}`;
    let targetScreen = "job_detail";

    if (isPickup) {
        notifTitle = "🛍️ ลูกค้าจองเข้ามารับเอง (Pickup)";
        notifBody = `ลูกค้า: ${job.customer.name}\nเบอร์โทร: ${job.customer.phoneNumber || '-'}`;
        targetScreen = "pickup_screen";
    }

    const payload = {
        notification: {
            title: notifTitle,
            body: notifBody,
        },
        android: {
            notification: {
                channelId: ANDROID_CHANNEL_ID,
                sound: SOUND_NAME,
            },
        },
        data: {
            jobId: (jobId || '').toString(),
            screen: targetScreen,
        },
    };

    try {
        // แจ้งคนขับทุกคน
        await getMessaging().send({ ...payload, topic: "driver_alerts" });
        // แจ้งแอดมินทุกคน
        await getMessaging().send({ ...payload, topic: "admin_alerts" });
        // แจ้งคนสร้างงานทุกคน (กึ่งประกาศ)
        await getMessaging().send({ ...payload, topic: "requester_alerts" });

        console.log(`✅ Everyone alerted for new job (${isPickup ? 'Pickup' : 'Delivery'}): ${jobId}`);
    } catch (e) {
        console.error("❌ Error sending New Job alert:", e);
    }

    // ✅ Stage 1: แจ้งเตือนลูกค้าผ่าน Line OA (เฉพาะ Delivery)
    console.log('❌ POS Desktop is now sending a detailed text (along with Image) for Stage 1. Direct send disabled.');
    // ❌ DISABLED: S-Link POS Desktop is now sending a detailed text (along with Image) for Stage 1.
    // So we don't send the generic "ได้รับรายการสั่งซื้อ" to prevent duplication.
    /*
    if (!isPickup) {
        const lineUserId = job.customer?.line_user_id || job.customer?.lineUserId;
        if (lineUserId) {
            const localOrderId = job.localOrderId || '';
            await sendLineDirectMessage(lineUserId,
                `🛒 ร้าน ส.บริการ ท่าข้าม ได้รับรายการสั่งซื้อของท่านแล้ว` +
                (localOrderId ? ` (#${localOrderId})` : '') +
                `\nกำลังดำเนินการจัดเตรียมสินค้าครับ...` +
                `\n(เมื่อรถออกจากร้าน จะมีข้อความแจ้งเตือนอีกครั้งครับ)`
            );
            console.log(`✅ Stage 1 Line sent to ${lineUserId} for job ${jobId}`);
        } else {
            console.log(`⚠️ Stage 1 skipped: No lineUserId for job ${jobId}`);
        }
    }
    */

    return null;
});

// =========================================================
// 1.5 onOrderCreated: แจ้ง Admin เมื่อมีรายการขายเข้าใหม่ (POS/POS-Web)
// =========================================================
exports.onOrderCreated = onDocumentCreated("orders/{orderId}", async (event) => {
    const order = event.data.data();
    const orderId = event.data.id;

    if (!order) return null;

    // ✅ เช็คว่ามีการเลือก Delivery หรือ Pickup หรือไม่
    const note = order.note || '';
    const isDelivery = note.toLowerCase().includes('deliver');
    const isPickup = note.toLowerCase().includes('pickup');

    // ❌ ถ้าเป็นรายการขายปกติ (ไม่ส่งของ/ไม่รับของ) -> ไม่แจ้งเตือน
    if (!isDelivery && !isPickup) {
        console.log(`⏭️ Order ${orderId} is regular sale (no delivery). Skipping notification.`);
        return null;
    }

    // ✅ มีการเลือกส่งของหรือรับของ -> แจ้งเตือน
    const deliveryType = isDelivery ? '📦 ส่งของ' : '🛍️ รับของหลังบ้าน';
    const customerInfo = order.customerId > 0
        ? `ลูกค้า ID: ${order.customerId}`
        : 'ลูกค้าทั่วไป';

    const payload = {
        notification: {
            title: `${deliveryType} - มีรายการใหม่!`,
            body: `บิลเลขที่ #${orderId}\nยอดรวม: ${order.grandTotal.toFixed(2)} บาท\n${customerInfo}`,
        },
        android: {
            notification: {
                channelId: ANDROID_CHANNEL_ID,
                sound: SOUND_NAME,
            },
        },
        data: {
            orderId: (orderId || '').toString(),
            screen: "order_detail",
            grandTotal: order.grandTotal.toString(),
            deliveryType: isDelivery ? 'delivery' : 'pickup',
        },
    };

    try {
        // แจ้งแอดมินทุกคน
        await getMessaging().send({ ...payload, topic: "admin_alerts" });
        console.log(`✅ Admin alerted for ${deliveryType}: ${orderId} (${order.grandTotal} บาท)`);
    } catch (e) {
        console.error("❌ Error sending Order alert:", e);
    }
    return null;
});

// =========================================================
// 2. onStockAlertCreated: แจ้ง Admin เมื่อมี Stock Alert ใหม่
// =========================================================
exports.onStockAlertCreated = onDocumentCreated("stock_alerts/{alertId}", async (event) => {
    const alert = event.data.data();
    const alertId = event.data.id;

    if (!alert) return null;

    if (!isWorkingHour()) {
        console.log("Stock Alert notification skipped outside working hours. Queueing to Batch...");
        await getFirestore().collection("batch_alerts").add({
            type: "stock_alert",
            target_topic: "admin_alerts",
            title: "⚠️ แจ้งเตือนสินค้า/ซ่อมบำรุง (นอกเวลา)",
            body: `รายการ: ${alert.name || alert.product_info || 'ไม่ทราบชื่อ'}`,
            created_at: FieldValue.serverTimestamp(),
            is_sent: false,
        });
        return null;
    }

    const payload = {
        notification: {
            title: "⚠️ แจ้งเตือนสินค้า/ซ่อมบำรุง",
            body: `รายการ: ${alert.name || alert.product_info || 'ไม่ทราบชื่อ'} (รอดำเนินการ)`,
        },
        android: {
            notification: {
                channelId: ANDROID_CHANNEL_ID,
                sound: SOUND_NAME,
            },
        },
        data: {
            alertId: (alertId || '').toString(),
            screen: "stock_alert",
            role: "admin",
        },
    };

    const finalPayload = { ...payload, topic: "admin_alerts" };

    try {
        await getMessaging().send(finalPayload);
        console.log(`✅ Admin alert sent for new stock alert: ${alertId}`);
    } catch (e) {
        console.error("❌ Error sending Admin alert for stock alert:", e);
    }
    return null;
});

// =========================================================
// 3. onJobStatusChanged: แจ้ง Admin/Requester เมื่อสถานะงานเปลี่ยน
// =========================================================
exports.onJobStatusChanged = onDocumentUpdated("jobs/{jobId}", async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const jobId = event.data.id;

    if (!before || !after) return null;

    const oldStatus = before.status;
    const newStatus = after.status;
    const customerName = after.customer.name;
    const oldApproved = before.is_departure_approved;
    const newApproved = after.is_departure_approved;

    // 🚩 Check if Job was Edited
    const itemsStrBefore = JSON.stringify(before.items || []);
    const itemsStrAfter = JSON.stringify(after.items || []);
    const isItemsChanged = itemsStrBefore !== itemsStrAfter;
    
    const custStrBefore = JSON.stringify(before.customer || {});
    const custStrAfter = JSON.stringify(after.customer || {});
    const isCustChanged = custStrBefore !== custStrAfter;
    
    const isNoteChanged = (before.note || '') !== (after.note || '');
    const isEdited = isItemsChanged || isCustChanged || isNoteChanged;

    // 🚩 Check Status Change OR Approval Change OR Edit
    if (oldStatus === newStatus && oldApproved === newApproved && !isEdited) return null;

    // =========================================================
    // 0. แจ้งเตือน Driver เมื่อ "แก้ไขงาน" (Job Edited)
    // =========================================================
    if (oldStatus === newStatus && oldApproved === newApproved && isEdited) {
        const driverIds = after.driver_ids || [];
        if (driverIds.length === 0 && after.driver_id) driverIds.push(after.driver_id);

        let editParts = [];
        if (isItemsChanged) editParts.push("รายการสินค้า");
        if (isCustChanged) editParts.push("ข้อมูลลูกค้า/ที่อยู่");
        if (isNoteChanged) editParts.push("หมายเหตุ");

        const payload = {
            notification: {
                title: `📝 งานถูกแก้ไข: ${customerName}`,
                body: `มีการเปลี่ยนแปลง: ${editParts.join(', ')}\nกรุณาตรวจสอบรายละเอียดงานอีกครั้ง`,
            },
            android: { notification: { channelId: ANDROID_CHANNEL_ID, sound: SOUND_NAME } },
            data: { jobId: (jobId || '').toString(), screen: "job_detail" }
        };

        if (driverIds.length > 0) {
            const sendPromises = driverIds.map(uid => getMessaging().send({ ...payload, topic: `user_${uid}` }));
            await Promise.all(sendPromises).catch(e => console.error("Edit alert error:", e));
            console.log(`✅ Assigned drivers alerted for job edit: ${jobId}`);
        } else {
            // แจ้งทุกคนถ้ายังไม่มีคนรับงาน
            await getMessaging().send({ ...payload, topic: "driver_alerts" }).catch(e => console.error("Edit alert error:", e));
            console.log(`✅ All drivers alerted for job edit (unassigned): ${jobId}`);
        }
        return null; // Stop here, no need to process status change
    }

    // =========================================================
    // 1. แจ้งเตือน Driver เมื่อ "อนุมัติให้รถออก"
    // =========================================================
    if (!oldApproved && newApproved) {
        const driverIds = after.driver_ids || [];
        // Fallback: ถ้าไม่มี driver_ids ให้ดู driver_id ตัวเดียว
        if (driverIds.length === 0 && after.driver_id) {
            driverIds.push(after.driver_id);
        }

        if (driverIds.length > 0) {
            const payload = {
                notification: {
                    title: "✅ อนุมัติออกรถได้",
                    body: `Admin อนุมัติงานส่งของให้ ${customerName} แล้ว เริ่มเดินทางได้เลย!`,
                },
                android: {
                    notification: { channelId: ANDROID_CHANNEL_ID, sound: SOUND_NAME },
                },
                data: { jobId: (jobId || '').toString(), screen: "job_detail" }
            };

            const sendPromises = driverIds.map(uid =>
                getMessaging().send({ ...payload, topic: `user_${uid}` })
                    .catch(e => console.error(`Failed to send to driver ${uid}:`, e))
            );

            try {
                await Promise.all(sendPromises);
                console.log(`✅ Drivers alerted for approved departure: ${jobId}`);
            } catch (e) {
                console.error("Error sending driver approval alerts:", e);
            }
        }
    }

    // =========================================================
    // 2. แจ้งเตือน Creator เมื่อ "งานเสร็จ"
    // =========================================================
    if (newStatus === 'completed' && oldStatus !== 'completed') {
        if (after.created_by) {
            try {
                const userDoc = await getFirestore().collection("users").doc(after.created_by).get();
                const fcmToken = userDoc.data()?.fcmToken;
                if (fcmToken) {
                    await getMessaging().send({
                        token: fcmToken,
                        notification: {
                            title: "✅ งานของคุณส่งสำเร็จแล้ว",
                            body: `ลูกค้า ${customerName} ได้รับของเรียบร้อย`,
                        },
                        data: { jobId: (jobId || '').toString(), screen: "job_detail" }
                    });
                    console.log(`✅ Requester ${after.created_by} alerted for completed job`);
                }
            } catch (e) { console.error("Error sending requester alert:", e); }
        }
    }

    // =========================================================
    // 3. แจ้งเตือน Admin (Completed / Requested)
    // =========================================================
    const isAdminEvent = (newStatus === 'completed' && oldStatus !== 'completed') ||
        (newStatus === 'requested' && oldStatus !== 'requested');

    if (!isAdminEvent) return null;

    let adminTitle = "";
    let adminBody = "";

    if (newStatus === 'completed') {
        adminTitle = "✅ งานจัดส่งสำเร็จ";
        adminBody = `คนขับส่งของให้ลูกค้า ${customerName} เรียบร้อยแล้ว`;
    } else if (newStatus === 'requested') {
        adminTitle = "🔔 มีงานร้องขอใหม่!";
        adminBody = `ลูกค้า ${customerName} มีการร้องขอการจัดส่ง`;
    }

    // A. นอกเวลาทำการ -> Batch
    if (!isWorkingHour()) {
        console.log("Job status alert for Admin skipped outside working hours. Queueing to Batch...");
        await getFirestore().collection("batch_alerts").add({
            type: "job_status",
            target_topic: "admin_alerts",
            title: adminTitle + " (นอกเวลา)",
            body: adminBody,
            created_at: FieldValue.serverTimestamp(),
            is_sent: false,
        });
        return null;
    }

    // B. ในเวลาทำการ -> ส่งเลย
    const adminPayload = {
        notification: {
            title: adminTitle,
            body: adminBody,
        },
        android: {
            notification: { channelId: ANDROID_CHANNEL_ID, sound: SOUND_NAME },
        },
        data: { jobId: (jobId || '').toString(), screen: "job_detail" }
    };

    try {
        await getMessaging().send({ ...adminPayload, topic: "admin_alerts" });
        console.log(`✅ Admin alert sent for job ${jobId} status: ${newStatus}`);
    } catch (e) {
        console.error(`❌ Error sending admin alert:`, e);
    }
});

const axios = require('axios');

// ✅ Line Channel Access Token (จาก Line Developers Console)
// TODO: ย้ายไปเก็บใน Firebase Config ด้วย: firebase functions:config:set line.token="..."
const LINE_ACCESS_TOKEN = "MQ6XpVaw49U6pmJGbYMfy32tv0DVGQuVvhTQOUilbwgTBGroF19SUcsT9YVQe+EzJFUdgrHJMZCq0wznkxCosr3B6QUHIvKuPSIO/BFVzs6PpSJKcpuKrrT/GwLCJ6e+00EiwvpRUBoApSTc1uT+rwdB04t89/1O/w1cDnyilFU=";

// =========================================================
// Helper: ส่งข้อความ Line OA โดยตรง (ไม่ผ่าน POS Backend)
// =========================================================
async function sendLineDirectMessage(lineUserId, message) {
    if (!lineUserId || !message) {
        console.log('⚠️ sendLineDirectMessage: Missing lineUserId or message');
        return false;
    }
    try {
        console.log(`📨 Sending Line to: ${lineUserId}`);
        await axios.post('https://api.line.me/v2/bot/message/push', {
            to: lineUserId,
            messages: [{ type: 'text', text: message }]
        }, {
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${LINE_ACCESS_TOKEN}`
            }
        });
        console.log(`✅ Line message sent successfully!`);
        return true;
    } catch (error) {
        console.error('❌ Line Direct Send Failed:', error.response ? error.response.data : error.message);
        return false;
    }
}

// =========================================================
// 3.5 onJobStatusChanged_LineOA: แจ้งเตือนลูกค้าผ่าน Line OA โดยตรง
// =========================================================
exports.onJobStatusChanged_LineOA = onDocumentUpdated("jobs/{jobId}", async (event) => {
    const after = event.data.after.data();
    const before = event.data.before.data();
    const jobId = event.data.id;

    if (!after || !before) return null;

    const newStatus = after.status;
    const oldStatus = before.status;
    const newApproval = after.is_departure_approved;
    const oldApproval = before.is_departure_approved;
    const customerName = after.customer?.name || 'ลูกค้า';
    const lineUserId = after.customer?.line_user_id || after.customer?.lineUserId;

    // ไม่มี Line User ID = ไม่ต้องส่ง
    if (!lineUserId) {
        console.log(`⚠️ Job ${jobId}: No lineUserId in customer data. Skipping Line notification.`);
        return null;
    }

    // Helper
    const isChangedTo = (s) => newStatus === s && oldStatus !== s;

    // Stage 2: Departure Approved / Shipping
    const isStage2 = isChangedTo('shipping') || isChangedTo('enroute') || (newApproval && !oldApproval);

    // Stage 3: Completed
    const isStage3 = isChangedTo('completed');

    if (!isStage2 && !isStage3) return null;

    // 💡 Offline Sync Delayed Notification Check
    const checkOfflineDelay = (timeField) => {
        if (!timeField) return false;
        try {
            const actionTime = timeField.toDate ? timeField.toDate() : new Date(timeField);
            const now = new Date();
            const diffMs = now.getTime() - actionTime.getTime();
            const diffMinutes = diffMs / (1000 * 60);
            return diffMinutes > 60; // 1 hour threshold
        } catch (e) {
            return false;
        }
    };

    if (isStage2 && checkOfflineDelay(after.updated_at || after.departure_time)) {
        console.log(`⚠️ Stage 2 skipped due to offline delay sync (> 1 hr)`);
        return null;
    }
    
    if (isStage3 && checkOfflineDelay(after.completed_at || after.updated_at)) {
        console.log(`⚠️ Stage 3 skipped due to offline delay sync (> 1 hr)`);
        return null;
    }

    const apiUrl = 'https://api.namecheap.work';

    // ✅ Stage 2: Shipping (กำลังส่ง)
    if (isStage2) {
        try {
            // A. Direct Send (Fast)
            console.log('❌ POS Desktop backend is now the sole sender to avoid duplicate messages for Stage 2');
            // ❌ DISABLED: POS Desktop backend is now the sole sender to avoid duplicate messages.
            /*
            await sendLineDirectMessage(lineUserId,
                `🚚 สินค้าของคุณ${customerName} กำลังดำเนินการจัดส่ง...\n` +
                `หากมีข้อสงสัยสามารถติดต่อได้ที่เบอร์ร้าน 085-1377402 ครับ`
            );
            */

            // B. Notify Backend (For MySQL Logging)
            const localOrderId = after.localOrderId || '';
            if (localOrderId) {
                const url = `${apiUrl}/api/v1/line/notify-stage2/${localOrderId}`;
                console.log(`📤 Syncing Stage 2 to Backend: ${url}`);
                await axios.post(url, {}, { timeout: 5000 }).catch(e => console.error('Backend Stage 2 Sync Error:', e.message));
            }
        } catch (e) {
            console.error('Stage 2 Error:', e);
        }
    }

    // ✅ Stage 3: Completed (ส่งเสร็จ)
    else if (isStage3) {
        try {
            // A. Direct Send (Fast)
            console.log('❌ POS Desktop backend is now the sole sender to avoid duplicate messages for Stage 3');
            // ❌ DISABLED: POS Desktop backend is now the sole sender to avoid duplicate messages.
            /*
            await sendLineDirectMessage(lineUserId,
                `✅ ส่งสินค้าเรียบร้อยแล้ว\n` +
                `ขอบคุณที่เลือกใช้บริการและให้ความไว้วางใจ\n` +
                `ร้าน ส.บริการ ท่าข้าม ยินดีให้บริการครับ 🙏`
            );
            */

            // B. Notify Backend (For MySQL Logging)
            const localOrderId = after.localOrderId || '';
            if (localOrderId) {
                const url = `${apiUrl}/api/v1/line/notify-stage3/${localOrderId}`;
                console.log(`📤 Syncing Stage 3 to Backend: ${url}`);
                const payload = {
                    imageUrl: after.proof_image_url || null,
                    locationUrl: after.location_link || null
                };
                await axios.post(url, payload, { timeout: 5000 }).catch(e => console.error('Backend Stage 3 Sync Error:', e.message));
            }
        } catch (e) {
            console.error('Stage 3 Error:', e);
        }
    }
});


// =========================================================
// 4. setUserRole: ฟังก์ชันสำหรับ Admin
// =========================================================
exports.setUserRole = onCall(async (request) => {
    if (!request.auth || request.auth.token.role !== 'admin') {
        throw new HttpsError('permission-denied', 'เฉพาะ Admin เท่านั้น');
    }

    const { targetUserId, newRole } = request.data;
    if (!targetUserId || !newRole) {
        throw new HttpsError('invalid-argument', 'ข้อมูลไม่ครบ');
    }

    try {
        await getAuth().setCustomUserClaims(targetUserId, { role: newRole });

        await getFirestore().collection("users").doc(targetUserId).update({
            role: newRole,
            updatedAt: FieldValue.serverTimestamp()
        });

        return { success: true, message: `อัปเดต ${targetUserId} เป็น ${newRole} สำเร็จ` };
    } catch (error) {
        console.error("Error setting role:", error);
        throw new HttpsError('internal', error.message);
    }
});

// =========================================================
// 5. sendBatchAlerts: ส่งแจ้งเตือนตกค้างตอน 7:00 น.
// =========================================================
exports.sendBatchAlerts = onSchedule({
    schedule: "0 7 * * *",
    timeZone: "Asia/Bangkok",
    region: "asia-southeast1",
}, async (event) => {

    const db = getFirestore();
    const messaging = getMessaging();
    console.log("⏰ Running Batch Alert Sender...");

    const snapshot = await db.collection("batch_alerts")
        .where("is_sent", "==", false)
        .orderBy("created_at", "asc")
        .get();

    if (snapshot.empty) {
        console.log("✅ No pending batch alerts to send.");
        return null;
    }

    const groupedAlerts = snapshot.docs.reduce((acc, doc) => {
        const data = doc.data();
        const topic = data.target_topic;

        if (!acc[topic]) {
            acc[topic] = { count: 0, bodyLines: [], docIds: [] };
        }

        acc[topic].count += 1;
        acc[topic].bodyLines.push(`• ${data.title}: ${data.body}`);
        acc[topic].docIds.push(doc.id);

        return acc;
    }, {});

    const promises = [];

    // คำนวณวันหมดอายุล่วงหน้า 7 วัน สำหรับ TTL
    const expireDate = new Date();
    expireDate.setDate(expireDate.getDate() + 3);

    for (const topic in groupedAlerts) {
        const group = groupedAlerts[topic];
        const totalCount = group.count;
        const alertType = topic === 'driver_alerts' ? 'งานใหม่' : 'แจ้งเตือนระบบ';

        const displayBody = group.bodyLines.slice(0, 5).join('\n') +
            (totalCount > 5 ? `\n...และรายการอื่น ๆ อีก ${totalCount - 5} รายการ` : '');

        const batchMessage = {
            notification: {
                title: `🌅 สรุป ${totalCount} รายการ ${alertType} (จากเมื่อคืน)`,
                body: displayBody,
            },
            android: {
                notification: {
                    channelId: ANDROID_CHANNEL_ID,
                    sound: SOUND_NAME,
                },
            },
            topic: topic,
            data: {
                isBatch: "true",
                role: topic === 'driver_alerts' ? 'driver' : 'admin'
            }
        };

        promises.push(
            messaging.send(batchMessage)
                .then(async () => {
                    console.log(`✅ Sent batch alert to ${topic} (${totalCount} items)`);

                    const batch = db.batch();
                    group.docIds.forEach(id => {
                        const ref = db.collection("batch_alerts").doc(id);
                        // ✅ Update เพิ่ม field expire_at เพื่อให้ TTL ของ Google ทำงาน
                        batch.update(ref, {
                            is_sent: true,
                            sent_at: FieldValue.serverTimestamp(),
                            expire_at: Timestamp.fromDate(expireDate)
                        });
                    });
                    await batch.commit();
                })
                .catch(e => console.error(`❌ Error sending batch alert to ${topic}:`, e))
        );
    }

    await Promise.all(promises);
    return null;
});

// =========================================================
// 6. onWorkLogCreated: แจ้ง Admin เมื่อมี Log งานหลังร้านใหม่
// =========================================================
exports.onWorkLogCreated = onDocumentCreated("shop_work_logs/{logId}", async (event) => {
    const log = event.data.data();
    const logId = event.data.id;
    const delivererId = log.deliverer_id || "ไม่ระบุ";
    const itemCount = log.items ? log.items.length : 0;

    if (!log) return null;

    if (!isWorkingHour()) {
        console.log("Work Log alert skipped outside working hours. Queueing to Batch...");
        await getFirestore().collection("batch_alerts").add({
            type: "work_log",
            target_topic: "admin_alerts",
            title: "🔨 งานหลังร้านใหม่ (นอกเวลา)",
            body: `บันทึกโดย Driver ID: ${delivererId}`,
            created_at: FieldValue.serverTimestamp(),
            is_sent: false,
        });
        return null;
    }

    const payload = {
        notification: {
            title: "🔨 งานหลังร้านใหม่ถูกบันทึก!",
            body: `รายการโดย Driver ID ${delivererId} จำนวน ${itemCount} รายการ`,
        },
        android: {
            notification: {
                channelId: ANDROID_CHANNEL_ID,
                sound: SOUND_NAME,
            },
        },
        data: {
            logId: (logId || '').toString(),
            screen: "work_log_detail",
            role: "admin",
        },
    };

    const finalPayload = { ...payload, topic: "admin_alerts" };

    try {
        await getMessaging().send(finalPayload);
        console.log(`✅ Admin alert sent for new work log: ${logId}`);
    } catch (e) {
        console.error("❌ Error sending Admin alert for work log:", e);
    }
    return null;
});