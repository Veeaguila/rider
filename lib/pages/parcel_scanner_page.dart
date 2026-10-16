import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/rider_content.dart';

import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/rider_parcel_api.dart';
import '../services/rider_session.dart';
import '../services/rider_session_guard.dart';
import 'delivery_dashboard_page.dart';
import 'delivery_history_page.dart';

class ParcelScannerPage extends StatefulWidget {
  final RiderSession? session;
  final Widget Function(ValueChanged<String> onDetected)? scannerBuilder;
  const ParcelScannerPage({super.key, this.session, this.scannerBuilder});
  @override
  State<ParcelScannerPage> createState() => _ParcelScannerPageState();
}

class _ParcelScannerPageState extends State<ParcelScannerPage>
    with WidgetsBindingObserver, RiderSessionGuard<ParcelScannerPage> {
  @override
  late final riderSession = widget.session ?? RiderSession();
  late final api = RiderParcelApi(riderSession);
  final reference = TextEditingController();
  MobileScannerController? camera;
  bool busy = false, scanLocked = false;
  String? error, cameraError;
  bool get nativeCamera =>
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);
  @override
  void initState() {
    super.initState();
    if (nativeCamera && widget.scannerBuilder == null) {
      camera = MobileScannerController(
        detectionTimeoutMs: 600,
        returnImage: false,
      );
    }
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission dialogs themselves change lifecycle; do not fight initial permission setup.
    if (camera?.value.hasCameraPermission != true) return;
    if (state == AppLifecycleState.resumed &&
        !busy &&
        !scanLocked &&
        ModalRoute.of(context)?.isCurrent == true) {
      unawaited(startCamera());
    } else if (state != AppLifecycleState.resumed) {
      unawaited(stopCamera());
    }
  }

  Future<void> stopCamera() async {
    try {
      await camera?.stop();
    } catch (_) {
      /* Already stopped/disposed. */
    }
  }

  Future<void> startCamera() async {
    try {
      await camera?.start();
    } catch (_) {
      if (mounted) {
        setState(
          () => cameraError = 'Camera could not start. Allow camera access in device Settings, then retry or enter the reference.',
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    reference.dispose();
    unawaited(camera?.dispose());
    super.dispose();
  }

  void detected(String value) {
    if (busy || scanLocked) return;
    reference.text = value.trim();
    unawaited(lookup());
  }

  Future<void> lookup() async {
    if (busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      scanLocked = true;
      error = null;
    });
    await stopCamera();
    try {
      final parcel = await sessionAction(() => api.lookup(reference.text));
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeliveryDashboardPage(
            session: riderSession,
            parcelId: parcel['id'] as int,
          ),
        ),
      );
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = failure is SessionFailure ? failure.message : 'Parcel lookup could not be confirmed. Retry or enter the reference.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
      // Resume requires an explicit scan-again action; a label held in frame cannot resubmit.
    }
  }

  Future<void> scanAgain() async {
    setState(() {
      scanLocked = false;
      error = null;
      cameraError = null;
    });
    await startCamera();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan parcel')),
    body: ListView(
      padding: riderPagePadding(context, maxWidth: 640),
      children: [
        Text(
          'Find your assigned delivery',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Place the parcel QR code or barcode inside the guide. Only your assigned deliveries can be opened.',
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: ((MediaQuery.sizeOf(context).width - 40) / 1.2).clamp(
              180.0,
              320.0,
            ),
            child: widget.scannerBuilder != null
                ? widget.scannerBuilder!(detected)
                : !nativeCamera
                ? const ColoredBox(
                    color: Color(0xffeaf4f4),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Use the Android or iOS app for camera scanning. Enter the parcel reference below on this device.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: camera,
                        useAppLifecycleState: false,
                        onDetect: (capture) {
                          for (final barcode in capture.barcodes) {
                            final value = barcode.rawValue;
                            if (value != null && value.trim().isNotEmpty) {
                              detected(value);
                              break;
                            }
                          }
                        },
                        errorBuilder: (_, failure) => ColoredBox(
                          color: const Color(0xffeaf4f4),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                failure.errorCode ==
                                        MobileScannerErrorCode.permissionDenied
                                    ? 'Camera access is denied. Allow Camera in device Settings, then retry. You can also enter the reference below.'
                                    : 'Camera is unavailable. Retry or enter the parcel reference below.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: Center(
                          child: FractionallySizedBox(
                            widthFactor: 0.78,
                            heightFactor: 0.55,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xff00c6b7),
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (busy)
                        const ColoredBox(
                          color: Color(0x88000000),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Checking your assignment...'),
          ),
        if (cameraError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              cameraError!,
              style: const TextStyle(color: Color(0xff9b3125)),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              error!,
              style: const TextStyle(color: Color(0xff9b3125)),
            ),
          ),
        if (nativeCamera || widget.scannerBuilder != null)
          TextButton.icon(
            onPressed: busy ? null : scanAgain,
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(scanLocked ? 'Scan another parcel' : 'Retry camera'),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: reference,
          enabled: !busy,
          textCapitalization: TextCapitalization.characters,
          maxLength: 50,
          decoration: const InputDecoration(
            labelText: 'Parcel reference',
            hintText: 'ITEM-123',
            prefixIcon: Icon(Icons.inventory_2_outlined),
          ),
          onSubmitted: busy ? null : (_) => lookup(),
        ),
        FilledButton.icon(
          onPressed: busy ? null : lookup,
          icon: const Icon(Icons.search),
          label: const Text('Open delivery details'),
        ),
        TextButton(
          onPressed: busy
              ? null
              : () async {
                  await stopCamera();
                  if (mounted) setState(() => scanLocked = true);
                  if (!context.mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DeliveryHistoryPage(session: riderSession),
                    ),
                  );
                  if (mounted) setState(() => scanLocked = true);
                },
          child: const Text('Delivery History'),
        ),
      ],
    ),
  );
}
