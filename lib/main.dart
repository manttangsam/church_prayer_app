import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 개인 저장용

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
  int myTotalMinutes = 0; // 개인 누적 시간
  
  final String _myId = Random().nextInt(1000000).toString(); // 임시 이름표
  final List<Point> _waterDrops = [];

  @override
  void initState() {
    super.initState();
    _loadMyTime(); // 내 기도시간 불러오기
    _setupPresence(); // 실시간 접속자 관리
    
    _potController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _waterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..addListener(_generateWaterDrop);
  }

  // 개인 기도시간 로드
  Future<void> _loadMyTime() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myTotalMinutes = prefs.getInt('my_prayer_minutes') ?? 0;
    });
  }

  // 실시간 접속자 핵심 로직 (이름표 방식)
  void _setupPresence() {
    final presenceRef = _dbRef.child('presence');
    
    // 1. 접속자 명단 변화 감시
    presenceRef.onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() => onlinePrayers = data.length);
      } else {
        setState(() => onlinePrayers = 0);
      }
    });

    // 2. 나를 명단에 추가 & 연결 끊기면 삭제 예약
    presenceRef.child(_myId).set(true);
    presenceRef.child(_myId).onDisconnect().remove();

    // 3. 공동체 전체 누적 시간 감시
    _dbRef.child('stats/total_minutes').onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        setState(() => globalTotalMinutes = int.parse(event.snapshot.value.toString()));
      }
    });
  }

  void _generateWaterDrop() {
    if (mounted && _isRunning) {
      setState(() {
        // 물줄기를 중앙 입구로 모으기 (폭 좁게 설정)
        for(int i=0; i<2; i++) {
          _waterDrops.add(Point(85 + Random().nextDouble() * 10, 0));
        }
      });
    }
  }

  void _moveWaterDrops() {
    if (mounted && _isRunning) {
      setState(() {
        _waterDrops.removeWhere((drop) => drop.y > 180);
        for (int i = 0; i < _waterDrops.length; i++) {
          _waterDrops[i] = Point(_waterDrops[i].x, _waterDrops[i].y + 7);
        }
      });
    }
  }

  void _toggleTimer() async {
    if (_isRunning) {
      int prayedMinutes = (_seconds / 60).ceil();
      // 공동체 시간 업데이트
      _dbRef.child('stats/total_minutes').set(ServerValue.increment(prayedMinutes));
      
      // 내 시간 저장
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        myTotalMinutes += prayedMinutes;
        prefs.setInt('my_prayer_minutes', myTotalMinutes);
      });
      
      _timer?.cancel();
      _waterController.stop();
      _waterDrops.clear();
      _seconds = 0; 
    } else {
      _waterController.repeat();
      Timer.periodic(const Duration(milliseconds: 20), (timer) {
        if (!_isRunning) { timer.cancel(); return; }
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
    int currentDay = (DateTime.now().difference(startDate).inDays + 1).clamp(1, 21);

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
            const SizedBox(height: 5),
            Text("나의 누적 기도: ${myTotalMinutes ~/ 60}시간 ${myTotalMinutes % 60}분",
                style: const TextStyle(fontSize: 16, color: Colors.yellowAccent, backgroundColor: Colors.black45)),
            
            Expanded(
              child: Center(
                child: Text(
                  "${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}",
                  style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w100, color: Colors.white),
                ),
              ),
            ),

            AnimatedBuilder(
              animation: _potController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 10 * _potController.value),
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Image.asset('assets/images/prayer_pot_256.png', width: 180, height: 180),
                      ),
                      SizedBox(
                        width: 180, height: 200, 
                        child: Stack(
                          children: _waterDrops.map((drop) {
                            return Positioned(
                              left: drop.x.toDouble(), top: drop.y.toDouble(),
                              child: Container(
                                width: 4, height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
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

  @override
  void dispose() {
    _potController.dispose();
    _waterController.dispose();
    _timer?.cancel();
    super.dispose();
  }
}