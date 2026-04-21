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

  // 접속자 관리: 시작 버튼 누를 때만 기록하도록 변경
  void _setupPresence() {
    _dbRef.child('presence').onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() => onlinePrayers = data.length);
      } else {
        setState(() => onlinePrayers = 0);
      }
    });

    _dbRef.child('stats/total_minutes').onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        setState(() => globalTotalMinutes = int.parse(event.snapshot.value.toString()));
      }
    });
  }

  // 물줄기 생성: 항아리 입구에 맞춰 풍성하게(80~100 범위)
  void _generateWaterDrop() {
    if (mounted && _isRunning) {
      setState(() {
        for (int i = 0; i < 5; i++) {
          _waterDrops.add(Point(80 + Random().nextDouble() * 20, 0));
        }
      });
    }
  }

  // 물줄기 이동: 항아리 입구 높이(80)에서 멈추도록 수정
  void _moveWaterDrops() {
    if (mounted) {
      setState(() {
        List<Point<double>> nextDrops = [];
        for (var drop in _waterDrops) {
          if (drop.y < 80) {
            nextDrops.add(Point(drop.x, drop.y + 2));
          }
        }
        _waterDrops = nextDrops;
      });
    }
  }

  void _toggleTimer() async {
    final presenceRef = _dbRef.child('presence').child(_myId);

    if (_isRunning) {
      // 기도 중단 시 인원 카운트 제외
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
      // 기도 시작 시에만 인원 카운트 등록
      presenceRef.set(true);
      presenceRef.onDisconnect().remove();

      setState(() => _isRunning = true);
      _waterController.repeat();
      
      Timer.periodic(const Duration(milliseconds: 20), (timer) {
        if (!_isRunning) { timer.cancel(); return; }
        _moveWaterDrops();
        if (Random().nextInt(5) == 0) _generateWaterDrop();
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _seconds++);
      });
    }
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/prayer_bg.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.5)),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("21일 특별 기도 타이머", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 40),
                Text("공동체 누적: ${globalTotalMinutes ~/ 60}시간 ${globalTotalMinutes % 60}분", style: const TextStyle(color: Colors.white70, fontSize: 18)),
                Text("나의 누적 기도: ${myTotalMinutes ~/ 60}시간 ${myTotalMinutes % 60}분", style: const TextStyle(color: Colors.yellowAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                Text(_formatTime(_seconds), style: const TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.w300)),
                const SizedBox(height: 20),
                // 물줄기 및 항아리 애니메이션 영역
                SizedBox(
                  width: 200,
                  height: 250,
                  child: Stack(
                    children: [
                      ..._waterDrops.map((drop) => Positioned(
                        left: drop.x,
                        top: drop.y,
                        child: Container(width: 3, height: 10, decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.6), borderRadius: BorderRadius.circular(2))),
                      )),
                      Positioned(
                        bottom: 0,
                        left: 25,
                        child: Image.asset('assets/images/pot.png', width: 150),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Text("현재 함께 기도 중: $onlinePrayers명", style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _toggleTimer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRunning ? Colors.redAccent : Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  ),
                  child: Text(_isRunning ? "기도 멈추기" : "기도 시작", style: const TextStyle(color: Colors.white, fontSize: 20)),
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