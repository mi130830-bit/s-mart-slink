// ไฟล์: lib/models/user_role.dart

enum UserRole {
  admin,
  requester,
  driver,
  pending, // For users awaiting approval
  unknown, // Fallback for undefined roles
}
