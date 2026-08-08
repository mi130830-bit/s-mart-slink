# S-Link Fix History

---

## [2026-08-08] Attendance queue retries automatically for every active role

**ไทย:** แก้กรณีลงเวลาแบบออฟไลน์แล้วต้องกดรีเฟรชเอง โดยเริ่มตัวติดตาม
เครือข่ายและ retry queue ของ S-Link หลังยืนยันตัวตนสำหรับทุก role ที่เข้าใช้
งานได้ รวมถึง `requester`, `gas_station` และ `gasstation` ไม่ผูกกับ flow งานส่ง
ข้อมูลยังใช้ `sync_id` เดิมและ POS API/MySQL เป็นแหล่งข้อมูลหลัก จึงไม่สร้าง
รายการลงเวลาซ้ำ

**English:** Every active role now starts S-Link's connectivity monitor and
attendance retry queue immediately after authentication, including
`requester`, `gas_station`, and `gasstation`, without depending on delivery
job loading. The existing `sync_id` and POS API/MySQL source-of-truth flow
remain unchanged, preventing duplicate attendance records.

---

## [2026-08-04] Driver Assignment Identity & Attendance Reliability

**ไทย:** แก้หน้าคนขับไม่แสดงงานที่กำลังส่ง เนื่องจากงานเดิมเก็บ
`employee_profile.id` แต่บัญชีล็อกอินใช้ `user.id` โดยเพิ่ม `employeeId`
ใน `UserModel`, ค้นหา assignment ด้วยรหัสทั้งสองแบบ, และบันทึก assignment
ที่ได้รับจาก Firestore ลง SQLite สำหรับใช้ออฟไลน์

**English:** Fixed active driver jobs being hidden by the mismatch between
`employee_profile.id` assignments and the logged-in `user.id`. The app now
keeps both identities, queries both legacy and canonical assignments, and
persists live assignment metadata into the per-user SQLite cache.

**Attendance / ลงเวลา:** ยืนยันว่า S-Link ใช้ Isar เป็น offline cache และ
POS/MySQL เป็น source of truth ผ่าน API; เพิ่มการป้องกันไม่ให้ server รายงาน
sync สำเร็จเมื่อหารหัสพนักงานไม่พบ เพื่อให้รายการคงอยู่สำหรับ retry

## [2026-08-04] Bug Fix: S-Link Attendance Sync (String instead of double)
**เป้าหมาย:** แก้ไขปัญหาพนักงานบางคน (เช่น ทูล) ลงเวลาแล้วในฝั่งเครื่องแม่ (POS) แต่ในมือถือ (S-Link) ไม่แสดงเวลาเข้างาน และให้กดเข้างานใหม่ซ้ำๆ
**สาเหตุ:** 
- ในฟังก์ชัน `fetchTodayLogFromServer` ของไฟล์ `attendance_service.dart` มีการเขียนโค้ด `response['check_in_lat']?.toDouble()`
- ซึ่งค่าที่ส่งกลับมาจาก POS API นั้นคือค่าทศนิยมของ MySQL (`DECIMAL`) ที่แปลงเป็น JSON แล้วจะได้เป็น **String** (`"16.160155"`)
- ภาษา Dart ไม่อนุญาตให้ใช้ `.toDouble()` กับตัวแปรที่เป็น String ได้โดยตรง (จะเกิด `NoSuchMethodError`)
- ส่งผลให้ฟังก์ชันแอบ Crash และข้ามขั้นตอนการอัปเดตลง `Isar Database` (Local Cache) ในมือถือไป ทำให้แอปมือถือไม่เคยได้รับสถานะการลงเวลาของวันนี้เลย
**สิ่งที่ทำไป:**
1. สร้างฟังก์ชัน `parseDouble()` ใน `AttendanceService` เพื่อรองรับข้อมูลทั้งที่เป็น `String`, `int` และ `double` ได้อย่างปลอดภัย
2. แก้ไขการแปลงค่า latitude และ longitude ทั้งหมดเป็น `parseDouble(response['...'])`
3. บิวต์ APK รหัสเวอร์ชัน `3.4.22+106` ใหม่ให้พี่ติ

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

- **Phase 9: Mobile UI & Approval Flow Fix** ✅ (Aug 4, 2026)
  - **Root Cause**: The migration to local SQLite caused the \isDepartureApproved\ state to be lost (defaulting to true), which bypassed the Admin Approval screen and sent users straight to the 'Close Job' screen. Additionally, the lack of \items\ in Firestore documents caused the details section to be empty.
  - **Fix**: Restored the \StreamBuilder\ in \JobDetailScreen\ to subscribe to real-time status from Firestore (for \isDepartureApproved\ and \deliveryTeam\), and merged it seamlessly with the local SQLite data (which holds the \items\). Now the UI correctly waits for Admin approval and displays job details without losing offline capabilities.
  - **Delete Job Bug**: Fixed an issue where deleting a job only removed it from Firestore, leaving a 'ghost' entry in the local SQLite database which caused the list screen to display an empty card.
\ n # #   4   A u g u s t   2 0 2 6 \ n -   F i x   Z o m b i e   J o b s   o v e r w r i t e   b u g   i n   L o c a l D b S e r v i c e . \ n -   U p g r a d e   S Q L i t e   S c h e m a   t o   v 2   a d d i n g   d r i v e r I d s ,   v e h i c l e I d s ,   d e l i v e r y T e a m J s o n . \ n -   E n s u r e   O f f l i n e   A s s i g n m e n t   d a t a   i s   p r e s e r v e d   w h e n   d i s c o n n e c t e d . \ n -   F i x   O f f l i n e   S y n c   m i s s i n g   d e l i v e r y T e a m D a t a   ( j o b s )   a n d   l a t / l n g   c o o r d i n a t e s   ( a t t e n d a n c e ) .  
 \ n -   F i x   T a b B a r   t e x t   c o l o r   i n   A d m i n J o b L i s t S c r e e n   ( w a s   w h i t e   o n   l i g h t   b a c k g r o u n d ,   n o w   g r e y ) \ n -   F i x   O f f l i n e   J o b   S y n c   P a y l o a d   m i s s i n g   d r i v e r N a m e   a n d   v e h i c l e P l a t e   f o r   P O S   B a c k e n d \ n -   B u m p   v e r s i o n   t o   3 . 4 . 2 2 + 1 0 5  
 
## 2026-08-04 — HR Override reliability and release 4.0.0+110

**ไทย:** หน้าเข้างานแทนส่งสถานะ `PRESENT_OVERRIDE` ลง local queue ครบถ้วน
และร้องขอผลยืนยันจาก POS server ก่อนแจ้งว่าสำเร็จ หาก server ใช้งานไม่ได้
จะแจ้งชัดว่าบันทึกในเครื่องแล้วและกำลังรอ sync โดยไม่ทำข้อมูลหาย

**English:** HR Override now persists `PRESENT_OVERRIDE` in the local queue
and requires POS-server confirmation before reporting success. When the server
is unavailable, the UI clearly reports that the record is safely queued for
retry instead of showing a false success.
# 2026-08-05 — Allow requester to approve job departure

- Centralized the departure-approval permission in `AuthenticationProvider.canApproveJobDeparture`.
- Allowed both `admin` and `requester` (including POS `CASHIER`, which maps to requester) to see and use the release-vehicle action.
- Removed the unintended HR permission from the departure action; no other roles receive this permission.
# 2026-08-05 — Driver COD Dynamic QR source and PromptPay number

- Fixed S-Link PromptPay mobile encoding to use the required `0066...` representation.
- Accepted `0921223385`, `+66921223385`, and `66921223385` as equivalent settings values.
- Driver QR now reads COD only from active jobs assigned during departure approval; it no longer requires the stale `shipping` status value.
- When a driver has multiple active COD jobs, the QR page now provides a customer/job selector instead of silently using an arbitrary amount.
- The driver can edit the QR amount for split cash/PromptPay payments; the value defaults to the assigned COD amount and cannot exceed it.
- Added focused PromptPay payload tests, including the locked COD amount.
# 2026-08-05 — Requester stock-alert access

- Centralized stock-alert authorization in `AuthenticationProvider.canManageStockAlerts`.
- Both `admin` and `requester` (including POS `CASHIER`) can open the low-stock screen, create alerts, mark items as ordered, and remove completed entries.
- Other roles are explicitly blocked when navigating directly to the screen.
# 2026-08-05 — Release 4.0.1+111

- Bumped S-Link release version from `4.0.0+110` to `4.0.1+111` for the requested Android App Bundle build.
# 2026-08-05 - Attendance uses MySQL as the single source of truth / ใช้ MySQL เป็นข้อมูลลงเวลาชุดเดียว

- TH: เพิ่มการส่งคิวลงเวลาจาก S-Link ไป POS API อัตโนมัติทุก 30 วินาทีและทันทีเมื่ออินเทอร์เน็ตกลับมา โดย Firebase ไม่ได้ใช้ตัดสินสถานะลงเวลา
- EN: Added automatic S-Link attendance queue delivery to the POS API every 30 seconds and immediately after connectivity returns; Firebase does not determine attendance state.
- TH: แสดงสถานะ “รอซิงก์กับ POS” เมื่อข้อมูลยังอยู่เฉพาะในเครื่อง เพื่อไม่ให้ผู้ใช้เข้าใจว่า MySQL ยืนยันแล้ว
- EN: Shows a “waiting to sync with POS” state while an event exists only on-device, avoiding false confirmation before MySQL accepts it.
# 2026-08-05 - Authenticated GPS job status / อัปเดตสถานะงาน GPS พร้อมสิทธิ์

- TH: เปลี่ยนการแจ้งสถานะรถตอนปล่อยรถและปิดงานให้ใช้ PosApiService/JWT แทน HTTP ตรง เพื่อให้ทำงานกับ GPS API ที่ป้องกันสิทธิ์
- EN: Vehicle status updates on departure and completion now use PosApiService/JWT instead of raw HTTP, matching the protected GPS job endpoint.
# 2026-08-05 - Automatic JWT renewal / ต่ออายุ JWT อัตโนมัติ

- TH: S-Link ตรวจ `exp` ก่อนทุก API call, ต่ออายุล่วงหน้า 60 วินาที และ retry คำขอเดิมหนึ่งครั้งเมื่อได้รับ 401/403
- EN: S-Link checks `exp` before API calls, refreshes 60 seconds early, and retries a standard request once after a 401/403 response.
- TH: ใช้คำขอ refresh ร่วมกันเมื่อหลายหน้าซิงก์พร้อมกัน เพื่อป้องกันการยิง refresh ซ้ำและลูปไม่สิ้นสุด
- EN: Concurrent API calls share one in-flight refresh operation, preventing refresh storms and infinite retry loops.

# 2026-08-06 — Driver loading and cached item resilience

- TH: แก้ Auth HTTP client ไม่ให้อ่าน response stream ของ 401/403 ซ้ำเมื่อไม่มี token ใหม่ จึงไม่เกิด `Bad state: Stream has already been listened to`; หน้าปล่อยรถจะแจ้งให้เข้าสู่ระบบ POS ใหม่เมื่อ JWT ไม่มี แทนการแสดงว่าไม่มีพนักงาน
- EN: Fixed the auth client so an unretried 401/403 response stream is not consumed twice; the departure dialog now requests a fresh POS login when JWT is absent rather than claiming no staff exists.
- TH: รองรับค่า qty/price/total ใน `itemsJson` ที่เป็นข้อความจากแคชเก่า เพื่อไม่ให้รายการสินค้าในงานอ่านไม่สำเร็จ
- EN: Made cached `itemsJson` tolerant of string-form qty/price/total values so legacy local jobs remain readable.
- TH: เมื่อ access/refresh token หาย แต่มีข้อมูล offline login เดิม ระบบจะ login POS ใหม่อัตโนมัติก่อนส่ง API เพื่อกู้ session โดยไม่ต้องให้พนักงานออก–เข้าแอป
- EN: When access/refresh tokens are missing but offline-login credentials exist, the client now re-authenticates with POS automatically before protected API calls.

# 2026-08-06 — S-Link release 4.0.2+112

- TH: เพิ่มเวอร์ชัน S-Link เป็น 4.0.2+112 และสร้าง Android App Bundle สำหรับการเผยแพร่
- EN: Bumped S-Link to 4.0.2+112 and produced the Android App Bundle release artifact.
