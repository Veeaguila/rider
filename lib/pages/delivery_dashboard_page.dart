import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_error.dart';

import 'package:url_launcher/url_launcher.dart';

import '../services/api_config.dart';
import '../services/parcel_address.dart';
import '../services/rider_session.dart';
import '../services/rider_session_guard.dart';
import '../widgets/failure_reason_dialog.dart';
import 'login_page.dart';
import 'rider_portal_page.dart';
import 'proof_capture_page.dart';
import 'delivery_history_page.dart';

class DeliveryDashboardPage extends StatefulWidget {
  final RiderSession? session;
  const DeliveryDashboardPage({super.key, this.session});

  @override
  State<DeliveryDashboardPage> createState() => _DeliveryDashboardPageState();
}

class _DeliveryDashboardPageState extends State<DeliveryDashboardPage>
    with WidgetsBindingObserver, RiderSessionGuard<DeliveryDashboardPage> {
  @override
  late final riderSession = widget.session ?? RiderSession();
  bool loggingOut = false;
  List<Map<String, dynamic>> deliveries = [];
  bool loading = true;
  String? error;
  String? success;
  int? actionParcelId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !loggingOut) refresh();
  }

  Future<void> refresh() async {
    if (loggingOut) return;
    setState(() {
      loading = true;
      deliveries = [];
      error = null;
      success = null;
    });
    try {
      final token = await readyToken();
      final response = await riderSession.get(
        Uri.parse(deliveriesUrl),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      await checkAuthorization(response.statusCode);
      if (response.statusCode != 200) {
        throw SessionFailure(apiErrorMessage(response));
      }
      if (!mounted) return;
      setState(() {
        deliveries = List<Map<String, dynamic>>.from(
          jsonDecode(response.body)['data'] as List,
        );
        loading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = exception is SessionFailure ? exception.message : 'Could not confirm this delivery request. Refresh before retrying.';
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

  String address(Map<String, dynamic> delivery) => deliveryAddress(delivery);

  Future<void> openMaps(Map<String, dynamic> delivery) async {
    final location = address(delivery);
    if (location.isEmpty) {
      setState(
        () => error =
            'The delivery address is unavailable. Contact the sorting center.',
      );
      return;
    }
    final uri = Uri.https('maps.google.com', '/', {'q': location});
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      setState(() => error = 'Could not open the delivery address in Maps.');
    }
  }

  Future<void> markDelivered(Map<String, dynamic> delivery) async {
    if (delivery['has_delivery_proof'] != true) {
      setState(
        () => error =
            'Upload delivery proof before marking this parcel as delivered.',
      );
      return;
    }
    await updateDelivery(delivery, 'deliver');
  }

  Future<void> startDelivery(Map<String, dynamic> delivery) async {
    if (loggingOut || actionParcelId != null) return;
    setState(() {
      actionParcelId = delivery['id'] as int;
      error = null;
      success = null;
    });
    try {
      final token = await readyToken();
      final response = await riderSession.post(
        Uri.parse('$deliveriesUrl/${delivery['id']}/start'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      await checkAuthorization(response.statusCode);
      if (response.statusCode != 200) {
        throw SessionFailure(apiErrorMessage(response));
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw Exception(
          payload['message']?.toString() ?? 'Could not start this delivery.',
        );
      }
      if (!mounted) return;
      setState(() {
        delivery['status'] = 'OUT_FOR_DELIVERY';
        success = payload['message']?.toString() ?? 'Delivery started.';
        actionParcelId = null;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        actionParcelId = null;
        error = exception is SessionFailure ? exception.message : 'Could not confirm this delivery request. Refresh before retrying.';
      });
    }
  }

  Future<void> markFailed(Map<String, dynamic> delivery) async {
    final reason = await showFailureReasonDialog();
    if (reason == null || reason.trim().isEmpty) {
      return;
    }
    await updateDelivery(delivery, 'fail', body: {'reason': reason.trim()});
  }

  Future<void> updateDelivery(
    Map<String, dynamic> delivery,
    String action, {
    Map<String, String>? body,
  }) async {
    if (loggingOut || actionParcelId != null) return;
    setState(() {
      actionParcelId = delivery['id'] as int;
      error = null;
      success = null;
    });
    try {
      final token = await readyToken();
      final response = await riderSession.post(
        Uri.parse('$deliveriesUrl/${delivery['id']}/$action'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body != null ? jsonEncode(body) : null,
      );
      await checkAuthorization(response.statusCode);
      if (response.statusCode != 200) {
        throw SessionFailure(apiErrorMessage(response));
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw Exception(
          payload['message']?.toString() ?? 'Could not update this delivery.',
        );
      }
      if (!mounted) return;
      setState(() {
        deliveries.removeWhere((item) => item['id'] == delivery['id']);
        success =
            payload['message']?.toString() ?? 'Delivery updated successfully.';
        actionParcelId = null;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && success != null) {
          setState(() => success = null);
        }
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        actionParcelId = null;
        error = exception is SessionFailure ? exception.message : 'Could not confirm this delivery request. Refresh before retrying.';
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && error != null) {
          setState(() => error = null);
        }
      });
    }
  }

  Future<String?> showFailureReasonDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => const FailureReasonDialog(),
    );
  }

  Widget deliveryCard(Map<String, dynamic> delivery) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffdce7e2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_shipping_outlined,
                color: Color(0xff008b8b),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Order ${delivery['order_id']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xffffefd0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  delivery['status'] == 'AT_SORTING_CENTER'
                      ? 'ASSIGNED'
                      : 'IN TRANSIT',
                  style: TextStyle(
                    color: Color(0xff995800),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Delivery address: ${address(delivery).isEmpty ? 'Unavailable' : address(delivery)}',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              color: const Color(0xffeaf4f4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffb8dada)),
            ),
            child: const Column(
              children: [
                Icon(Icons.map_outlined, size: 28, color: Color(0xff008b8b)),
                SizedBox(height: 6),
                Text(
                  'Delivery location',
                  style: TextStyle(
                    color: Color(0xff006f6f),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => openMaps(delivery),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Open in Maps'),
            ),
          ),
          if (delivery['status'] == 'AT_SORTING_CENTER')
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: actionParcelId != null
                    ? null
                    : () => startDelivery(delivery),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Delivery'),
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProofCapturePage(
                        parcelId: delivery['id'],
                        session: riderSession,
                        deliveryAddress: address(delivery),
                      ),
                    ),
                  ).then((_) {
                    if (mounted) refresh();
                  });
                },
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Capture Proof'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff0066cc),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        actionParcelId != null ||
                            delivery['has_delivery_proof'] != true
                        ? null
                        : () => markDelivered(delivery),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Mark Delivered'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff28a745),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: actionParcelId != null
                        ? null
                        : () => markFailed(delivery),
                    icon: const Icon(Icons.report_problem_outlined),
                    label: const Text('Mark Failed'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/alona/alonalogo1.png',
              height: 36,
              width: 36,
            ),
            const SizedBox(width: 10),
            const Text('Deliveries'),
          ],
        ),
        actions: [
          riderTools(context, riderSession),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Delivery history',
            onPressed: () =>
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeliveryHistoryPage(session: riderSession),
                  ),
                ).then((_) {
                  if (mounted) refresh();
                }),
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
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xff008b8b),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assigned deliveries',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Record the outcome of each dispatched parcel.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${deliveries.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (error != null) ...[
              const SizedBox(height: 16),
              _statusMessage(error!),
            ],
            if (success != null) ...[
              const SizedBox(height: 16),
              _successMessage(success!),
            ],
            if (loading) ...[
              const SizedBox(height: 40),
              const Center(child: CircularProgressIndicator()),
            ] else ...[
              const SizedBox(height: 28),
              if (deliveries.isEmpty)
                Text(
                  'No deliveries assigned right now.',
                  style: TextStyle(color: Colors.grey.shade700),
                )
              else
                ...deliveries.map(deliveryCard),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusMessage(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffffe6e2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xff9b3125))),
    );
  }

  Widget _successMessage(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffdff4e9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xff176b43))),
    );
  }
}
