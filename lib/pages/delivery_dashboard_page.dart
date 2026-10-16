import 'dart:convert';

import 'package:flutter/material.dart';

import '../widgets/rider_content.dart';

import 'package:image_picker/image_picker.dart';

import '../services/api_error.dart';

import '../services/api_config.dart';
import '../services/parcel_address.dart';
import '../services/rider_session.dart';
import '../services/rider_session_guard.dart';
import '../widgets/failure_reason_dialog.dart';
import '../widgets/address_details.dart';
import 'login_page.dart';
import 'rider_portal_page.dart';
import 'proof_capture_page.dart';
import 'delivery_history_page.dart';
import 'parcel_scanner_page.dart';
import 'delivery_success_page.dart';

class DeliveryDashboardPage extends StatefulWidget {
  final RiderSession? session;
  final int? parcelId;
  final Future<XFile?> Function()? capturePhoto;
  const DeliveryDashboardPage({
    super.key,
    this.session,
    this.parcelId,
    this.capturePhoto,
  });

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
  bool proofFlow = false;
  int refreshRevision = 0;
  final scroll = ScrollController();

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
    if (state == AppLifecycleState.resumed && !loggingOut && !proofFlow) {
      refresh();
    }
  }

  Future<void> refresh() async {
    if (loggingOut) return;
    final revision = ++refreshRevision;
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
      if (!mounted || revision != refreshRevision) return;
      setState(() {
        deliveries =
            List<Map<String, dynamic>>.from(
                  jsonDecode(response.body)['data'] as List,
                )
                .where(
                  (parcel) =>
                      widget.parcelId == null ||
                      parcel['id'] == widget.parcelId,
                )
                .toList();
        loading = false;
      });
    } catch (exception) {
      if (!mounted || revision != refreshRevision) return;
      setState(() {
        loading = false;
        error = exception is SessionFailure ? exception.message : 'Could not confirm this delivery request. Refresh before retrying.';
      });
    }
  }

  Future<void> logout() async {
    if (loggingOut || proofFlow || actionParcelId != null) return;
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

  Future<void> markDelivered(Map<String, dynamic> delivery) async {
    if (loggingOut || proofFlow || actionParcelId != null) return;
    setState(() => proofFlow = true);
    try {
      var current = delivery;
      if (current['has_valid_photo_proof'] != true) {
        final uploaded = await openProof(current);
        if (!mounted || uploaded != true) return;
        await refresh();
        if (!mounted || error != null) return;
        final updated = deliveries
            .where((row) => row['id'] == delivery['id'])
            .firstOrNull;
        if (updated == null || updated['has_valid_photo_proof'] != true) {
          setState(
            () => error = 'Your photo could not be verified for this active delivery. Refresh and retry.',
          );
          return;
        }
        current = updated;
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm successful delivery'),
          content: Text(
            'Confirm that ${current['order_id']} was successfully delivered to the recipient. Your photo proof will be attached.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm delivery'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      if (await updateDelivery(current, 'deliver') && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DeliverySuccessPage(
              reference: current['order_id'].toString(),
              returnToScanner: widget.parcelId != null,
            ),
          ),
        );
        if (mounted && widget.parcelId != null) Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => proofFlow = false);
    }
  }

  Future<bool?> openProof(Map<String, dynamic> delivery) =>
      Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ProofCapturePage(
            openCameraOnStart: true,
            capturePhoto: widget.capturePhoto,
            parcelId: delivery['id'],
            session: riderSession,
            deliveryAddress: address(delivery),
          ),
        ),
      );

  Future<void> startDelivery(Map<String, dynamic> delivery) async {
    if (loggingOut || actionParcelId != null || proofFlow) return;
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
    if (loggingOut || proofFlow || actionParcelId != null) return;
    final reason = await showFailureReasonDialog();
    if (reason == null || reason.trim().isEmpty) {
      return;
    }
    await updateDelivery(delivery, 'fail', body: {'reason': reason.trim()});
  }

  Future<bool> updateDelivery(
    Map<String, dynamic> delivery,
    String action, {
    Map<String, String>? body,
  }) async {
    if (loggingOut || actionParcelId != null) return false;
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
        if (response.statusCode == 422) {
          try {
            if (jsonDecode(response.body)['code'] == 'valid_photo_required') {
              delivery['has_valid_photo_proof'] = false;
            }
          } catch (_) {
            /* Only trust the known backend code. */
          }
        }
        throw SessionFailure(apiErrorMessage(response));
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw Exception(
          payload['message']?.toString() ?? 'Could not update this delivery.',
        );
      }
      if (!mounted) return false;
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
      return true;
    } catch (exception) {
      if (!mounted) return false;
      if (scroll.hasClients) scroll.jumpTo(0);
      setState(() {
        actionParcelId = null;
        error = exception is SessionFailure ? exception.message : 'Could not confirm this delivery request. Refresh before retrying.';
      });
      return false;
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Order ${delivery['order_id']}',
                style: const TextStyle(fontWeight: FontWeight.w700),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AddressDetails(parcel: delivery),
          const SizedBox(height: 12),
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
                onPressed: loggingOut || proofFlow || actionParcelId != null
                    ? null
                    : () async {
                        setState(() => proofFlow = true);
                        try {
                          await openProof(delivery);
                          if (mounted) await refresh();
                        } finally {
                          if (mounted) setState(() => proofFlow = false);
                        }
                      },
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Capture Proof'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff0066cc),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: actionParcelId != null || proofFlow || loggingOut
                      ? null
                      : () => markDelivered(delivery),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Mark Delivered'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff28a745),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: actionParcelId != null
                      ? null
                      : () => markFailed(delivery),
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('Mark Failed'),
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
        title: Text(
          widget.parcelId == null ? 'Deliveries' : 'Delivery details',
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
          controller: scroll,
          padding: riderPagePadding(context),
          children: [
            if (widget.parcelId == null) ...[
              FilledButton.icon(
                onPressed: loggingOut || actionParcelId != null
                    ? null
                    : () =>
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ParcelScannerPage(session: riderSession),
                            ),
                          ).then((_) {
                            if (mounted) refresh();
                          }),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan parcel'),
              ),
              const SizedBox(height: 16),
            ],
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
                  widget.parcelId == null
                      ? 'No deliveries assigned right now.'
                      : 'This parcel is no longer in your active assignments. Refresh or check Delivery History.',
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
