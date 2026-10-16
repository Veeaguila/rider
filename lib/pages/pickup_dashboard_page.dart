import 'dart:convert';

import 'package:flutter/material.dart';

import '../widgets/rider_content.dart';

import '../services/api_error.dart';

import '../services/api_config.dart';
import '../widgets/address_details.dart';
import '../services/rider_session.dart';
import '../services/rider_session_guard.dart';
import 'delivery_dashboard_page.dart';
import 'login_page.dart';
import 'rider_portal_page.dart';

class PickupDashboardPage extends StatefulWidget {
  final RiderSession? session;
  const PickupDashboardPage({super.key, this.session});

  @override
  State<PickupDashboardPage> createState() => _PickupDashboardPageState();
}

class _PickupDashboardPageState extends State<PickupDashboardPage>
    with WidgetsBindingObserver, RiderSessionGuard<PickupDashboardPage> {
  @override
  late final riderSession = widget.session ?? RiderSession();
  bool loggingOut = false;
  final scroll = ScrollController();
  int? actionParcelId;
  int refreshRevision = 0;
  List<Map<String, dynamic>> available = [];
  List<Map<String, dynamic>> mine = [];
  bool loading = true;
  String? error;
  String? success;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    scroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !loggingOut) refresh();
  }

  Future<void> refresh() async {
    if (loggingOut) return;
    final revision = ++refreshRevision;
    setState(() {
      loading = true;
      available = [];
      mine = [];
      error = null;
    });
    try {
      final token = await readyToken();
      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final availableResponse = await riderSession.get(
        Uri.parse(pickupsAvailableUrl),
        headers: headers,
      );
      await checkAuthorization(availableResponse.statusCode);
      if (availableResponse.statusCode != 200) {
        throw SessionFailure(apiErrorMessage(availableResponse));
      }
      final mineResponse = await riderSession.get(
        Uri.parse(pickupsMineUrl),
        headers: headers,
      );
      await checkAuthorization(mineResponse.statusCode);
      if (mineResponse.statusCode != 200) {
        throw SessionFailure(apiErrorMessage(mineResponse));
      }
      if (!mounted || revision != refreshRevision) return;
      setState(() {
        available = List<Map<String, dynamic>>.from(
          jsonDecode(availableResponse.body)['data'] as List,
        );
        mine = List<Map<String, dynamic>>.from(
          jsonDecode(mineResponse.body)['data'] as List,
        );
        loading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = exception is SessionFailure
            ? exception.message
            : 'Could not load pickup jobs. Refresh and retry.';
      });
    }
  }

  Future<void> logout() async {
    if (loggingOut) return;
    setState(() => loggingOut = true);
    try {
      await riderSession.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (failure) {
      if (!mounted) return;
      setState(
        () => error = failure is SessionFailure
            ? failure.message
            : 'Could not clear your session. Please retry logout.',
      );
    } finally {
      if (mounted) setState(() => loggingOut = false);
    }
  }

  Future<void> accept(Map<String, dynamic> pickup) =>
      pickupAction(pickup, 'accept');

  Future<void> pickupAction(Map<String, dynamic> pickup, String action) async {
    if (loggingOut || actionParcelId != null) return;
    setState(() {
      actionParcelId = pickup['id'] as int;
      error = null;
      success = null;
    });
    try {
      final token = await readyToken();
      final response = await riderSession.post(
        Uri.parse('$pickupsUrl/${pickup['id']}/$action'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      await checkAuthorization(response.statusCode);
      if (response.statusCode != 200) {
        throw SessionFailure(apiErrorMessage(response));
      }
      await refresh();
      if (mounted) {
        setState(
          () => success = action == 'confirm'
              ? 'Pickup confirmed successfully.'
              : 'Pickup accepted successfully.',
        );
      }
    } catch (failure) {
      if (!mounted) return;
      final message = failure is SessionFailure
          ? failure.message
          : 'Could not confirm this pickup action. Refresh before retrying.';
      if (failure is! SessionFailure || !failure.accessDenied) await refresh();
      if (mounted) {
        if (scroll.hasClients) scroll.jumpTo(0);
        setState(() => error = message);
      }
    } finally {
      if (mounted) setState(() => actionParcelId = null);
    }
  }

  Future<void> confirmPickup(Map<String, dynamic> pickup) =>
      pickupAction(pickup, 'confirm');

  Widget pickupCard(Map<String, dynamic> pickup, {required bool isMine}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order ${pickup['order_id']}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          AddressDetails(parcel: pickup, pickup: true),
          if (!isMine) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: actionParcelId != null ? null : () => accept(pickup),
                icon: const Icon(Icons.handshake_outlined),
                label: const Text('Accept pickup'),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: actionParcelId != null
                        ? null
                        : () => confirmPickup(pickup),
                    icon: const Icon(Icons.check),
                    label: const Text('Confirm Pickup'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget jobSection(
    String title,
    List<Map<String, dynamic>> jobs, {
    required bool isMine,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (jobs.isEmpty)
          Text(
            isMine
                ? 'No accepted pickups yet.'
                : 'No pickup jobs are available right now.',
            style: TextStyle(color: Colors.grey.shade700),
          )
        else
          ...jobs.map((pickup) => pickupCard(pickup, isMine: isMine)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pickups'),
        actions: [
          riderTools(context, riderSession),
          IconButton(
            tooltip: 'Deliveries',
            onPressed: () => Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) =>
                        DeliveryDashboardPage(session: riderSession),
                  ),
                )
                .then((_) {
                  if (mounted) refresh();
                }),
            icon: const Icon(Icons.local_shipping_outlined),
          ),
          IconButton(
            onPressed: loading ? null : refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: loggingOut ? null : logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          controller: scroll,
          padding: riderPagePadding(context),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xff008b8b),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your pickup work queue',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _summaryCount('Available pickups', available.length),
                      const SizedBox(width: 12),
                      _summaryCount('Accepted by you', mine.length),
                    ],
                  ),
                ],
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              _statusMessage(error!, false),
            ],
            if (success != null) ...[
              const SizedBox(height: 16),
              _statusMessage(success!, true),
            ],
            if (loading) ...[
              const SizedBox(height: 40),
              const Center(child: CircularProgressIndicator()),
            ] else ...[
              const SizedBox(height: 28),
              jobSection('Available pickup jobs', available, isMine: false),
              const SizedBox(height: 28),
              jobSection('My accepted pickups', mine, isMine: true),
            ],
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _summaryCount(String label, int count) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusMessage(String text, bool isSuccess) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSuccess ? const Color(0xffdff4e9) : const Color(0xffffe6e2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isSuccess ? const Color(0xff176b43) : const Color(0xff9b3125),
        ),
      ),
    );
  }
}
