import 'package:flutter/material.dart';

import '../widgets/rider_content.dart';

import '../services/rider_session.dart';
import '../services/rider_session_guard.dart';
import '../services/rider_portal_api.dart';
import 'rider_account_page.dart';
export 'rider_account_page.dart';
import 'rider_notifications_page.dart';
export 'rider_notifications_page.dart';
import 'profit_dashboard_page.dart';
import '../theme/rider_theme.dart';

Widget riderTools(BuildContext context, RiderSession session) =>
    PopupMenuButton<String>(
      tooltip: 'Rider tools',
      onSelected: (value) {
        final page = value == 'earnings'
            ? ProfitDashboardPage(session: session)
            : value == 'chat'
            ? RiderChatPage(session: session)
            : value == 'notifications'
            ? RiderNotificationsPage(session: session)
            : RiderAccountPage(session: session);
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'earnings', child: Text('Earnings')),
        PopupMenuItem(value: 'chat', child: Text('Messages')),
        PopupMenuItem(value: 'notifications', child: Text('Notifications')),
        PopupMenuItem(value: 'account', child: Text('My account')),
      ],
    );

class RiderChatPage extends StatefulWidget {
  final RiderSession? session;
  final int? conversationId;
  const RiderChatPage({super.key, this.session, this.conversationId});
  @override
  State<RiderChatPage> createState() => _RiderChatPageState();
}

class _RiderChatPageState extends State<RiderChatPage>
    with RiderSessionGuard<RiderChatPage> {
  @override
  late final riderSession = widget.session ?? RiderSession();
  late final api = RiderPortalApi(riderSession);
  final text = TextEditingController();
  List<Map<String, dynamic>> recipients = [], conversations = [], messages = [];
  int? recipientId, conversationId;
  int revision = 0;
  bool loading = true, opening = false, sending = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await sessionAction(
        () => Future.wait([
          api.request('rider/messages/recipients'),
          api.request('rider/messages/conversations'),
        ]),
      );
      if (!mounted) return;
      setState(() {
        recipients = List<Map<String, dynamic>>.from(result[0]['data'] as List);
        if (!recipients.any((r) => r['id'] == recipientId)) recipientId = null;
        conversations = List<Map<String, dynamic>>.from(
          result[1]['data'] as List,
        );
        loading = false;
      });
      if (widget.conversationId != null && conversationId == null) {
        await open(widget.conversationId!);
      }
    } catch (failure) {
      if (mounted) {
        setState(() {
          loading = false;
          error = portalError(failure);
        });
      }
    }
  }

  Future<void> open(int id) async {
    if (sending) return;
    final current = ++revision;
    setState(() {
      conversationId = id;
      messages = [];
      opening = true;
      error = null;
    });
    try {
      final payload = await sessionAction(
        () => api.request('rider/messages/conversations/$id'),
      );
      if (!mounted || current != revision) return;
      setState(() {
        messages = List<Map<String, dynamic>>.from(payload['data'] as List);
        opening = false;
        for (final row in conversations) {
          if (row['id'] == id) {
            row['unread_count'] = 0;
          }
        }
      });
    } catch (failure) {
      if (mounted && current == revision) {
        setState(() {
          opening = false;
          error = portalError(failure);
        });
      }
    }
  }

  Future<void> send() async {
    if (sending ||
        opening ||
        text.text.trim().isEmpty ||
        (conversationId == null && recipientId == null)) {
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      final id = conversationId;
      final payload = await sessionAction(
        () => api.request(
          id == null ? 'rider/messages' : 'rider/messages/conversations/$id',
          method: 'POST',
          body: {
            'body': text.text.trim(),
            if (id == null) 'recipient_id': recipientId,
          },
        ),
      );
      if (!mounted) return;
      final savedId = (payload['conversation_id'] as num).toInt();
      text.clear();
      setState(() => sending = false);
      await open(savedId);
      await load();
    } catch (failure) {
      if (mounted) setState(() => error = portalError(failure));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: RiderColors.background,
    appBar: AppBar(
      title: const Text('Messages'),
      actions: [
        IconButton(
          onPressed: loading || sending ? null : load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
    ),
    body: ListView(
      padding: riderPagePadding(context, maxWidth: 720),
      children: [
        if (loading) const Center(child: CircularProgressIndicator()),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(error!, style: const TextStyle(color: RiderColors.danger)),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RiderColors.border),
          ),
          child: DropdownButtonFormField<int>(
            key: ValueKey('recipient-$recipientId-${recipients.length}'),
            initialValue: recipientId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'New message to'),
            items: recipients
                .map(
                  (r) => DropdownMenuItem<int>(
                    value: (r['id'] as num).toInt(),
                    child: Text(r['name'].toString()),
                  ),
                )
                .toList(),
            onChanged: sending || opening
                ? null
                : (id) => setState(() {
                    recipientId = id;
                    conversationId = null;
                    messages = [];
                    revision++;
                  }),
          ),
        ),
        const SizedBox(height: 12),
        for (final row in conversations)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: RiderColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: RiderColors.teal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: RiderColors.teal,
                    size: 20,
                  ),
                ),
                title: Text(
                  row['recipient']?['name']?.toString() ?? 'Conversation',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(row['latest_message']?['body']?.toString() ?? ''),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (row['unread_count'] ?? 0) > 0
                        ? RiderColors.redBadge
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${row['unread_count'] ?? 0} unread',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: (row['unread_count'] ?? 0) > 0
                          ? RiderColors.redBadgeText
                          : RiderColors.textSecondary,
                    ),
                  ),
                ),
                onTap: sending ? null : () => open((row['id'] as num).toInt()),
              ),
            ),
          ),
        if (opening) const LinearProgressIndicator(),
        for (final message in messages)
          Align(
            alignment: message['is_mine'] == true
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              decoration: BoxDecoration(
                color: message['is_mine'] == true
                    ? RiderColors.teal
                    : Colors.white,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: message['is_mine'] == true
                      ? const Radius.circular(2)
                      : const Radius.circular(16),
                  bottomLeft: message['is_mine'] == true
                      ? const Radius.circular(16)
                      : const Radius.circular(2),
                ),
                border: message['is_mine'] == true
                    ? null
                    : Border.all(color: RiderColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '${message['sender']?['name'] ?? 'Rider'}: ${message['body']}',
                style: TextStyle(
                  color: message['is_mine'] == true
                      ? Colors.white
                      : RiderColors.text,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RiderColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: text,
                maxLength: 4000,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: sending || opening ? null : send,
                child: Text(sending ? 'Sending...' : 'Send message'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String portalError(Object failure) => failure is SessionFailure
    ? failure.message
    : 'The request could not be confirmed. Refresh before retrying.';
