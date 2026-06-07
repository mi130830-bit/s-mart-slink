// ไฟล์: lib/models/user_role.dart

enum UserRole {
  admin,
  requester,
  driver,
  hr,
  gasStation,
  pending, // For users awaiting approval
  unknown, // Fallback for undefined roles
}
