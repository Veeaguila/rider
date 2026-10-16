import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/rider_content.dart';

import '../services/rider_session.dart';
import '../services/rider_session_guard.dart';
import '../services/rider_portal_api.dart';
import 'rider_portal_page.dart'
    show RiderAccountPage, RiderChatPage, portalError;
import 'pickup_dashboard_page.dart';
import 'delivery_dashboard_page.dart';
import 'delivery_history_page.dart';
import 'profit_dashboard_page.dart';

class RiderNotificationsPage extends StatefulWidget {
  final RiderSession? session;
  const RiderNotificationsPage({super.key, this.session});
  @override
  State<RiderNotificationsPage> createState() => _RiderNotificationsPageState();
}

class _RiderNotificationsPageState extends State<RiderNotificationsPage>
    with WidgetsBindingObserver, RiderSessionGuard<RiderNotificationsPage> {
  @override
  late final riderSession = widget.session ?? RiderSession();
  late final api = RiderPortalApi(riderSession);
  Timer? poll;
  final rows = <Map<String, dynamic>>[];
  bool loading = false, opening = false;
  int? unread;
  int page = 1, lastPage = 1;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    startPolling();
  }

  void startPolling() {
    poll?.cancel();
    poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !opening && ModalRoute.of(context)?.isCurrent == true) {
        load(quiet: true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      startPolling();
      load(quiet: true);
    } else {
      poll?.cancel();
    }
  }

  @override
  void dispose() {
    poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> load({bool more = false, bool quiet = false}) async {
    if (loading || opening) return;
    setState(() {
      loading = true;
      if (!quiet) error = null;
    });
    try {
      final target = more ? page + 1 : 1;
      final payload = await sessionAction(
        () => api.request('rider/notifications?page=$target', ready: false),
      );
      if (!mounted) return;
      setState(() {
        if (!more) rows.clear();
        final ids = rows.map((row) => row['id']).toSet();
        for (final row in List<Map<String, dynamic>>.from(
          payload['data'] as List,
        )) {
          if (ids.add(row['id'])) rows.add(row);
        }
        unread = (payload['unread_count'] as num).toInt();
        page = (payload['current_page'] as num).toInt();
        lastPage = (payload['last_page'] as num).toInt();
        error = null;
      });
    } catch (failure) {
      if (mounted) setState(() => error = portalError(failure));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> open(Map<String, dynamic> row) async {
    if (opening || loading) return;
    setState(() {
      opening = true;
      error = null;
    });
    try {
      await sessionAction(
        () => api.request(
          'rider/notifications/${row['id']}/read',
          method: 'POST',
          ready: false,
        ),
      );
      if (!mounted) return;
      final data = row['data'] as Map? ?? {};
      final screen = data['screen'];
      if (screen != 'account') await readyToken();
      if (!mounted) return;
      final Widget destination = switch (screen) {
        'pickups' => PickupDashboardPage(session: riderSession),
        'deliveries' => DeliveryDashboardPage(session: riderSession),
        'history' => DeliveryHistoryPage(session: riderSession),
        'earnings' => ProfitDashboardPage(session: riderSession),
        'chat' => RiderChatPage(
          session: riderSession,
          conversationId: (data['conversation_id'] as num?)?.toInt(),
        ),
        _ => RiderAccountPage(session: riderSession),
      };
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => destination),
      );
    } catch (failure) {
      if (mounted) setState(() => error = portalError(failure));
    } finally {
      if (mounted) {
        setState(() => opening = false);
        await load();
      }
    }
  }

  String timestamp(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    return date == null
        ? 'Time unavailable'
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${TimeOfDay.fromDateTime(date).format(context)}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: loading || opening ? null : () => load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () => load(),
      child: ListView(
        padding: riderPagePadding(context, maxWidth: 720),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(
            unread == null
                ? 'Unread count unavailable'
                : '$unread unread notifications',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          if (loading || opening) const LinearProgressIndicator(),
          if (error != null)
            Text(error!, style: const TextStyle(color: Color(0xff9b3125))),
          if (!loading && rows.isEmpty && error == null)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('You are up to date.'),
            ),
          for (final row in rows)
            Card(
              child: ListTile(
                leading: Icon(
                  row['read_at'] == null
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_none,
                  color: const Color(0xff008b8b),
                ),
                title: Text(
                  row['title'].toString(),
                  style: TextStyle(
                    fontWeight: row['read_at'] == null
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  '${row['body']}\n${timestamp(row['created_at'])}\n${row['read_at'] == null ? 'Unread' : 'Read'}',
                ),
                onTap: loading || opening ? null : () => open(row),
              ),
            ),
          if (page < lastPage)
            TextButton(
              onPressed: loading || opening ? null : () => load(more: true),
              child: const Text('Load older notifications'),
            ),
          const SizedBox(height: 12),
          const Text('Updates while this screen is open.'),
        ],
      ),
    ),
  );
}
