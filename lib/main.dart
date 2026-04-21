import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PrayerApp());
}

class PrayerApp extends StatelessWidget {
  const PrayerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '21일 특별 기도 타이머',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const PrayerTimerPage(),
    );
  }
}

class PrayerTimerPage extends StatefulWidget {
  const PrayerTimerPage({super.key});
  @override
  State<PrayerTimerPage> createState() => _PrayerTimerPageState();
}

class _PrayerTimerPageState extends State<PrayerTimerPage> with SingleTickerProviderStateMixin {
  int _seconds = 0;
  bool _isRunning = false;
  int _selectedDay = 2; // 기본 2일차 선택
  Timer? _timer;
  final String _myId = DateTime.now().millisecondsSinceEpoch.toString();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  int onlinePrayers = 0;
  int globalTotalMinutes = 0;
  int myTotalMinutes = 0;

  List<Point<double>> _waterDrops = [];
  late AnimationController _waterController;

  @override
  void initState() {
    super.initState();
    _loadMyTotalMinutes();
    _setupPresence();
    _waterController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
  }

  Future<void> _loadMyTotalMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myTotalMinutes = prefs.getInt('my_prayer_minutes') ?? 0;
    });
  }

  void _setupPresence() {
    _dbRef.child('presence').onValue.listen((event) {
      if (mounted) {
        if (event.snapshot.value != null) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          setState(() => onlinePrayers = data.length);
        } else {
          setState(() => onlinePrayers = 0);
        }
      }
    });

    _dbRef.child('stats/total_minutes').onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        setState(() => globalTotalMinutes = int.parse(event.snapshot.value.toString()));
      }
    });
  }

  void _generateWaterDrop() {
    if (mounted && _isRunning) {
      setState(() {
        for (int i = 0; i < 5; i++) {
          // 항아리 입구 가로 범위 (약 75~125 사이로 조절)
          _waterDrops.add(Point(75 + Random().nextDouble() * 50, 0));
        }
      });
    }
  }

  void _moveWaterDrops() {
    if (mounted) {
      setState(() {
        List<Point<double>> nextDrops = [];
        for (var drop in _waterDrops) {
          if (drop.y < 85) { // 항아리 입구 높이까지만 하강
            nextDrops.add(Point(drop.x, drop.y + 3));
          }
        }
        _waterDrops = nextDrops;
      });
    }
  }

  void _toggleTimer() async {
    final presenceRef = _dbRef.child('presence').child(_myId);

    if (_isRunning) {
      presenceRef.remove();
      int prayedMinutes = (_seconds / 60).ceil();
      _dbRef.child('stats/total_minutes').set(ServerValue.increment(prayedMinutes));
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        myTotalMinutes += prayedMinutes;
        prefs.setInt('my_prayer_minutes', myTotalMinutes);
        _isRunning = false;
      });
      _timer?.cancel();
      _waterController.stop();
      _waterDrops.clear();
      _seconds = 0;
    } else {
      await presenceRef.set(true);
      presenceRef.onDisconnect().remove();
      setState(() => _isRunning = true);
      _waterController.repeat();
      Timer.periodic(const Duration(milliseconds: 20), (timer) {
        if (!_isRunning) { timer.cancel(); return; }
        _moveWaterDrops();
        if (Random().nextInt(4) == 0) _generateWaterDrop();
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _seconds++);
      });
    }
  }

  String _formatTime(int totalSeconds) => 
      "${(totalSeconds ~/ 60).toString().padLeft(2, '0')}:${(totalSeconds % 60).toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(image: AssetImage('assets/images/prayer_bg.jpg'), fit: BoxFit.cover),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.5)),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Text("21일 특별 기도 타이머", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                // 날짜 선택 바 (1일~21일)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(21, (index) {
                      int day = index + 1;
                      bool isSelected = _selectedDay == day;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedDay = day),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.orange : Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: Text("$day일", style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 12)),
                        ),
                      );
                    }),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("공동체 누적: ${globalTotalMinutes ~/ 60}시간 ${globalTotalMinutes % 60}분", style: const TextStyle(color: Colors.white70, fontSize: 16)),
                      Text("나의 누적 기도: ${myTotalMinutes ~/ 60}시간 ${myTotalMinutes % 60}분", style: const TextStyle(color: Colors.yellowAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Text(_formatTime(_seconds), style: const TextStyle(color: Colors.white, fontSize: 70, fontWeight: FontWeight.w200)),
                      const SizedBox(height: 20),
                      // 항아리 및 물줄기 영역
                      SizedBox(
                        width: 200, height: 220,
                        child: Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            ..._waterDrops.map((drop) => Positioned(
                              left: drop.x, top: drop.y,
                              child: Container(width: 3, height: 10, decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.7), borderRadius: BorderRadius.circular(2))),
                            )),
                            Positioned(
                              bottom: 0,
                              child: Image.asset('assets/images/pot.png', width: 140),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text("현재 함께 기도 중: $onlinePrayers명", style: const TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _toggleTimer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRunning ? Colors.redAccent : Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                        ),
                        child: Text(_isRunning ? "기도 멈추기" : "기도 시작", style: const TextStyle(color: Colors.white, fontSize: 18)),
                      ),
                    ],
                  ),
                ),
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
    _waterController.dispose();
    super.dispose();
  }
}