import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_error.dart';

import '../services/api_config.dart';
import '../services/rider_session.dart';
import 'pickup_dashboard_page.dart';
import 'registration_page.dart';
import 'rider_portal_page.dart';

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
  bool showPassword = false;
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
    if (submitting) return;
    FocusScope.of(context).unfocus();
    setState(() {
      message = null;
      success = false;
    });
    if (!formKey.currentState!.validate()) return;
    setState(() => submitting = true);
    try {
      final response = await riderSession.post(
        Uri.parse(loginApiUrl),
        headers: {'Accept': 'application/json'},
        body: {'email': email.text.trim(), 'password': password.text},
      );
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          submitting = false;
          message = response.statusCode == 401
              ? 'Invalid email or password.'
              : response.statusCode == 403
              ? 'Your rider account is unavailable. Contact your sorting center.'
              : apiErrorMessage(response);
        });
        return;
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final token = payload['token'];
      if (token is! String || token.isEmpty) throw const FormatException();
      await riderSession.tokens.save(token);
      await riderSession.requireReadyToken();
      if (!mounted) return;
      setState(() {
        submitting = false;
        success = true;
        message = 'Login successful.';
      });
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PickupDashboardPage(session: riderSession),
        ),
      );
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        submitting = false;
        message = exception is SessionFailure
            ? exception.message
            : 'Could not sign in. Check your connection and retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Image.asset(
                        'assets/images/alona/alonalogo2.png',
                        height: 52,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Welcome back',
                      style: TextStyle(
                        fontSize: 32,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to your rider account.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 32),
                    AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            enabled: !submitting,
                            validator: (value) =>
                                value == null || !value.contains('@')
                                ? 'Enter a valid email'
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: password,
                            obscureText: !showPassword,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            autocorrect: false,
                            enableSuggestions: false,
                            enabled: !submitting,
                            onFieldSubmitted: (_) => submit(),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Enter your password'
                                : null,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              suffixIcon: IconButton(
                                tooltip: showPassword
                                    ? 'Hide password'
                                    : 'Show password',
                                onPressed: () => setState(
                                  () => showPassword = !showPassword,
                                ),
                                icon: Icon(
                                  showPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                          ),
                          if (message != null) ...[
                            const SizedBox(height: 16),
                            _statusMessage(message!, success),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RiderAccountPage(session: riderSession),
                                ),
                              ),
                              child: const Text('View account status'),
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: submitting ? null : submit,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (submitting) ...[
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Text(
                                    submitting ? 'Signing in...' : 'Sign in',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RegistrationPage(),
                          ),
                        ),
                        child: const Text('Create a rider account'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusMessage(String text, bool isSuccess) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSuccess ? const Color(0xffdff4e9) : const Color(0xffffe6e2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isSuccess ? const Color(0xff176b43) : const Color(0xff9b3125),
        ),
      ),
    );
  }
}
