import 'dart:convert';
import 'dart:developer' as developer;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AppTelemetryEvents {
  AppTelemetryEvents._();

  static const String dashboardExportPdfStarted =
      'dashboard_export_pdf_started';
  static const String dashboardExportPdfFinished =
      'dashboard_export_pdf_finished';
  static const String dashboardExportPdfException =
      'dashboard_export_pdf_exception';
  static const String dashboardExportPdfIgnoredBusy =
      'dashboard_export_pdf_ignored_busy';
  static const String dashboardExportPdfUnsupportedPlatform =
      'dashboard_export_pdf_unsupported_platform';
}

abstract class TelemetryProvider {
  Future<void> send(String event, Map<String, Object?> params);
}

class DeveloperLogTelemetryProvider implements TelemetryProvider {
  const DeveloperLogTelemetryProvider();

  @override
  Future<void> send(String event, Map<String, Object?> params) async {
    final Map<String, Object?> payload = <String, Object?>{
      'event': event,
      'timestamp': DateTime.now().toIso8601String(),
      ...params,
    };

    developer.log(jsonEncode(payload), name: 'app.telemetry', level: 800);
  }
}

class FirebaseAnalyticsTelemetryProvider implements TelemetryProvider {
  FirebaseAnalyticsTelemetryProvider({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> send(String event, Map<String, Object?> params) async {
    await _analytics.logEvent(name: event, parameters: _toAnalytics(params));
  }

  Map<String, Object> _toAnalytics(Map<String, Object?> params) {
    final Map<String, Object> result = <String, Object>{};

    params.forEach((String key, Object? value) {
      if (value == null) {
        return;
      }
      if (value is String || value is num || value is bool) {
        result[key] = value;
        return;
      }
      result[key] = value.toString();
    });

    return result;
  }
}

class AppTelemetryService {
  AppTelemetryService({List<TelemetryProvider>? providers})
    : _providers = providers ?? _defaultProviders();

  final List<TelemetryProvider> _providers;

  static final Map<String, Set<String>> _allowedParams = <String, Set<String>>{
    AppTelemetryEvents.dashboardExportPdfStarted: <String>{
      'origemAcao',
      'referenciaAno',
      'referenciaMes',
    },
    AppTelemetryEvents.dashboardExportPdfFinished: <String>{
      'origemAcao',
      'referenciaAno',
      'referenciaMes',
      'duracaoMs',
      'sucesso',
      'fallbackCompartilhamento',
      'erroTipo',
    },
    AppTelemetryEvents.dashboardExportPdfException: <String>{
      'origemAcao',
      'erroTipo',
      'erroMensagem',
    },
    AppTelemetryEvents.dashboardExportPdfIgnoredBusy: <String>{'origemAcao'},
    AppTelemetryEvents.dashboardExportPdfUnsupportedPlatform: <String>{
      'origemAcao',
      'platform',
      'duracaoMs',
    },
  };

  void logEvent(String event, {Map<String, Object?> params = const {}}) {
    if (!_allowedParams.containsKey(event)) {
      // Unknown events are ignored to prevent ungoverned telemetry growth.
      return;
    }

    final Map<String, Object?> sanitized = _sanitize(event, params);
    for (final TelemetryProvider provider in _providers) {
      provider.send(event, sanitized);
    }
  }

  Map<String, Object?> _sanitize(String event, Map<String, Object?> params) {
    final Set<String> allowed = _allowedParams[event] ?? const <String>{};
    final Map<String, Object?> sanitized = <String, Object?>{};

    params.forEach((String key, Object? value) {
      if (!allowed.contains(key)) {
        return;
      }
      sanitized[key] = _sanitizeValue(key, value);
    });

    return sanitized;
  }

  Object? _sanitizeValue(String key, Object? value) {
    if (value == null) {
      return null;
    }

    final String lowerKey = key.toLowerCase();
    if (lowerKey.contains('valor') || lowerKey.contains('montante')) {
      return _bucketMoney(value);
    }

    if (lowerKey.contains('erro') && value is String) {
      final String clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
      return clean.length > 120 ? clean.substring(0, 120) : clean;
    }

    if (value is String || value is num || value is bool) {
      return value;
    }

    return value.toString();
  }

  String _bucketMoney(Object value) {
    final double? parsed = value is num
        ? value.toDouble()
        : double.tryParse(value.toString());

    if (parsed == null) {
      return 'desconhecido';
    }
    if (parsed < 100) {
      return '0-99';
    }
    if (parsed < 500) {
      return '100-499';
    }
    if (parsed < 2000) {
      return '500-1999';
    }
    return '2000+';
  }

  static List<TelemetryProvider> _defaultProviders() {
    final List<TelemetryProvider> providers = <TelemetryProvider>[
      FirebaseAnalyticsTelemetryProvider(),
    ];

    if (!kReleaseMode) {
      providers.add(const DeveloperLogTelemetryProvider());
    }

    return providers;
  }
}
