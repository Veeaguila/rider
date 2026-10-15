import 'package:flutter/material.dart';

import '../services/rider_session.dart';
import '../services/rider_session_guard.dart';
import '../services/rider_portal_api.dart';
import 'login_page.dart';

Widget riderTools(BuildContext context, RiderSession session) =>
    PopupMenuButton<String>(
      tooltip: 'Rider tools',
      onSelected: (value) {
        final page = value == 'chat'
            ? RiderChatPage(session: session)
            : value == 'notifications'
            ? RiderNotificationsPage(session: session)
            : RiderAccountPage(session: session);
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
      itemBuilder: (_) => const [
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
      padding: const EdgeInsets.all(20),
      children: [
        if (loading) const Center(child: CircularProgressIndicator()),
        if (error != null)
          Text(error!, style: const TextStyle(color: Color(0xff9b3125))),
        DropdownButtonFormField<int>(
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
        const SizedBox(height: 12),
        for (final row in conversations)
          Card(
            child: ListTile(
              title: Text(
                row['recipient']?['name']?.toString() ?? 'Conversation',
              ),
              subtitle: Text(row['latest_message']?['body']?.toString() ?? ''),
              trailing: Text('${row['unread_count'] ?? 0} unread'),
              onTap: sending ? null : () => open((row['id'] as num).toInt()),
            ),
          ),
        if (opening) const LinearProgressIndicator(),
        for (final message in messages)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '${message['sender']?['name'] ?? 'Rider'}: ${message['body']}',
              ),
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: text,
          maxLength: 4000,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Message'),
        ),
        FilledButton(
          onPressed: sending || opening ? null : send,
          child: Text(sending ? 'Sending...' : 'Send message'),
        ),
      ],
    ),
  );
}

class RiderAccountPage extends StatefulWidget {
  final RiderSession? session;
  const RiderAccountPage({super.key, this.session});
  @override
  State<RiderAccountPage> createState() => _RiderAccountPageState();
}

class _RiderAccountPageState extends State<RiderAccountPage>
    with RiderSessionGuard<RiderAccountPage> {
  @override
  late final riderSession = widget.session ?? RiderSession();
  late final api = RiderPortalApi(riderSession);
  final contact = TextEditingController();
  Map<String, dynamic>? profile;
  bool loading = true, saving = false;
  String? error, success;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    contact.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final payload = await sessionAction(
        () => api.request('partner/profile', ready: false),
      );
      final data = Map<String, dynamic>.from(payload['data'] as Map);
      if (data['role'] != 'rider') {
        throw const SessionFailure(
          'This account is not a rider.',
          accessDenied: true,
        );
      }
      if (!mounted) return;
      setState(() {
        profile = data;
        contact.text =
            data['profile']?['details']?['contact_no']?.toString() ?? '';
        loading = false;
      });
    } catch (failure) {
      if (mounted) {
        setState(() {
          loading = false;
          error = portalError(failure);
        });
      }
    }
  }

  Future<void> save() async {
    if (saving ||
        !RegExp(r'^(09\d{9}|\+639\d{9})$').hasMatch(contact.text.trim())) {
      setState(() => error = 'Use a valid 09 or +639 mobile number.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
      success = null;
    });
    try {
      await sessionAction(
        () => api.request(
          'partner/profile',
          method: 'PATCH',
          body: {'contact_no': contact.text.trim()},
          ready: false,
        ),
      );
      if (mounted) setState(() => success = 'Contact number updated.');
    } catch (failure) {
      if (mounted) setState(() => error = portalError(failure));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> logout() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await riderSession.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      }
    } catch (failure) {
      if (mounted) setState(() => error = portalError(failure));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My account'),
      actions: [
        IconButton(
          onPressed: loading || saving ? null : load,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          onPressed: saving ? null : logout,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (loading) const Center(child: CircularProgressIndicator()),
        if (error != null)
          Text(error!, style: const TextStyle(color: Color(0xff9b3125))),
        if (success != null)
          Text(success!, style: const TextStyle(color: Color(0xff176b43))),
        if (profile != null) ...[
          Text(
            profile!['name']?.toString() ?? '',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(profile!['email']?.toString() ?? ''),
          const SizedBox(height: 12),
          Text(
            'Status: ${profile!['status']}\nApproval: ${profile!['approvalStatus']}\nActive: ${profile!['is_active'] == true ? 'Yes' : 'No'}\nEmail verified: ${profile!['verified'] == true ? 'Yes' : 'No'}',
          ),
          if (profile!['reason'] != null) Text(profile!['reason'].toString()),
          if (profile!['verification_required'] == true &&
              profile!['verified'] != true)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Open the verification email in a browser and sign in to ALONA when prompted.',
              ),
            ),
          if (profile!['profile'] != null) ...[
            const SizedBox(height: 16),
            TextField(
              controller: contact,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Contact number'),
            ),
            FilledButton(
              onPressed: saving ? null : save,
              child: const Text('Save contact number'),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Changes to verified identity, vehicle or coverage require a new review. Contact your sorting center.',
          ),
        ],
      ],
    ),
  );
}

class RiderNotificationsPage extends StatefulWidget {
  final RiderSession? session;
  const RiderNotificationsPage({super.key, this.session});
  @override
  State<RiderNotificationsPage> createState() => _RiderNotificationsPageState();
}

class _RiderNotificationsPageState extends State<RiderNotificationsPage>
    with RiderSessionGuard<RiderNotificationsPage> {
  @override
  late final riderSession = widget.session ?? RiderSession();
  late final api = RiderPortalApi(riderSession);
  List<Map<String, dynamic>> conversations = [], deliveries = [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
      conversations = [];
      deliveries = [];
    });
    try {
      final rows = await sessionAction(
        () => Future.wait([
          api.request('rider/messages/conversations'),
          api.request('rider/deliveries'),
        ]),
      );
      if (!mounted) return;
      setState(() {
        conversations = List<Map<String, dynamic>>.from(rows[0]['data'] as List)
            .where((r) => (r['unread_count'] as num? ?? 0) > 0)
            .toList();
        deliveries = List<Map<String, dynamic>>.from(rows[1]['data'] as List);
        loading = false;
      });
    } catch (failure) {
      if (mounted) {
        setState(() {
          loading = false;
          error = portalError(failure);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        IconButton(
          onPressed: loading ? null : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Unread messages and active delivery tasks.'),
        if (loading) const Center(child: CircularProgressIndicator()),
        if (error != null)
          Text(error!, style: const TextStyle(color: Color(0xff9b3125))),
        for (final row in conversations)
          Card(
            child: ListTile(
              leading: const Icon(Icons.mark_chat_unread),
              title: Text('${row['unread_count']} unread messages'),
              subtitle: Text(
                row['recipient']?['name']?.toString() ?? 'Sorting center',
              ),
              onTap: () =>
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RiderChatPage(
                        session: riderSession,
                        conversationId: (row['id'] as num).toInt(),
                      ),
                    ),
                  ).then((_) {
                    if (mounted) load();
                  }),
            ),
          ),
        for (final row in deliveries)
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: Text('Order ${row['order_id']}'),
              subtitle: Text(row['status'].toString().replaceAll('_', ' ')),
            ),
          ),
        if (!loading &&
            error == null &&
            conversations.isEmpty &&
            deliveries.isEmpty)
          const Text('You are up to date.'),
      ],
    ),
  );
}

String portalError(Object failure) => failure is SessionFailure
    ? failure.message
    : 'The request could not be confirmed. Refresh before retrying.';
