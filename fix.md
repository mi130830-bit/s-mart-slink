# S-Link Fix History

---

## [2026-07-14] Phase 8: Delivery Proof Image & Offline COD Sync
**สิ่งที่ดำเนินการ (POS Desktop & S-Link):**
1. **Offline COD Payment Sync:**
   - [S-Link] แก้ไข `sync_service.dart` ให้ส่ง `orderId` ไปยัง API `/jobs/complete` และเรียกใช้ `payCodDebt` เพื่อให้ระบบ POS Desktop ตัดยอดหนี้ COD อัตโนมัติแม้คนขับรถจะทำงานแบบ Offline
2. **Delivery Proof Image Sync (รายงานการส่งของมีรูป):**
   - [S-Link] เพิ่มการส่ง `billImageUrl` (ดึงจาก `proof_image` ของ Firebase) เข้าไปใน payload ของ `/jobs/complete` ทั้งแบบ Online (`job_provider.dart`) และ Offline (`sync_service.dart`)
   - [POS Desktop] อัปเดตตรรกะใน `job_controller.dart` เพื่ออ่าน `billImageUrl` และบันทึกลงคอลัมน์ `billImageUrl` ในฐานข้อมูล MySQL (`delivery_history`)
   - [S-Link] เพิ่มการแปลง `billImageUrl` เข้าไปใน `Job.fromHistory()` เพื่อให้แสดงรูปในหน้ารายงานประวัติการส่งของฝั่งคนขับรถได้ (ตามความต้องการที่ระบุว่าใน POS ไม่ต้องแสดงรูป ให้แสดงแค่ S-Link)
3. **การตรวจสอบความเรียบร้อย:**
   - รัน `flutter analyze` ทั้งสองโปรเจกต์ โค้ดผ่านไม่มี syntax error ที่ขัดขวางการทำงาน

## [2026-07-02] Driver QR — ย้ายจาก Settings → Dashboard Card

### 📋 สรุป
ปรับ UX ให้ Driver เข้า QR ได้โดยตรงจาก Dashboard (ง่ายกว่าเข้าผ่าน Settings)
**ผลลัพธ์:** `flutter analyze` ผ่าน ✅ — No issues found!

### 🔀 เปลี่ยนแปลง
| ไฟล์ | รายละเอียด |
|---|---|
| `employee_dashboard.dart` | เพิ่มการ์ด **QR รับเงิน** ใน GridView (Driver เท่านั้น, card ที่ 3) |
| `settings_screen.dart` | ลบ Driver QR tile ออกจาก Settings Section |
| `driver_qr_screen.dart` | รองรับทั้ง Static QR (รูปจาก POS) และ Dynamic QR ผ่าน API, fullscreen mode |
| `pos_api_service.dart` | เปลี่ยน `getPromptPayId()` → `getPaymentConfig()` คืนค่า config ครบ (mode + base64) |

---

## [2026-07-02] Settings Cleanup + Driver QR Screen (Backend)


### 📋 สรุปการเปลี่ยนแปลง (Summary)
ตรวจสอบและทำความสะอาด Settings Screen ทั้งหมด + เพิ่มฟีเจอร์ Driver QR PromptPay
**ผลลัพธ์:** `flutter analyze` ผ่าน ✅ — No issues found!

### ❌ ลบออก (Deleted)
| ไฟล์ | เหตุผล |
|---|---|
| `lib/features/sql/sql_connect_screen.dart` + โฟลเดอร์ | Dead Code — ไม่มีใคร navigate มาเลย Architecture เก่า (Direct MySQL ยกเลิกแล้ว) |
| `lib/features/settings/screens/connection_settings_screen.dart` | MySQL LAN Config Screen — ไม่ใช้แล้วหลังเปลี่ยนไป Single API Tunnel |

### 🔧 แก้ไข (Fixed / Improved)
| ไฟล์ | รายละเอียด |
|---|---|
| `login_screen.dart` | ลบ import + ปุ่ม Settings ที่ navigate ไปหน้า MySQL LAN ที่ถูกลบออกไปแล้ว |
| `account_settings_section.dart` | 1) เปลี่ยน imports ออกจาก cloud_firestore โดยตรง → ใช้ UserService.updateUser() 2) เพิ่ม _roleLabel() รองรับทุก Role ครบ (admin/driver/requester/hr/gasStation/pending/unknown) 3) เพิ่ม auth.refreshCurrentUser() หลัง save ให้ UI อัปเดตทันที |
| `connection_settings_section.dart` | เปลี่ยนจาก StatelessWidget+FutureBuilder เป็น StatefulWidget ที่ถูกต้อง ลบ anti-pattern markNeedsBuild() ซ่อน PromptPay/DeviceID fields จาก Driver role |
| `pos_config_section.dart` | เพิ่ม Printer Settings tile (ก่อนหน้านี้หน้า PrinterSettingsScreen ไม่มีทางเข้า) |
| `auth_provider.dart` | เพิ่ม refreshCurrentUser() — ดึงข้อมูล User ใหม่จาก Firestore หลังแก้ไข profile |

### ✨ เพิ่มใหม่ (New Features)
| ไฟล์ | รายละเอียด |
|---|---|
| `lib/features/settings/screens/driver_qr_screen.dart` | **Driver QR Screen** — หน้าแสดง QR PromptPay แบบ Fullscreen สำหรับเก็บเงินปลายทาง (COD) ดึง ID จาก Server API ก่อน (fallback SharedPreferences), WakeLock, สลับ Static/Dynamic QR พร้อมล็อคยอด COD |
| `pos_api_service.dart` | เพิ่ม getPromptPayId() — GET /api/v1/config/promptpay เพื่อดึง PromptPay ID จาก Server เป็น Single Source of Truth |
| `settings_screen.dart` | เพิ่ม Driver Tools Section (เห็นเฉพาะ Driver) — tile นำไปหน้า Driver QR Screen |

---

## [2026-07-02] Codebase Cleanup — ลบโค้ดซ้ำซ้อน & รวม Logic


### 📋 สรุปการเปลี่ยนแปลง (Summary)
กวาดบ้านครั้งใหญ่ ลบโค้ดที่ไม่ได้ใช้และรวม logic ที่ซ้ำซ้อนให้เป็นที่เดียวกัน
**ผลลัพธ์:** `flutter analyze` ผ่าน ✅ — No issues found!

### ❌ ลบออก (Deleted)
| ไฟล์/Method | เหตุผล |
|---|---|
| `core/services/customer_service.dart` | ไม่มีไฟล์ใดเรียกใช้เลย — ซ้ำกับ `MasterDataProvider` |
| `MasterDataService.getDeliverers()` (Stream) | ถูกแทนที่ด้วย `getDeliverersOnce()` (Future) ตั้งแต่รอบ Cost Optimization |
| `MasterDataService.getAllDeliverersForReport()` | เหมือนกัน 100% กับ `getDeliverersOnce()` — รวมเป็นตัวเดียว |
| `MasterDataService.getCars()` (Stream) | ถูกแทนที่ด้วย `getCarsOnce()` (Future) |
| `MasterDataService.toggleDelivererStatus()` | ไม่มีใครเรียกใช้ |
| `MasterDataService.toggleCarAvailability()` | ไม่มีใครเรียกใช้ |
| `MasterDataProvider.addDeliverer/updateDeliverer/deleteDeliverer()` | ไม่มี UI เรียกตรง — การจัดการพนักงานย้ายไป `UserService` + `DriverListScreen` แล้ว |
| `MasterDataProvider.refreshMasterData()` | แค่ wrapper ซ้อน `loadMasterData()` โดยไม่มีใครเรียก |
| `NotificationService.subscribeToTopic()` | FCM topics ทั้งหมดจัดการใน `UserService` อยู่แล้ว |
| `NotificationService.unsubscribeFromTopic()` | FCM topics ทั้งหมดจัดการใน `UserService` อยู่แล้ว |

### 🔀 รวม/ปรับปรุง (Merged/Improved)
| การเปลี่ยนแปลง | รายละเอียด |
|---|---|
| `AuthProvider.logout()` | รวม FCM unsubscribe จาก hardcode 2 topics ให้เรียก `UserService.unsubscribeAllTopics()` — ป้องกัน miss topics ในอนาคต |
| `export_provider.dart` | แก้ให้เรียก `getDeliverersOnce()` แทน `getAllDeliverersForReport()` |
| `MasterDataProvider.startListeningToMasterData()` | ปรับ comment ให้ถูกต้อง (เป็น Future ไม่ใช่ Stream) |

### ✅ ยืนยัน (Verified)
- `flutter analyze` → **No issues found!**
- `deliverers` collection ยังถูกใช้โดย `job_detail_screen.dart` และ `work_log_history_screen.dart` สำหรับ lookup ชื่อทีมงาน — **ยังเก็บไว้ถูกต้อง**
- `customer.dart` (embedded value object ใน Job) — **ยังเก็บไว้ถูกต้อง** ต่างจาก `customer_master.dart` (standalone Firestore doc)

### วันที่ 24 กรกฎาคม 2026
- **GPS Integration**: ปรับปรุงหน้า ApproveDepartureDialog ให้ส่งชื่อลูกค้า (Job Customer Name) ไปบอกหน้าจอ Dashboard แผนที่บน POS Backend อัตโนมัติเวลาคนขับกดปุ่ม "ปล่อยรถ"

### 2026-07-28: 🔧 Smart Fallback & Auto-Lock COD สำหรับหน้า QR Code
- **ไฟล์ที่แก้ไข:** `lib/features/settings/screens/driver_qr_screen.dart`
- **รายละเอียด:**
  - **Smart Fallback:** ปรับปรุงให้แสดง Static QR (รูปภาพ) ได้ทันทีหากไม่ได้ตั้งค่า PromptPay ID แต่มีการอัปโหลดรูปภาพไว้ แม้ว่าโหมดในระบบจะเป็น `dynamic` ก็ตาม
  - **Auto-Lock COD:** เพิ่มระบบล็อคยอด COD ลงใน QR Code แบบ Dynamic อัตโนมัติ โดยไม่ต้องให้คนขับกดปุ่มบังคับสลับโหมดอีกต่อไป
  - **Error Handling:** ปรับปรุงข้อความแจ้งเตือนกรณีที่ไม่ได้ตั้งค่าการรับเงินให้ชัดเจนขึ้น และรองรับกรณี Offline Fallback โดยใช้ Local ID แทน
  - **UI/UX:** ปรับปรุงปุ่มกดสลับโหมดให้แสดงสถานะและคำแนะนำที่สอดคล้องกับพฤติกรรมจริงมากขึ้น

