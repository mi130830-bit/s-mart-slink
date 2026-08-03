import 'package:isar/isar.dart';

part 'shop_work_log_isar.g.dart';

@embedded
class WorkItemIsar {
  String? description;
  double? quantity;
  String? unit;
}

@collection
class ShopWorkLogIsar {
  Id id = Isar.autoIncrement; // Local ID
  
  @Index(unique: true)
  String? syncId; // Remote ID (UUID from server or generated locally)
  
  @Index()
  String? delivererId;
  
  DateTime? loggedAt;
  
  List<WorkItemIsar>? items;
  
  // Sync status
  @Index()
  bool isSynced = false; // true if successfully synced to POS API
  
  @Index()
  bool isDeleted = false; // true if marked for deletion offline, pending sync
}
