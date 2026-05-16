# S-Link Mobile: Project Analysis & Architecture

เอกสารนี้วิเคราะห์โครงสร้างและสถาปัตยกรรมของโปรเจกต์ S-Link (Mobile App) เพื่อให้เข้าใจจุดแข็ง จุดอ่อน และแนวทางการพัฒนาต่อ

---

## 1. สถาปัตยกรรม (Architecture)

### 1.1 ภาพรวม
S-Link เป็นแอปพลิเคชันแบบ **Cloud-First** ที่พึ่งพา Firebase Ecosystem เป็นหลัก แต่เริ่มมีการขยายฟีเจอร์แบบ **Hybrid** เพื่อเชื่อมต่อกับระบบ POS Desktop (MySQL)

### 1.2 Tech Stack Analysis
*   **Firebase Focus:** ใช้ Firebase แทบทุกส่วน (Auth, Firestore, Storage, Functions, Cloud Messaging) ข้อดีคือพัฒนาเร็ว สเกลได้ง่าย แต่ต้องระวังเรื่อง Cost และ Cold Start ของ Cloud Functions
*   **State Management:** ใช้ `Provider` ซึ่งเพียงพอสำหรับแอปขนาดกลาง แต่เริ่มมีความซับซ้อนในส่วนของการจัดการ Real-time Stream จาก Firestore
*   **Maps & Location:** ใช้ `flutter_map` (OpenStreetMap) + `latlong2` ซึ่งประหยัดค่าใช้จ่ายกว่า Google Maps SDK แต่ฟีเจอร์อาจครบถ้วนน้อยกว่า

---

## 2. สิ่งที่ทำไปแล้ว (Key Features Implemented)
*   **Authentication:** ระบบ Login/Register ผ่าน Firebase Auth
*   **Profile Management:** แก้ไขข้อมูลส่วนตัวและรูปโปรไฟล์ (เก็บใน Firebase Storage)
*   **Messaging:** ระบบแจ้งเตือนเบื้องต้นผ่าน FCM
*   **QR Scanner:** อ่าน QR Code ได้ (ใช้ `mobile_scanner`)

---

## 3. แผนงานและจุดที่ต้องพัฒนา (Roadmap & Improvements)

### 3.1 (High Priority) Hybrid Integration
*   **โจทย์:** ต้องการดึงข้อมูลสินค้า หรือ Points จากระบบ POS Desktop (MySQL) มาแสดงบนมือถือ
*   **แนวทาง:**
    1.  ผ่าน **Direct MySQL Connection** (ใช้ `mysql_client`): เร็ว แต่อันตรายถ้าเปิด Port Database ออก Public
    2.  ผ่าน **App Server API** (POS Desktop รัน Server): ปลอดภัยกว่า แต่ต้องจัดการเรื่อง DDNS หรือ Public IP ของร้านค้า

### 3.2 Notification System
*   **สถานะ:** มีพื้นฐานแล้ว
*   **สิ่งที่ต้องทำ:** เพิ่ม Logic การส่ง Notification ตาม Event (เช่น สินค้า POS เหลือน้อย ให้เตือนมาที่มือถือเจ้าของ)

### 3.3 Geolocation Features
*   **สิ่งที่ต้องทำ:** ฟีเจอร์ "Check-in" หรือระบุพิกัดร้านค้า/ลูกค้า เพื่อใช้ในการคำนวณค่าส่ง (Delivery Logic)

---

## 4. ข้อควรระวัง (Critical Points)
*   **Firebase Rules:** ต้องตรวจสอบ Security Rules ของ Firestore/Storage ให้แน่นหนา ห้ามเปิด `allow read, write: if true;` เด็ดขาด
*   **Environment Variables:** ห้าม Hardcode API Key ของ Google Maps หรือ Firebase Config ลงใน Code (แม้จะเป็นไฟล์ Config แต่ควรแยก Environment ถ้าทำได้)
