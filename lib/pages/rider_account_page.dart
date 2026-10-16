import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../widgets/rider_content.dart';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../services/api_config.dart';
import '../services/api_error.dart';
import '../services/rider_session.dart';
import '../services/rider_session_guard.dart';
import '../services/rider_portal_api.dart';
import 'rider_address_edit_page.dart';
import 'rider_notifications_page.dart';
import 'login_page.dart';

class RiderAccountPage extends StatefulWidget {
  final RiderSession? session;
  final Future<XFile?> Function()? choosePhoto;
  const RiderAccountPage({super.key, this.session, this.choosePhoto});
  @override
  State<RiderAccountPage> createState() => _RiderAccountPageState();
}

class _RiderAccountPageState extends State<RiderAccountPage>
    with RiderSessionGuard<RiderAccountPage> {
  @override
  late final riderSession = widget.session ?? RiderSession();
  late final api = RiderPortalApi(riderSession);
  final contact = TextEditingController();
  final scroll = ScrollController();
  Map<String, dynamic>? profile;
  Uint8List? photo;
  bool loading = true, saving = false;
  String? error, success;
  Map get details => profile?['rider_profile'] as Map? ?? {};
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    scroll.dispose();
    contact.dispose();
    super.dispose();
  }

  String value(dynamic field) =>
      field == null || field.toString().trim().isEmpty
      ? 'Not provided'
      : field.toString();
  Future<String> token() async {
    final value = await riderSession.tokens.read();
    if (value == null || value.isEmpty) {
      throw const SessionFailure('Please sign in.', accessDenied: true);
    }
    return value;
  }

  Future<void> check(http.Response response) async {
    if (response.statusCode == 401) {
      await riderSession.tokens.clear();
      throw const SessionFailure(
        'Your session has expired. Please sign in.',
        accessDenied: true,
      );
    }
    if (response.statusCode != 200) {
      throw SessionFailure(apiErrorMessage(response));
    }
  }

  Future<void> load() async {
    if (!mounted) return;
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
            data['rider_profile']?['contact_no']?.toString() ??
            data['profile']?['details']?['contact_no']?.toString() ??
            '';
        photo = null;
      });
      if (details['photo_available'] == true) {
        final response = await sessionAction(() async {
          final response = await riderSession.get(
            Uri.parse('$apiBaseUrl/rider/profile-photo'),
            headers: {'Authorization': 'Bearer ${await token()}'},
          );
          await check(response);
          return response;
        });
        if (mounted) setState(() => photo = response.bodyBytes);
      }
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = failure is SessionFailure
              ? failure.message
              : 'Could not load your profile. Refresh to retry.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    if (saving || loading) return;
    if (!RegExp(r'^(09\d{9}|\+639\d{9})$').hasMatch(contact.text.trim())) {
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
          'rider/profile',
          method: 'PATCH',
          body: {'contact_no': contact.text.trim()},
          ready: false,
        ),
      );
      if (mounted) setState(() => success = 'Contact number updated.');
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = failure is SessionFailure ? failure.message : 'Profile update could not be confirmed. Refresh before retrying.',
        );
      }
    } finally {
      if (mounted) {
        if (scroll.hasClients) scroll.jumpTo(0);
        setState(() => saving = false);
      }
    }
  }

  Future<void> uploadPhoto() async {
    if (saving || loading) return;
    setState(() {
      saving = true;
      error = null;
      success = null;
    });
    try {
      // Start the picker from the click so browser file selection keeps user activation.
      final image =
          await (widget.choosePhoto?.call() ??
              ImagePicker().pickImage(
                source: ImageSource.gallery,
                maxWidth: 1200,
                maxHeight: 1200,
                imageQuality: 85,
              ));
      if (image == null) return;
      if (await image.length() > 5 * 1024 * 1024) {
        throw const SessionFailure('Choose a photo smaller than 5 MB.');
      }
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) {
        throw const SessionFailure(
          'This photo is empty. Choose another photo.',
        );
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        try {
          if (descriptor.width > 2000 || descriptor.height > 2000) {
            throw const SessionFailure(
              'Use a photo no larger than 2000 × 2000 pixels.',
            );
          }
        } finally {
          descriptor.dispose();
        }
      } finally {
        buffer.dispose();
      }
      await sessionAction(() async {
        final request =
            http.MultipartRequest(
                'POST',
                Uri.parse('$apiBaseUrl/rider/profile-photo'),
              )
              ..headers.addAll({
                'Authorization': 'Bearer ${await token()}',
                'Accept': 'application/json',
              })
              ..files.add(
                http.MultipartFile.fromBytes(
                  'photo',
                  bytes,
                  filename: image.name,
                ),
              );
        await check(await riderSession.sendMultipart(request));
      });
      await load();
      if (mounted) setState(() => success = 'Profile picture updated.');
    } on PlatformException catch (failure) {
      if (mounted) {
        setState(
          () => error =
              failure.code.contains('denied') ||
                  failure.code.contains('restricted')
              ? 'Photo access is denied. Allow Photos access in device Settings, then retry.'
              : 'Photo selection is unavailable on this device.',
        );
      }
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = failure is SessionFailure ? failure.message : 'Could not read or upload this photo. Use a JPEG, PNG or WebP image and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> editAddress() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RiderAddressEditPage(
          session: riderSession,
          initial: Map<String, dynamic>.from(
            details['address_fields'] as Map? ?? {},
          ),
        ),
      ),
    );
    if (!mounted || changed != true) return;
    await load();
    if (mounted) {
      setState(
        () => success =
            'Address saved. Check your approval status before working.',
      );
    }
  }

  Future<void> logout() async {
    if (saving || loading) return;
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
      if (mounted) {
        setState(
          () => error = failure is SessionFailure
              ? failure.message
              : 'Could not sign out. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget field(String label, dynamic data) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        SelectableText(value(data)),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My account'),
      actions: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: loading || saving
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        RiderNotificationsPage(session: riderSession),
                  ),
                ),
          icon: const Icon(Icons.notifications_none),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: loading || saving ? null : load,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: 'Logout',
          onPressed: loading || saving ? null : logout,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: ListView(
      controller: scroll,
      padding: riderPagePadding(context, maxWidth: 640),
      children: [
        if (loading || saving) const LinearProgressIndicator(),
        if (error != null)
          Text(error!, style: const TextStyle(color: Color(0xff9b3125))),
        if (success != null)
          Text(success!, style: const TextStyle(color: Color(0xff176b43))),
        if (profile != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 88,
              height: 88,
              child: ClipOval(
                child: photo != null
                    ? Image.memory(
                        photo!,
                        fit: BoxFit.cover,
                        cacheWidth: 176,
                        errorBuilder: (_, e, s) =>
                            const Icon(Icons.person_outline, size: 60),
                      )
                    : details['public_photo_url'] != null
                    ? Image.network(
                        details['public_photo_url'].toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, e, s) =>
                            const Icon(Icons.person_outline, size: 60),
                      )
                    : const ColoredBox(
                        color: Color(0xffeaf4f4),
                        child: Icon(
                          Icons.person_outline,
                          size: 60,
                          color: Color(0xff008b8b),
                        ),
                      ),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: loading || saving ? null : uploadPhoto,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Change profile picture'),
          ),
          field('Full name', profile!['name']),
          field('Email', profile!['email']),
          field('Birthday', details['birthday']),
          field('Address', details['address']),
          field('Vehicle type', details['vehicle_type']),
          field('Plate number', details['plate_number']),
          const SizedBox(height: 8),
          Text(
            'Account status',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Status: ${value(profile!['status'])}\nApproval: ${value(profile!['approvalStatus'])}\nActive: ${profile!['is_active'] == true ? 'Yes' : 'No'}\nEmail verified: ${profile!['verified'] == true ? 'Yes' : 'No'}',
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
          const SizedBox(height: 16),
          const SizedBox(height: 8),
          Text(
            'Contact details',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: contact,
            enabled: !saving && !loading,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Contact number'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: saving || loading ? null : save,
            child: const Text('Save contact number'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: saving || loading ? null : editAddress,
            child: const Text('Update address'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Address changes require Logistics reapproval and pause operational access. Identity, email, vehicle and coverage changes must be reviewed by your sorting center.',
          ),
        ],
      ],
    ),
  );
}
