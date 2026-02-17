import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/network/telegram_api_client.dart';

enum EnergyPackId {
  full,
  weekUnlimited,
  monthUnlimited,
  yearUnlimited,
  fiveCardsSingle,
  selfAnalysisReport,
}

extension EnergyPackIdValue on EnergyPackId {
  String get value {
    return switch (this) {
      EnergyPackId.full => 'full',
      EnergyPackId.weekUnlimited => 'week_unlimited',
      EnergyPackId.monthUnlimited => 'month_unlimited',
      EnergyPackId.yearUnlimited => 'year_unlimited',
      EnergyPackId.fiveCardsSingle => 'five_cards_single',
      EnergyPackId.selfAnalysisReport => 'self_analysis_report',
    };
  }
}

class EnergyInvoiceData {
  const EnergyInvoiceData({
    required this.packId,
    required this.energyAmount,
    required this.starsAmount,
    required this.invoiceLink,
    required this.payload,
  });

  final EnergyPackId packId;
  final int energyAmount;
  final int starsAmount;
  final String invoiceLink;
  final String payload;
}

class EnergyTopUpRepositoryException implements Exception {
  const EnergyTopUpRepositoryException({
    required this.message,
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  @override
  String toString() {
    if (statusCode == null) {
      return 'EnergyTopUpRepositoryException($message)';
    }
    return 'EnergyTopUpRepositoryException($statusCode, $message)';
  }
}

class EnergyTopUpRepository {
  static const Duration _invoiceTimeout = Duration(seconds: 20);
  static const Duration _confirmTimeout = Duration(seconds: 12);

  Future<EnergyInvoiceData> createInvoice(EnergyPackId packId) async {
    final uri = Uri.parse(ApiConfig.apiBaseUrl).replace(
      path: '/api/payments/stars/invoice',
    );
    final client = TelegramApiClient(http.Client());
    try {
      final response = await client
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'packId': packId.value,
            }),
          )
          .timeout(_invoiceTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw EnergyTopUpRepositoryException(
          statusCode: response.statusCode,
          message: 'Failed to create invoice',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const EnergyTopUpRepositoryException(
          message: 'Invalid invoice response',
        );
      }
      final invoiceLink = decoded['invoiceLink'];
      final energyAmount = decoded['energyAmount'];
      final starsAmount = decoded['starsAmount'];
      final payload = decoded['payload'];
      if (invoiceLink is! String || invoiceLink.trim().isEmpty) {
        throw const EnergyTopUpRepositoryException(
          message: 'Invoice link is missing',
        );
      }
      if (energyAmount is! num || starsAmount is! num) {
        throw const EnergyTopUpRepositoryException(
          message: 'Invoice pack data is invalid',
        );
      }
      if (payload is! String || payload.trim().isEmpty) {
        throw const EnergyTopUpRepositoryException(
          message: 'Invoice payload is missing',
        );
      }
      return EnergyInvoiceData(
        packId: packId,
        energyAmount: energyAmount.round(),
        starsAmount: starsAmount.round(),
        invoiceLink: invoiceLink,
        payload: payload,
      );
    } finally {
      client.close();
    }
  }

  Future<void> confirmInvoiceResult({
    required String payload,
    required String status,
  }) async {
    final uri = Uri.parse(ApiConfig.apiBaseUrl).replace(
      path: '/api/payments/stars/confirm',
    );
    final client = TelegramApiClient(http.Client());
    try {
      final response = await client
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'payload': payload,
              'status': status,
            }),
          )
          .timeout(_confirmTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw EnergyTopUpRepositoryException(
          statusCode: response.statusCode,
          message: 'Failed to confirm invoice status',
        );
      }
    } finally {
      client.close();
    }
  }
}
