import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rider_app/services/rider_session.dart';
import 'package:rider_app/widgets/rider_handovers.dart';

import 'rider_session_test.dart' show MemoryTokens;

void main() {
  testWidgets(
    'physical handover requires explicit confirmation and never marks parcels delivered',
    (tester) async {
      var acknowledged = false;
      final posts = <String>[];
      final session = RiderSession(
        tokens: MemoryTokens(),
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test-token');
          expect(request.url.path.contains('partner/profile'), false);
          if (request.method == 'POST') {
            posts.add(request.url.path);
            expect(jsonDecode(request.body), {'physical_handover': true});
            acknowledged = true;
            return http.Response('{"data":{"status":"pending"}}', 200);
          }
          return http.Response(
            jsonEncode({
              'meta': {'rider_id': 1},
              'data': [
                {
                  'id': 9,
                  'status': 'pending',
                  'from_rider_id': 1,
                  'to_rider_id': 2,
                  'from_rider': {'name': 'Suspended source'},
                  'to_rider': {'name': 'Approved receiver'},
                  'parcel': {'order_id': 'ITEM-7', 'status': 'PICKED_UP'},
                  'parcel_ids': [42, 43],
                  'reason': 'Approved whole-shipment physical handover.',
                  'source_acknowledged_at': acknowledged
                      ? '2026-10-20T12:00:00Z'
                      : null,
                  'target_acknowledged_at': null,
                },
              ],
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RiderHandovers(session: session)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('I acknowledge physical handover'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('physically handed all listed parcels to'),
        findsOneWidget,
      );
      expect(posts, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(posts, isEmpty);
      await tester.tap(find.text('I acknowledge physical handover'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I confirm the physical handover'));
      await tester.pumpAndSettle();
      expect(posts, ['/api/rider/handovers/9/acknowledge']);
      expect(
        find.text('Acknowledged by you. Await the other Rider and Logistics.'),
        findsOneWidget,
      );
      expect(find.text('I acknowledge physical handover'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
