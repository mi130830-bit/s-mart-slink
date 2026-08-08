// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_log_isar.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAttendanceLogIsarCollection on Isar {
  IsarCollection<AttendanceLogIsar> get attendanceLogIsars => this.collection();
}

const AttendanceLogIsarSchema = CollectionSchema(
  name: r'AttendanceLogIsar',
  id: -592391286840993469,
  properties: {
    r'backToWorkLat': PropertySchema(
      id: 0,
      name: r'backToWorkLat',
      type: IsarType.double,
    ),
    r'backToWorkLng': PropertySchema(
      id: 1,
      name: r'backToWorkLng',
      type: IsarType.double,
    ),
    r'backToWorkTime': PropertySchema(
      id: 2,
      name: r'backToWorkTime',
      type: IsarType.dateTime,
    ),
    r'checkInLat': PropertySchema(
      id: 3,
      name: r'checkInLat',
      type: IsarType.double,
    ),
    r'checkInLng': PropertySchema(
      id: 4,
      name: r'checkInLng',
      type: IsarType.double,
    ),
    r'checkInTime': PropertySchema(
      id: 5,
      name: r'checkInTime',
      type: IsarType.dateTime,
    ),
    r'checkOutLat': PropertySchema(
      id: 6,
      name: r'checkOutLat',
      type: IsarType.double,
    ),
    r'checkOutLng': PropertySchema(
      id: 7,
      name: r'checkOutLng',
      type: IsarType.double,
    ),
    r'checkOutTime': PropertySchema(
      id: 8,
      name: r'checkOutTime',
      type: IsarType.dateTime,
    ),
    r'date': PropertySchema(
      id: 9,
      name: r'date',
      type: IsarType.string,
    ),
    r'isDeleted': PropertySchema(
      id: 10,
      name: r'isDeleted',
      type: IsarType.bool,
    ),
    r'isSynced': PropertySchema(
      id: 11,
      name: r'isSynced',
      type: IsarType.bool,
    ),
    r'lastModified': PropertySchema(
      id: 12,
      name: r'lastModified',
      type: IsarType.dateTime,
    ),
    r'note': PropertySchema(
      id: 13,
      name: r'note',
      type: IsarType.string,
    ),
    r'status': PropertySchema(
      id: 14,
      name: r'status',
      type: IsarType.string,
    ),
    r'syncId': PropertySchema(
      id: 15,
      name: r'syncId',
      type: IsarType.string,
    ),
    r'tempOutLat': PropertySchema(
      id: 16,
      name: r'tempOutLat',
      type: IsarType.double,
    ),
    r'tempOutLng': PropertySchema(
      id: 17,
      name: r'tempOutLng',
      type: IsarType.double,
    ),
    r'tempOutTime': PropertySchema(
      id: 18,
      name: r'tempOutTime',
      type: IsarType.dateTime,
    ),
    r'userId': PropertySchema(
      id: 19,
      name: r'userId',
      type: IsarType.string,
    ),
    r'userName': PropertySchema(
      id: 20,
      name: r'userName',
      type: IsarType.string,
    )
  },
  estimateSize: _attendanceLogIsarEstimateSize,
  serialize: _attendanceLogIsarSerialize,
  deserialize: _attendanceLogIsarDeserialize,
  deserializeProp: _attendanceLogIsarDeserializeProp,
  idName: r'id',
  indexes: {
    r'syncId': IndexSchema(
      id: 7538593479801827566,
      name: r'syncId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'syncId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _attendanceLogIsarGetId,
  getLinks: _attendanceLogIsarGetLinks,
  attach: _attendanceLogIsarAttach,
  version: '3.1.0+1',
);

int _attendanceLogIsarEstimateSize(
  AttendanceLogIsar object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.date;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.note;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.status;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.syncId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.userId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.userName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _attendanceLogIsarSerialize(
  AttendanceLogIsar object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.backToWorkLat);
  writer.writeDouble(offsets[1], object.backToWorkLng);
  writer.writeDateTime(offsets[2], object.backToWorkTime);
  writer.writeDouble(offsets[3], object.checkInLat);
  writer.writeDouble(offsets[4], object.checkInLng);
  writer.writeDateTime(offsets[5], object.checkInTime);
  writer.writeDouble(offsets[6], object.checkOutLat);
  writer.writeDouble(offsets[7], object.checkOutLng);
  writer.writeDateTime(offsets[8], object.checkOutTime);
  writer.writeString(offsets[9], object.date);
  writer.writeBool(offsets[10], object.isDeleted);
  writer.writeBool(offsets[11], object.isSynced);
  writer.writeDateTime(offsets[12], object.lastModified);
  writer.writeString(offsets[13], object.note);
  writer.writeString(offsets[14], object.status);
  writer.writeString(offsets[15], object.syncId);
  writer.writeDouble(offsets[16], object.tempOutLat);
  writer.writeDouble(offsets[17], object.tempOutLng);
  writer.writeDateTime(offsets[18], object.tempOutTime);
  writer.writeString(offsets[19], object.userId);
  writer.writeString(offsets[20], object.userName);
}

AttendanceLogIsar _attendanceLogIsarDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AttendanceLogIsar();
  object.backToWorkLat = reader.readDoubleOrNull(offsets[0]);
  object.backToWorkLng = reader.readDoubleOrNull(offsets[1]);
  object.backToWorkTime = reader.readDateTimeOrNull(offsets[2]);
  object.checkInLat = reader.readDoubleOrNull(offsets[3]);
  object.checkInLng = reader.readDoubleOrNull(offsets[4]);
  object.checkInTime = reader.readDateTimeOrNull(offsets[5]);
  object.checkOutLat = reader.readDoubleOrNull(offsets[6]);
  object.checkOutLng = reader.readDoubleOrNull(offsets[7]);
  object.checkOutTime = reader.readDateTimeOrNull(offsets[8]);
  object.date = reader.readStringOrNull(offsets[9]);
  object.id = id;
  object.isDeleted = reader.readBool(offsets[10]);
  object.isSynced = reader.readBool(offsets[11]);
  object.lastModified = reader.readDateTimeOrNull(offsets[12]);
  object.note = reader.readStringOrNull(offsets[13]);
  object.status = reader.readStringOrNull(offsets[14]);
  object.syncId = reader.readStringOrNull(offsets[15]);
  object.tempOutLat = reader.readDoubleOrNull(offsets[16]);
  object.tempOutLng = reader.readDoubleOrNull(offsets[17]);
  object.tempOutTime = reader.readDateTimeOrNull(offsets[18]);
  object.userId = reader.readStringOrNull(offsets[19]);
  object.userName = reader.readStringOrNull(offsets[20]);
  return object;
}

P _attendanceLogIsarDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDoubleOrNull(offset)) as P;
    case 1:
      return (reader.readDoubleOrNull(offset)) as P;
    case 2:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 3:
      return (reader.readDoubleOrNull(offset)) as P;
    case 4:
      return (reader.readDoubleOrNull(offset)) as P;
    case 5:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 6:
      return (reader.readDoubleOrNull(offset)) as P;
    case 7:
      return (reader.readDoubleOrNull(offset)) as P;
    case 8:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readBool(offset)) as P;
    case 11:
      return (reader.readBool(offset)) as P;
    case 12:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readDoubleOrNull(offset)) as P;
    case 17:
      return (reader.readDoubleOrNull(offset)) as P;
    case 18:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 19:
      return (reader.readStringOrNull(offset)) as P;
    case 20:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _attendanceLogIsarGetId(AttendanceLogIsar object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _attendanceLogIsarGetLinks(
    AttendanceLogIsar object) {
  return [];
}

void _attendanceLogIsarAttach(
    IsarCollection<dynamic> col, Id id, AttendanceLogIsar object) {
  object.id = id;
}

extension AttendanceLogIsarByIndex on IsarCollection<AttendanceLogIsar> {
  Future<AttendanceLogIsar?> getBySyncId(String? syncId) {
    return getByIndex(r'syncId', [syncId]);
  }

  AttendanceLogIsar? getBySyncIdSync(String? syncId) {
    return getByIndexSync(r'syncId', [syncId]);
  }

  Future<bool> deleteBySyncId(String? syncId) {
    return deleteByIndex(r'syncId', [syncId]);
  }

  bool deleteBySyncIdSync(String? syncId) {
    return deleteByIndexSync(r'syncId', [syncId]);
  }

  Future<List<AttendanceLogIsar?>> getAllBySyncId(List<String?> syncIdValues) {
    final values = syncIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'syncId', values);
  }

  List<AttendanceLogIsar?> getAllBySyncIdSync(List<String?> syncIdValues) {
    final values = syncIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'syncId', values);
  }

  Future<int> deleteAllBySyncId(List<String?> syncIdValues) {
    final values = syncIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'syncId', values);
  }

  int deleteAllBySyncIdSync(List<String?> syncIdValues) {
    final values = syncIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'syncId', values);
  }

  Future<Id> putBySyncId(AttendanceLogIsar object) {
    return putByIndex(r'syncId', object);
  }

  Id putBySyncIdSync(AttendanceLogIsar object, {bool saveLinks = true}) {
    return putByIndexSync(r'syncId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllBySyncId(List<AttendanceLogIsar> objects) {
    return putAllByIndex(r'syncId', objects);
  }

  List<Id> putAllBySyncIdSync(List<AttendanceLogIsar> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'syncId', objects, saveLinks: saveLinks);
  }
}

extension AttendanceLogIsarQueryWhereSort
    on QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QWhere> {
  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension AttendanceLogIsarQueryWhere
    on QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QWhereClause> {
  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterWhereClause>
      syncIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'syncId',
        value: [null],
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterWhereClause>
      syncIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'syncId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterWhereClause>
      syncIdEqualTo(String? syncId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'syncId',
        value: [syncId],
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterWhereClause>
      syncIdNotEqualTo(String? syncId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'syncId',
              lower: [],
              upper: [syncId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'syncId',
              lower: [syncId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'syncId',
              lower: [syncId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'syncId',
              lower: [],
              upper: [syncId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension AttendanceLogIsarQueryFilter
    on QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QFilterCondition> {
  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      backToWorkLatIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'backToWorkLat',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      backToWorkLatIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'backToWorkLat',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      backToWorkLatEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'backToWorkLat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      backToWorkLatGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'backToWorkLat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      backToWorkLatLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'backToWorkLat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      backToWorkLatBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'backToWorkLat',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      backToWorkLngIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'backToWorkLng',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      backToWorkLngIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'backToWorkLng',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      backToWorkLngEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'backToWorkLng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      backToWorkLngGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'backToWorkLng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      backToWorkLngLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'backToWorkLng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      backToWorkLngBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'backToWorkLng',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      backToWorkTimeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'backToWorkTime',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      backToWorkTimeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'backToWorkTime',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      backToWorkTimeEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'backToWorkTime',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      backToWorkTimeGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'backToWorkTime',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      backToWorkTimeLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'backToWorkTime',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      backToWorkTimeBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'backToWorkTime',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkInLatIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'checkInLat',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkInLatIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'checkInLat',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkInLatEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'checkInLat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkInLatGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'checkInLat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkInLatLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'checkInLat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkInLatBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'checkInLat',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkInLngIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'checkInLng',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkInLngIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'checkInLng',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkInLngEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'checkInLng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkInLngGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'checkInLng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkInLngLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'checkInLng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkInLngBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'checkInLng',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkInTimeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'checkInTime',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkInTimeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'checkInTime',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkInTimeEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'checkInTime',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkInTimeGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'checkInTime',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkInTimeLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'checkInTime',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkInTimeBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'checkInTime',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkOutLatIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'checkOutLat',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkOutLatIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'checkOutLat',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkOutLatEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'checkOutLat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkOutLatGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'checkOutLat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkOutLatLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'checkOutLat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkOutLatBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'checkOutLat',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkOutLngIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'checkOutLng',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkOutLngIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'checkOutLng',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkOutLngEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'checkOutLng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkOutLngGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'checkOutLng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkOutLngLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'checkOutLng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkOutLngBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'checkOutLng',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkOutTimeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'checkOutTime',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkOutTimeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'checkOutTime',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkOutTimeEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'checkOutTime',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkOutTimeGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'checkOutTime',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkOutTimeLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'checkOutTime',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      checkOutTimeBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'checkOutTime',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      dateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'date',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      dateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'date',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      dateEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'date',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      dateGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'date',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      dateLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'date',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      dateBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'date',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      dateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'date',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      dateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'date',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      dateContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'date',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      dateMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'date',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      dateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'date',
        value: '',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      dateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'date',
        value: '',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      isDeletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDeleted',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      isSyncedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isSynced',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      lastModifiedIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastModified',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      lastModifiedIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastModified',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      lastModifiedEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastModified',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      lastModifiedGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastModified',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      lastModifiedLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastModified',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      lastModifiedBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastModified',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      noteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'note',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      noteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'note',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      noteEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      noteGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      noteLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      noteBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'note',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      noteStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      noteEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      noteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      noteMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'note',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      noteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'note',
        value: '',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      noteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'note',
        value: '',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      statusIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'status',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      statusIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'status',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      statusEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      statusGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      statusLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      statusBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'status',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      statusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      statusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      statusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      statusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'status',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      syncIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'syncId',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      syncIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'syncId',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      syncIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      syncIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'syncId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      syncIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'syncId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      syncIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'syncId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      syncIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'syncId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      syncIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'syncId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      syncIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'syncId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      syncIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'syncId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      syncIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncId',
        value: '',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      syncIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'syncId',
        value: '',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      tempOutLatIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'tempOutLat',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      tempOutLatIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'tempOutLat',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      tempOutLatEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tempOutLat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      tempOutLatGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'tempOutLat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      tempOutLatLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'tempOutLat',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      tempOutLatBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'tempOutLat',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      tempOutLngIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'tempOutLng',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      tempOutLngIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'tempOutLng',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      tempOutLngEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tempOutLng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      tempOutLngGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'tempOutLng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      tempOutLngLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'tempOutLng',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      tempOutLngBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'tempOutLng',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      tempOutTimeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'tempOutTime',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      tempOutTimeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'tempOutTime',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      tempOutTimeEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tempOutTime',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      tempOutTimeGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'tempOutTime',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      tempOutTimeLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'tempOutTime',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      tempOutTimeBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'tempOutTime',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'userId',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'userId',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'userId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'userId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'userId',
        value: '',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'userId',
        value: '',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'userName',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'userName',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'userName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'userName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'userName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'userName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'userName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'userName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'userName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'userName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'userName',
        value: '',
      ));
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterFilterCondition>
      userNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'userName',
        value: '',
      ));
    });
  }
}

extension AttendanceLogIsarQueryObject
    on QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QFilterCondition> {}

extension AttendanceLogIsarQueryLinks
    on QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QFilterCondition> {}

extension AttendanceLogIsarQuerySortBy
    on QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QSortBy> {
  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByBackToWorkLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backToWorkLat', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByBackToWorkLatDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backToWorkLat', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByBackToWorkLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backToWorkLng', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByBackToWorkLngDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backToWorkLng', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByBackToWorkTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backToWorkTime', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByBackToWorkTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backToWorkTime', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByCheckInLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkInLat', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByCheckInLatDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkInLat', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByCheckInLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkInLng', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByCheckInLngDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkInLng', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByCheckInTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkInTime', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByCheckInTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkInTime', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByCheckOutLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkOutLat', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByCheckOutLatDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkOutLat', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByCheckOutLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkOutLng', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByCheckOutLngDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkOutLng', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByCheckOutTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkOutTime', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByCheckOutTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkOutTime', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByLastModified() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModified', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByLastModifiedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModified', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortBySyncId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncId', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortBySyncIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncId', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByTempOutLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tempOutLat', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByTempOutLatDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tempOutLat', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByTempOutLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tempOutLng', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByTempOutLngDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tempOutLng', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByTempOutTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tempOutTime', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByTempOutTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tempOutTime', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByUserName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userName', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      sortByUserNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userName', Sort.desc);
    });
  }
}

extension AttendanceLogIsarQuerySortThenBy
    on QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QSortThenBy> {
  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByBackToWorkLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backToWorkLat', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByBackToWorkLatDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backToWorkLat', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByBackToWorkLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backToWorkLng', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByBackToWorkLngDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backToWorkLng', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByBackToWorkTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backToWorkTime', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByBackToWorkTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'backToWorkTime', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByCheckInLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkInLat', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByCheckInLatDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkInLat', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByCheckInLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkInLng', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByCheckInLngDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkInLng', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByCheckInTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkInTime', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByCheckInTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkInTime', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByCheckOutLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkOutLat', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByCheckOutLatDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkOutLat', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByCheckOutLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkOutLng', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByCheckOutLngDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkOutLng', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByCheckOutTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkOutTime', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByCheckOutTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'checkOutTime', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByIsDeletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDeleted', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByIsSyncedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isSynced', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByLastModified() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModified', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByLastModifiedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModified', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenBySyncId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncId', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenBySyncIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncId', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByTempOutLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tempOutLat', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByTempOutLatDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tempOutLat', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByTempOutLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tempOutLng', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByTempOutLngDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tempOutLng', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByTempOutTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tempOutTime', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByTempOutTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'tempOutTime', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.desc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByUserName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userName', Sort.asc);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QAfterSortBy>
      thenByUserNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userName', Sort.desc);
    });
  }
}

extension AttendanceLogIsarQueryWhereDistinct
    on QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QDistinct> {
  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QDistinct>
      distinctByBackToWorkLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'backToWorkLat');
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QDistinct>
      distinctByBackToWorkLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'backToWorkLng');
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QDistinct>
      distinctByBackToWorkTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'backToWorkTime');
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QDistinct>
      distinctByCheckInLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'checkInLat');
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QDistinct>
      distinctByCheckInLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'checkInLng');
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QDistinct>
      distinctByCheckInTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'checkInTime');
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QDistinct>
      distinctByCheckOutLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'checkOutLat');
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QDistinct>
      distinctByCheckOutLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'checkOutLng');
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QDistinct>
      distinctByCheckOutTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'checkOutTime');
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QDistinct> distinctByDate(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'date', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QDistinct>
      distinctByIsDeleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDeleted');
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QDistinct>
      distinctByIsSynced() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isSynced');
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QDistinct>
      distinctByLastModified() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastModified');
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QDistinct> distinctByNote(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'note', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QDistinct>
      distinctByStatus({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QDistinct>
      distinctBySyncId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QDistinct>
      distinctByTempOutLat() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tempOutLat');
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QDistinct>
      distinctByTempOutLng() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tempOutLng');
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QDistinct>
      distinctByTempOutTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tempOutTime');
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QDistinct>
      distinctByUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'userId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QDistinct>
      distinctByUserName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'userName', caseSensitive: caseSensitive);
    });
  }
}

extension AttendanceLogIsarQueryProperty
    on QueryBuilder<AttendanceLogIsar, AttendanceLogIsar, QQueryProperty> {
  QueryBuilder<AttendanceLogIsar, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AttendanceLogIsar, double?, QQueryOperations>
      backToWorkLatProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'backToWorkLat');
    });
  }

  QueryBuilder<AttendanceLogIsar, double?, QQueryOperations>
      backToWorkLngProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'backToWorkLng');
    });
  }

  QueryBuilder<AttendanceLogIsar, DateTime?, QQueryOperations>
      backToWorkTimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'backToWorkTime');
    });
  }

  QueryBuilder<AttendanceLogIsar, double?, QQueryOperations>
      checkInLatProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'checkInLat');
    });
  }

  QueryBuilder<AttendanceLogIsar, double?, QQueryOperations>
      checkInLngProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'checkInLng');
    });
  }

  QueryBuilder<AttendanceLogIsar, DateTime?, QQueryOperations>
      checkInTimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'checkInTime');
    });
  }

  QueryBuilder<AttendanceLogIsar, double?, QQueryOperations>
      checkOutLatProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'checkOutLat');
    });
  }

  QueryBuilder<AttendanceLogIsar, double?, QQueryOperations>
      checkOutLngProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'checkOutLng');
    });
  }

  QueryBuilder<AttendanceLogIsar, DateTime?, QQueryOperations>
      checkOutTimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'checkOutTime');
    });
  }

  QueryBuilder<AttendanceLogIsar, String?, QQueryOperations> dateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'date');
    });
  }

  QueryBuilder<AttendanceLogIsar, bool, QQueryOperations> isDeletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDeleted');
    });
  }

  QueryBuilder<AttendanceLogIsar, bool, QQueryOperations> isSyncedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isSynced');
    });
  }

  QueryBuilder<AttendanceLogIsar, DateTime?, QQueryOperations>
      lastModifiedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastModified');
    });
  }

  QueryBuilder<AttendanceLogIsar, String?, QQueryOperations> noteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'note');
    });
  }

  QueryBuilder<AttendanceLogIsar, String?, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<AttendanceLogIsar, String?, QQueryOperations> syncIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncId');
    });
  }

  QueryBuilder<AttendanceLogIsar, double?, QQueryOperations>
      tempOutLatProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tempOutLat');
    });
  }

  QueryBuilder<AttendanceLogIsar, double?, QQueryOperations>
      tempOutLngProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tempOutLng');
    });
  }

  QueryBuilder<AttendanceLogIsar, DateTime?, QQueryOperations>
      tempOutTimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tempOutTime');
    });
  }

  QueryBuilder<AttendanceLogIsar, String?, QQueryOperations> userIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'userId');
    });
  }

  QueryBuilder<AttendanceLogIsar, String?, QQueryOperations>
      userNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'userName');
    });
  }
}
