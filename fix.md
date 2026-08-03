# S-Link Fix History

---

## [2026-08-02] Refactor: Universal Dashboard (แผงควบคุมหลัก)
**เป้าหมาย:** ยุบรวมหน้าจอ Dashboard ของทุก Role (Admin, HR, Requester, Driver) ให้เป็นหน้าจอเดียว (`main_dashboard.dart`) เพื่อให้แก้ไขง่าย เป็นระเบียบ และลดความซ้ำซ้อนของโค้ด

**สิ่งที่ทำไป:**
1. สร้างไฟล์ `lib/features/dashboard/screens/main_dashboard.dart` ซึ่งเป็น Universal Dashboard เช็คสิทธิ์ด้วยค่า `user?.role.name` เพื่อแสดงหรือซ่อนการ์ดเมนูโดยอัตโนมัติ
2. แปลชื่อการ์ดเมนูทั้งหมดให้เป็นภาษาไทย เพื่อความสวยงามและเป็นมาตรฐานเดียวกันทั้งหมด
3. แก้ไข `home_screen.dart` ให้ทำการ Route ผู้ใช้ในกลุ่ม `admin`, `hr`, `requester` และ `driver` มาที่ `MainDashboard()` ทั้งหมด
4. ลบไฟล์เดิมที่ไม่ใช้แล้วทิ้งเพื่อทำความสะอาดโปรเจกต์ (`admin_dashboard.dart`, `hr_dashboard.dart`, `employee_dashboard.dart`)
5. รัน `flutter analyze` ตรวจสอบเรียบร้อย ไม่พบ Error ใดๆ ฟังก์ชันทุกอย่างเรียกใช้งานได้เหมือนเดิม

---

## [2026-08-01] Milestone 2: Offline-First Architecture (SQLite Local Cache)
**เป้าหมาย:** ย้ายการจัดการงานจัดส่งออกจาก Firebase มาเก็บใน SQLite บนมือถือแทน ทำให้คนขับดูข้อมูลได้แม้ไม่มีเน็ต และปิดงานได้แม้สัญญาณหลุด

**ไฟล์ที่สร้างใหม่:**
1. **`lib/core/database/local_db_service.dart`** — SQLite singleton สำหรับจัดการ 2 ตาราง:
   - `local_jobs`: Cache ข้อมูลงาน (บิล, ลูกค้า, สินค้า) ที่ดาวน์โหลดมาจาก API
   - `sync_queue`: คิวสำหรับงานที่ปิดตอนออฟไลน์ รอส่งเมื่อเน็ตกลับมา
2. **`lib/features/jobs/repositories/local_job_repository.dart`** — Repository แปลง SQLite Row ↔ Job Model

**ไฟล์ที่แก้ไข (S-Link):**
1. **`lib/features/pos/services/extensions/pos_api_job_extension.dart`** — เพิ่ม `getActiveJobs()` เรียก `GET /api/v1/jobs/active`
2. **`lib/core/services/sync_service.dart`** — รื้อโครงสร้างใหม่ทั้งหมด:
   - `syncJobsDown()`: ดาวน์โหลดงาน PENDING จาก API → เก็บ SQLite (รองรับ Delta Sync ด้วย `?since=`)
   - `saveOfflineJob()`: บันทึกการปิดงานออฟไลน์ลง SQLite แทน SharedPreferences เดิม
   - `syncPendingJobs()`: Worker ประมวลผล sync_queue ส่งรูป + แจ้ง API + update Firebase signal
   - `_migrateLegacyQueue()`: ย้าย queue เก่าจาก SharedPreferences มาที่ SQLite (ทำครั้งเดียว)
3. **`lib/features/jobs/providers/job_provider.dart`** — ปรับให้อ่านงานจาก Local SQLite เป็นหลัก:
   - `loadLocalJobs()`: โหลดงานจาก Local DB แสดงผลได้ทันทีแม้ไม่มีเน็ต
   - `syncAndRefreshJobs()`: Sync + reload ใน 1 ฟังก์ชัน พร้อม `isSyncingDown` flag
   - `driverAssignedJobs`: Prioritize Local SQLite → Fallback Firebase
   - `completeJob()`: บันทึก Local ก่อน ถ้าออฟไลน์ยัด sync_queue, ถ้าออนไลน์ส่ง API แล้วลบจาก Local
4. **`lib/features/jobs/screens/admin_job_list_screen.dart`** — ปรับ UI:
   - ปุ่ม Sync เปลี่ยนเป็น `cloud_download_outlined` + แสดง Spinner ระหว่าง sync
   - Tab "กำลังดำเนินการ" เพิ่ม `RefreshIndicator` (Pull-to-refresh)
   - อ่านข้อมูลจาก `activeLocalJobs` → Fallback `pendingJobs`

**ไฟล์ที่สร้างใหม่ (POS Desktop Backend):**
1. **`backend/lib/controllers/job_controller.dart`** — เพิ่ม `GET /api/v1/jobs/active`:
   - JOIN ตาราง `delivery_jobs + order + customer + orderitem`
   - รองรับ `?since=` สำหรับ Delta Sync
   - Logging ละเอียดทุกขั้นตอนพร้อม Response Time

---

## [2026-08-01] Milestone 1: Direct Database Job Completion & Bug Fixes
**สิ่งที่ดำเนินการ (POS Desktop & S-Link):**
1. **[S-Link] รื้อโครงสร้างปิดงาน (Direct API First):**
   - แก้ไข `job_provider.dart` สลับให้ยิง API `/jobs/complete` เข้าสู่ POS Backend ทันทีเป็นลำดับแรก 
   - ยกเลิกการอัปโหลดข้อมูลหนักๆ อย่าง `proof_image`, `delivery_team`, `proof_location` ลงใน Firebase (ที่ `job_service.dart`) เพื่อลดขนาดข้อมูลบน Cloud 
   - แก้ไข `sync_service.dart` ให้ส่ง `downloadUrl` ตรงเข้า API และอัปเดตสถานะใน Firebase เพียงแค่เป็น Signal (`status: completed`)
2. **[S-Link] แก้บั๊กรูปหลักฐานไม่ขึ้น:**
   - แก้ไข `Job.fromHistory` ใน `job.dart` ให้รองรับกรณี `billImageUrl` เป็น empty string (`""`) ให้แปลงเป็น `null` ป้องกันการแครช
   - เพิ่มการอ่านค่า `destinationLat` / `destinationLng` ให้แสดงพิกัดนำทางได้ในประวัติ
   - แก้ไข `job_detail_screen.dart` ให้ตัวแปร `isHistory` รองรับ prefix `history_` เพื่อให้ UI แสดงผลเป็นโหมดรายงานย้อนหลังได้ถูกต้อง
   - ใส่ `errorBuilder` ดักรูปเสียใน `_buildProofSection` เพื่อให้แอปไม่เด้งหลุด
3. **[POS Desktop] ป้องกันข้อมูลโดนลบทับ (Safe Overwrite):**
   - แก้คำสั่ง SQL ใน `delivery_history_repository.dart` (`saveArchivedJob`) ให้ใช้ `COALESCE` ป้องกันการดึงค่าจาก Firebase อันเก่า (ที่ไม่มีข้อมูลรูปถ่ายแล้ว) มาเขียนทับรูปถ่ายและพิกัดจริงที่ S-Link เพิ่งยิงผ่าน API มาเมื่อสักครู่
   - ปรับให้ `delivery_cleanup_service.dart` หาฟิลด์ `proof_image` เผื่อแอปเวอร์ชั่นเก่า และทำหน้าที่หลักในการ "ลบ" ตั๋วออกจาก Firebase เมื่อเห็นสัญญาณว่า completed แล้วเท่านั้น

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

### 2026-07-28: 🔧 เพิ่มเมนูตั้งค่า API Server (การเชื่อมต่อ)
- **ไฟล์ที่แก้ไข:** `lib/features/settings/screens/widgets/connection_settings_section.dart`
- **รายละเอียด:** เพิ่มเมนู "API Server URL" ให้คนขับหรือแอดมินสามารถเข้าไปแก้ไข/กำหนด URL ของเซิร์ฟเวอร์ (เช่นเปลี่ยนเป็น IP วง LAN หรือ Tunnel ภายนอก) ได้จากหน้าตั้งค่า (Settings) โดยตรง เพื่อแก้ปัญหาแอปเชื่อมต่อไม่ได้แล้วค้างอยู่หน้าจอโชว์ Error

### 2026-07-28: 🔧 ดึงยอด COD อัตโนมัติในหน้า QR รับเงิน (Smart Auto-Detect)
- **ไฟล์ที่แก้ไข:** `lib/features/settings/screens/driver_qr_screen.dart`
- **รายละเอียด:** เพิ่มระบบดึงยอดเงินเก็บปลายทาง (COD) และชื่อลูกค้ามาแสดงในหน้า QR PromptPay โดยอัตโนมัติ 
  - ระบบจะตรวจสอบหา "งานที่กำลังจัดส่ง" (สถานะ shipping และผ่านการปล่อยรถแล้ว) ของคนขับคนนั้น
  - ถ้าระบบเจองานที่ต้องเก็บเงินปลายทาง มันจะล็อคยอดเงินสร้างเป็น QR และแสดงชื่อลูกค้าให้โดยที่พนักงานไม่ต้องพิมพ์ยอดเองเลย


- **[2026-07-29] Fix Driver QR COD Integration:** Automatically fetch COD amount for driver's active job directly in `driver_qr_screen.dart`, removing the need for manual API setup or props.

## [2026-08-01] Milestone 3 Phase 3: Single Source of Truth for Drivers and Vehicles
**เป้าหมาย:** เลิกดึงรายชื่อพนักงานจาก Firestore หันมาดึงจาก POS Desktop API แทน เพื่อให้รหัสพนักงาน (id) ในมือถือตรงกับฐานข้อมูลหลัก MySQL
**ไฟล์ที่แก้ไข (S-Link):**
1. **`lib/features/pos/services/pos_api_service.dart`** — เพิ่มฟังก์ชัน `getRaw` สำหรับดึงข้อมูล GET Request แบบส่ง Custom JWT อัตโนมัติ
2. **`lib/features/auth/services/user_service.dart`** — แก้ไข `getDrivers()` ให้ดึงข้อมูลจาก `GET /employees/drivers` ผ่าน API และแปลงค่ากลับเป็น `UserModel` โดยใช้ `id` ของ MySQL เป็น `uid` หลัก
3. **`lib/features/auth/services/user_service.dart`** — แก้ไข `getDeliveryStaff()` ให้ return ค่าแบบเดียวกับ `getDrivers()` เพื่อให้การ lookup พนักงานเวลาอนุมัติปล่อยรถ (`ApproveDepartureDialog`) ถูกต้องตามรหัส MySQL ID
**ผลลัพธ์:** เมื่อปล่อยรถ รหัส `driverId` ที่ถูกบันทึกลงใน Firestore จะตรงกับ Primary Key ในตาราง `employee_profile` บนเครื่อง POS ทันที

## [2026-08-03] Add manual refresh button to attendance screen
**การแก้ไข:** เพิ่มปุ่ม Refresh มุมขวาบนในหน้าจอลงเวลาเข้างาน (ttendance_screen.dart) เพื่อให้คนขับสามารถกดบังคับซิงค์ดึงข้อมูลเวลาเข้างานล่าสุดได้ด้วยตัวเอง นอกเหนือจากการรออัปเดตอัตโนมัติแบบ Real-time
**เวอร์ชัน:** Bump เป็น 3.4.16+99
