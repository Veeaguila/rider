import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_config.dart';
import '../services/rider_session.dart';
import 'pickup_dashboard_page.dart';
import 'registration_page.dart';

class LoginPage extends StatefulWidget {
  final String? initialMessage;
  final RiderSession? session;
  const LoginPage({super.key, this.initialMessage, this.session});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  late final riderSession = widget.session ?? RiderSession();
  bool submitting = false;
  String? message;
  bool success = false;

  @override
  void initState() {
    super.initState();
    message = widget.initialMessage;
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      message = null;
      success = false;
    });
    if (!formKey.currentState!.validate()) return;
    setState(() => submitting = true);
    try {
      final response = await http.post(
        Uri.parse(loginApiUrl),
        headers: {'Accept': 'application/json'},
        body: {'email': email.text.trim(), 'password': password.text},
      );
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          submitting = false;
          message = payload['message']?.toString() ?? 'Invalid email or password.';
        });
        return;
      }
      await riderSession.tokens.save(payload['token'] as String);
      await riderSession.requireReadyToken();
      if (!mounted) return;
      setState(() {
        submitting = false;
        success = true;
        message = 'Login successful.';
      });
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => PickupDashboardPage(session: riderSession),
      ));
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        submitting = false;
        message = exception is SessionFailure
            ? exception.message : 'Could not sign in. Check your connection and retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(
                    child: Image.asset(
                      'assets/images/alona/alonalogo2.png',
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('RIDER / 02', style: TextStyle(letterSpacing: 2, color: Color(0xff008b8b), fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('Welcome back', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Sign in to check your rider account status.', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xffdce7e2))),
                    child: Column(children: [
                      TextFormField(controller: email, keyboardType: TextInputType.emailAddress, validator: (value) => value == null || !value.contains('@') ? 'Enter a valid email' : null, decoration: const InputDecoration(labelText: 'Email')),
                      const SizedBox(height: 14),
                      TextFormField(controller: password, obscureText: true, validator: (value) => value == null || value.isEmpty ? 'Required' : null, decoration: const InputDecoration(labelText: 'Password')),
                      if (message != null) ...[const SizedBox(height: 16), _statusMessage(message!, success)],
                      const SizedBox(height: 20),
                      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: submitting ? null : submit, icon: submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login), label: Text(submitting ? 'Signing in...' : 'Sign in'), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)))),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  Center(child: TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegistrationPage())), child: const Text('Create a rider account'))),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusMessage(String text, bool isSuccess) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: isSuccess ? const Color(0xffdff4e9) : const Color(0xffffe6e2), borderRadius: BorderRadius.circular(12)), child: Text(text, style: TextStyle(color: isSuccess ? const Color(0xff176b43) : const Color(0xff9b3125))));
  }
}
