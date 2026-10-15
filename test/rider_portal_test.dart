import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rider_app/pages/rider_portal_page.dart';
import 'package:rider_app/services/rider_portal_api.dart';
import 'package:rider_app/services/rider_session.dart';

import 'rider_session_test.dart' show MemoryTokens, readyProfile;

void main() {
  testWidgets(
    'chat uses recipient user ID and existing conversation contract',
    (tester) async {
      int? recipient;
      String? body;
      final session = RiderSession(
        tokens: MemoryTokens(),
        client: MockClient((request) async {
          final p = request.url.path;
          if (p.endsWith('/partner/profile')) {
            return http.Response(jsonEncode({'data': readyProfile()}), 200);
          }
          if (p.endsWith('/recipients')) {
            return http.Response(
              '{"data":[{"id":70,"name":"Sorting center","role":"sorting_center"}]}',
              200,
            );
          }
          if (p.endsWith('/conversations')) {
            return http.Response(
              jsonEncode({
                'data': body == null
                    ? []
                    : [
                        {
                          'id': 4,
                          'recipient': {'id': 70, 'name': 'Sorting center'},
                          'latest_message': {'body': body},
                          'unread_count': 0,
                        },
                      ],
              }),
              200,
            );
          }
          if (request.method == 'POST') {
            final fields = jsonDecode(request.body);
            recipient = fields['recipient_id'];
            body = fields['body'];
            return http.Response('{"conversation_id":4}', 201);
          }
          if (p.endsWith('/conversations/4')) {
            return http.Response(
              jsonEncode({
                'data': [
                  {
                    'id': 1,
                    'sender': {'name': 'Rider'},
                    'body': body,
                    'is_mine': true,
                  },
                ],
              }),
              200,
            );
          }
          throw StateError('Unexpected request $p');
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: RiderChatPage(session: session)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sorting center').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Hello sorting center');
      await tester.ensureVisible(find.text('Send message'));
      await tester.tap(find.text('Send message'));
      await tester.pumpAndSettle();
      expect(recipient, 70);
      expect(body, 'Hello sorting center');
      expect(find.text('Rider: Hello sorting center'), findsOneWidget);
    },
  );
  testWidgets(
    'pending account can inspect its status and update its own contact',
    (tester) async {
      String? contact;
      final session = RiderSession(
        tokens: MemoryTokens(),
        client: MockClient((request) async {
          expect(request.url.path, '/api/partner/profile');
          if (request.method == 'PATCH') {
            contact = jsonDecode(request.body)['contact_no'];
            return http.Response('{"message":"Profile updated."}', 200);
          }
          return http.Response(
            jsonEncode({
              'data': readyProfile({
                'name': 'Rider',
                'email': 'rider@example.test',
                'status': 'pending',
                'approvalStatus': 'pending',
                'verified': false,
                'profile': {
                  'details': {'contact_no': '09111111111'},
                },
              }),
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: RiderAccountPage(session: session)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Approval: pending'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '09123456789');
      await tester.ensureVisible(find.text('Save contact number'));
      await tester.tap(find.text('Save contact number'));
      await tester.pumpAndSettle();
      expect(contact, '09123456789');
      expect(find.text('Contact number updated.'), findsOneWidget);
    },
  );
  testWidgets('notifications reflect real unread counts and assigned tasks', (
    tester,
  ) async {
    final session = RiderSession(
      tokens: MemoryTokens(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/partner/profile')) {
          return http.Response(jsonEncode({'data': readyProfile()}), 200);
        }
        if (request.url.path.endsWith('/conversations')) {
          return http.Response(
            '{"data":[{"id":1,"recipient":{"name":"Center"},"unread_count":2},{"id":2,"unread_count":0}]}',
            200,
          );
        }
        return http.Response(
          '{"data":[{"id":52,"order_id":"ITEM-7","status":"OUT_FOR_DELIVERY"}]}',
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: RiderNotificationsPage(session: session)),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 unread messages'), findsOneWidget);
    expect(find.text('0 unread messages'), findsNothing);
    expect(find.text('Order ITEM-7'), findsOneWidget);
  });
  test(
    'expired account token is cleared and server internals are suppressed',
    () async {
      final tokens = MemoryTokens();
      final session = RiderSession(
        tokens: tokens,
        client: MockClient(
          (_) async => http.Response('<html>stack trace</html>', 401),
        ),
      );
      await expectLater(
        RiderPortalApi(session).request('partner/profile', ready: false),
        throwsA(
          isA<SessionFailure>().having((e) => e.accessDenied, 'denied', true),
        ),
      );
      expect(tokens.token, isNull);
    },
  );
}
