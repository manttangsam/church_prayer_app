import 'package:flutter/material.dart';
import 'package:flutter_dnd/flutter_dnd.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const baseScheme = ColorScheme.dark(
      primary: Color(0xFF4A6CF7),
      secondary: Color(0xFF5BD4FF),
      tertiary: Color(0xFFFFD369),
    );

    return MaterialApp(
      title: '21일 특별 기도 타이머',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: baseScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        textTheme: ThemeData(brightness: Brightness.dark)
            .textTheme
            .apply(bodyColor: Colors.white, displayColor: Colors.white),
      ),
      home: const PrayerTimerPage(),
    );
  }
}

class PrayerTimerPage extends StatefulWidget {
  const PrayerTimerPage({super.key});

  @override
  State<PrayerTimerPage> createState() => _PrayerTimerPageState();
}

class _PrayerTimerPageState extends State<PrayerTimerPage> {
  bool _isPraying = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  SharedPreferences? _prefs;
  DateTime? _challengeStartDate; 
  Set<int> _completedDays = <int>{};
  int _totalPrayerSeconds = 0;
  int _activeUsers = 0; 

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final startMs = prefs.getInt('challenge_start_ms');
    final start = startMs == null
        ? _dateOnly(DateTime.now())
        : _dateOnly(DateTime.fromMillisecondsSinceEpoch(startMs));

    if (startMs == null) {
      await prefs.setInt('challenge_start_ms', start.millisecondsSinceEpoch);
    }

    final completed = prefs.getStringList('challenge_completed_days') ?? <String>[];
    final completedSet = completed
        .map((e) => int.tryParse(e))
        .whereType<int>()
        .where((d) => d >= 1 && d <= 21)
        .toSet();

    final totalSeconds = prefs.getInt('total_prayer_seconds') ?? 0;

    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _challengeStartDate = start;
      _completedDays = completedSet;
      _totalPrayerSeconds = totalSeconds;
    });
  }

  int _todayChallengeDay() {
    final start = _challengeStartDate;
    if (start == null) return 1;
    final diff = _dateOnly(DateTime.now()).difference(start).inDays;
    final day = diff + 1;
    if (day < 1) return 1;
    if (day > 21) return 21;
    return day;
  }

  Future<void> _persistCompletedDays() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final sorted = _completedDays.toList()..sort();
    await prefs.setStringList(
      'challenge_completed_days',
      sorted.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _persistTotalPrayerSeconds() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setInt('total_prayer_seconds', _totalPrayerSeconds);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _setDnd(bool enabled) async {
    try {
      final granted = await FlutterDnd.isNotificationPolicyAccessGranted;
      if (granted != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('방해 금지 권한이 필요해요.')),
        );
        FlutterDnd.gotoPolicySettings();
        return;
      }
      await FlutterDnd.setInterruptionFilter(
        enabled ? FlutterDnd.INTERRUPTION_FILTER_NONE : FlutterDnd.INTERRUPTION_FILTER_ALL,
      );
    } catch (_) {}
  }

  Future<void> _togglePrayer() async {
    setState(() => _activeUsers = Random().nextInt(8) + 1);

    if (_isPraying) {
      await _setDnd(false);
      _stopTimer();
      final today = _todayChallengeDay();
      setState(() {
        _isPraying = false;
        _totalPrayerSeconds += _elapsed.inSeconds;
        _completedDays = {..._completedDays, today};
      });
      unawaited(_persistTotalPrayerSeconds());
      unawaited(_persistCompletedDays());
      return;
    }

    setState(() {
      _isPraying = true;
      _elapsed = Duration.zero;
    });
    _startTimer();
    await _setDnd(true);
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${two(minutes)}:${two(seconds)}';
  }

  String _formatTotalPrayerTime() {
    final hours = _totalPrayerSeconds ~/ 3600;
    final minutes = (_totalPrayerSeconds % 3600) ~/ 60;
    return '$hours시간 $minutes분';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          '21일 특별 기도 타이머',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            // [가독성 개선] 검은색 그림자 추가
            shadows: [
  Shadow(
    blurRadius: 15.0,           // 10.0에서 15.0으로 키워서 더 부드럽고 넓게 퍼지게 함
    color: Colors.black,        // Opacity 없이 진한 검은색으로 변경
    offset: const Offset(3.0, 3.0), // 그림자 위치를 조금 더 멀리 밀어냄
  ),
  // 하나 더 추가해서 테두리 효과를 줄 수도 있습니다
  Shadow(
    blurRadius: 5.0,
    color: Colors.black,
    offset: const Offset(-1.0, -1.0),
  ),
],
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/prayer_bg.jpg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      _ChallengeDaysRow(
                        today: _todayChallengeDay(),
                        startDate: _challengeStartDate ?? _dateOnly(DateTime.now()),
                        completedDays: _completedDays,
                        colorScheme: scheme,
                      ),
                      const SizedBox(height: 20),
                      _TotalTimeBadge(label: '누적 기도 시간', value: _formatTotalPrayerTime()),
                      const SizedBox(height: 30),
                      Text(
                        _isPraying ? '기도가 쌓이고 있습니다...' : '나의 기도 시간 타이머',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _format(_elapsed),
                        style: const TextStyle(
                          fontSize: 60,
                          fontWeight: FontWeight.w900,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // [물줄기 애니메이션이 포함된 항아리]
                      _PrayerPotWithWater(isPraying: _isPraying, activeUsers: _activeUsers),
                      const SizedBox(height: 10),
                      Text('현재 함께 기도 중: $_activeUsers명'),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 65,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _isPraying ? Colors.redAccent : scheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          onPressed: _togglePrayer,
                          child: Text(
                            _isPraying ? '기도 종료' : '기도 시작',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// [새로운 물줄기 애니메이션 위젯]
class _PrayerPotWithWater extends StatelessWidget {
  final bool isPraying;
  final int activeUsers;

  const _PrayerPotWithWater({required this.isPraying, required this.activeUsers});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isPraying)
            Positioned(
              top: 0,
              child: SizedBox(
                width: 100,
                height: 180,
                child: _WaterStreamAnimation(),
              ),
            ),
          Positioned(
            bottom: 20,
            child: Image.asset(
              activeUsers <= 2 
                ? 'assets/images/prayer_pot_64.png' 
                : activeUsers <= 4 
                  ? 'assets/images/prayer_pot_128.png' 
                  : 'assets/images/prayer_pot_256.png',
              width: 180,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class _WaterStreamAnimation extends StatefulWidget {
  @override
  State<_WaterStreamAnimation> createState() => _WaterStreamAnimationState();
}

class _WaterStreamAnimationState extends State<_WaterStreamAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (particles.length < 30) {
          particles.add(Particle());
        }
        for (var p in particles) {
          p.update();
        }
        particles.removeWhere((p) => p.y > 1.0);

        return CustomPaint(painter: WaterPainter(particles));
      },
    );
  }
}

class Particle {
  double x = 0.5 + (Random().nextDouble() - 0.5) * 0.2;
  double y = 0.0;
  double speed = 0.02 + Random().nextDouble() * 0.02;
  double size = 2.0 + Random().nextDouble() * 4.0;

  void update() {
    y += speed;
  }
}

class WaterPainter extends CustomPainter {
  final List<Particle> particles;
  WaterPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF5BD4FF), Color(0xFF4A6CF7)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    for (var p in particles) {
      canvas.drawCircle(Offset(p.x * size.width, p.y * size.height), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 기존 위젯들 (생략 없이 유지)
class _ChallengeDaysRow extends StatelessWidget {
  final int today;
  final DateTime startDate;
  final Set<int> completedDays;
  final ColorScheme colorScheme;

  const _ChallengeDaysRow({required this.today, required this.startDate, required this.completedDays, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: List.generate(21, (index) {
        final day = index + 1;
        final isCompleted = completedDays.contains(day);
        final isToday = day == today;
        return Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted ? colorScheme.primary : (isToday ? Colors.white24 : Colors.white10),
            border: isToday ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: Center(
            child: isCompleted ? const Icon(Icons.check, size: 20) : Text('$day'),
          ),
        );
      }),
    );
  }
}

class _TotalTimeBadge extends StatelessWidget {
  final String label;
  final String value;
  const _TotalTimeBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}