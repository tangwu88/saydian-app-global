import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../l10n/global_locale_controller.dart';
import '../l10n/ui_labels.dart';

bool _isEnglishUi(BuildContext context) =>
    Localizations.localeOf(context).languageCode != 'zh';

String healthAlertTitle(BuildContext context, HealthWarningAlert alert) {
  if (!_isEnglishUi(context)) return alert.title;
  return '${context.l10n.metricName(alert.metric)} alert';
}

String healthAlertMessage(BuildContext context, HealthWarningAlert alert) {
  if (!_isEnglishUi(context)) return alert.message;
  if (!RegExp(r'[\u4e00-\u9fff]').hasMatch(alert.message)) {
    return alert.message;
  }
  return switch (alert.metric) {
    HealthMetric.heartRate =>
      'A reading was above your heart rate alert limit.',
    HealthMetric.bloodPressure =>
      'A reading was above your blood pressure alert limit.',
    HealthMetric.bodyTemperature =>
      'A reading was above your temperature alert limit.',
    _ => 'A reading was above your alert limit.',
  };
}

String healthAlertOrigin(BuildContext context, MeasurementOrigin origin) {
  if (!_isEnglishUi(context)) return origin.label;
  return switch (origin) {
    MeasurementOrigin.watchHistory => 'Watch',
    MeasurementOrigin.appMeasurement => 'App',
    MeasurementOrigin.remoteMember => 'Shared',
    MeasurementOrigin.manualEntry => 'Manual',
    MeasurementOrigin.imported => 'Imported',
    MeasurementOrigin.unknown => 'Unknown',
  };
}
