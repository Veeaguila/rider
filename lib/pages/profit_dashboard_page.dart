import 'package:flutter/material.dart';

import '../widgets/rider_content.dart';

import '../services/rider_earnings_api.dart';
import '../services/rider_session.dart';
import '../services/rider_session_guard.dart';
import '../theme/rider_theme.dart';

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

  Widget total(String label, String amount) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: label == 'Paid earnings'
          ? RiderColors.mintBadge
          : label == 'Pending payout'
          ? RiderColors.amberBadge
          : const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: label == 'Paid earnings'
                ? RiderColors.mintBadgeText
                : label == 'Pending payout'
                ? RiderColors.amberBadgeText
                : const Color(0xFF1E40AF),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '₱$amount',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: label == 'Paid earnings'
                ? RiderColors.mintBadgeText
                : label == 'Pending payout'
                ? RiderColors.amberBadgeText
                : const Color(0xFF1E3A8A),
          ),
        ),
      ],
    ),
  );

  String dateLabel(String value) {
    final date = DateTime.parse(value).toLocal();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: RiderColors.background,
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: RiderColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth >= 600
                      ? (constraints.maxWidth - 48) / 3
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Earnings history',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: RiderColors.text,
                ),
              ),
            ),
            if (result.rows.isEmpty) const Text('No delivery earnings yet.'),
            for (final row in result.rows)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: RiderColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: row.status == 'paid'
                          ? RiderColors.mintBadge
                          : RiderColors.amberBadge,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 20,
                      color: row.status == 'paid'
                          ? RiderColors.mintBadgeText
                          : RiderColors.amberBadgeText,
                    ),
                  ),
                  title: Text(
                    'Shipment ${row.shipmentId}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Earned: ${dateLabel(row.earnedAt)}\n${row.status == 'paid' ? 'Paid' : 'Pending payout'}${row.paidAt == null ? '' : ' · ${dateLabel(row.paidAt!)}'}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: Text(
                    '₱${row.amount}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: RiderColors.success,
                    ),
                  ),
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
