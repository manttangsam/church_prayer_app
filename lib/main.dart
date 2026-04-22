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
    debugPrint("Firebase 초기화 오류: $e");
  }
  runApp(const PrayerApp());
}

class PrayerApp extends StatelessWidget {
  const PrayerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '21일 기도 타이머',
    theme: ThemeData(brightness: Brightness.dark),
    home: const PrayerTimerPage(),
    debugShowCheckedModeBanner: false,
  );
}

class WaterDropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.6)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    Path path = Path();
    path.moveTo(size.width / 2, 0); 
    path.cubicTo(size.width * 0.9, size.height * 0.3, size.width, size.height * 0.8, size.width / 2, size.height);
    path.cubicTo(0, size.height * 0.8, size.width * 0.1, size.height * 0.3, size.width / 2, 0);
    path.close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class PrayerTimerPage extends StatefulWidget {
  const PrayerTimerPage({super.key});
  @override
  State<PrayerTimerPage> createState() => _PrayerTimerPageState();
}

class _PrayerTimerPageState extends State<PrayerTimerPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _seconds = 0;
  bool _isRunning = false;
  late int _today; 
  Timer? _timer;
  late AnimationController _shakeController;
  final ScrollController _scrollController = ScrollController();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  int onlinePrayers = 0;
  int globalTotalMinutes = 0;
  int myTotalMinutes = 0;
  List<Point<double>> _waterDrops = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    DateTime startDate = DateTime(2026, 4, 20); 
    DateTime now = DateTime.now();
    int dayDiff = now.difference(startDate).inDays + 1;
    _today = dayDiff.clamp(1, 21); 

    _loadMyTotalMinutes();
    _setupPresence(); 
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _today > 4) {
        _scrollController.animateTo((_today - 1) * 60.0, duration: const Duration(milliseconds: 1000), curve: Curves.easeInOut);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (_isRunning) _decrementCount();
    }
  }

  // 카운트 감소 공통 로직 (트랜잭션)
  void _decrementCount() {
    _dbRef.child('online_count').runTransaction((Object? count) {
      int currentCount = (count as int? ?? 0);
      return Transaction.success(currentCount > 0 ? currentCount - 1 : 0);
    });
  }

  Future<void> _loadMyTotalMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => myTotalMinutes = prefs.getInt('my_prayer_minutes') ?? 0);
  }

  void _setupPresence() {
    _dbRef.child('online_count').onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        setState(() { onlinePrayers = int.parse(event.snapshot.value.toString()); });
      }
    });
    _dbRef.child('total_minutes').onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        setState(() { globalTotalMinutes = int.parse(event.snapshot.value.toString()); });
      }
    });
  }

  void _toggleTimer() async {
    if (_isRunning) {
      _decrementCount();
      int prayedMinutes = (_seconds / 60).round();
      if (prayedMinutes > 0) {
        _dbRef.child('total_minutes').set(ServerValue.increment(prayedMinutes));
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          myTotalMinutes += prayedMinutes;
          prefs.setInt('my_prayer_minutes', myTotalMinutes);
        });
      }
      setState(() { _isRunning = false; _seconds = 0; _waterDrops.clear(); });
      _timer?.cancel();
    } else {
      _dbRef.child('online_count').set(ServerValue.increment(1));
      _dbRef.child('online_count').onDisconnect().runTransaction((Object? count) {
        int currentCount = (count as int? ?? 0);
        return Transaction.success(currentCount > 0 ? currentCount - 1 : 0);
      });

      setState(() => _isRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() {
          _seconds++;
          _moveWaterDrops();
          _waterDrops.add(Point(20 + Random().nextDouble() * 160, 0)); 
        });
      });
    }
  }

  void _moveWaterDrops() {
    List<Point<double>> nextDrops = [];
    double targetX = 100.0; 
    for (var drop in _waterDrops) {
      if (drop.y < 130) {
        double newX = drop.x + (targetX - drop.x) * 0.15; 
        nextDrops.add(Point(newX, drop.y + 12)); 
      }
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
            opacity: 0.3,
            child: Image.asset('assets/images/prayer_bg.jpg', fit: BoxFit.cover, width: double.infinity, height: double.infinity, 
              errorBuilder: (context, error, stackTrace) => Container(color: Colors.black)),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 50),
                const Text("21일 특별 기도 타이머", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(21, (i) {
                      int day = i + 1;
                      bool isToday = day == _today;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: day < _today ? Colors.blue.withOpacity(0.3) : (isToday ? Colors.orange : Colors.white10),
                          shape: BoxShape.circle,
                          border: isToday ? Border.all(color: Colors.yellow, width: 2) : null
                        ),
                        child: Text("$day일", style: const TextStyle(color: Colors.white, fontSize: 12)),
                      );
                    }),
                  ),
                ),
                const Spacer(),
                Text("전체 누적: ${globalTotalMinutes ~/ 60}시간 ${globalTotalMinutes % 60}분", style: const TextStyle(color: Colors.white60, fontSize: 14)),
                Text("나의 누적: ${myTotalMinutes ~/ 60}시간 ${myTotalMinutes % 60}분", style: const TextStyle(color: Colors.yellowAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 40),
                Text("${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}", 
                  style: const TextStyle(color: Colors.white, fontSize: 90, fontWeight: FontWeight.w100)),
                const SizedBox(height: 20),
                SizedBox(
                  width: 200, height: 180,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      ..._waterDrops.map((drop) => Positioned(
                        left: drop.x - 6, top: drop.y, 
                        child: CustomPaint(size: const Size(12, 18), painter: WaterDropPainter())
                      )),
                      Positioned(
                        bottom: 0,
                        child: AnimatedBuilder(
                          animation: _shakeController,
                          builder: (context, child) => Transform.rotate(
                            angle: _isRunning ? (sin(_shakeController.value * pi * 2) * 0.05) : 0,
                            child: child,
                          ),
                          child: Image.asset('assets/images/prayer_pot_256.png', width: 130, 
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.wine_bar, size: 80, color: Colors.amber)),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 25),
                  child: Text(
                    "계시록 8:3\n\n\"또 다른 천사가 와서 제단 곁에 서서 금 향로를 가지고\n많은 향을 받았으니 이는 모든 성도의 기도와 합하여\n보좌 앞 금 제단에 드리고자 함이라\"",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.7, fontStyle: FontStyle.italic),
                  ),
                ),
                Text("현재 함께 기도 중: ${onlinePrayers}명", style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 35),
                ElevatedButton(
                  onPressed: _toggleTimer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRunning ? Colors.redAccent.withOpacity(0.8) : Colors.blueAccent, 
                    padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35))
                  ),
                  child: Text(_isRunning ? "기도 멈추기" : "기도 시작", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _shakeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}