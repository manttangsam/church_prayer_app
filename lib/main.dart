import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

// ---------------------------------------------------------
// 1. 기간 설정 (4/20 월요일 00:00 시작 기준)
// ---------------------------------------------------------
final DateTime startDate = DateTime(2026, 4, 20);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBLynU_hVQXyzUXD9dYTVYaF8_-c9-8a9Y",
      authDomain: "church-prayer-app-57370.firebaseapp.com",
      projectId: "church-prayer-app-57370",
      storageBucket: "church-prayer-app-57370.firebasestorage.app",
      messagingSenderId: "19817451561",
      appId: "1:19817451561:web:166687df2ec2a373648c38",
      measurementId: "G-4Y2B1CZ6YB",
      databaseURL: "https://church-prayer-app-57370-default-rtdb.asia-southeast1.firebasedatabase.app",
    ),
  );
  runApp(const PrayerTimerApp());
}

class PrayerTimerApp extends StatelessWidget {
  const PrayerTimerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '21일 특별 기도 타이머',
      theme: ThemeData(brightness: Brightness.dark),
      home: const PrayerTimerPage(),
    );
  }
}

class PrayerTimerPage extends StatefulWidget {
  const PrayerTimerPage({super.key});
  @override
  State<PrayerTimerPage> createState() => _PrayerTimerPageState();
}

class _PrayerTimerPageState extends State<PrayerTimerPage> with TickerProviderStateMixin {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  late AnimationController _potController;
  late AnimationController _waterController;
  
  int _seconds = 0; 
  Timer? _timer;
  bool _isRunning = false;
  int globalTotalMinutes = 0;
  int onlinePrayers = 0; 
  final List<Point> _waterDrops = [];

  @override
  void initState() {
    super.initState();
    _setupRealtimeSync(); 
    
    // 항아리 둥실둥실
    _potController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // 물방울 생성 주기
    _waterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..addListener(_generateWaterDrop);
  }

  @override
  void dispose() {
    _potController.dispose();
    _waterController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // 데이터베이스 실시간 감시 (모든 창 동기화 핵심)
  void _setupRealtimeSync() {
    _dbRef.child('stats/total_minutes').onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        setState(() => globalTotalMinutes = int.parse(event.snapshot.value.toString()));
      }
    });
    _dbRef.child('stats/online_count').onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        int count = int.parse(event.snapshot.value.toString());
        setState(() => onlinePrayers = count < 0 ? 0 : count);
      }
    });
  }

  // 오늘이 며칠째인지 계산 (20일=1일차, 21일=2일차)
  int _calculateCurrentDay() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    return today.difference(start).inDays + 1;
  }

  void _generateWaterDrop() {
    if (mounted && _isRunning) {
      setState(() {
        _waterDrops.add(Point(Random().nextDouble() * 100 + 40, 0));
      });
    }
  }

  void _moveWaterDrops() {
    if (mounted && _isRunning) {
      setState(() {
        _waterDrops.removeWhere((drop) => drop.y > 180);
        for (int i = 0; i < _waterDrops.length; i++) {
          _waterDrops[i] = Point(_waterDrops[i].x, _waterDrops[i].y + 6);
        }
      });
    }
  }

  void _toggleTimer() {
    if (_isRunning) {
      // 기도 멈출 때
      int prayedMinutes = (_seconds / 60).ceil();
      _dbRef.child('stats/total_minutes').set(ServerValue.increment(prayedMinutes));
      _dbRef.child('stats/online_count').set(ServerValue.increment(-1));
      
      _timer?.cancel();
      _waterController.stop();
      _waterDrops.clear();
      _seconds = 0; 
    } else {
      // 기도 시작할 때
      _dbRef.child('stats/online_count').set(ServerValue.increment(1));
      _waterController.repeat();
      Timer.periodic(const Duration(milliseconds: 20), (timer) {
        if (!_isRunning) {
          timer.cancel();
          return;
        }
        _moveWaterDrops();
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _seconds++);
      });
    }
    setState(() => _isRunning = !_isRunning);
  }

  @override
  Widget build(BuildContext context) {
    int currentDay = _calculateCurrentDay();

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/prayer_bg.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 60),
            const Text("21일 특별 기도 타이머", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // 날짜 표시 부분
            Wrap(
              spacing: 8, runSpacing: 8,
              children: List.generate(21, (index) {
                int dayNum = index + 1;
                bool isPast = dayNum < currentDay;
                bool isToday = dayNum == currentDay;
                return Container(
                  width: 45, height: 45,
                  decoration: BoxDecoration(
                    color: isToday ? Colors.orange : (isPast ? Colors.blue : Colors.white24),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text("${dayNum}일", style: const TextStyle(fontSize: 12))),
                );
              }),
            ),

            const SizedBox(height: 30),
            Text("공동체 누적: ${globalTotalMinutes ~/ 60}시간 ${globalTotalMinutes % 60}분",
                style: const TextStyle(fontSize: 18, backgroundColor: Colors.black45)),
            
            // 타이머 숫자
            Expanded(
              child: Center(
                child: Text(
                  "${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}",
                  style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w100, color: Colors.white),
                ),
              ),
            ),

            // 항아리 + 폭포 애니메이션
            AnimatedBuilder(
              animation: _potController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * _potController.value),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 0,
                        child: SizedBox(
                          width: 180,
                          height: 180,
                          child: Stack(
                            children: _waterDrops.map((drop) => Positioned(
                              left: drop.x. toDouble(),
                              top: drop.y. toDouble(),
                              child: Container(
                                width: 7, height: 7,
                                decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                              ),
                            )).toList(),
                          ),
                        ),
                      ),
                      Image.asset('assets/images/prayer_pot_256.png', width: 180, height: 180),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 10),
            Text("현재 함께 기도 중: $onlinePrayers명", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: _toggleTimer,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRunning ? Colors.red : Colors.blueAccent,
                minimumSize: const Size(250, 60),
              ),
              child: Text(_isRunning ? "기도 멈추기" : "기도 시작", style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}