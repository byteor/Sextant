// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_database.dart';

// ignore_for_file: type=lint
class $ScansTable extends Scans with TableInfo<$ScansTable, Scan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _networkIdMeta = const VerificationMeta(
    'networkId',
  );
  @override
  late final GeneratedColumn<String> networkId = GeneratedColumn<String>(
    'network_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _networkLabelMeta = const VerificationMeta(
    'networkLabel',
  );
  @override
  late final GeneratedColumn<String> networkLabel = GeneratedColumn<String>(
    'network_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceCountMeta = const VerificationMeta(
    'deviceCount',
  );
  @override
  late final GeneratedColumn<int> deviceCount = GeneratedColumn<int>(
    'device_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _devicesJsonMeta = const VerificationMeta(
    'devicesJson',
  );
  @override
  late final GeneratedColumn<String> devicesJson = GeneratedColumn<String>(
    'devices_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    networkId,
    networkLabel,
    timestamp,
    deviceCount,
    devicesJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scans';
  @override
  VerificationContext validateIntegrity(
    Insertable<Scan> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('network_id')) {
      context.handle(
        _networkIdMeta,
        networkId.isAcceptableOrUnknown(data['network_id']!, _networkIdMeta),
      );
    } else if (isInserting) {
      context.missing(_networkIdMeta);
    }
    if (data.containsKey('network_label')) {
      context.handle(
        _networkLabelMeta,
        networkLabel.isAcceptableOrUnknown(
          data['network_label']!,
          _networkLabelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_networkLabelMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('device_count')) {
      context.handle(
        _deviceCountMeta,
        deviceCount.isAcceptableOrUnknown(
          data['device_count']!,
          _deviceCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deviceCountMeta);
    }
    if (data.containsKey('devices_json')) {
      context.handle(
        _devicesJsonMeta,
        devicesJson.isAcceptableOrUnknown(
          data['devices_json']!,
          _devicesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_devicesJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Scan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Scan(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      networkId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}network_id'],
      )!,
      networkLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}network_label'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      deviceCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}device_count'],
      )!,
      devicesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}devices_json'],
      )!,
    );
  }

  @override
  $ScansTable createAlias(String alias) {
    return $ScansTable(attachedDatabase, alias);
  }
}

class Scan extends DataClass implements Insertable<Scan> {
  final int id;
  final String networkId;
  final String networkLabel;
  final DateTime timestamp;
  final int deviceCount;
  final String devicesJson;
  const Scan({
    required this.id,
    required this.networkId,
    required this.networkLabel,
    required this.timestamp,
    required this.deviceCount,
    required this.devicesJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['network_id'] = Variable<String>(networkId);
    map['network_label'] = Variable<String>(networkLabel);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['device_count'] = Variable<int>(deviceCount);
    map['devices_json'] = Variable<String>(devicesJson);
    return map;
  }

  ScansCompanion toCompanion(bool nullToAbsent) {
    return ScansCompanion(
      id: Value(id),
      networkId: Value(networkId),
      networkLabel: Value(networkLabel),
      timestamp: Value(timestamp),
      deviceCount: Value(deviceCount),
      devicesJson: Value(devicesJson),
    );
  }

  factory Scan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Scan(
      id: serializer.fromJson<int>(json['id']),
      networkId: serializer.fromJson<String>(json['networkId']),
      networkLabel: serializer.fromJson<String>(json['networkLabel']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      deviceCount: serializer.fromJson<int>(json['deviceCount']),
      devicesJson: serializer.fromJson<String>(json['devicesJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'networkId': serializer.toJson<String>(networkId),
      'networkLabel': serializer.toJson<String>(networkLabel),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'deviceCount': serializer.toJson<int>(deviceCount),
      'devicesJson': serializer.toJson<String>(devicesJson),
    };
  }

  Scan copyWith({
    int? id,
    String? networkId,
    String? networkLabel,
    DateTime? timestamp,
    int? deviceCount,
    String? devicesJson,
  }) => Scan(
    id: id ?? this.id,
    networkId: networkId ?? this.networkId,
    networkLabel: networkLabel ?? this.networkLabel,
    timestamp: timestamp ?? this.timestamp,
    deviceCount: deviceCount ?? this.deviceCount,
    devicesJson: devicesJson ?? this.devicesJson,
  );
  Scan copyWithCompanion(ScansCompanion data) {
    return Scan(
      id: data.id.present ? data.id.value : this.id,
      networkId: data.networkId.present ? data.networkId.value : this.networkId,
      networkLabel: data.networkLabel.present
          ? data.networkLabel.value
          : this.networkLabel,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      deviceCount: data.deviceCount.present
          ? data.deviceCount.value
          : this.deviceCount,
      devicesJson: data.devicesJson.present
          ? data.devicesJson.value
          : this.devicesJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Scan(')
          ..write('id: $id, ')
          ..write('networkId: $networkId, ')
          ..write('networkLabel: $networkLabel, ')
          ..write('timestamp: $timestamp, ')
          ..write('deviceCount: $deviceCount, ')
          ..write('devicesJson: $devicesJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    networkId,
    networkLabel,
    timestamp,
    deviceCount,
    devicesJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Scan &&
          other.id == this.id &&
          other.networkId == this.networkId &&
          other.networkLabel == this.networkLabel &&
          other.timestamp == this.timestamp &&
          other.deviceCount == this.deviceCount &&
          other.devicesJson == this.devicesJson);
}

class ScansCompanion extends UpdateCompanion<Scan> {
  final Value<int> id;
  final Value<String> networkId;
  final Value<String> networkLabel;
  final Value<DateTime> timestamp;
  final Value<int> deviceCount;
  final Value<String> devicesJson;
  const ScansCompanion({
    this.id = const Value.absent(),
    this.networkId = const Value.absent(),
    this.networkLabel = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.deviceCount = const Value.absent(),
    this.devicesJson = const Value.absent(),
  });
  ScansCompanion.insert({
    this.id = const Value.absent(),
    required String networkId,
    required String networkLabel,
    required DateTime timestamp,
    required int deviceCount,
    required String devicesJson,
  }) : networkId = Value(networkId),
       networkLabel = Value(networkLabel),
       timestamp = Value(timestamp),
       deviceCount = Value(deviceCount),
       devicesJson = Value(devicesJson);
  static Insertable<Scan> custom({
    Expression<int>? id,
    Expression<String>? networkId,
    Expression<String>? networkLabel,
    Expression<DateTime>? timestamp,
    Expression<int>? deviceCount,
    Expression<String>? devicesJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (networkId != null) 'network_id': networkId,
      if (networkLabel != null) 'network_label': networkLabel,
      if (timestamp != null) 'timestamp': timestamp,
      if (deviceCount != null) 'device_count': deviceCount,
      if (devicesJson != null) 'devices_json': devicesJson,
    });
  }

  ScansCompanion copyWith({
    Value<int>? id,
    Value<String>? networkId,
    Value<String>? networkLabel,
    Value<DateTime>? timestamp,
    Value<int>? deviceCount,
    Value<String>? devicesJson,
  }) {
    return ScansCompanion(
      id: id ?? this.id,
      networkId: networkId ?? this.networkId,
      networkLabel: networkLabel ?? this.networkLabel,
      timestamp: timestamp ?? this.timestamp,
      deviceCount: deviceCount ?? this.deviceCount,
      devicesJson: devicesJson ?? this.devicesJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (networkId.present) {
      map['network_id'] = Variable<String>(networkId.value);
    }
    if (networkLabel.present) {
      map['network_label'] = Variable<String>(networkLabel.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (deviceCount.present) {
      map['device_count'] = Variable<int>(deviceCount.value);
    }
    if (devicesJson.present) {
      map['devices_json'] = Variable<String>(devicesJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScansCompanion(')
          ..write('id: $id, ')
          ..write('networkId: $networkId, ')
          ..write('networkLabel: $networkLabel, ')
          ..write('timestamp: $timestamp, ')
          ..write('deviceCount: $deviceCount, ')
          ..write('devicesJson: $devicesJson')
          ..write(')'))
        .toString();
  }
}

class $LatencySamplesTable extends LatencySamples
    with TableInfo<$LatencySamplesTable, LatencySample> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LatencySamplesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _deviceIdentityMeta = const VerificationMeta(
    'deviceIdentity',
  );
  @override
  late final GeneratedColumn<String> deviceIdentity = GeneratedColumn<String>(
    'device_identity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _networkIdMeta = const VerificationMeta(
    'networkId',
  );
  @override
  late final GeneratedColumn<String> networkId = GeneratedColumn<String>(
    'network_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rttMsMeta = const VerificationMeta('rttMs');
  @override
  late final GeneratedColumn<double> rttMs = GeneratedColumn<double>(
    'rtt_ms',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deviceIdentity,
    networkId,
    timestamp,
    rttMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'latency_samples';
  @override
  VerificationContext validateIntegrity(
    Insertable<LatencySample> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('device_identity')) {
      context.handle(
        _deviceIdentityMeta,
        deviceIdentity.isAcceptableOrUnknown(
          data['device_identity']!,
          _deviceIdentityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deviceIdentityMeta);
    }
    if (data.containsKey('network_id')) {
      context.handle(
        _networkIdMeta,
        networkId.isAcceptableOrUnknown(data['network_id']!, _networkIdMeta),
      );
    } else if (isInserting) {
      context.missing(_networkIdMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('rtt_ms')) {
      context.handle(
        _rttMsMeta,
        rttMs.isAcceptableOrUnknown(data['rtt_ms']!, _rttMsMeta),
      );
    } else if (isInserting) {
      context.missing(_rttMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LatencySample map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LatencySample(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      deviceIdentity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_identity'],
      )!,
      networkId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}network_id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      rttMs: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rtt_ms'],
      )!,
    );
  }

  @override
  $LatencySamplesTable createAlias(String alias) {
    return $LatencySamplesTable(attachedDatabase, alias);
  }
}

class LatencySample extends DataClass implements Insertable<LatencySample> {
  final int id;
  final String deviceIdentity;
  final String networkId;
  final DateTime timestamp;
  final double rttMs;
  const LatencySample({
    required this.id,
    required this.deviceIdentity,
    required this.networkId,
    required this.timestamp,
    required this.rttMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['device_identity'] = Variable<String>(deviceIdentity);
    map['network_id'] = Variable<String>(networkId);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['rtt_ms'] = Variable<double>(rttMs);
    return map;
  }

  LatencySamplesCompanion toCompanion(bool nullToAbsent) {
    return LatencySamplesCompanion(
      id: Value(id),
      deviceIdentity: Value(deviceIdentity),
      networkId: Value(networkId),
      timestamp: Value(timestamp),
      rttMs: Value(rttMs),
    );
  }

  factory LatencySample.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LatencySample(
      id: serializer.fromJson<int>(json['id']),
      deviceIdentity: serializer.fromJson<String>(json['deviceIdentity']),
      networkId: serializer.fromJson<String>(json['networkId']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      rttMs: serializer.fromJson<double>(json['rttMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'deviceIdentity': serializer.toJson<String>(deviceIdentity),
      'networkId': serializer.toJson<String>(networkId),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'rttMs': serializer.toJson<double>(rttMs),
    };
  }

  LatencySample copyWith({
    int? id,
    String? deviceIdentity,
    String? networkId,
    DateTime? timestamp,
    double? rttMs,
  }) => LatencySample(
    id: id ?? this.id,
    deviceIdentity: deviceIdentity ?? this.deviceIdentity,
    networkId: networkId ?? this.networkId,
    timestamp: timestamp ?? this.timestamp,
    rttMs: rttMs ?? this.rttMs,
  );
  LatencySample copyWithCompanion(LatencySamplesCompanion data) {
    return LatencySample(
      id: data.id.present ? data.id.value : this.id,
      deviceIdentity: data.deviceIdentity.present
          ? data.deviceIdentity.value
          : this.deviceIdentity,
      networkId: data.networkId.present ? data.networkId.value : this.networkId,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      rttMs: data.rttMs.present ? data.rttMs.value : this.rttMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LatencySample(')
          ..write('id: $id, ')
          ..write('deviceIdentity: $deviceIdentity, ')
          ..write('networkId: $networkId, ')
          ..write('timestamp: $timestamp, ')
          ..write('rttMs: $rttMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, deviceIdentity, networkId, timestamp, rttMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LatencySample &&
          other.id == this.id &&
          other.deviceIdentity == this.deviceIdentity &&
          other.networkId == this.networkId &&
          other.timestamp == this.timestamp &&
          other.rttMs == this.rttMs);
}

class LatencySamplesCompanion extends UpdateCompanion<LatencySample> {
  final Value<int> id;
  final Value<String> deviceIdentity;
  final Value<String> networkId;
  final Value<DateTime> timestamp;
  final Value<double> rttMs;
  const LatencySamplesCompanion({
    this.id = const Value.absent(),
    this.deviceIdentity = const Value.absent(),
    this.networkId = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.rttMs = const Value.absent(),
  });
  LatencySamplesCompanion.insert({
    this.id = const Value.absent(),
    required String deviceIdentity,
    required String networkId,
    required DateTime timestamp,
    required double rttMs,
  }) : deviceIdentity = Value(deviceIdentity),
       networkId = Value(networkId),
       timestamp = Value(timestamp),
       rttMs = Value(rttMs);
  static Insertable<LatencySample> custom({
    Expression<int>? id,
    Expression<String>? deviceIdentity,
    Expression<String>? networkId,
    Expression<DateTime>? timestamp,
    Expression<double>? rttMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceIdentity != null) 'device_identity': deviceIdentity,
      if (networkId != null) 'network_id': networkId,
      if (timestamp != null) 'timestamp': timestamp,
      if (rttMs != null) 'rtt_ms': rttMs,
    });
  }

  LatencySamplesCompanion copyWith({
    Value<int>? id,
    Value<String>? deviceIdentity,
    Value<String>? networkId,
    Value<DateTime>? timestamp,
    Value<double>? rttMs,
  }) {
    return LatencySamplesCompanion(
      id: id ?? this.id,
      deviceIdentity: deviceIdentity ?? this.deviceIdentity,
      networkId: networkId ?? this.networkId,
      timestamp: timestamp ?? this.timestamp,
      rttMs: rttMs ?? this.rttMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (deviceIdentity.present) {
      map['device_identity'] = Variable<String>(deviceIdentity.value);
    }
    if (networkId.present) {
      map['network_id'] = Variable<String>(networkId.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (rttMs.present) {
      map['rtt_ms'] = Variable<double>(rttMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LatencySamplesCompanion(')
          ..write('id: $id, ')
          ..write('deviceIdentity: $deviceIdentity, ')
          ..write('networkId: $networkId, ')
          ..write('timestamp: $timestamp, ')
          ..write('rttMs: $rttMs')
          ..write(')'))
        .toString();
  }
}

class $SeenDevicesTable extends SeenDevices
    with TableInfo<$SeenDevicesTable, SeenDevice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeenDevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _networkIdMeta = const VerificationMeta(
    'networkId',
  );
  @override
  late final GeneratedColumn<String> networkId = GeneratedColumn<String>(
    'network_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdentityMeta = const VerificationMeta(
    'deviceIdentity',
  );
  @override
  late final GeneratedColumn<String> deviceIdentity = GeneratedColumn<String>(
    'device_identity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ipMeta = const VerificationMeta('ip');
  @override
  late final GeneratedColumn<String> ip = GeneratedColumn<String>(
    'ip',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstSeenAtMeta = const VerificationMeta(
    'firstSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> firstSeenAt = GeneratedColumn<DateTime>(
    'first_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _acknowledgedMeta = const VerificationMeta(
    'acknowledged',
  );
  @override
  late final GeneratedColumn<bool> acknowledged = GeneratedColumn<bool>(
    'acknowledged',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("acknowledged" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    networkId,
    deviceIdentity,
    ip,
    label,
    firstSeenAt,
    acknowledged,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'seen_devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeenDevice> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('network_id')) {
      context.handle(
        _networkIdMeta,
        networkId.isAcceptableOrUnknown(data['network_id']!, _networkIdMeta),
      );
    } else if (isInserting) {
      context.missing(_networkIdMeta);
    }
    if (data.containsKey('device_identity')) {
      context.handle(
        _deviceIdentityMeta,
        deviceIdentity.isAcceptableOrUnknown(
          data['device_identity']!,
          _deviceIdentityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deviceIdentityMeta);
    }
    if (data.containsKey('ip')) {
      context.handle(_ipMeta, ip.isAcceptableOrUnknown(data['ip']!, _ipMeta));
    } else if (isInserting) {
      context.missing(_ipMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('first_seen_at')) {
      context.handle(
        _firstSeenAtMeta,
        firstSeenAt.isAcceptableOrUnknown(
          data['first_seen_at']!,
          _firstSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstSeenAtMeta);
    }
    if (data.containsKey('acknowledged')) {
      context.handle(
        _acknowledgedMeta,
        acknowledged.isAcceptableOrUnknown(
          data['acknowledged']!,
          _acknowledgedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_acknowledgedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {networkId, deviceIdentity};
  @override
  SeenDevice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeenDevice(
      networkId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}network_id'],
      )!,
      deviceIdentity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_identity'],
      )!,
      ip: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ip'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      firstSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_seen_at'],
      )!,
      acknowledged: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}acknowledged'],
      )!,
    );
  }

  @override
  $SeenDevicesTable createAlias(String alias) {
    return $SeenDevicesTable(attachedDatabase, alias);
  }
}

class SeenDevice extends DataClass implements Insertable<SeenDevice> {
  final String networkId;
  final String deviceIdentity;
  final String ip;
  final String label;
  final DateTime firstSeenAt;
  final bool acknowledged;
  const SeenDevice({
    required this.networkId,
    required this.deviceIdentity,
    required this.ip,
    required this.label,
    required this.firstSeenAt,
    required this.acknowledged,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['network_id'] = Variable<String>(networkId);
    map['device_identity'] = Variable<String>(deviceIdentity);
    map['ip'] = Variable<String>(ip);
    map['label'] = Variable<String>(label);
    map['first_seen_at'] = Variable<DateTime>(firstSeenAt);
    map['acknowledged'] = Variable<bool>(acknowledged);
    return map;
  }

  SeenDevicesCompanion toCompanion(bool nullToAbsent) {
    return SeenDevicesCompanion(
      networkId: Value(networkId),
      deviceIdentity: Value(deviceIdentity),
      ip: Value(ip),
      label: Value(label),
      firstSeenAt: Value(firstSeenAt),
      acknowledged: Value(acknowledged),
    );
  }

  factory SeenDevice.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeenDevice(
      networkId: serializer.fromJson<String>(json['networkId']),
      deviceIdentity: serializer.fromJson<String>(json['deviceIdentity']),
      ip: serializer.fromJson<String>(json['ip']),
      label: serializer.fromJson<String>(json['label']),
      firstSeenAt: serializer.fromJson<DateTime>(json['firstSeenAt']),
      acknowledged: serializer.fromJson<bool>(json['acknowledged']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'networkId': serializer.toJson<String>(networkId),
      'deviceIdentity': serializer.toJson<String>(deviceIdentity),
      'ip': serializer.toJson<String>(ip),
      'label': serializer.toJson<String>(label),
      'firstSeenAt': serializer.toJson<DateTime>(firstSeenAt),
      'acknowledged': serializer.toJson<bool>(acknowledged),
    };
  }

  SeenDevice copyWith({
    String? networkId,
    String? deviceIdentity,
    String? ip,
    String? label,
    DateTime? firstSeenAt,
    bool? acknowledged,
  }) => SeenDevice(
    networkId: networkId ?? this.networkId,
    deviceIdentity: deviceIdentity ?? this.deviceIdentity,
    ip: ip ?? this.ip,
    label: label ?? this.label,
    firstSeenAt: firstSeenAt ?? this.firstSeenAt,
    acknowledged: acknowledged ?? this.acknowledged,
  );
  SeenDevice copyWithCompanion(SeenDevicesCompanion data) {
    return SeenDevice(
      networkId: data.networkId.present ? data.networkId.value : this.networkId,
      deviceIdentity: data.deviceIdentity.present
          ? data.deviceIdentity.value
          : this.deviceIdentity,
      ip: data.ip.present ? data.ip.value : this.ip,
      label: data.label.present ? data.label.value : this.label,
      firstSeenAt: data.firstSeenAt.present
          ? data.firstSeenAt.value
          : this.firstSeenAt,
      acknowledged: data.acknowledged.present
          ? data.acknowledged.value
          : this.acknowledged,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeenDevice(')
          ..write('networkId: $networkId, ')
          ..write('deviceIdentity: $deviceIdentity, ')
          ..write('ip: $ip, ')
          ..write('label: $label, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('acknowledged: $acknowledged')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    networkId,
    deviceIdentity,
    ip,
    label,
    firstSeenAt,
    acknowledged,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeenDevice &&
          other.networkId == this.networkId &&
          other.deviceIdentity == this.deviceIdentity &&
          other.ip == this.ip &&
          other.label == this.label &&
          other.firstSeenAt == this.firstSeenAt &&
          other.acknowledged == this.acknowledged);
}

class SeenDevicesCompanion extends UpdateCompanion<SeenDevice> {
  final Value<String> networkId;
  final Value<String> deviceIdentity;
  final Value<String> ip;
  final Value<String> label;
  final Value<DateTime> firstSeenAt;
  final Value<bool> acknowledged;
  final Value<int> rowid;
  const SeenDevicesCompanion({
    this.networkId = const Value.absent(),
    this.deviceIdentity = const Value.absent(),
    this.ip = const Value.absent(),
    this.label = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.acknowledged = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeenDevicesCompanion.insert({
    required String networkId,
    required String deviceIdentity,
    required String ip,
    required String label,
    required DateTime firstSeenAt,
    required bool acknowledged,
    this.rowid = const Value.absent(),
  }) : networkId = Value(networkId),
       deviceIdentity = Value(deviceIdentity),
       ip = Value(ip),
       label = Value(label),
       firstSeenAt = Value(firstSeenAt),
       acknowledged = Value(acknowledged);
  static Insertable<SeenDevice> custom({
    Expression<String>? networkId,
    Expression<String>? deviceIdentity,
    Expression<String>? ip,
    Expression<String>? label,
    Expression<DateTime>? firstSeenAt,
    Expression<bool>? acknowledged,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (networkId != null) 'network_id': networkId,
      if (deviceIdentity != null) 'device_identity': deviceIdentity,
      if (ip != null) 'ip': ip,
      if (label != null) 'label': label,
      if (firstSeenAt != null) 'first_seen_at': firstSeenAt,
      if (acknowledged != null) 'acknowledged': acknowledged,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeenDevicesCompanion copyWith({
    Value<String>? networkId,
    Value<String>? deviceIdentity,
    Value<String>? ip,
    Value<String>? label,
    Value<DateTime>? firstSeenAt,
    Value<bool>? acknowledged,
    Value<int>? rowid,
  }) {
    return SeenDevicesCompanion(
      networkId: networkId ?? this.networkId,
      deviceIdentity: deviceIdentity ?? this.deviceIdentity,
      ip: ip ?? this.ip,
      label: label ?? this.label,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      acknowledged: acknowledged ?? this.acknowledged,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (networkId.present) {
      map['network_id'] = Variable<String>(networkId.value);
    }
    if (deviceIdentity.present) {
      map['device_identity'] = Variable<String>(deviceIdentity.value);
    }
    if (ip.present) {
      map['ip'] = Variable<String>(ip.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (firstSeenAt.present) {
      map['first_seen_at'] = Variable<DateTime>(firstSeenAt.value);
    }
    if (acknowledged.present) {
      map['acknowledged'] = Variable<bool>(acknowledged.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeenDevicesCompanion(')
          ..write('networkId: $networkId, ')
          ..write('deviceIdentity: $deviceIdentity, ')
          ..write('ip: $ip, ')
          ..write('label: $label, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('acknowledged: $acknowledged, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeepScanPortsTable extends DeepScanPorts
    with TableInfo<$DeepScanPortsTable, DeepScanPort> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeepScanPortsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdentityMeta = const VerificationMeta(
    'deviceIdentity',
  );
  @override
  late final GeneratedColumn<String> deviceIdentity = GeneratedColumn<String>(
    'device_identity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _networkIdMeta = const VerificationMeta(
    'networkId',
  );
  @override
  late final GeneratedColumn<String> networkId = GeneratedColumn<String>(
    'network_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _portMeta = const VerificationMeta('port');
  @override
  late final GeneratedColumn<int> port = GeneratedColumn<int>(
    'port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _discoveredAtMeta = const VerificationMeta(
    'discoveredAt',
  );
  @override
  late final GeneratedColumn<DateTime> discoveredAt = GeneratedColumn<DateTime>(
    'discovered_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    deviceIdentity,
    networkId,
    port,
    discoveredAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deep_scan_ports';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeepScanPort> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_identity')) {
      context.handle(
        _deviceIdentityMeta,
        deviceIdentity.isAcceptableOrUnknown(
          data['device_identity']!,
          _deviceIdentityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deviceIdentityMeta);
    }
    if (data.containsKey('network_id')) {
      context.handle(
        _networkIdMeta,
        networkId.isAcceptableOrUnknown(data['network_id']!, _networkIdMeta),
      );
    } else if (isInserting) {
      context.missing(_networkIdMeta);
    }
    if (data.containsKey('port')) {
      context.handle(
        _portMeta,
        port.isAcceptableOrUnknown(data['port']!, _portMeta),
      );
    } else if (isInserting) {
      context.missing(_portMeta);
    }
    if (data.containsKey('discovered_at')) {
      context.handle(
        _discoveredAtMeta,
        discoveredAt.isAcceptableOrUnknown(
          data['discovered_at']!,
          _discoveredAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_discoveredAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceIdentity, port};
  @override
  DeepScanPort map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeepScanPort(
      deviceIdentity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_identity'],
      )!,
      networkId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}network_id'],
      )!,
      port: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}port'],
      )!,
      discoveredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}discovered_at'],
      )!,
    );
  }

  @override
  $DeepScanPortsTable createAlias(String alias) {
    return $DeepScanPortsTable(attachedDatabase, alias);
  }
}

class DeepScanPort extends DataClass implements Insertable<DeepScanPort> {
  final String deviceIdentity;
  final String networkId;
  final int port;
  final DateTime discoveredAt;
  const DeepScanPort({
    required this.deviceIdentity,
    required this.networkId,
    required this.port,
    required this.discoveredAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_identity'] = Variable<String>(deviceIdentity);
    map['network_id'] = Variable<String>(networkId);
    map['port'] = Variable<int>(port);
    map['discovered_at'] = Variable<DateTime>(discoveredAt);
    return map;
  }

  DeepScanPortsCompanion toCompanion(bool nullToAbsent) {
    return DeepScanPortsCompanion(
      deviceIdentity: Value(deviceIdentity),
      networkId: Value(networkId),
      port: Value(port),
      discoveredAt: Value(discoveredAt),
    );
  }

  factory DeepScanPort.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeepScanPort(
      deviceIdentity: serializer.fromJson<String>(json['deviceIdentity']),
      networkId: serializer.fromJson<String>(json['networkId']),
      port: serializer.fromJson<int>(json['port']),
      discoveredAt: serializer.fromJson<DateTime>(json['discoveredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceIdentity': serializer.toJson<String>(deviceIdentity),
      'networkId': serializer.toJson<String>(networkId),
      'port': serializer.toJson<int>(port),
      'discoveredAt': serializer.toJson<DateTime>(discoveredAt),
    };
  }

  DeepScanPort copyWith({
    String? deviceIdentity,
    String? networkId,
    int? port,
    DateTime? discoveredAt,
  }) => DeepScanPort(
    deviceIdentity: deviceIdentity ?? this.deviceIdentity,
    networkId: networkId ?? this.networkId,
    port: port ?? this.port,
    discoveredAt: discoveredAt ?? this.discoveredAt,
  );
  DeepScanPort copyWithCompanion(DeepScanPortsCompanion data) {
    return DeepScanPort(
      deviceIdentity: data.deviceIdentity.present
          ? data.deviceIdentity.value
          : this.deviceIdentity,
      networkId: data.networkId.present ? data.networkId.value : this.networkId,
      port: data.port.present ? data.port.value : this.port,
      discoveredAt: data.discoveredAt.present
          ? data.discoveredAt.value
          : this.discoveredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeepScanPort(')
          ..write('deviceIdentity: $deviceIdentity, ')
          ..write('networkId: $networkId, ')
          ..write('port: $port, ')
          ..write('discoveredAt: $discoveredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(deviceIdentity, networkId, port, discoveredAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeepScanPort &&
          other.deviceIdentity == this.deviceIdentity &&
          other.networkId == this.networkId &&
          other.port == this.port &&
          other.discoveredAt == this.discoveredAt);
}

class DeepScanPortsCompanion extends UpdateCompanion<DeepScanPort> {
  final Value<String> deviceIdentity;
  final Value<String> networkId;
  final Value<int> port;
  final Value<DateTime> discoveredAt;
  final Value<int> rowid;
  const DeepScanPortsCompanion({
    this.deviceIdentity = const Value.absent(),
    this.networkId = const Value.absent(),
    this.port = const Value.absent(),
    this.discoveredAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeepScanPortsCompanion.insert({
    required String deviceIdentity,
    required String networkId,
    required int port,
    required DateTime discoveredAt,
    this.rowid = const Value.absent(),
  }) : deviceIdentity = Value(deviceIdentity),
       networkId = Value(networkId),
       port = Value(port),
       discoveredAt = Value(discoveredAt);
  static Insertable<DeepScanPort> custom({
    Expression<String>? deviceIdentity,
    Expression<String>? networkId,
    Expression<int>? port,
    Expression<DateTime>? discoveredAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceIdentity != null) 'device_identity': deviceIdentity,
      if (networkId != null) 'network_id': networkId,
      if (port != null) 'port': port,
      if (discoveredAt != null) 'discovered_at': discoveredAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeepScanPortsCompanion copyWith({
    Value<String>? deviceIdentity,
    Value<String>? networkId,
    Value<int>? port,
    Value<DateTime>? discoveredAt,
    Value<int>? rowid,
  }) {
    return DeepScanPortsCompanion(
      deviceIdentity: deviceIdentity ?? this.deviceIdentity,
      networkId: networkId ?? this.networkId,
      port: port ?? this.port,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceIdentity.present) {
      map['device_identity'] = Variable<String>(deviceIdentity.value);
    }
    if (networkId.present) {
      map['network_id'] = Variable<String>(networkId.value);
    }
    if (port.present) {
      map['port'] = Variable<int>(port.value);
    }
    if (discoveredAt.present) {
      map['discovered_at'] = Variable<DateTime>(discoveredAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeepScanPortsCompanion(')
          ..write('deviceIdentity: $deviceIdentity, ')
          ..write('networkId: $networkId, ')
          ..write('port: $port, ')
          ..write('discoveredAt: $discoveredAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$HistoryDatabase extends GeneratedDatabase {
  _$HistoryDatabase(QueryExecutor e) : super(e);
  $HistoryDatabaseManager get managers => $HistoryDatabaseManager(this);
  late final $ScansTable scans = $ScansTable(this);
  late final $LatencySamplesTable latencySamples = $LatencySamplesTable(this);
  late final $SeenDevicesTable seenDevices = $SeenDevicesTable(this);
  late final $DeepScanPortsTable deepScanPorts = $DeepScanPortsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    scans,
    latencySamples,
    seenDevices,
    deepScanPorts,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$ScansTableCreateCompanionBuilder =
    ScansCompanion Function({
      Value<int> id,
      required String networkId,
      required String networkLabel,
      required DateTime timestamp,
      required int deviceCount,
      required String devicesJson,
    });
typedef $$ScansTableUpdateCompanionBuilder =
    ScansCompanion Function({
      Value<int> id,
      Value<String> networkId,
      Value<String> networkLabel,
      Value<DateTime> timestamp,
      Value<int> deviceCount,
      Value<String> devicesJson,
    });

class $$ScansTableFilterComposer
    extends Composer<_$HistoryDatabase, $ScansTable> {
  $$ScansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get networkId => $composableBuilder(
    column: $table.networkId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get networkLabel => $composableBuilder(
    column: $table.networkLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deviceCount => $composableBuilder(
    column: $table.deviceCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get devicesJson => $composableBuilder(
    column: $table.devicesJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScansTableOrderingComposer
    extends Composer<_$HistoryDatabase, $ScansTable> {
  $$ScansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get networkId => $composableBuilder(
    column: $table.networkId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get networkLabel => $composableBuilder(
    column: $table.networkLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deviceCount => $composableBuilder(
    column: $table.deviceCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get devicesJson => $composableBuilder(
    column: $table.devicesJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScansTableAnnotationComposer
    extends Composer<_$HistoryDatabase, $ScansTable> {
  $$ScansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get networkId =>
      $composableBuilder(column: $table.networkId, builder: (column) => column);

  GeneratedColumn<String> get networkLabel => $composableBuilder(
    column: $table.networkLabel,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<int> get deviceCount => $composableBuilder(
    column: $table.deviceCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get devicesJson => $composableBuilder(
    column: $table.devicesJson,
    builder: (column) => column,
  );
}

class $$ScansTableTableManager
    extends
        RootTableManager<
          _$HistoryDatabase,
          $ScansTable,
          Scan,
          $$ScansTableFilterComposer,
          $$ScansTableOrderingComposer,
          $$ScansTableAnnotationComposer,
          $$ScansTableCreateCompanionBuilder,
          $$ScansTableUpdateCompanionBuilder,
          (Scan, BaseReferences<_$HistoryDatabase, $ScansTable, Scan>),
          Scan,
          PrefetchHooks Function()
        > {
  $$ScansTableTableManager(_$HistoryDatabase db, $ScansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> networkId = const Value.absent(),
                Value<String> networkLabel = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<int> deviceCount = const Value.absent(),
                Value<String> devicesJson = const Value.absent(),
              }) => ScansCompanion(
                id: id,
                networkId: networkId,
                networkLabel: networkLabel,
                timestamp: timestamp,
                deviceCount: deviceCount,
                devicesJson: devicesJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String networkId,
                required String networkLabel,
                required DateTime timestamp,
                required int deviceCount,
                required String devicesJson,
              }) => ScansCompanion.insert(
                id: id,
                networkId: networkId,
                networkLabel: networkLabel,
                timestamp: timestamp,
                deviceCount: deviceCount,
                devicesJson: devicesJson,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScansTableProcessedTableManager =
    ProcessedTableManager<
      _$HistoryDatabase,
      $ScansTable,
      Scan,
      $$ScansTableFilterComposer,
      $$ScansTableOrderingComposer,
      $$ScansTableAnnotationComposer,
      $$ScansTableCreateCompanionBuilder,
      $$ScansTableUpdateCompanionBuilder,
      (Scan, BaseReferences<_$HistoryDatabase, $ScansTable, Scan>),
      Scan,
      PrefetchHooks Function()
    >;
typedef $$LatencySamplesTableCreateCompanionBuilder =
    LatencySamplesCompanion Function({
      Value<int> id,
      required String deviceIdentity,
      required String networkId,
      required DateTime timestamp,
      required double rttMs,
    });
typedef $$LatencySamplesTableUpdateCompanionBuilder =
    LatencySamplesCompanion Function({
      Value<int> id,
      Value<String> deviceIdentity,
      Value<String> networkId,
      Value<DateTime> timestamp,
      Value<double> rttMs,
    });

class $$LatencySamplesTableFilterComposer
    extends Composer<_$HistoryDatabase, $LatencySamplesTable> {
  $$LatencySamplesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceIdentity => $composableBuilder(
    column: $table.deviceIdentity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get networkId => $composableBuilder(
    column: $table.networkId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rttMs => $composableBuilder(
    column: $table.rttMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LatencySamplesTableOrderingComposer
    extends Composer<_$HistoryDatabase, $LatencySamplesTable> {
  $$LatencySamplesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceIdentity => $composableBuilder(
    column: $table.deviceIdentity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get networkId => $composableBuilder(
    column: $table.networkId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rttMs => $composableBuilder(
    column: $table.rttMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LatencySamplesTableAnnotationComposer
    extends Composer<_$HistoryDatabase, $LatencySamplesTable> {
  $$LatencySamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceIdentity => $composableBuilder(
    column: $table.deviceIdentity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get networkId =>
      $composableBuilder(column: $table.networkId, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<double> get rttMs =>
      $composableBuilder(column: $table.rttMs, builder: (column) => column);
}

class $$LatencySamplesTableTableManager
    extends
        RootTableManager<
          _$HistoryDatabase,
          $LatencySamplesTable,
          LatencySample,
          $$LatencySamplesTableFilterComposer,
          $$LatencySamplesTableOrderingComposer,
          $$LatencySamplesTableAnnotationComposer,
          $$LatencySamplesTableCreateCompanionBuilder,
          $$LatencySamplesTableUpdateCompanionBuilder,
          (
            LatencySample,
            BaseReferences<
              _$HistoryDatabase,
              $LatencySamplesTable,
              LatencySample
            >,
          ),
          LatencySample,
          PrefetchHooks Function()
        > {
  $$LatencySamplesTableTableManager(
    _$HistoryDatabase db,
    $LatencySamplesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LatencySamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LatencySamplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LatencySamplesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> deviceIdentity = const Value.absent(),
                Value<String> networkId = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<double> rttMs = const Value.absent(),
              }) => LatencySamplesCompanion(
                id: id,
                deviceIdentity: deviceIdentity,
                networkId: networkId,
                timestamp: timestamp,
                rttMs: rttMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String deviceIdentity,
                required String networkId,
                required DateTime timestamp,
                required double rttMs,
              }) => LatencySamplesCompanion.insert(
                id: id,
                deviceIdentity: deviceIdentity,
                networkId: networkId,
                timestamp: timestamp,
                rttMs: rttMs,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LatencySamplesTableProcessedTableManager =
    ProcessedTableManager<
      _$HistoryDatabase,
      $LatencySamplesTable,
      LatencySample,
      $$LatencySamplesTableFilterComposer,
      $$LatencySamplesTableOrderingComposer,
      $$LatencySamplesTableAnnotationComposer,
      $$LatencySamplesTableCreateCompanionBuilder,
      $$LatencySamplesTableUpdateCompanionBuilder,
      (
        LatencySample,
        BaseReferences<_$HistoryDatabase, $LatencySamplesTable, LatencySample>,
      ),
      LatencySample,
      PrefetchHooks Function()
    >;
typedef $$SeenDevicesTableCreateCompanionBuilder =
    SeenDevicesCompanion Function({
      required String networkId,
      required String deviceIdentity,
      required String ip,
      required String label,
      required DateTime firstSeenAt,
      required bool acknowledged,
      Value<int> rowid,
    });
typedef $$SeenDevicesTableUpdateCompanionBuilder =
    SeenDevicesCompanion Function({
      Value<String> networkId,
      Value<String> deviceIdentity,
      Value<String> ip,
      Value<String> label,
      Value<DateTime> firstSeenAt,
      Value<bool> acknowledged,
      Value<int> rowid,
    });

class $$SeenDevicesTableFilterComposer
    extends Composer<_$HistoryDatabase, $SeenDevicesTable> {
  $$SeenDevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get networkId => $composableBuilder(
    column: $table.networkId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceIdentity => $composableBuilder(
    column: $table.deviceIdentity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ip => $composableBuilder(
    column: $table.ip,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get acknowledged => $composableBuilder(
    column: $table.acknowledged,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SeenDevicesTableOrderingComposer
    extends Composer<_$HistoryDatabase, $SeenDevicesTable> {
  $$SeenDevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get networkId => $composableBuilder(
    column: $table.networkId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceIdentity => $composableBuilder(
    column: $table.deviceIdentity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ip => $composableBuilder(
    column: $table.ip,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get acknowledged => $composableBuilder(
    column: $table.acknowledged,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SeenDevicesTableAnnotationComposer
    extends Composer<_$HistoryDatabase, $SeenDevicesTable> {
  $$SeenDevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get networkId =>
      $composableBuilder(column: $table.networkId, builder: (column) => column);

  GeneratedColumn<String> get deviceIdentity => $composableBuilder(
    column: $table.deviceIdentity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ip =>
      $composableBuilder(column: $table.ip, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get acknowledged => $composableBuilder(
    column: $table.acknowledged,
    builder: (column) => column,
  );
}

class $$SeenDevicesTableTableManager
    extends
        RootTableManager<
          _$HistoryDatabase,
          $SeenDevicesTable,
          SeenDevice,
          $$SeenDevicesTableFilterComposer,
          $$SeenDevicesTableOrderingComposer,
          $$SeenDevicesTableAnnotationComposer,
          $$SeenDevicesTableCreateCompanionBuilder,
          $$SeenDevicesTableUpdateCompanionBuilder,
          (
            SeenDevice,
            BaseReferences<_$HistoryDatabase, $SeenDevicesTable, SeenDevice>,
          ),
          SeenDevice,
          PrefetchHooks Function()
        > {
  $$SeenDevicesTableTableManager(_$HistoryDatabase db, $SeenDevicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeenDevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeenDevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeenDevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> networkId = const Value.absent(),
                Value<String> deviceIdentity = const Value.absent(),
                Value<String> ip = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<DateTime> firstSeenAt = const Value.absent(),
                Value<bool> acknowledged = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeenDevicesCompanion(
                networkId: networkId,
                deviceIdentity: deviceIdentity,
                ip: ip,
                label: label,
                firstSeenAt: firstSeenAt,
                acknowledged: acknowledged,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String networkId,
                required String deviceIdentity,
                required String ip,
                required String label,
                required DateTime firstSeenAt,
                required bool acknowledged,
                Value<int> rowid = const Value.absent(),
              }) => SeenDevicesCompanion.insert(
                networkId: networkId,
                deviceIdentity: deviceIdentity,
                ip: ip,
                label: label,
                firstSeenAt: firstSeenAt,
                acknowledged: acknowledged,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SeenDevicesTableProcessedTableManager =
    ProcessedTableManager<
      _$HistoryDatabase,
      $SeenDevicesTable,
      SeenDevice,
      $$SeenDevicesTableFilterComposer,
      $$SeenDevicesTableOrderingComposer,
      $$SeenDevicesTableAnnotationComposer,
      $$SeenDevicesTableCreateCompanionBuilder,
      $$SeenDevicesTableUpdateCompanionBuilder,
      (
        SeenDevice,
        BaseReferences<_$HistoryDatabase, $SeenDevicesTable, SeenDevice>,
      ),
      SeenDevice,
      PrefetchHooks Function()
    >;
typedef $$DeepScanPortsTableCreateCompanionBuilder =
    DeepScanPortsCompanion Function({
      required String deviceIdentity,
      required String networkId,
      required int port,
      required DateTime discoveredAt,
      Value<int> rowid,
    });
typedef $$DeepScanPortsTableUpdateCompanionBuilder =
    DeepScanPortsCompanion Function({
      Value<String> deviceIdentity,
      Value<String> networkId,
      Value<int> port,
      Value<DateTime> discoveredAt,
      Value<int> rowid,
    });

class $$DeepScanPortsTableFilterComposer
    extends Composer<_$HistoryDatabase, $DeepScanPortsTable> {
  $$DeepScanPortsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceIdentity => $composableBuilder(
    column: $table.deviceIdentity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get networkId => $composableBuilder(
    column: $table.networkId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get discoveredAt => $composableBuilder(
    column: $table.discoveredAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeepScanPortsTableOrderingComposer
    extends Composer<_$HistoryDatabase, $DeepScanPortsTable> {
  $$DeepScanPortsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceIdentity => $composableBuilder(
    column: $table.deviceIdentity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get networkId => $composableBuilder(
    column: $table.networkId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get discoveredAt => $composableBuilder(
    column: $table.discoveredAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeepScanPortsTableAnnotationComposer
    extends Composer<_$HistoryDatabase, $DeepScanPortsTable> {
  $$DeepScanPortsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceIdentity => $composableBuilder(
    column: $table.deviceIdentity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get networkId =>
      $composableBuilder(column: $table.networkId, builder: (column) => column);

  GeneratedColumn<int> get port =>
      $composableBuilder(column: $table.port, builder: (column) => column);

  GeneratedColumn<DateTime> get discoveredAt => $composableBuilder(
    column: $table.discoveredAt,
    builder: (column) => column,
  );
}

class $$DeepScanPortsTableTableManager
    extends
        RootTableManager<
          _$HistoryDatabase,
          $DeepScanPortsTable,
          DeepScanPort,
          $$DeepScanPortsTableFilterComposer,
          $$DeepScanPortsTableOrderingComposer,
          $$DeepScanPortsTableAnnotationComposer,
          $$DeepScanPortsTableCreateCompanionBuilder,
          $$DeepScanPortsTableUpdateCompanionBuilder,
          (
            DeepScanPort,
            BaseReferences<
              _$HistoryDatabase,
              $DeepScanPortsTable,
              DeepScanPort
            >,
          ),
          DeepScanPort,
          PrefetchHooks Function()
        > {
  $$DeepScanPortsTableTableManager(
    _$HistoryDatabase db,
    $DeepScanPortsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeepScanPortsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeepScanPortsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeepScanPortsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> deviceIdentity = const Value.absent(),
                Value<String> networkId = const Value.absent(),
                Value<int> port = const Value.absent(),
                Value<DateTime> discoveredAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeepScanPortsCompanion(
                deviceIdentity: deviceIdentity,
                networkId: networkId,
                port: port,
                discoveredAt: discoveredAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deviceIdentity,
                required String networkId,
                required int port,
                required DateTime discoveredAt,
                Value<int> rowid = const Value.absent(),
              }) => DeepScanPortsCompanion.insert(
                deviceIdentity: deviceIdentity,
                networkId: networkId,
                port: port,
                discoveredAt: discoveredAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeepScanPortsTableProcessedTableManager =
    ProcessedTableManager<
      _$HistoryDatabase,
      $DeepScanPortsTable,
      DeepScanPort,
      $$DeepScanPortsTableFilterComposer,
      $$DeepScanPortsTableOrderingComposer,
      $$DeepScanPortsTableAnnotationComposer,
      $$DeepScanPortsTableCreateCompanionBuilder,
      $$DeepScanPortsTableUpdateCompanionBuilder,
      (
        DeepScanPort,
        BaseReferences<_$HistoryDatabase, $DeepScanPortsTable, DeepScanPort>,
      ),
      DeepScanPort,
      PrefetchHooks Function()
    >;

class $HistoryDatabaseManager {
  final _$HistoryDatabase _db;
  $HistoryDatabaseManager(this._db);
  $$ScansTableTableManager get scans =>
      $$ScansTableTableManager(_db, _db.scans);
  $$LatencySamplesTableTableManager get latencySamples =>
      $$LatencySamplesTableTableManager(_db, _db.latencySamples);
  $$SeenDevicesTableTableManager get seenDevices =>
      $$SeenDevicesTableTableManager(_db, _db.seenDevices);
  $$DeepScanPortsTableTableManager get deepScanPorts =>
      $$DeepScanPortsTableTableManager(_db, _db.deepScanPorts);
}
