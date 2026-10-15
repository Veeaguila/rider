import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'token_store.dart';

class SessionFailure implements Exception {
  final String message;
  final bool accessDenied;
  const SessionFailure(this.message, {this.accessDenied = false});
  @override
  String toString() => message;
}

class RiderSession {
  final TokenStore tokens;
  final http.Client? client;
  final Duration timeout;
  RiderSession({
    TokenStore? tokens,
    this.client,
    this.timeout = const Duration(seconds: 15),
  }) : tokens = tokens ?? TokenStore();

  Future<String> requireReadyToken() async {
    final token = await tokens.read();
    if (token == null || token.isEmpty) {
      throw const SessionFailure(
        'Your session has expired. Please sign in.',
        accessDenied: true,
      );
    }
    http.Response response;
    try {
      final uri = Uri.parse(partnerProfileUrl);
      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
      response =
          await (client != null
                  ? client!.get(uri, headers: headers)
                  : http.get(uri, headers: headers))
              .timeout(timeout);
    } catch (_) {
      throw const SessionFailure(
        'Could not verify your account. Check your connection and retry.',
      );
    }
    if (response.statusCode == 401) {
      await tokens.clear();
      throw const SessionFailure(
        'Your session has expired. Please sign in.',
        accessDenied: true,
      );
    }
    if (response.statusCode == 403) {
      throw const SessionFailure(
        'Your account cannot access Rider operations. Please sign in to check its status.',
        accessDenied: true,
      );
    }
    if (response.statusCode != 200) {
      throw const SessionFailure(
        'Could not verify your account. Please retry shortly.',
      );
    }
    Map<String, dynamic> data;
    try {
      final payload = jsonDecode(response.body);
      data = Map<String, dynamic>.from(payload['data'] as Map);
      if (data['is_active'] is! bool ||
          data['verification_required'] is! bool ||
          data['verified'] is! bool) {
        throw const FormatException();
      }
    } catch (_) {
      throw const SessionFailure(
        'Could not verify your account. Please retry shortly.',
      );
    }
    String? reason;
    if (data['role'] != 'rider') {
      reason = 'This account is not registered as a rider.';
    } else if (data['status'] == 'pending' ||
        data['approvalStatus'] == 'pending') {
      reason = 'Your rider registration is awaiting approval.';
    } else if (data['status'] != 'approved' ||
        data['approvalStatus'] != 'approved') {
      reason = 'Your rider account is unavailable or suspended. Contact your sorting center.';
    } else if (data['is_active'] != true) {
      reason = 'Your rider account has been deactivated. Contact your sorting center.';
    } else if (data['verification_required'] == true &&
        data['verified'] != true) {
      reason =
          'Please verify your email before accepting pickups or deliveries.';
    }
    if (reason != null) throw SessionFailure(reason, accessDenied: true);
    return token;
  }

  Future<void> logout() async {
    final token = await tokens.read();
    if (token == null || token.isEmpty) {
      await tokens.clear();
      return;
    }
    http.Response response;
    try {
      final uri = Uri.parse(logoutApiUrl);
      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
      response =
          await (client != null
                  ? client!.post(uri, headers: headers)
                  : http.post(uri, headers: headers))
              .timeout(timeout);
    } catch (_) {
      throw const SessionFailure(
        'Logout could not be confirmed. Your server token may still be active. Check your connection and retry.',
      );
    }
    // A 401 from Sanctum confirms this token is already unusable.
    if (response.statusCode != 200 && response.statusCode != 401) {
      throw const SessionFailure(
        'Logout could not be confirmed. Your server token may still be active. Please retry.',
      );
    }
    if (response.statusCode == 200) {
      try {
        final payload = jsonDecode(response.body);
        if (payload is! Map || payload['message'] != 'Signed out.') {
          throw const FormatException();
        }
      } catch (_) {
        throw const SessionFailure(
          'Logout could not be confirmed. Your server token may still be active. Please retry.',
        );
      }
    }
    await tokens.clear();
  }
}
