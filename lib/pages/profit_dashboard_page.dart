import 'package:flutter/material.dart';

import '../widgets/rider_content.dart';

import '../services/rider_earnings_api.dart';
import '../services/rider_session.dart';
import '../services/rider_session_guard.dart';

class ProfitDashboardPage extends StatefulWidget {
  final RiderSession? session;
  const ProfitDashboardPage({super.key, this.session});

  @override
  State<ProfitDashboardPage> createState() => _ProfitDashboardPageState();
}

class _ProfitDashboardPageState extends State<ProfitDashboardPage>
    with WidgetsBindingObserver, RiderSessionGuard<ProfitDashboardPage> {
  @override
  late final riderSession = widget.session ?? RiderSession();
  late final api = RiderEarningsApi(riderSession);
  RiderEarningsPage? data;
  bool loading = true;
  String? error;
  int revision = 0;

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
    if (state == AppLifecycleState.resumed) load();
  }

  Future<void> load({int page = 1}) async {
    final current = ++revision;
    setState(() {
      loading = true;
      error = null;
      data = null;
    });
    try {
      final result = await sessionAction(() => api.load(page: page));
      if (!mounted || current != revision) return;
      setState(() {
        data = result;
        loading = false;
      });
    } catch (failure) {
      if (!mounted || current != revision) return;
      setState(() {
        loading = false;
        error = failure is SessionFailure
            ? failure.message
            : 'Could not load earnings. Please refresh and retry.';
      });
    }
  }

  Widget total(String label, String amount) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      const SizedBox(height: 8),
      Text(
        '₱$amount',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );

  String dateLabel(String value) {
    final date = DateTime.parse(value).toLocal();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Delivery earnings'),
      actions: [
        IconButton(
          tooltip: 'Refresh earnings',
          onPressed: loading ? null : () => load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () => load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: riderPagePadding(context),
        children: [
          if (loading) const Center(child: CircularProgressIndicator()),
          if (error != null) ...[
            Text(error!, style: const TextStyle(color: Color(0xff9b3125))),
            TextButton(onPressed: () => load(), child: const Text('Retry')),
          ],
          if (data case final result?) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 600
                        ? (constraints.maxWidth - 48) / 3
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 24,
                      runSpacing: 24,
                      children: [
                        SizedBox(
                          width: width,
                          child: total('Total earned', result.total),
                        ),
                        SizedBox(
                          width: width,
                          child: total('Pending payout', result.pending),
                        ),
                        SizedBox(
                          width: width,
                          child: total('Paid earnings', result.paid),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Earnings history',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            if (result.rows.isEmpty) const Text('No delivery earnings yet.'),
            for (final row in result.rows)
              Card(
                child: ListTile(
                  title: Text('Shipment ${row.shipmentId}'),
                  subtitle: Text(
                    'Earned: ${dateLabel(row.earnedAt)}\n${row.status == 'paid' ? 'Paid' : 'Pending payout'}${row.paidAt == null ? '' : ' · ${dateLabel(row.paidAt!)}'}',
                  ),
                  trailing: Text('₱${row.amount}'),
                ),
              ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: result.page <= 1
                      ? null
                      : () => load(page: result.page - 1),
                  child: const Text('Previous'),
                ),
                Text('Page ${result.page} of ${result.lastPage}'),
                TextButton(
                  onPressed: result.page >= result.lastPage
                      ? null
                      : () => load(page: result.page + 1),
                  child: const Text('Next'),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
