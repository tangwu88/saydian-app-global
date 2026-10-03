import '../domain/models.dart';
import '../domain/health_record_validation.dart';
import 'api_client.dart';
import 'local_health_store.dart';

class SyncOutcome {
  const SyncOutcome({
    required this.uploaded,
    required this.rejected,
    this.message,
    this.hasPending = false,
  });

  final int uploaded;
  final int rejected;
  final String? message;
  final bool hasPending;
}

class HealthSyncService {
  const HealthSyncService(this._store, this._api);

  final HealthStore _store;
  final SaydianApi _api;

  Future<SyncOutcome> synchronizeNow({bool Function()? isCurrent}) async {
    bool canContinue() => isCurrent?.call() ?? true;
    final supportApi = _api is DailySummarySupportApi
        ? _api as DailySummarySupportApi
        : null;
    final dailySupported =
        supportApi != null && await supportApi.supportsDailySummaries();
    var uploaded = 0;
    var rejected = 0;
    var quarantined = 0;
    final preparationFailures = <String, String>{};
    while (true) {
      if (!canContinue()) {
        return SyncOutcome(uploaded: uploaded, rejected: rejected);
      }
      // ECG records contain a calibrated waveform and can be much larger than
      // ordinary health rows. Keep cloud batches small so reading an old
      // offline queue never delays a freshly completed manual measurement for
      // tens of seconds. Uploads still continue until the queue is empty.
      final pending = await _store.pending(
        limit: 10,
        includeDailySummaries: dailySupported,
      );
      if (!canContinue()) {
        return SyncOutcome(uploaded: uploaded, rejected: rejected);
      }
      if (pending.isEmpty) {
        final heldDaily =
            !dailySupported &&
            (await _store.pending(
              limit: 1,
            )).any((record) => record.aggregation != null);
        return SyncOutcome(
          uploaded: uploaded,
          rejected: rejected,
          hasPending: heldDaily,
          message: heldDaily
              ? '已保存到本机，暂未同步'
              : quarantined == 0
              ? null
              : '已隔离 $quarantined 条无效设备数据',
        );
      }
      final invalid = pending
          .where((record) => !hasSaneWearableTransportValues(record))
          .toList();
      if (invalid.isNotEmpty) {
        await _store.markInvalid(invalid.map((record) => record.id));
        if (!canContinue()) {
          return SyncOutcome(uploaded: uploaded, rejected: rejected);
        }
        quarantined += invalid.length;
        rejected += invalid.length;
      }
      final records = pending.where(hasSaneWearableTransportValues).toList();
      if (records.isEmpty) continue;
      final cursor = await _store.readCursor();
      if (!canContinue()) {
        return SyncOutcome(uploaded: uploaded, rejected: rejected);
      }
      try {
        final preparedRecords = <HealthRecord>[];
        for (final record in records) {
          var prepared = record;
          if (_api is HealthRecordPreparationApi &&
              !preparationFailures.containsKey(record.id)) {
            try {
              prepared = await (_api as HealthRecordPreparationApi)
                  .prepareHealthRecord(record);
            } on ApiException catch (error) {
              if (error.code == 'STALE_HEALTH_SESSION' ||
                  error.statusCode == 401) {
                rethrow;
              }
              // Let unrelated ordinary rows continue. The global batch rejects
              // this unprepared waveform, retaining the complete pending row.
              preparationFailures[record.id] = error.message;
            }
          }
          if (!canContinue()) {
            return SyncOutcome(uploaded: uploaded, rejected: rejected);
          }
          if (!identical(prepared, record)) {
            await _store.savePreparedRecord(prepared);
            if (!canContinue()) {
              return SyncOutcome(uploaded: uploaded, rejected: rejected);
            }
          }
          preparedRecords.add(prepared);
        }
        final result = await _api.uploadHealthBatch(
          SyncBatch(cursor: cursor, records: preparedRecords),
        );
        if (!canContinue()) {
          return SyncOutcome(uploaded: uploaded, rejected: rejected);
        }
        await _store.markSynced(result.acceptedIds);
        if (!canContinue()) {
          return SyncOutcome(uploaded: uploaded, rejected: rejected);
        }
        if (result.nextCursor != null) {
          await _store.writeCursor(result.nextCursor!);
          if (!canContinue()) {
            return SyncOutcome(uploaded: uploaded, rejected: rejected);
          }
        }
        uploaded += result.acceptedIds.length;
        rejected += result.rejected.length;
        if (result.acceptedIds.isEmpty) {
          return SyncOutcome(
            uploaded: uploaded,
            rejected: rejected,
            hasPending: true,
            message: result.rejected.isNotEmpty
                ? preparationFailures[result.rejected.keys.first] ??
                      result.rejected.values.first
                : '服务器未确认本批记录，已保留本地队列',
          );
        }
      } on FeatureNotConfiguredException catch (error) {
        return SyncOutcome(
          uploaded: uploaded,
          rejected: rejected,
          hasPending: true,
          message: error.message,
        );
      }
    }
  }
}
