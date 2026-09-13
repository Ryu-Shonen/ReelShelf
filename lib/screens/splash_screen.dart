import 'package:flutter/material.dart';

class UnstreamedSplashScreen extends StatelessWidget {
  const UnstreamedSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF070707),
      body: SizedBox.expand(
        child: Image(
          image: AssetImage(
            'assets/branding/unstreamed_splash.png',
          ),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
