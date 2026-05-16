# GEMINI.md: S-Link Project Context (Mobile App)

## 📱 Project Overview (ภาพรวมโปรเจกต์)
**S-Link** (Mobile Application) คือแอปพลิเคชัน **Mobile POS & Logistics** ที่ทำงานร่วมกับระบบ **POS Desktop** อย่างสมบูรณ์แบบ
เป้าหมายคือช่วยให้พนักงานสามารถ **ขายของ เช็คสต็อก รับของเข้า และจัดการงานส่งของ** ได้จากโทรศัพท์มือถือผ่านระบบ Internet (Cloudflare Tunnel) โดยไม่ต้องพึ่งพาคอมพิวเตอร์หน้าร้านตลอดเวลา

## 🛠 Tech Stack (เทคโนโลยีที่ใช้)
- **Framework**: Flutter (Dart)
- **Backend Connection**:
  - **Single Tunnel (API Only)**: เชื่อมต่อผ่าน `https://api.namecheap.work` (Port 8080) เพียงช่องทางเดียว
  - ❌ **No Direct DB Connection**: ยกเลิกการต่อ MySQL ตรงจากมือถือเพื่อความปลอดภัยและเสถียรภาพ
- **Key Services**:
  - **POS & Stock**: `PosApiService` (จัดการขาย, ตัดสต็อก, รับของเข้า)
  - **Logistics**: `Google Maps` (นำทาง), `Firebase Firestore` (งานส่งของ, สถานะงาน)
- **State Management**: `Provider` (Cart, Stock, Auth)

## ✨ Core Features (ฟีเจอร์หลัก)
### 1. 🛒 Mobile POS (ระบบขายหน้าร้าน)
- **Scan & Sell**: สแกนบาร์โค้ดขายสินค้าได้ทันที
- **Product Search**: ค้นหาสินค้าจากชื่อหรือรหัส (API Search)
- **Customer**: ค้นหาสมาชิก/ลูกค้า เพื่อสะสมแต้มหรือออกใบกำกับภาษี
- **Payment**:
  - รับเงินสด (Cash) พร้อมคำนวณเงินทอน
  - สร้าง QR PromptPay อัตโนมัติ
- **Receipt**: สั่งพิมพ์ใบเสร็จออกเครื่อง POS Desktop ได้ทันที (ผ่าน Firestore Trigger)

### 2. 📦 Inventory Management (จัดการสต็อก)
- **Stock Check**: นับสต็อกสินค้าจริงหน้าร้าน -> ปรับยอดในระบบทันที (Adjust Stock)
- **Stock In**: รับของเข้าเติมสต็อก -> บันทึกประวัติการรับ (Stock Ledger)
- **Low Stock Alerts**: แจ้งเตือนสินค้าใกล้หมด (Shortage Report)

### 3. 🚚 Logistics (งานส่งของ - *Next Phase*)
- **Job Dashboard**: ดูรายการงานที่ต้องไปส่งในแต่ละวัน
- **Workflow**: รับงาน -> นำทาง -> ส่งสำเร็จ -> ถ่ายรูปยืนยัน
- **Report**: Export Excel แยกตามรถ (Date, Customer/Location, Driver, Location Link)

## 📁 Directory Structure (โครงสร้างไฟล์)
- `lib/features/`
  - `pos/`: ระบบขาย, ตะกร้า, สินค้า, สต็อก (`screens/`, `services/`, `repositories/`)
  - `alerts/`: แจ้งเตือนสินค้าหมด (`stock_alert_screen.dart`)
  - `jobs/`: ระบบงานส่งของ (Logistics)
  - `auth/`: ล็อกอิน/จัดการสิทธิ์

## 📝 Configuration (การตั้งค่า)
- **API URL**: ระบุ `https://api.namecheap.work` (หรือ URL ของ Tunnel ที่ตั้งไว้)
- **Printer**: ตั้งค่าในเมนูสำหรับการพิมพ์ใบเสร็จอัตโนมัติ

## 🚀 Roadmap / Active Tasks
- [x] **Single Tunnel**: ปรับระบบให้วิ่งผ่าน API 100% (เลิกใช้ Direct DB)
- [x] **Stock Operations**: เช็คสต็อก, รับของเข้า ใช้งานได้จริง
- [x] **Job Dashboard**: รายการงานส่งของวันนี้
- [x] **Workflow**: ปล่อยรถ -> ส่งของ -> จบงาน
- [x] **Export Report**: Export Excel แยกตามรถ (Date, Customer/Location, Driver, Location Link)
- [x] **Consolidated Stats**: ระบบ Driver Stats แสดงผลสถิติแยกคน/รถ ได้ถูกต้องแม่นยำ (หักล้างชื่อเล่น/ทะเบียนซ้ำซ้อน)
- [x] **Phase 8: Mobile COD Fix** ✅ (Feb 25, 2026)
  - **Root Cause**: `JobProvider.completeJob()` ใน `job_provider.dart` throw Exception ทันทีถ้า `payCodDebt()` fail ทำให้ driver ปิดงานไม่ได้เลย
  - **Fix**: แยก COD debt กับการปิดงานออกจากกัน — ถ้าตัดหนี้ fail ให้ log error (`⚠️ Job xxx ปิดสำเร็จแล้ว แต่ตัดหนี้ COD ไม่สำเร็จ`) แต่ยังปิดงาน Firestore ได้ปกติ
  - **ไฟล์ที่แก้**: `lib/features/jobs/providers/job_provider.dart`
  - **หมายเหตุ**: `job.customerId` เป็น Firestore string — backend มี fallback ดึง MySQL ID จาก `orderId` (= `job.localOrderId`) ซึ่งต้องมีค่าเสมอ
- [ ] **Phase 8: Notification Support**: ตรวจสอบสถานะและส่งรูปบิล/พิกัดประกอบการแจ้งเตือน
- [ ] **Optional Feature**: เพิ่มระบบ "Automatic Server Discovery" (UDP Broadcast) ค้นหาเครื่องแม่ในวง LAN อัตโนมัติ (จดไว้ก่อน ยังไม่ทำตอนนี้)
