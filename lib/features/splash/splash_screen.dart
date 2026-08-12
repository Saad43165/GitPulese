import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/router/app_router.dart';
import '../../core/constants/api_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _mainCtrl;
  late final Animation<double> _imageScale;
  late final Animation<double> _imageFade;

  @override
  void initState() {
    super.initState();

    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _imageFade = CurvedAnimation(
      parent: _mainCtrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );

    _imageScale = Tween<double>(begin: 1.05, end: 1.0).animate(
      CurvedAnimation(parent: _mainCtrl, curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic)),
    );

    _mainCtrl.forward();
    _navigateNext();
  }

    Future<void> _navigateNext() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;

    String? token;
    try {
      const secureStorage = FlutterSecureStorage();
      token = await secureStorage.read(key: ApiConstants.patStorageKey);
    } catch (_) {}
    final hasPat = token != null && token.isNotEmpty;

    if (!mounted) return;
    HapticFeedback.lightImpact();

    context.go(hasPat ? AppRoutes.home : AppRoutes.login);
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02040A),
      body: AnimatedBuilder(
        animation: _mainCtrl,
        builder: (context, _) {
          return SizedBox.expand(
            child: FadeTransition(
              opacity: _imageFade,
              child: ScaleTransition(
                scale: _imageScale,
                child: Image.asset(
                  'assets/images/splash.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
