import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint("Firebase 초기화 중...");
  }
  runApp(const PrayerApp());
}

class PrayerApp extends StatelessWidget {
  const PrayerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: const PrayerTimerPage(),
    debugShowCheckedModeBanner: false,
  );
}

class PrayerTimerPage extends StatefulWidget {
  const PrayerTimerPage({super.key});
  @override
  State<PrayerTimerPage> createState() => _PrayerTimerPageState();
}

class _PrayerTimerPageState extends State<PrayerTimerPage> with SingleTickerProviderStateMixin {
  int _seconds = 0;
  bool _isRunning = false;
  
  // 날짜 관련 변수
  late int _today; 
  Timer? _timer;
  late AnimationController _shakeController;
  final ScrollController _scrollController = ScrollController();
  
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final String _myId = DateTime.now().millisecondsSinceEpoch.toString();

  int onlinePrayers = 0;
  int globalTotalMinutes = 0;
  int myTotalMinutes = 0;
  List<Point<double>> _waterDrops = [];

  @override
  void initState() {
    super.initState();
    
    // [날짜 자동 계산 로직] 4월 20일 0시 기준
    DateTime startDate = DateTime(2026, 4, 20); 
    DateTime now = DateTime.now();
    // 시작일과의 차이를 구해서 오늘이 며칠차인지 계산 (최소 1일, 최대 21일)
    int dayDiff = now.difference(startDate).inDays + 1;
    _today = dayDiff.clamp(1, 21); 

    _loadMyTotalMinutes();
    _setupPresence();
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    // 화면이 그려진 후 오늘 날짜로 자동 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _today > 4) {
        double targetPosition = (_today - 1) * 60.0;
        _scrollController.animateTo(
          targetPosition,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadMyTotalMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => myTotalMinutes = prefs.getInt('my_prayer_minutes') ?? 0);
  }

  void _setupPresence() {
    _dbRef.child('presence').onValue.listen((event) {
      if (mounted) {
        final data = event.snapshot.value as Map?;
        setState(() => onlinePrayers = data?.length ?? 0);
      }
    });
    _dbRef.child('stats/total_minutes').onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        setState(() => globalTotalMinutes = int.tryParse(event.snapshot.value.toString()) ?? 0);
      }
    });
  }

  void _toggleTimer() async {
    if (_isRunning) {
      _dbRef.child('presence').child(_myId).remove().catchError((e) {});
      int prayedMinutes = (_seconds / 60).round(); 
      if (prayedMinutes > 0) {
        _dbRef.child('stats/total_minutes').set(ServerValue.increment(prayedMinutes)).catchError((e) {});
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          myTotalMinutes += prayedMinutes;
          prefs.setInt('my_prayer_minutes', myTotalMinutes);
        });
      }
      setState(() {
        _isRunning = false;
        _seconds = 0;
        _waterDrops.clear();
      });
      _timer?.cancel();
    } else {
      _dbRef.child('presence').child(_myId).set(true).catchError((e) {});
      _dbRef.child('presence').child(_myId).onDisconnect().remove();
      setState(() => _isRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() {
          _seconds++;
          _moveWaterDrops();
          // 풍성한 물방울 생성
          _waterDrops.add(Point(85 + Random().nextDouble() * 30, 0));
          _waterDrops.add(Point(85 + Random().nextDouble() * 30, -25));
          _waterDrops.add(Point(85 + Random().nextDouble() * 30, -50));
        });
      });
    }
  }

  void _moveWaterDrops() {
    List<Point<double>> nextDrops = [];
    for (var drop in _waterDrops) {
      if (drop.y < 85) nextDrops.add(Point(drop.x, drop.y + 25)); 
    }
    _waterDrops = nextDrops;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Opacity(
            opacity: 0.4,
            child: Image.asset('assets/images/prayer_bg.jpg', fit: BoxFit.cover, width: double.infinity, height: double.infinity, 
              errorBuilder: (context, error, stackTrace) => Container(color: Colors.black)),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Text("21일 특별 기도 타이머", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(21, (i) {
                      int day = i + 1;
                      Color dayColor = Colors.white12;
                      if (day < _today) dayColor = const Color(0xFF0D47A1); 
                      if (day == _today) dayColor = Colors.orange; 

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: dayColor, 
                          shape: BoxShape.circle,
                          border: day == _today ? Border.all(color: Colors.yellowAccent, width: 2) : null
                        ),
                        child: Text("${day}일", style: const TextStyle(color: Colors.white, fontSize: 12)),
                      );
                    }),
                  ),
                ),
                const Spacer(),
                Text("공동체 누적: ${globalTotalMinutes ~/ 60}시간 ${globalTotalMinutes % 60}분", style: const TextStyle(color: Colors.white70, fontSize: 16)),
                Text("나의 누적 기도: ${myTotalMinutes ~/ 60}시간 ${myTotalMinutes % 60}분", style: const TextStyle(color: Colors.yellowAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                Text("${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}", 
                  style: const TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.w100)),
                const SizedBox(height: 20),
                SizedBox(
                  width: 200, height: 180,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      ..._waterDrops.map((drop) => Positioned(left: drop.x, top: drop.y, child: Container(width: 4, height: 12, decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(2))))),
                      Positioned(
                        bottom: 0,
                        child: AnimatedBuilder(
                          animation: _shakeController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _isRunning ? (sin(_shakeController.value * pi * 2) * 0.05) : 0,
                              child: child,
                            );
                          },
                          child: Image.asset('assets/images/prayer_pot_256.png', width: 130, 
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.wine_bar, size: 100, color: Colors.amber)),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  child: Text(
                    "\"또 다른 천사가 와서 제단 곁에 서서 금 향로를 가지고 많은 향을 받았으니 이는 모든 성도의 기도와 합하여 보좌 앞 금 제단에 드리고자 함이라\"\n(요한계시록 8장 3절)",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5, fontWeight: FontWeight.w100),
                  ),
                ),
                const SizedBox(height: 10),
                Text("현재 함께 기도 중: ${onlinePrayers == 0 && _isRunning ? 1 : onlinePrayers}명", style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _toggleTimer,
                  style: ElevatedButton.styleFrom(backgroundColor: _isRunning ? Colors.redAccent : Colors.blueAccent, padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 15)),
                  child: Text(_isRunning ? "기도 멈추기" : "기도 시작", style: const TextStyle(color: Colors.white, fontSize: 20)),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}