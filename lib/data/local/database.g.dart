// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
mixin _$TerritoryDaoMixin on DatabaseAccessor<ClaimTrekDatabase> {
  $TerritoriesTable get territories => attachedDatabase.territories;
  TerritoryDaoManager get managers => TerritoryDaoManager(this);
}

class TerritoryDaoManager {
  final _$TerritoryDaoMixin _db;
  TerritoryDaoManager(this._db);
  $$TerritoriesTableTableManager get territories =>
      $$TerritoriesTableTableManager(_db.attachedDatabase, _db.territories);
}

mixin _$RunDaoMixin on DatabaseAccessor<ClaimTrekDatabase> {
  $RunsTable get runs => attachedDatabase.runs;
  RunDaoManager get managers => RunDaoManager(this);
}

class RunDaoManager {
  final _$RunDaoMixin _db;
  RunDaoManager(this._db);
  $$RunsTableTableManager get runs =>
      $$RunsTableTableManager(_db.attachedDatabase, _db.runs);
}

mixin _$TrailDaoMixin on DatabaseAccessor<ClaimTrekDatabase> {
  $TrailsTable get trails => attachedDatabase.trails;
  $TrailCellsTable get trailCells => attachedDatabase.trailCells;
  TrailDaoManager get managers => TrailDaoManager(this);
}

class TrailDaoManager {
  final _$TrailDaoMixin _db;
  TrailDaoManager(this._db);
  $$TrailsTableTableManager get trails =>
      $$TrailsTableTableManager(_db.attachedDatabase, _db.trails);
  $$TrailCellsTableTableManager get trailCells =>
      $$TrailCellsTableTableManager(_db.attachedDatabase, _db.trailCells);
}

class $TerritoriesTable extends Territories
    with TableInfo<$TerritoriesTable, Territory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TerritoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerNameMeta = const VerificationMeta(
    'ownerName',
  );
  @override
  late final GeneratedColumn<String> ownerName = GeneratedColumn<String>(
    'owner_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wktMeta = const VerificationMeta('wkt');
  @override
  late final GeneratedColumn<String> wkt = GeneratedColumn<String>(
    'wkt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _areaM2Meta = const VerificationMeta('areaM2');
  @override
  late final GeneratedColumn<double> areaM2 = GeneratedColumn<double>(
    'area_m2',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _geohash5Meta = const VerificationMeta(
    'geohash5',
  );
  @override
  late final GeneratedColumn<String> geohash5 = GeneratedColumn<String>(
    'geohash5',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _refLatMeta = const VerificationMeta('refLat');
  @override
  late final GeneratedColumn<double> refLat = GeneratedColumn<double>(
    'ref_lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _refLngMeta = const VerificationMeta('refLng');
  @override
  late final GeneratedColumn<double> refLng = GeneratedColumn<double>(
    'ref_lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _claimedAtMeta = const VerificationMeta(
    'claimedAt',
  );
  @override
  late final GeneratedColumn<int> claimedAt = GeneratedColumn<int>(
    'claimed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _verifiedMeta = const VerificationMeta(
    'verified',
  );
  @override
  late final GeneratedColumn<bool> verified = GeneratedColumn<bool>(
    'verified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("verified" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    ownerName,
    colorHex,
    wkt,
    areaM2,
    geohash5,
    refLat,
    refLng,
    claimedAt,
    verified,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'territories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Territory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('owner_name')) {
      context.handle(
        _ownerNameMeta,
        ownerName.isAcceptableOrUnknown(data['owner_name']!, _ownerNameMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerNameMeta);
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    } else if (isInserting) {
      context.missing(_colorHexMeta);
    }
    if (data.containsKey('wkt')) {
      context.handle(
        _wktMeta,
        wkt.isAcceptableOrUnknown(data['wkt']!, _wktMeta),
      );
    } else if (isInserting) {
      context.missing(_wktMeta);
    }
    if (data.containsKey('area_m2')) {
      context.handle(
        _areaM2Meta,
        areaM2.isAcceptableOrUnknown(data['area_m2']!, _areaM2Meta),
      );
    } else if (isInserting) {
      context.missing(_areaM2Meta);
    }
    if (data.containsKey('geohash5')) {
      context.handle(
        _geohash5Meta,
        geohash5.isAcceptableOrUnknown(data['geohash5']!, _geohash5Meta),
      );
    } else if (isInserting) {
      context.missing(_geohash5Meta);
    }
    if (data.containsKey('ref_lat')) {
      context.handle(
        _refLatMeta,
        refLat.isAcceptableOrUnknown(data['ref_lat']!, _refLatMeta),
      );
    } else if (isInserting) {
      context.missing(_refLatMeta);
    }
    if (data.containsKey('ref_lng')) {
      context.handle(
        _refLngMeta,
        refLng.isAcceptableOrUnknown(data['ref_lng']!, _refLngMeta),
      );
    } else if (isInserting) {
      context.missing(_refLngMeta);
    }
    if (data.containsKey('claimed_at')) {
      context.handle(
        _claimedAtMeta,
        claimedAt.isAcceptableOrUnknown(data['claimed_at']!, _claimedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_claimedAtMeta);
    }
    if (data.containsKey('verified')) {
      context.handle(
        _verifiedMeta,
        verified.isAcceptableOrUnknown(data['verified']!, _verifiedMeta),
      );
    } else if (isInserting) {
      context.missing(_verifiedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Territory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Territory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      ownerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_name'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      )!,
      wkt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wkt'],
      )!,
      areaM2: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}area_m2'],
      )!,
      geohash5: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}geohash5'],
      )!,
      refLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ref_lat'],
      )!,
      refLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ref_lng'],
      )!,
      claimedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}claimed_at'],
      )!,
      verified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}verified'],
      )!,
    );
  }

  @override
  $TerritoriesTable createAlias(String alias) {
    return $TerritoriesTable(attachedDatabase, alias);
  }
}

class Territory extends DataClass implements Insertable<Territory> {
  final String id;
  final String ownerId;
  final String ownerName;
  final String colorHex;

  /// Geographic WKT. Stored in degrees so it can be reloaded next to any other territory,
  /// whatever reference point that one was projected about.
  final String wkt;
  final double areaM2;
  final String geohash5;

  /// The run's projection origin. Kept so the exact metre frame can be reconstructed.
  final double refLat;
  final double refLng;
  final int claimedAt;
  final bool verified;
  const Territory({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.colorHex,
    required this.wkt,
    required this.areaM2,
    required this.geohash5,
    required this.refLat,
    required this.refLng,
    required this.claimedAt,
    required this.verified,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['owner_name'] = Variable<String>(ownerName);
    map['color_hex'] = Variable<String>(colorHex);
    map['wkt'] = Variable<String>(wkt);
    map['area_m2'] = Variable<double>(areaM2);
    map['geohash5'] = Variable<String>(geohash5);
    map['ref_lat'] = Variable<double>(refLat);
    map['ref_lng'] = Variable<double>(refLng);
    map['claimed_at'] = Variable<int>(claimedAt);
    map['verified'] = Variable<bool>(verified);
    return map;
  }

  TerritoriesCompanion toCompanion(bool nullToAbsent) {
    return TerritoriesCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      ownerName: Value(ownerName),
      colorHex: Value(colorHex),
      wkt: Value(wkt),
      areaM2: Value(areaM2),
      geohash5: Value(geohash5),
      refLat: Value(refLat),
      refLng: Value(refLng),
      claimedAt: Value(claimedAt),
      verified: Value(verified),
    );
  }

  factory Territory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Territory(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      ownerName: serializer.fromJson<String>(json['ownerName']),
      colorHex: serializer.fromJson<String>(json['colorHex']),
      wkt: serializer.fromJson<String>(json['wkt']),
      areaM2: serializer.fromJson<double>(json['areaM2']),
      geohash5: serializer.fromJson<String>(json['geohash5']),
      refLat: serializer.fromJson<double>(json['refLat']),
      refLng: serializer.fromJson<double>(json['refLng']),
      claimedAt: serializer.fromJson<int>(json['claimedAt']),
      verified: serializer.fromJson<bool>(json['verified']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'ownerName': serializer.toJson<String>(ownerName),
      'colorHex': serializer.toJson<String>(colorHex),
      'wkt': serializer.toJson<String>(wkt),
      'areaM2': serializer.toJson<double>(areaM2),
      'geohash5': serializer.toJson<String>(geohash5),
      'refLat': serializer.toJson<double>(refLat),
      'refLng': serializer.toJson<double>(refLng),
      'claimedAt': serializer.toJson<int>(claimedAt),
      'verified': serializer.toJson<bool>(verified),
    };
  }

  Territory copyWith({
    String? id,
    String? ownerId,
    String? ownerName,
    String? colorHex,
    String? wkt,
    double? areaM2,
    String? geohash5,
    double? refLat,
    double? refLng,
    int? claimedAt,
    bool? verified,
  }) => Territory(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    ownerName: ownerName ?? this.ownerName,
    colorHex: colorHex ?? this.colorHex,
    wkt: wkt ?? this.wkt,
    areaM2: areaM2 ?? this.areaM2,
    geohash5: geohash5 ?? this.geohash5,
    refLat: refLat ?? this.refLat,
    refLng: refLng ?? this.refLng,
    claimedAt: claimedAt ?? this.claimedAt,
    verified: verified ?? this.verified,
  );
  Territory copyWithCompanion(TerritoriesCompanion data) {
    return Territory(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      ownerName: data.ownerName.present ? data.ownerName.value : this.ownerName,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      wkt: data.wkt.present ? data.wkt.value : this.wkt,
      areaM2: data.areaM2.present ? data.areaM2.value : this.areaM2,
      geohash5: data.geohash5.present ? data.geohash5.value : this.geohash5,
      refLat: data.refLat.present ? data.refLat.value : this.refLat,
      refLng: data.refLng.present ? data.refLng.value : this.refLng,
      claimedAt: data.claimedAt.present ? data.claimedAt.value : this.claimedAt,
      verified: data.verified.present ? data.verified.value : this.verified,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Territory(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('ownerName: $ownerName, ')
          ..write('colorHex: $colorHex, ')
          ..write('wkt: $wkt, ')
          ..write('areaM2: $areaM2, ')
          ..write('geohash5: $geohash5, ')
          ..write('refLat: $refLat, ')
          ..write('refLng: $refLng, ')
          ..write('claimedAt: $claimedAt, ')
          ..write('verified: $verified')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    ownerName,
    colorHex,
    wkt,
    areaM2,
    geohash5,
    refLat,
    refLng,
    claimedAt,
    verified,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Territory &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.ownerName == this.ownerName &&
          other.colorHex == this.colorHex &&
          other.wkt == this.wkt &&
          other.areaM2 == this.areaM2 &&
          other.geohash5 == this.geohash5 &&
          other.refLat == this.refLat &&
          other.refLng == this.refLng &&
          other.claimedAt == this.claimedAt &&
          other.verified == this.verified);
}

class TerritoriesCompanion extends UpdateCompanion<Territory> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<String> ownerName;
  final Value<String> colorHex;
  final Value<String> wkt;
  final Value<double> areaM2;
  final Value<String> geohash5;
  final Value<double> refLat;
  final Value<double> refLng;
  final Value<int> claimedAt;
  final Value<bool> verified;
  final Value<int> rowid;
  const TerritoriesCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.ownerName = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.wkt = const Value.absent(),
    this.areaM2 = const Value.absent(),
    this.geohash5 = const Value.absent(),
    this.refLat = const Value.absent(),
    this.refLng = const Value.absent(),
    this.claimedAt = const Value.absent(),
    this.verified = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TerritoriesCompanion.insert({
    required String id,
    required String ownerId,
    required String ownerName,
    required String colorHex,
    required String wkt,
    required double areaM2,
    required String geohash5,
    required double refLat,
    required double refLng,
    required int claimedAt,
    required bool verified,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       ownerName = Value(ownerName),
       colorHex = Value(colorHex),
       wkt = Value(wkt),
       areaM2 = Value(areaM2),
       geohash5 = Value(geohash5),
       refLat = Value(refLat),
       refLng = Value(refLng),
       claimedAt = Value(claimedAt),
       verified = Value(verified);
  static Insertable<Territory> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<String>? ownerName,
    Expression<String>? colorHex,
    Expression<String>? wkt,
    Expression<double>? areaM2,
    Expression<String>? geohash5,
    Expression<double>? refLat,
    Expression<double>? refLng,
    Expression<int>? claimedAt,
    Expression<bool>? verified,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (ownerName != null) 'owner_name': ownerName,
      if (colorHex != null) 'color_hex': colorHex,
      if (wkt != null) 'wkt': wkt,
      if (areaM2 != null) 'area_m2': areaM2,
      if (geohash5 != null) 'geohash5': geohash5,
      if (refLat != null) 'ref_lat': refLat,
      if (refLng != null) 'ref_lng': refLng,
      if (claimedAt != null) 'claimed_at': claimedAt,
      if (verified != null) 'verified': verified,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TerritoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<String>? ownerName,
    Value<String>? colorHex,
    Value<String>? wkt,
    Value<double>? areaM2,
    Value<String>? geohash5,
    Value<double>? refLat,
    Value<double>? refLng,
    Value<int>? claimedAt,
    Value<bool>? verified,
    Value<int>? rowid,
  }) {
    return TerritoriesCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      colorHex: colorHex ?? this.colorHex,
      wkt: wkt ?? this.wkt,
      areaM2: areaM2 ?? this.areaM2,
      geohash5: geohash5 ?? this.geohash5,
      refLat: refLat ?? this.refLat,
      refLng: refLng ?? this.refLng,
      claimedAt: claimedAt ?? this.claimedAt,
      verified: verified ?? this.verified,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (ownerName.present) {
      map['owner_name'] = Variable<String>(ownerName.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (wkt.present) {
      map['wkt'] = Variable<String>(wkt.value);
    }
    if (areaM2.present) {
      map['area_m2'] = Variable<double>(areaM2.value);
    }
    if (geohash5.present) {
      map['geohash5'] = Variable<String>(geohash5.value);
    }
    if (refLat.present) {
      map['ref_lat'] = Variable<double>(refLat.value);
    }
    if (refLng.present) {
      map['ref_lng'] = Variable<double>(refLng.value);
    }
    if (claimedAt.present) {
      map['claimed_at'] = Variable<int>(claimedAt.value);
    }
    if (verified.present) {
      map['verified'] = Variable<bool>(verified.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TerritoriesCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('ownerName: $ownerName, ')
          ..write('colorHex: $colorHex, ')
          ..write('wkt: $wkt, ')
          ..write('areaM2: $areaM2, ')
          ..write('geohash5: $geohash5, ')
          ..write('refLat: $refLat, ')
          ..write('refLng: $refLng, ')
          ..write('claimedAt: $claimedAt, ')
          ..write('verified: $verified, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RunsTable extends Runs with TableInfo<$RunsTable, Run> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isPublicMeta = const VerificationMeta(
    'isPublic',
  );
  @override
  late final GeneratedColumn<bool> isPublic = GeneratedColumn<bool>(
    'is_public',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_public" IN (0, 1))',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _distanceMMeta = const VerificationMeta(
    'distanceM',
  );
  @override
  late final GeneratedColumn<double> distanceM = GeneratedColumn<double>(
    'distance_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stepsMeta = const VerificationMeta('steps');
  @override
  late final GeneratedColumn<int> steps = GeneratedColumn<int>(
    'steps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _elevationGainMMeta = const VerificationMeta(
    'elevationGainM',
  );
  @override
  late final GeneratedColumn<double> elevationGainM = GeneratedColumn<double>(
    'elevation_gain_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _areaM2Meta = const VerificationMeta('areaM2');
  @override
  late final GeneratedColumn<double> areaM2 = GeneratedColumn<double>(
    'area_m2',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _verifiedMeta = const VerificationMeta(
    'verified',
  );
  @override
  late final GeneratedColumn<bool> verified = GeneratedColumn<bool>(
    'verified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("verified" IN (0, 1))',
    ),
  );
  static const VerificationMeta _plausibleRatioMeta = const VerificationMeta(
    'plausibleRatio',
  );
  @override
  late final GeneratedColumn<double> plausibleRatio = GeneratedColumn<double>(
    'plausible_ratio',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _refLatMeta = const VerificationMeta('refLat');
  @override
  late final GeneratedColumn<double> refLat = GeneratedColumn<double>(
    'ref_lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _refLngMeta = const VerificationMeta('refLng');
  @override
  late final GeneratedColumn<double> refLng = GeneratedColumn<double>(
    'ref_lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encodedPathMeta = const VerificationMeta(
    'encodedPath',
  );
  @override
  late final GeneratedColumn<String> encodedPath = GeneratedColumn<String>(
    'encoded_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    isPublic,
    startedAt,
    durationMs,
    distanceM,
    steps,
    elevationGainM,
    areaM2,
    verified,
    plausibleRatio,
    refLat,
    refLng,
    encodedPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Run> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('is_public')) {
      context.handle(
        _isPublicMeta,
        isPublic.isAcceptableOrUnknown(data['is_public']!, _isPublicMeta),
      );
    } else if (isInserting) {
      context.missing(_isPublicMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('distance_m')) {
      context.handle(
        _distanceMMeta,
        distanceM.isAcceptableOrUnknown(data['distance_m']!, _distanceMMeta),
      );
    } else if (isInserting) {
      context.missing(_distanceMMeta);
    }
    if (data.containsKey('steps')) {
      context.handle(
        _stepsMeta,
        steps.isAcceptableOrUnknown(data['steps']!, _stepsMeta),
      );
    } else if (isInserting) {
      context.missing(_stepsMeta);
    }
    if (data.containsKey('elevation_gain_m')) {
      context.handle(
        _elevationGainMMeta,
        elevationGainM.isAcceptableOrUnknown(
          data['elevation_gain_m']!,
          _elevationGainMMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_elevationGainMMeta);
    }
    if (data.containsKey('area_m2')) {
      context.handle(
        _areaM2Meta,
        areaM2.isAcceptableOrUnknown(data['area_m2']!, _areaM2Meta),
      );
    } else if (isInserting) {
      context.missing(_areaM2Meta);
    }
    if (data.containsKey('verified')) {
      context.handle(
        _verifiedMeta,
        verified.isAcceptableOrUnknown(data['verified']!, _verifiedMeta),
      );
    } else if (isInserting) {
      context.missing(_verifiedMeta);
    }
    if (data.containsKey('plausible_ratio')) {
      context.handle(
        _plausibleRatioMeta,
        plausibleRatio.isAcceptableOrUnknown(
          data['plausible_ratio']!,
          _plausibleRatioMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_plausibleRatioMeta);
    }
    if (data.containsKey('ref_lat')) {
      context.handle(
        _refLatMeta,
        refLat.isAcceptableOrUnknown(data['ref_lat']!, _refLatMeta),
      );
    } else if (isInserting) {
      context.missing(_refLatMeta);
    }
    if (data.containsKey('ref_lng')) {
      context.handle(
        _refLngMeta,
        refLng.isAcceptableOrUnknown(data['ref_lng']!, _refLngMeta),
      );
    } else if (isInserting) {
      context.missing(_refLngMeta);
    }
    if (data.containsKey('encoded_path')) {
      context.handle(
        _encodedPathMeta,
        encodedPath.isAcceptableOrUnknown(
          data['encoded_path']!,
          _encodedPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encodedPathMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Run map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Run(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      isPublic: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_public'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      distanceM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance_m'],
      )!,
      steps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}steps'],
      )!,
      elevationGainM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}elevation_gain_m'],
      )!,
      areaM2: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}area_m2'],
      )!,
      verified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}verified'],
      )!,
      plausibleRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}plausible_ratio'],
      )!,
      refLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ref_lat'],
      )!,
      refLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ref_lng'],
      )!,
      encodedPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encoded_path'],
      )!,
    );
  }

  @override
  $RunsTable createAlias(String alias) {
    return $RunsTable(attachedDatabase, alias);
  }
}

class Run extends DataClass implements Insertable<Run> {
  final String id;
  final String title;
  final bool isPublic;
  final int startedAt;
  final int durationMs;
  final double distanceM;
  final int steps;
  final double elevationGainM;
  final double areaM2;
  final bool verified;
  final double plausibleRatio;
  final double refLat;
  final double refLng;

  /// "lat,lng;lat,lng;..." — one column, no join table for a few hundred points.
  final String encodedPath;
  const Run({
    required this.id,
    required this.title,
    required this.isPublic,
    required this.startedAt,
    required this.durationMs,
    required this.distanceM,
    required this.steps,
    required this.elevationGainM,
    required this.areaM2,
    required this.verified,
    required this.plausibleRatio,
    required this.refLat,
    required this.refLng,
    required this.encodedPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['is_public'] = Variable<bool>(isPublic);
    map['started_at'] = Variable<int>(startedAt);
    map['duration_ms'] = Variable<int>(durationMs);
    map['distance_m'] = Variable<double>(distanceM);
    map['steps'] = Variable<int>(steps);
    map['elevation_gain_m'] = Variable<double>(elevationGainM);
    map['area_m2'] = Variable<double>(areaM2);
    map['verified'] = Variable<bool>(verified);
    map['plausible_ratio'] = Variable<double>(plausibleRatio);
    map['ref_lat'] = Variable<double>(refLat);
    map['ref_lng'] = Variable<double>(refLng);
    map['encoded_path'] = Variable<String>(encodedPath);
    return map;
  }

  RunsCompanion toCompanion(bool nullToAbsent) {
    return RunsCompanion(
      id: Value(id),
      title: Value(title),
      isPublic: Value(isPublic),
      startedAt: Value(startedAt),
      durationMs: Value(durationMs),
      distanceM: Value(distanceM),
      steps: Value(steps),
      elevationGainM: Value(elevationGainM),
      areaM2: Value(areaM2),
      verified: Value(verified),
      plausibleRatio: Value(plausibleRatio),
      refLat: Value(refLat),
      refLng: Value(refLng),
      encodedPath: Value(encodedPath),
    );
  }

  factory Run.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Run(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      isPublic: serializer.fromJson<bool>(json['isPublic']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      distanceM: serializer.fromJson<double>(json['distanceM']),
      steps: serializer.fromJson<int>(json['steps']),
      elevationGainM: serializer.fromJson<double>(json['elevationGainM']),
      areaM2: serializer.fromJson<double>(json['areaM2']),
      verified: serializer.fromJson<bool>(json['verified']),
      plausibleRatio: serializer.fromJson<double>(json['plausibleRatio']),
      refLat: serializer.fromJson<double>(json['refLat']),
      refLng: serializer.fromJson<double>(json['refLng']),
      encodedPath: serializer.fromJson<String>(json['encodedPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'isPublic': serializer.toJson<bool>(isPublic),
      'startedAt': serializer.toJson<int>(startedAt),
      'durationMs': serializer.toJson<int>(durationMs),
      'distanceM': serializer.toJson<double>(distanceM),
      'steps': serializer.toJson<int>(steps),
      'elevationGainM': serializer.toJson<double>(elevationGainM),
      'areaM2': serializer.toJson<double>(areaM2),
      'verified': serializer.toJson<bool>(verified),
      'plausibleRatio': serializer.toJson<double>(plausibleRatio),
      'refLat': serializer.toJson<double>(refLat),
      'refLng': serializer.toJson<double>(refLng),
      'encodedPath': serializer.toJson<String>(encodedPath),
    };
  }

  Run copyWith({
    String? id,
    String? title,
    bool? isPublic,
    int? startedAt,
    int? durationMs,
    double? distanceM,
    int? steps,
    double? elevationGainM,
    double? areaM2,
    bool? verified,
    double? plausibleRatio,
    double? refLat,
    double? refLng,
    String? encodedPath,
  }) => Run(
    id: id ?? this.id,
    title: title ?? this.title,
    isPublic: isPublic ?? this.isPublic,
    startedAt: startedAt ?? this.startedAt,
    durationMs: durationMs ?? this.durationMs,
    distanceM: distanceM ?? this.distanceM,
    steps: steps ?? this.steps,
    elevationGainM: elevationGainM ?? this.elevationGainM,
    areaM2: areaM2 ?? this.areaM2,
    verified: verified ?? this.verified,
    plausibleRatio: plausibleRatio ?? this.plausibleRatio,
    refLat: refLat ?? this.refLat,
    refLng: refLng ?? this.refLng,
    encodedPath: encodedPath ?? this.encodedPath,
  );
  Run copyWithCompanion(RunsCompanion data) {
    return Run(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      isPublic: data.isPublic.present ? data.isPublic.value : this.isPublic,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      distanceM: data.distanceM.present ? data.distanceM.value : this.distanceM,
      steps: data.steps.present ? data.steps.value : this.steps,
      elevationGainM: data.elevationGainM.present
          ? data.elevationGainM.value
          : this.elevationGainM,
      areaM2: data.areaM2.present ? data.areaM2.value : this.areaM2,
      verified: data.verified.present ? data.verified.value : this.verified,
      plausibleRatio: data.plausibleRatio.present
          ? data.plausibleRatio.value
          : this.plausibleRatio,
      refLat: data.refLat.present ? data.refLat.value : this.refLat,
      refLng: data.refLng.present ? data.refLng.value : this.refLng,
      encodedPath: data.encodedPath.present
          ? data.encodedPath.value
          : this.encodedPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Run(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('isPublic: $isPublic, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('distanceM: $distanceM, ')
          ..write('steps: $steps, ')
          ..write('elevationGainM: $elevationGainM, ')
          ..write('areaM2: $areaM2, ')
          ..write('verified: $verified, ')
          ..write('plausibleRatio: $plausibleRatio, ')
          ..write('refLat: $refLat, ')
          ..write('refLng: $refLng, ')
          ..write('encodedPath: $encodedPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    isPublic,
    startedAt,
    durationMs,
    distanceM,
    steps,
    elevationGainM,
    areaM2,
    verified,
    plausibleRatio,
    refLat,
    refLng,
    encodedPath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Run &&
          other.id == this.id &&
          other.title == this.title &&
          other.isPublic == this.isPublic &&
          other.startedAt == this.startedAt &&
          other.durationMs == this.durationMs &&
          other.distanceM == this.distanceM &&
          other.steps == this.steps &&
          other.elevationGainM == this.elevationGainM &&
          other.areaM2 == this.areaM2 &&
          other.verified == this.verified &&
          other.plausibleRatio == this.plausibleRatio &&
          other.refLat == this.refLat &&
          other.refLng == this.refLng &&
          other.encodedPath == this.encodedPath);
}

class RunsCompanion extends UpdateCompanion<Run> {
  final Value<String> id;
  final Value<String> title;
  final Value<bool> isPublic;
  final Value<int> startedAt;
  final Value<int> durationMs;
  final Value<double> distanceM;
  final Value<int> steps;
  final Value<double> elevationGainM;
  final Value<double> areaM2;
  final Value<bool> verified;
  final Value<double> plausibleRatio;
  final Value<double> refLat;
  final Value<double> refLng;
  final Value<String> encodedPath;
  final Value<int> rowid;
  const RunsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.isPublic = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.distanceM = const Value.absent(),
    this.steps = const Value.absent(),
    this.elevationGainM = const Value.absent(),
    this.areaM2 = const Value.absent(),
    this.verified = const Value.absent(),
    this.plausibleRatio = const Value.absent(),
    this.refLat = const Value.absent(),
    this.refLng = const Value.absent(),
    this.encodedPath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RunsCompanion.insert({
    required String id,
    required String title,
    required bool isPublic,
    required int startedAt,
    required int durationMs,
    required double distanceM,
    required int steps,
    required double elevationGainM,
    required double areaM2,
    required bool verified,
    required double plausibleRatio,
    required double refLat,
    required double refLng,
    required String encodedPath,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       isPublic = Value(isPublic),
       startedAt = Value(startedAt),
       durationMs = Value(durationMs),
       distanceM = Value(distanceM),
       steps = Value(steps),
       elevationGainM = Value(elevationGainM),
       areaM2 = Value(areaM2),
       verified = Value(verified),
       plausibleRatio = Value(plausibleRatio),
       refLat = Value(refLat),
       refLng = Value(refLng),
       encodedPath = Value(encodedPath);
  static Insertable<Run> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<bool>? isPublic,
    Expression<int>? startedAt,
    Expression<int>? durationMs,
    Expression<double>? distanceM,
    Expression<int>? steps,
    Expression<double>? elevationGainM,
    Expression<double>? areaM2,
    Expression<bool>? verified,
    Expression<double>? plausibleRatio,
    Expression<double>? refLat,
    Expression<double>? refLng,
    Expression<String>? encodedPath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (isPublic != null) 'is_public': isPublic,
      if (startedAt != null) 'started_at': startedAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (distanceM != null) 'distance_m': distanceM,
      if (steps != null) 'steps': steps,
      if (elevationGainM != null) 'elevation_gain_m': elevationGainM,
      if (areaM2 != null) 'area_m2': areaM2,
      if (verified != null) 'verified': verified,
      if (plausibleRatio != null) 'plausible_ratio': plausibleRatio,
      if (refLat != null) 'ref_lat': refLat,
      if (refLng != null) 'ref_lng': refLng,
      if (encodedPath != null) 'encoded_path': encodedPath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RunsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<bool>? isPublic,
    Value<int>? startedAt,
    Value<int>? durationMs,
    Value<double>? distanceM,
    Value<int>? steps,
    Value<double>? elevationGainM,
    Value<double>? areaM2,
    Value<bool>? verified,
    Value<double>? plausibleRatio,
    Value<double>? refLat,
    Value<double>? refLng,
    Value<String>? encodedPath,
    Value<int>? rowid,
  }) {
    return RunsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      isPublic: isPublic ?? this.isPublic,
      startedAt: startedAt ?? this.startedAt,
      durationMs: durationMs ?? this.durationMs,
      distanceM: distanceM ?? this.distanceM,
      steps: steps ?? this.steps,
      elevationGainM: elevationGainM ?? this.elevationGainM,
      areaM2: areaM2 ?? this.areaM2,
      verified: verified ?? this.verified,
      plausibleRatio: plausibleRatio ?? this.plausibleRatio,
      refLat: refLat ?? this.refLat,
      refLng: refLng ?? this.refLng,
      encodedPath: encodedPath ?? this.encodedPath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (isPublic.present) {
      map['is_public'] = Variable<bool>(isPublic.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (distanceM.present) {
      map['distance_m'] = Variable<double>(distanceM.value);
    }
    if (steps.present) {
      map['steps'] = Variable<int>(steps.value);
    }
    if (elevationGainM.present) {
      map['elevation_gain_m'] = Variable<double>(elevationGainM.value);
    }
    if (areaM2.present) {
      map['area_m2'] = Variable<double>(areaM2.value);
    }
    if (verified.present) {
      map['verified'] = Variable<bool>(verified.value);
    }
    if (plausibleRatio.present) {
      map['plausible_ratio'] = Variable<double>(plausibleRatio.value);
    }
    if (refLat.present) {
      map['ref_lat'] = Variable<double>(refLat.value);
    }
    if (refLng.present) {
      map['ref_lng'] = Variable<double>(refLng.value);
    }
    if (encodedPath.present) {
      map['encoded_path'] = Variable<String>(encodedPath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RunsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('isPublic: $isPublic, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('distanceM: $distanceM, ')
          ..write('steps: $steps, ')
          ..write('elevationGainM: $elevationGainM, ')
          ..write('areaM2: $areaM2, ')
          ..write('verified: $verified, ')
          ..write('plausibleRatio: $plausibleRatio, ')
          ..write('refLat: $refLat, ')
          ..write('refLng: $refLng, ')
          ..write('encodedPath: $encodedPath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrailsTable extends Trails with TableInfo<$TrailsTable, Trail> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrailsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lengthMMeta = const VerificationMeta(
    'lengthM',
  );
  @override
  late final GeneratedColumn<double> lengthM = GeneratedColumn<double>(
    'length_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encodedPathMeta = const VerificationMeta(
    'encodedPath',
  );
  @override
  late final GeneratedColumn<String> encodedPath = GeneratedColumn<String>(
    'encoded_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _geohash5Meta = const VerificationMeta(
    'geohash5',
  );
  @override
  late final GeneratedColumn<String> geohash5 = GeneratedColumn<String>(
    'geohash5',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<int> cachedAt = GeneratedColumn<int>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    kind,
    lengthM,
    encodedPath,
    geohash5,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trails';
  @override
  VerificationContext validateIntegrity(
    Insertable<Trail> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('length_m')) {
      context.handle(
        _lengthMMeta,
        lengthM.isAcceptableOrUnknown(data['length_m']!, _lengthMMeta),
      );
    } else if (isInserting) {
      context.missing(_lengthMMeta);
    }
    if (data.containsKey('encoded_path')) {
      context.handle(
        _encodedPathMeta,
        encodedPath.isAcceptableOrUnknown(
          data['encoded_path']!,
          _encodedPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encodedPathMeta);
    }
    if (data.containsKey('geohash5')) {
      context.handle(
        _geohash5Meta,
        geohash5.isAcceptableOrUnknown(data['geohash5']!, _geohash5Meta),
      );
    } else if (isInserting) {
      context.missing(_geohash5Meta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Trail map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Trail(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      lengthM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}length_m'],
      )!,
      encodedPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encoded_path'],
      )!,
      geohash5: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}geohash5'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $TrailsTable createAlias(String alias) {
    return $TrailsTable(attachedDatabase, alias);
  }
}

class Trail extends DataClass implements Insertable<Trail> {
  final String id;
  final String name;
  final String kind;
  final double lengthM;
  final String encodedPath;
  final String geohash5;
  final int cachedAt;
  const Trail({
    required this.id,
    required this.name,
    required this.kind,
    required this.lengthM,
    required this.encodedPath,
    required this.geohash5,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    map['length_m'] = Variable<double>(lengthM);
    map['encoded_path'] = Variable<String>(encodedPath);
    map['geohash5'] = Variable<String>(geohash5);
    map['cached_at'] = Variable<int>(cachedAt);
    return map;
  }

  TrailsCompanion toCompanion(bool nullToAbsent) {
    return TrailsCompanion(
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      lengthM: Value(lengthM),
      encodedPath: Value(encodedPath),
      geohash5: Value(geohash5),
      cachedAt: Value(cachedAt),
    );
  }

  factory Trail.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Trail(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      lengthM: serializer.fromJson<double>(json['lengthM']),
      encodedPath: serializer.fromJson<String>(json['encodedPath']),
      geohash5: serializer.fromJson<String>(json['geohash5']),
      cachedAt: serializer.fromJson<int>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'lengthM': serializer.toJson<double>(lengthM),
      'encodedPath': serializer.toJson<String>(encodedPath),
      'geohash5': serializer.toJson<String>(geohash5),
      'cachedAt': serializer.toJson<int>(cachedAt),
    };
  }

  Trail copyWith({
    String? id,
    String? name,
    String? kind,
    double? lengthM,
    String? encodedPath,
    String? geohash5,
    int? cachedAt,
  }) => Trail(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    lengthM: lengthM ?? this.lengthM,
    encodedPath: encodedPath ?? this.encodedPath,
    geohash5: geohash5 ?? this.geohash5,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  Trail copyWithCompanion(TrailsCompanion data) {
    return Trail(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      lengthM: data.lengthM.present ? data.lengthM.value : this.lengthM,
      encodedPath: data.encodedPath.present
          ? data.encodedPath.value
          : this.encodedPath,
      geohash5: data.geohash5.present ? data.geohash5.value : this.geohash5,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Trail(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('lengthM: $lengthM, ')
          ..write('encodedPath: $encodedPath, ')
          ..write('geohash5: $geohash5, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, kind, lengthM, encodedPath, geohash5, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Trail &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.lengthM == this.lengthM &&
          other.encodedPath == this.encodedPath &&
          other.geohash5 == this.geohash5 &&
          other.cachedAt == this.cachedAt);
}

class TrailsCompanion extends UpdateCompanion<Trail> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> kind;
  final Value<double> lengthM;
  final Value<String> encodedPath;
  final Value<String> geohash5;
  final Value<int> cachedAt;
  final Value<int> rowid;
  const TrailsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.lengthM = const Value.absent(),
    this.encodedPath = const Value.absent(),
    this.geohash5 = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrailsCompanion.insert({
    required String id,
    required String name,
    required String kind,
    required double lengthM,
    required String encodedPath,
    required String geohash5,
    required int cachedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       kind = Value(kind),
       lengthM = Value(lengthM),
       encodedPath = Value(encodedPath),
       geohash5 = Value(geohash5),
       cachedAt = Value(cachedAt);
  static Insertable<Trail> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<double>? lengthM,
    Expression<String>? encodedPath,
    Expression<String>? geohash5,
    Expression<int>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (lengthM != null) 'length_m': lengthM,
      if (encodedPath != null) 'encoded_path': encodedPath,
      if (geohash5 != null) 'geohash5': geohash5,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrailsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? kind,
    Value<double>? lengthM,
    Value<String>? encodedPath,
    Value<String>? geohash5,
    Value<int>? cachedAt,
    Value<int>? rowid,
  }) {
    return TrailsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      lengthM: lengthM ?? this.lengthM,
      encodedPath: encodedPath ?? this.encodedPath,
      geohash5: geohash5 ?? this.geohash5,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (lengthM.present) {
      map['length_m'] = Variable<double>(lengthM.value);
    }
    if (encodedPath.present) {
      map['encoded_path'] = Variable<String>(encodedPath.value);
    }
    if (geohash5.present) {
      map['geohash5'] = Variable<String>(geohash5.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<int>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrailsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('lengthM: $lengthM, ')
          ..write('encodedPath: $encodedPath, ')
          ..write('geohash5: $geohash5, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrailCellsTable extends TrailCells
    with TableInfo<$TrailCellsTable, TrailCell> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrailCellsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _geohash5Meta = const VerificationMeta(
    'geohash5',
  );
  @override
  late final GeneratedColumn<String> geohash5 = GeneratedColumn<String>(
    'geohash5',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<int> fetchedAt = GeneratedColumn<int>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [geohash5, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trail_cells';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrailCell> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('geohash5')) {
      context.handle(
        _geohash5Meta,
        geohash5.isAcceptableOrUnknown(data['geohash5']!, _geohash5Meta),
      );
    } else if (isInserting) {
      context.missing(_geohash5Meta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {geohash5};
  @override
  TrailCell map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrailCell(
      geohash5: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}geohash5'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $TrailCellsTable createAlias(String alias) {
    return $TrailCellsTable(attachedDatabase, alias);
  }
}

class TrailCell extends DataClass implements Insertable<TrailCell> {
  final String geohash5;
  final int fetchedAt;
  const TrailCell({required this.geohash5, required this.fetchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['geohash5'] = Variable<String>(geohash5);
    map['fetched_at'] = Variable<int>(fetchedAt);
    return map;
  }

  TrailCellsCompanion toCompanion(bool nullToAbsent) {
    return TrailCellsCompanion(
      geohash5: Value(geohash5),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory TrailCell.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrailCell(
      geohash5: serializer.fromJson<String>(json['geohash5']),
      fetchedAt: serializer.fromJson<int>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'geohash5': serializer.toJson<String>(geohash5),
      'fetchedAt': serializer.toJson<int>(fetchedAt),
    };
  }

  TrailCell copyWith({String? geohash5, int? fetchedAt}) => TrailCell(
    geohash5: geohash5 ?? this.geohash5,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  TrailCell copyWithCompanion(TrailCellsCompanion data) {
    return TrailCell(
      geohash5: data.geohash5.present ? data.geohash5.value : this.geohash5,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrailCell(')
          ..write('geohash5: $geohash5, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(geohash5, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrailCell &&
          other.geohash5 == this.geohash5 &&
          other.fetchedAt == this.fetchedAt);
}

class TrailCellsCompanion extends UpdateCompanion<TrailCell> {
  final Value<String> geohash5;
  final Value<int> fetchedAt;
  final Value<int> rowid;
  const TrailCellsCompanion({
    this.geohash5 = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrailCellsCompanion.insert({
    required String geohash5,
    required int fetchedAt,
    this.rowid = const Value.absent(),
  }) : geohash5 = Value(geohash5),
       fetchedAt = Value(fetchedAt);
  static Insertable<TrailCell> custom({
    Expression<String>? geohash5,
    Expression<int>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (geohash5 != null) 'geohash5': geohash5,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrailCellsCompanion copyWith({
    Value<String>? geohash5,
    Value<int>? fetchedAt,
    Value<int>? rowid,
  }) {
    return TrailCellsCompanion(
      geohash5: geohash5 ?? this.geohash5,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (geohash5.present) {
      map['geohash5'] = Variable<String>(geohash5.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrailCellsCompanion(')
          ..write('geohash5: $geohash5, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ClaimTrekDatabase extends GeneratedDatabase {
  _$ClaimTrekDatabase(QueryExecutor e) : super(e);
  $ClaimTrekDatabaseManager get managers => $ClaimTrekDatabaseManager(this);
  late final $TerritoriesTable territories = $TerritoriesTable(this);
  late final $RunsTable runs = $RunsTable(this);
  late final $TrailsTable trails = $TrailsTable(this);
  late final $TrailCellsTable trailCells = $TrailCellsTable(this);
  late final Index territoriesGeohash5 = Index(
    'territories_geohash5',
    'CREATE INDEX territories_geohash5 ON territories (geohash5)',
  );
  late final Index territoriesOwner = Index(
    'territories_owner',
    'CREATE INDEX territories_owner ON territories (owner_id)',
  );
  late final Index trailsGeohash5 = Index(
    'trails_geohash5',
    'CREATE INDEX trails_geohash5 ON trails (geohash5)',
  );
  late final TerritoryDao territoryDao = TerritoryDao(
    this as ClaimTrekDatabase,
  );
  late final RunDao runDao = RunDao(this as ClaimTrekDatabase);
  late final TrailDao trailDao = TrailDao(this as ClaimTrekDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    territories,
    runs,
    trails,
    trailCells,
    territoriesGeohash5,
    territoriesOwner,
    trailsGeohash5,
  ];
}

typedef $$TerritoriesTableCreateCompanionBuilder =
    TerritoriesCompanion Function({
      required String id,
      required String ownerId,
      required String ownerName,
      required String colorHex,
      required String wkt,
      required double areaM2,
      required String geohash5,
      required double refLat,
      required double refLng,
      required int claimedAt,
      required bool verified,
      Value<int> rowid,
    });
typedef $$TerritoriesTableUpdateCompanionBuilder =
    TerritoriesCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<String> ownerName,
      Value<String> colorHex,
      Value<String> wkt,
      Value<double> areaM2,
      Value<String> geohash5,
      Value<double> refLat,
      Value<double> refLng,
      Value<int> claimedAt,
      Value<bool> verified,
      Value<int> rowid,
    });

class $$TerritoriesTableFilterComposer
    extends Composer<_$ClaimTrekDatabase, $TerritoriesTable> {
  $$TerritoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerName => $composableBuilder(
    column: $table.ownerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wkt => $composableBuilder(
    column: $table.wkt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get areaM2 => $composableBuilder(
    column: $table.areaM2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get geohash5 => $composableBuilder(
    column: $table.geohash5,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get refLat => $composableBuilder(
    column: $table.refLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get refLng => $composableBuilder(
    column: $table.refLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get claimedAt => $composableBuilder(
    column: $table.claimedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get verified => $composableBuilder(
    column: $table.verified,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TerritoriesTableOrderingComposer
    extends Composer<_$ClaimTrekDatabase, $TerritoriesTable> {
  $$TerritoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerName => $composableBuilder(
    column: $table.ownerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wkt => $composableBuilder(
    column: $table.wkt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get areaM2 => $composableBuilder(
    column: $table.areaM2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get geohash5 => $composableBuilder(
    column: $table.geohash5,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get refLat => $composableBuilder(
    column: $table.refLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get refLng => $composableBuilder(
    column: $table.refLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get claimedAt => $composableBuilder(
    column: $table.claimedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get verified => $composableBuilder(
    column: $table.verified,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TerritoriesTableAnnotationComposer
    extends Composer<_$ClaimTrekDatabase, $TerritoriesTable> {
  $$TerritoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get ownerName =>
      $composableBuilder(column: $table.ownerName, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<String> get wkt =>
      $composableBuilder(column: $table.wkt, builder: (column) => column);

  GeneratedColumn<double> get areaM2 =>
      $composableBuilder(column: $table.areaM2, builder: (column) => column);

  GeneratedColumn<String> get geohash5 =>
      $composableBuilder(column: $table.geohash5, builder: (column) => column);

  GeneratedColumn<double> get refLat =>
      $composableBuilder(column: $table.refLat, builder: (column) => column);

  GeneratedColumn<double> get refLng =>
      $composableBuilder(column: $table.refLng, builder: (column) => column);

  GeneratedColumn<int> get claimedAt =>
      $composableBuilder(column: $table.claimedAt, builder: (column) => column);

  GeneratedColumn<bool> get verified =>
      $composableBuilder(column: $table.verified, builder: (column) => column);
}

class $$TerritoriesTableTableManager
    extends
        RootTableManager<
          _$ClaimTrekDatabase,
          $TerritoriesTable,
          Territory,
          $$TerritoriesTableFilterComposer,
          $$TerritoriesTableOrderingComposer,
          $$TerritoriesTableAnnotationComposer,
          $$TerritoriesTableCreateCompanionBuilder,
          $$TerritoriesTableUpdateCompanionBuilder,
          (
            Territory,
            BaseReferences<_$ClaimTrekDatabase, $TerritoriesTable, Territory>,
          ),
          Territory,
          PrefetchHooks Function()
        > {
  $$TerritoriesTableTableManager(
    _$ClaimTrekDatabase db,
    $TerritoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TerritoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TerritoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TerritoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> ownerName = const Value.absent(),
                Value<String> colorHex = const Value.absent(),
                Value<String> wkt = const Value.absent(),
                Value<double> areaM2 = const Value.absent(),
                Value<String> geohash5 = const Value.absent(),
                Value<double> refLat = const Value.absent(),
                Value<double> refLng = const Value.absent(),
                Value<int> claimedAt = const Value.absent(),
                Value<bool> verified = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TerritoriesCompanion(
                id: id,
                ownerId: ownerId,
                ownerName: ownerName,
                colorHex: colorHex,
                wkt: wkt,
                areaM2: areaM2,
                geohash5: geohash5,
                refLat: refLat,
                refLng: refLng,
                claimedAt: claimedAt,
                verified: verified,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                required String ownerName,
                required String colorHex,
                required String wkt,
                required double areaM2,
                required String geohash5,
                required double refLat,
                required double refLng,
                required int claimedAt,
                required bool verified,
                Value<int> rowid = const Value.absent(),
              }) => TerritoriesCompanion.insert(
                id: id,
                ownerId: ownerId,
                ownerName: ownerName,
                colorHex: colorHex,
                wkt: wkt,
                areaM2: areaM2,
                geohash5: geohash5,
                refLat: refLat,
                refLng: refLng,
                claimedAt: claimedAt,
                verified: verified,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TerritoriesTable, Territory>(table),
                  BaseReferences<
                    _$ClaimTrekDatabase,
                    $TerritoriesTable,
                    Territory
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TerritoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$ClaimTrekDatabase,
      $TerritoriesTable,
      Territory,
      $$TerritoriesTableFilterComposer,
      $$TerritoriesTableOrderingComposer,
      $$TerritoriesTableAnnotationComposer,
      $$TerritoriesTableCreateCompanionBuilder,
      $$TerritoriesTableUpdateCompanionBuilder,
      (
        Territory,
        BaseReferences<_$ClaimTrekDatabase, $TerritoriesTable, Territory>,
      ),
      Territory,
      PrefetchHooks Function()
    >;
typedef $$RunsTableCreateCompanionBuilder = RunsCompanion Function({
  required String id,
  required String title,
  required bool isPublic,
  required int startedAt,
  required int durationMs,
  required double distanceM,
  required int steps,
  required double elevationGainM,
  required double areaM2,
  required bool verified,
  required double plausibleRatio,
  required double refLat,
  required double refLng,
  required String encodedPath,
  Value<int> rowid,
});
typedef $$RunsTableUpdateCompanionBuilder = RunsCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<bool> isPublic,
  Value<int> startedAt,
  Value<int> durationMs,
  Value<double> distanceM,
  Value<int> steps,
  Value<double> elevationGainM,
  Value<double> areaM2,
  Value<bool> verified,
  Value<double> plausibleRatio,
  Value<double> refLat,
  Value<double> refLng,
  Value<String> encodedPath,
  Value<int> rowid,
});

class $$RunsTableFilterComposer
    extends Composer<_$ClaimTrekDatabase, $RunsTable> {
  $$RunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPublic => $composableBuilder(
    column: $table.isPublic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get elevationGainM => $composableBuilder(
    column: $table.elevationGainM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get areaM2 => $composableBuilder(
    column: $table.areaM2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get verified => $composableBuilder(
    column: $table.verified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get plausibleRatio => $composableBuilder(
    column: $table.plausibleRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get refLat => $composableBuilder(
    column: $table.refLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get refLng => $composableBuilder(
    column: $table.refLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encodedPath => $composableBuilder(
    column: $table.encodedPath,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RunsTableOrderingComposer
    extends Composer<_$ClaimTrekDatabase, $RunsTable> {
  $$RunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPublic => $composableBuilder(
    column: $table.isPublic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get elevationGainM => $composableBuilder(
    column: $table.elevationGainM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get areaM2 => $composableBuilder(
    column: $table.areaM2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get verified => $composableBuilder(
    column: $table.verified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get plausibleRatio => $composableBuilder(
    column: $table.plausibleRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get refLat => $composableBuilder(
    column: $table.refLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get refLng => $composableBuilder(
    column: $table.refLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encodedPath => $composableBuilder(
    column: $table.encodedPath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RunsTableAnnotationComposer
    extends Composer<_$ClaimTrekDatabase, $RunsTable> {
  $$RunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<bool> get isPublic =>
      $composableBuilder(column: $table.isPublic, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<double> get distanceM =>
      $composableBuilder(column: $table.distanceM, builder: (column) => column);

  GeneratedColumn<int> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);

  GeneratedColumn<double> get elevationGainM => $composableBuilder(
    column: $table.elevationGainM,
    builder: (column) => column,
  );

  GeneratedColumn<double> get areaM2 =>
      $composableBuilder(column: $table.areaM2, builder: (column) => column);

  GeneratedColumn<bool> get verified =>
      $composableBuilder(column: $table.verified, builder: (column) => column);

  GeneratedColumn<double> get plausibleRatio => $composableBuilder(
    column: $table.plausibleRatio,
    builder: (column) => column,
  );

  GeneratedColumn<double> get refLat =>
      $composableBuilder(column: $table.refLat, builder: (column) => column);

  GeneratedColumn<double> get refLng =>
      $composableBuilder(column: $table.refLng, builder: (column) => column);

  GeneratedColumn<String> get encodedPath => $composableBuilder(
    column: $table.encodedPath,
    builder: (column) => column,
  );
}

class $$RunsTableTableManager
    extends
        RootTableManager<
          _$ClaimTrekDatabase,
          $RunsTable,
          Run,
          $$RunsTableFilterComposer,
          $$RunsTableOrderingComposer,
          $$RunsTableAnnotationComposer,
          $$RunsTableCreateCompanionBuilder,
          $$RunsTableUpdateCompanionBuilder,
          (Run, BaseReferences<_$ClaimTrekDatabase, $RunsTable, Run>),
          Run,
          PrefetchHooks Function()
        > {
  $$RunsTableTableManager(_$ClaimTrekDatabase db, $RunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<bool> isPublic = const Value.absent(),
                Value<int> startedAt = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<double> distanceM = const Value.absent(),
                Value<int> steps = const Value.absent(),
                Value<double> elevationGainM = const Value.absent(),
                Value<double> areaM2 = const Value.absent(),
                Value<bool> verified = const Value.absent(),
                Value<double> plausibleRatio = const Value.absent(),
                Value<double> refLat = const Value.absent(),
                Value<double> refLng = const Value.absent(),
                Value<String> encodedPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunsCompanion(
                id: id,
                title: title,
                isPublic: isPublic,
                startedAt: startedAt,
                durationMs: durationMs,
                distanceM: distanceM,
                steps: steps,
                elevationGainM: elevationGainM,
                areaM2: areaM2,
                verified: verified,
                plausibleRatio: plausibleRatio,
                refLat: refLat,
                refLng: refLng,
                encodedPath: encodedPath,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required bool isPublic,
                required int startedAt,
                required int durationMs,
                required double distanceM,
                required int steps,
                required double elevationGainM,
                required double areaM2,
                required bool verified,
                required double plausibleRatio,
                required double refLat,
                required double refLng,
                required String encodedPath,
                Value<int> rowid = const Value.absent(),
              }) => RunsCompanion.insert(
                id: id,
                title: title,
                isPublic: isPublic,
                startedAt: startedAt,
                durationMs: durationMs,
                distanceM: distanceM,
                steps: steps,
                elevationGainM: elevationGainM,
                areaM2: areaM2,
                verified: verified,
                plausibleRatio: plausibleRatio,
                refLat: refLat,
                refLng: refLng,
                encodedPath: encodedPath,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RunsTable, Run>(table),
                  BaseReferences<_$ClaimTrekDatabase, $RunsTable, Run>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RunsTableProcessedTableManager =
    ProcessedTableManager<
      _$ClaimTrekDatabase,
      $RunsTable,
      Run,
      $$RunsTableFilterComposer,
      $$RunsTableOrderingComposer,
      $$RunsTableAnnotationComposer,
      $$RunsTableCreateCompanionBuilder,
      $$RunsTableUpdateCompanionBuilder,
      (Run, BaseReferences<_$ClaimTrekDatabase, $RunsTable, Run>),
      Run,
      PrefetchHooks Function()
    >;
typedef $$TrailsTableCreateCompanionBuilder = TrailsCompanion Function({
  required String id,
  required String name,
  required String kind,
  required double lengthM,
  required String encodedPath,
  required String geohash5,
  required int cachedAt,
  Value<int> rowid,
});
typedef $$TrailsTableUpdateCompanionBuilder = TrailsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> kind,
  Value<double> lengthM,
  Value<String> encodedPath,
  Value<String> geohash5,
  Value<int> cachedAt,
  Value<int> rowid,
});

class $$TrailsTableFilterComposer
    extends Composer<_$ClaimTrekDatabase, $TrailsTable> {
  $$TrailsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lengthM => $composableBuilder(
    column: $table.lengthM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encodedPath => $composableBuilder(
    column: $table.encodedPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get geohash5 => $composableBuilder(
    column: $table.geohash5,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrailsTableOrderingComposer
    extends Composer<_$ClaimTrekDatabase, $TrailsTable> {
  $$TrailsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lengthM => $composableBuilder(
    column: $table.lengthM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encodedPath => $composableBuilder(
    column: $table.encodedPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get geohash5 => $composableBuilder(
    column: $table.geohash5,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrailsTableAnnotationComposer
    extends Composer<_$ClaimTrekDatabase, $TrailsTable> {
  $$TrailsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<double> get lengthM =>
      $composableBuilder(column: $table.lengthM, builder: (column) => column);

  GeneratedColumn<String> get encodedPath => $composableBuilder(
    column: $table.encodedPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get geohash5 =>
      $composableBuilder(column: $table.geohash5, builder: (column) => column);

  GeneratedColumn<int> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$TrailsTableTableManager
    extends
        RootTableManager<
          _$ClaimTrekDatabase,
          $TrailsTable,
          Trail,
          $$TrailsTableFilterComposer,
          $$TrailsTableOrderingComposer,
          $$TrailsTableAnnotationComposer,
          $$TrailsTableCreateCompanionBuilder,
          $$TrailsTableUpdateCompanionBuilder,
          (Trail, BaseReferences<_$ClaimTrekDatabase, $TrailsTable, Trail>),
          Trail,
          PrefetchHooks Function()
        > {
  $$TrailsTableTableManager(_$ClaimTrekDatabase db, $TrailsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrailsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrailsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrailsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<double> lengthM = const Value.absent(),
                Value<String> encodedPath = const Value.absent(),
                Value<String> geohash5 = const Value.absent(),
                Value<int> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrailsCompanion(
                id: id,
                name: name,
                kind: kind,
                lengthM: lengthM,
                encodedPath: encodedPath,
                geohash5: geohash5,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String kind,
                required double lengthM,
                required String encodedPath,
                required String geohash5,
                required int cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => TrailsCompanion.insert(
                id: id,
                name: name,
                kind: kind,
                lengthM: lengthM,
                encodedPath: encodedPath,
                geohash5: geohash5,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrailsTable, Trail>(table),
                  BaseReferences<_$ClaimTrekDatabase, $TrailsTable, Trail>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrailsTableProcessedTableManager =
    ProcessedTableManager<
      _$ClaimTrekDatabase,
      $TrailsTable,
      Trail,
      $$TrailsTableFilterComposer,
      $$TrailsTableOrderingComposer,
      $$TrailsTableAnnotationComposer,
      $$TrailsTableCreateCompanionBuilder,
      $$TrailsTableUpdateCompanionBuilder,
      (Trail, BaseReferences<_$ClaimTrekDatabase, $TrailsTable, Trail>),
      Trail,
      PrefetchHooks Function()
    >;
typedef $$TrailCellsTableCreateCompanionBuilder = TrailCellsCompanion Function({
  required String geohash5,
  required int fetchedAt,
  Value<int> rowid,
});
typedef $$TrailCellsTableUpdateCompanionBuilder = TrailCellsCompanion Function({
  Value<String> geohash5,
  Value<int> fetchedAt,
  Value<int> rowid,
});

class $$TrailCellsTableFilterComposer
    extends Composer<_$ClaimTrekDatabase, $TrailCellsTable> {
  $$TrailCellsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get geohash5 => $composableBuilder(
    column: $table.geohash5,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrailCellsTableOrderingComposer
    extends Composer<_$ClaimTrekDatabase, $TrailCellsTable> {
  $$TrailCellsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get geohash5 => $composableBuilder(
    column: $table.geohash5,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrailCellsTableAnnotationComposer
    extends Composer<_$ClaimTrekDatabase, $TrailCellsTable> {
  $$TrailCellsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get geohash5 =>
      $composableBuilder(column: $table.geohash5, builder: (column) => column);

  GeneratedColumn<int> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$TrailCellsTableTableManager
    extends
        RootTableManager<
          _$ClaimTrekDatabase,
          $TrailCellsTable,
          TrailCell,
          $$TrailCellsTableFilterComposer,
          $$TrailCellsTableOrderingComposer,
          $$TrailCellsTableAnnotationComposer,
          $$TrailCellsTableCreateCompanionBuilder,
          $$TrailCellsTableUpdateCompanionBuilder,
          (
            TrailCell,
            BaseReferences<_$ClaimTrekDatabase, $TrailCellsTable, TrailCell>,
          ),
          TrailCell,
          PrefetchHooks Function()
        > {
  $$TrailCellsTableTableManager(_$ClaimTrekDatabase db, $TrailCellsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrailCellsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrailCellsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrailCellsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> geohash5 = const Value.absent(),
                Value<int> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrailCellsCompanion(
                geohash5: geohash5,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String geohash5,
                required int fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => TrailCellsCompanion.insert(
                geohash5: geohash5,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrailCellsTable, TrailCell>(table),
                  BaseReferences<
                    _$ClaimTrekDatabase,
                    $TrailCellsTable,
                    TrailCell
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrailCellsTableProcessedTableManager =
    ProcessedTableManager<
      _$ClaimTrekDatabase,
      $TrailCellsTable,
      TrailCell,
      $$TrailCellsTableFilterComposer,
      $$TrailCellsTableOrderingComposer,
      $$TrailCellsTableAnnotationComposer,
      $$TrailCellsTableCreateCompanionBuilder,
      $$TrailCellsTableUpdateCompanionBuilder,
      (
        TrailCell,
        BaseReferences<_$ClaimTrekDatabase, $TrailCellsTable, TrailCell>,
      ),
      TrailCell,
      PrefetchHooks Function()
    >;

class $ClaimTrekDatabaseManager {
  final _$ClaimTrekDatabase _db;
  $ClaimTrekDatabaseManager(this._db);
  $$TerritoriesTableTableManager get territories =>
      $$TerritoriesTableTableManager(_db, _db.territories);
  $$RunsTableTableManager get runs => $$RunsTableTableManager(_db, _db.runs);
  $$TrailsTableTableManager get trails =>
      $$TrailsTableTableManager(_db, _db.trails);
  $$TrailCellsTableTableManager get trailCells =>
      $$TrailCellsTableTableManager(_db, _db.trailCells);
}
