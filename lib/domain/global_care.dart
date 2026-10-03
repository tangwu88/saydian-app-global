import 'models.dart';

class GlobalCareRelationship {
  const GlobalCareRelationship({
    required this.id,
    required this.status,
    required this.received,
    required this.name,
    required this.metrics,
    this.expiresAt,
  });
  final String id;
  final String status;
  final bool received;
  final String name;
  final Set<String> metrics;
  final DateTime? expiresAt;
  bool get active =>
      status == 'active' &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));
  factory GlobalCareRelationship.fromJson(Map<String, Object?> value) {
    final id = value['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Missing care identifier');
    }
    final received = value['direction'] == 'received';
    final person = value[received ? 'inviter' : 'recipient'];
    return GlobalCareRelationship(
      id: id,
      status: '${value['status'] ?? ''}',
      received: received,
      name: person is Map ? '${person['nickname'] ?? ''}' : '',
      metrics: (value['metrics'] as List? ?? const [])
          .whereType<String>()
          .toSet(),
      expiresAt: DateTime.tryParse('${value['expiresAt'] ?? ''}'),
    );
  }
}

/// Calendar midnights, not fixed 24-hour durations, preserve DST boundaries.
({DateTime from, DateTime to}) globalLocalDayRange(DateTime date) => (
  from: DateTime(date.year, date.month, date.day).toUtc(),
  to: DateTime(date.year, date.month, date.day + 1).toUtc(),
);

/// Shared records are view-only and never belong to the current user's store.
HealthRecord globalCareHealthRecord(Map<String, Object?> row) {
  final offset = (row['timezoneOffsetMinutes'] as num?)?.toInt() ?? 0;
  final timezone =
      '${offset < 0 ? '-' : '+'}${(offset.abs() ~/ 60).toString().padLeft(2, '0')}:${(offset.abs() % 60).toString().padLeft(2, '0')}';
  final artifact = row['ecgArtifact'];
  final source = row['source'];
  return HealthRecord.fromJson({
    'id': row['id'],
    'type': row['metric'],
    'values': row['values'],
    'unit': row['unit'],
    'measuredAt': row['observedAt'],
    'timezone': timezone,
    'source': 'wearable',
    'origin': 'remote_member',
    'quality': row['quality'],
    'rawVersion': source is Map && source['rawVersion'] is num
        ? source['rawVersion']
        : artifact is Map && row['quality'] != 'suspect'
        ? 2
        : 1,
    'aggregation': row['aggregation'],
    if (artifact is Map && artifact['sampleRateHz'] is num)
      'values': {
        ...?row['values'] as Map?,
        'sampleFrequency': artifact['sampleRateHz'],
      },
  });
}
