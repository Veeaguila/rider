import 'dart:convert';

import 'package:flutter/material.dart';

import '../widgets/rider_content.dart';

import '../services/api_config.dart';
import '../services/api_error.dart';
import '../services/parcel_address.dart';
import '../services/rider_session.dart';
import '../services/rider_session_guard.dart';
import 'profit_dashboard_page.dart';

class DeliveryHistoryPage extends StatefulWidget {
  final RiderSession? session;
  const DeliveryHistoryPage({super.key, this.session});
  @override
  State<DeliveryHistoryPage> createState() => _DeliveryHistoryPageState();
}

class _DeliveryHistoryPageState extends State<DeliveryHistoryPage>
    with WidgetsBindingObserver, RiderSessionGuard<DeliveryHistoryPage> {
  @override
  late final riderSession = widget.session ?? RiderSession();
  List<Map<String, dynamic>> rows = [];
  Map<String, dynamic> summary = {};
  int page = 1, lastPage = 1, revision = 0;
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      load();
    }
  }

  Future<void> load({int? target}) async {
    final current = ++revision;
    setState(() {
      loading = true;
      error = null;
      rows = [];
    });
    try {
      final token = await readyToken();
      final uri = Uri.parse(deliveriesUrl).replace(
        queryParameters: {'view': 'history', 'page': '${target ?? page}'},
      );
      final response = await riderSession.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      await checkAuthorization(response.statusCode);
      if (response.statusCode != 200) {
        throw SessionFailure(apiErrorMessage(response));
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final data = List<Map<String, dynamic>>.from(payload['data'] as List);
      if (!mounted || current != revision) return;
      setState(() {
        rows = data;
        summary = Map<String, dynamic>.from(payload['summary'] as Map);
        page = (payload['meta']['current_page'] as num).toInt();
        lastPage = (payload['meta']['last_page'] as num).toInt();
        loading = false;
      });
    } catch (failure) {
      if (mounted && current == revision) {
        setState(() {
          loading = false;
          error = failure is SessionFailure
              ? failure.message
              : 'Could not load delivery history. Refresh and retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Delivery History'),
      actions: [
        IconButton(
          onPressed: loading ? null : () => load(),
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
    ),
    body: ListView(
      padding: riderPagePadding(context),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Delivered: ${summary['DELIVERED'] ?? 0}   Failed: ${summary['FAILED_RETURNED'] ?? 0}   Active: ${summary['active'] ?? 0}',
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfitDashboardPage(session: riderSession),
              ),
            ),
            child: const Text('View earnings'),
          ),
        ),
        if (loading) const Center(child: CircularProgressIndicator()),
        if (error != null)
          Text(error!, style: const TextStyle(color: Color(0xff9b3125))),
        if (!loading && error == null && rows.isEmpty)
          const Text('No completed deliveries yet.'),
        for (final row in rows)
          Card(
            child: ListTile(
              title: Text('Order ${row['order_id']}'),
              subtitle: Text(
                '${row['status'].toString().replaceAll('_', ' ')}\n${deliveryAddress(row)}${row['failure_reason'] == null ? '' : '\n${row['failure_reason']}'}${row['delivered_at'] == null ? '' : '\nCompleted: ${row['delivered_at']}'}',
              ),
              isThreeLine: true,
            ),
          ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            TextButton(
              onPressed: loading || page <= 1
                  ? null
                  : () => load(target: page - 1),
              child: const Text('Previous'),
            ),
            Text('Page $page of $lastPage'),
            TextButton(
              onPressed: loading || page >= lastPage
                  ? null
                  : () => load(target: page + 1),
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    ),
  );
}
