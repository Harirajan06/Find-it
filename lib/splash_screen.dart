import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'search_screen.dart';
import 'supabase_client.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    String? savedOrg;

    await Future.wait([
      _initSupabase(),
      _loadPrefs().then((value) => savedOrg = value),
      Future.delayed(const Duration(seconds: 3)),
    ]);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SearchScreen(initialOrgCode: savedOrg),
      ),
    );
  }

  Future<void> _initSupabase() async {
    if (_initialized) return;
    await Supabase.initialize(
      url: 'https://mphzlbhlideuwzsugsln.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1waHpsYmhsaWRldXd6c3Vnc2xuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA3MTEyNzEsImV4cCI6MjA4NjI4NzI3MX0.NY7GkK8wUnXzSEmZX2OWxYl4zzYeasPwCQp3EdLbRyk',
    );
    // Touch the client to ensure it's ready.
    // ignore: unused_local_variable
    final _ = supabase;
    _initialized = true;
  }

  Future<String?> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('org_code');
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0A2540);
    return Scaffold(
      backgroundColor: primary,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1200),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 16),
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _BrandLogo(),
              SizedBox(height: 16),
              Text(
                'FIND IT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        width: 112,
        height: 112,
        color: const Color(0xFF0A2540),
        child: Image.asset(
          'assets/app_icon.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.school,
            size: 88,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
