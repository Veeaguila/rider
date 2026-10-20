import 'package:flutter/material.dart';

import '../services/rider_session.dart';
import '../services/rider_portal_api.dart';

class RiderHandovers extends StatefulWidget {
  final RiderSession session;
  const RiderHandovers({super.key, required this.session});
  @override
  State<RiderHandovers> createState() => _RiderHandoversState();
}

class _RiderHandoversState extends State<RiderHandovers> {
  List<Map<String, dynamic>> rows = [];
  int? riderId, savingId;
  bool loading = true;
  String? error, success;
  late final api = RiderPortalApi(widget.session);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final data = await api.request('rider/handovers', ready: false);
      if (!mounted) return;
      setState(() {
        rows = List<Map<String, dynamic>>.from(data['data'] as List);
        riderId = data['meta']['rider_id'] as int;
      });
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = failure is SessionFailure
              ? failure.message
              : 'Could not load supervised handovers. Refresh to retry.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> acknowledge(Map<String, dynamic> row) async {
    if (savingId != null || loading) return;
    final source = row['from_rider_id'] == riderId;
    final counterparty = source ? row['to_rider'] : row['from_rider'];
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acknowledge physical handover'),
        content: Text(
          'Shipment ${row['parcel']?['order_id']} contains ${(row['parcel_ids'] as List).length} parcel(s). '
          '${source ? 'Confirm that you physically handed all listed parcels to' : 'Confirm that you physically received all listed parcels from'} '
          '${counterparty?['name']}. Logistics must still confirm the transfer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('I confirm the physical handover'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      savingId = row['id'] as int;
      error = null;
      success = null;
    });
    try {
      await api.request(
        'rider/handovers/${row['id']}/acknowledge',
        method: 'POST',
        ready: false,
        body: {'physical_handover': true},
      );
      if (mounted) {
        setState(
          () => success =
              'Physical handover acknowledged. Await Logistics confirmation.',
        );
      }
      await load();
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = failure is SessionFailure
              ? failure.message
              : 'Could not confirm acknowledgment. Refresh before retrying.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => savingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Supervised handovers',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const Text(
            'Existing physical custody only. This does not enable new work on a suspended account.',
          ),
          TextButton(
            onPressed: loading || savingId != null ? null : load,
            child: const Text('Refresh handovers'),
          ),
          if (loading) const LinearProgressIndicator(),
          if (error != null) Text(error!),
          if (success != null) Text(success!),
          if (!loading && error == null && rows.isEmpty)
            const Text('No supervised handovers recorded.'),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shipment ${row['parcel']?['order_id']} · ${row['status']}',
                  ),
                  Text(
                    '${row['from_rider']?['name']} → ${row['to_rider']?['name']}',
                  ),
                  Text('Parcels: ${(row['parcel_ids'] as List).join(', ')}'),
                  Text('Reason: ${row['reason']}'),
                  if (row['status'] == 'pending' &&
                      (row['from_rider_id'] == riderId
                              ? row['source_acknowledged_at']
                              : row['target_acknowledged_at']) ==
                          null)
                    FilledButton(
                      onPressed: savingId != null || loading
                          ? null
                          : () => acknowledge(row),
                      child: const Text('I acknowledge physical handover'),
                    )
                  else if (row['status'] == 'pending')
                    const Text(
                      'Acknowledged by you. Await the other Rider and Logistics.',
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
