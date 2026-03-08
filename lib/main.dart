import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:app_links/app_links.dart';
import 'package:workmanager/workmanager.dart';

import 'contribution_painter.dart';
import 'github_api.dart';
import 'token_manager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final tokenManager = TokenManager();
    final token = await tokenManager.getToken();
    if (token != null) {
      try {
        final credentials = await tokenManager.getCredentials();
        final clientId = credentials['clientId'] ?? '';
        final clientSecret = credentials['clientSecret'] ?? '';
        final redirectUri = credentials['redirectUri'] ?? '';

        if (clientId.isNotEmpty) {
          final api = GitHubApi(
            clientId: clientId,
            clientSecret: clientSecret,
            redirectUri: redirectUri,
          );
          final data = await api.fetchContributions(token);
          await tokenManager.saveContributions(jsonEncode(data));
        }
      } catch (e) {
        debugPrint('Background sync failed: $e');
      }
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  Workmanager().registerPeriodicTask(
    "1",
    "githubBackgroundSync",
    frequency: const Duration(hours: 1),
    constraints: Constraints(networkType: NetworkType.connected),
  );
  runApp(const MyApp());
}

// Entry point for Wallpaper if needed separately, but we handle it in main for simplicity
@pragma('vm:entry-point')
void wallpaperMain() {
  debugPrint('Wallpaper Entry Point: wallpaperMain started');
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Container(
        color: const Color(0xFF0D1117),
        child: const WallPaperView(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitHub Wallpaper',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        useMaterial3: true,
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _tokenManager = TokenManager();
  final _methodChannel = const MethodChannel('com.shibu.wallpaper/github');

  String? _token;
  String? _username;
  bool _isLoading = false;
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  late GitHubApi _api;
  Timer? _autoSyncTimer;

  @override
  void initState() {
    super.initState();
    _initApi();
    _loadStoredData();
    _handleDeepLinks();

    // Auto-sync every 30 minutes while app is foregrounded
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (_token != null) _fetchAndSyncData();
    });
  }

  Future<void> _initApi() async {
    // Fetch credentials from Native side (BuildConfig)
    try {
      final clientId =
          await _methodChannel.invokeMethod<String>('getClientId') ?? '';
      final clientSecret =
          await _methodChannel.invokeMethod<String>('getClientSecret') ?? '';
      final redirectUri =
          await _methodChannel.invokeMethod<String>('getRedirectUri') ?? '';

      _api = GitHubApi(
        clientId: clientId,
        clientSecret: clientSecret,
        redirectUri: redirectUri,
      );
    } catch (e) {
      // Fallback or error handling
      debugPrint('Error fetching BuildConfig: $e');
    }
  }

  Future<void> _loadStoredData() async {
    final token = await _tokenManager.getToken();
    final username = await _tokenManager.getUsername();
    setState(() {
      _token = token;
      _username = username;
    });
  }

  void _handleDeepLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri? uri) {
        if (uri != null && uri.scheme == 'githubwallpaper') {
          final code = uri.queryParameters['code'];
          if (code != null) {
            _exchangeCode(code);
          }
        }
      },
      onError: (err) {
        debugPrint('Deep Link Error: $err');
      },
    );
  }

  Future<void> _exchangeCode(String code) async {
    setState(() => _isLoading = true);
    try {
      final token = await _api.exchangeCodeForToken(code);
      await _tokenManager.saveToken(token);
      await _fetchAndSyncData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchAndSyncData() async {
    final token = await _tokenManager.getToken();
    if (token == null) return;

    try {
      // Save credentials for background task
      final clientId =
          await _methodChannel.invokeMethod<String>('getClientId') ?? '';
      final clientSecret =
          await _methodChannel.invokeMethod<String>('getClientSecret') ?? '';
      final redirectUri =
          await _methodChannel.invokeMethod<String>('getRedirectUri') ?? '';
      await _tokenManager.saveCredentials(clientId, clientSecret, redirectUri);

      final data = await _api.fetchContributions(token);
      await _tokenManager.saveContributions(jsonEncode(data));
      final username = data['data']['viewer']['login'];
      await _tokenManager.saveUsername(username);
      await _loadStoredData();
    } catch (e) {
      debugPrint('Sync Error: $e');
    }
  }

  Future<void> _login() async {
    final url =
        'https://github.com/login/oauth/authorize'
        '?client_id=${_api.clientId}'
        '&scope=user,repo'
        '&redirect_uri=${_api.redirectUri}';

    try {
      await launchUrl(
        Uri.parse(url),
        customTabsOptions: CustomTabsOptions(
          showTitle: true,
          colorSchemes: CustomTabsColorSchemes.defaults(
            toolbarColor: const Color(0xFF0D1117),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Could not launch $url: $e');
    }
  }

  Future<void> _setWallpaper() async {
    try {
      await _methodChannel.invokeMethod('setWallpaper');
    } on PlatformException catch (e) {
      debugPrint("Failed to set wallpaper: '${e.message}'.");
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Strictly Centered Content
          Positioned.fill(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Minimalist White Icon
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.code_rounded,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),

                      const Text(
                        'GITGLOW',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Turn your commits into light.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 64),

                      if (_isLoading)
                        const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        )
                      else if (_token == null)
                        _buildGlassButton(
                          onPressed: _login,
                          text: 'LOGIN',
                          isPrimary: true,
                        )
                      else ...[
                        Text(
                          '@$_username'.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildGlassButton(
                          onPressed: () async {
                            await _fetchAndSyncData();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Sync Done')),
                              );
                            }
                          },
                          text: 'SYNC',
                        ),
                        const SizedBox(height: 12),
                        _buildGlassButton(
                          onPressed: _setWallpaper,
                          text: 'APPLY',
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () async {
                            await _tokenManager.clear();
                            _loadStoredData();
                          },
                          child: Text(
                            'LOGOUT',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.2),
                              letterSpacing: 2,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Glowing Info Button (top-right, visible on all states)
          Positioned(top: 52, right: 20, child: _buildInfoButton()),

          // Developer credit — fixed slightly above bottom on every screen
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Text(
              '~Developed By Swayanshu',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.2),
                fontSize: 11,
                letterSpacing: 1.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoButton() {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => _buildAboutSheet(context),
        );
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.6, end: 1.0),
        duration: const Duration(seconds: 5),
        curve: Curves.easeInOut,
        builder: (context, glow, _) {
          return Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.07),
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.15 * glow),
                  blurRadius: 12 * glow,
                  spreadRadius: 2 * glow,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '!',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAboutSheet(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.04),
            blurRadius: 30,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          const Text(
            'SWAYANSHU',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Developer',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),

          // About GitGlow Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'ABOUT GITGLOW',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'GitGlow turns your GitHub contribution graph into a live, animated wallpaper. '
                  'Your commits glow on your home screen updated automatically.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          // Social Links
          _buildSocialLink(
            icon: Icons.language_rounded,
            label: 'Website',
            url: 'https://swayanshu-nine.vercel.app/',
          ),
          const SizedBox(height: 12),
          _buildSocialLink(
            icon: Icons.work_rounded,
            label: 'LinkedIn',
            url:
                'https://www.linkedin.com/in/swayanshu-sarthak-sadangi-b6751931a/',
          ),
          const SizedBox(height: 12),
          _buildSocialLink(
            icon: Icons.camera_alt_rounded,
            label: 'Instagram',
            url: 'https://instagram.com/swayan.shuuu',
          ),
        ],
      ),
    );
  }

  Widget _buildSocialLink({
    required IconData icon,
    required String label,
    required String url,
  }) {
    return GestureDetector(
      onTap: () async {
        try {
          await launchUrl(
            Uri.parse(url),
            customTabsOptions: CustomTabsOptions(
              showTitle: true,
              colorSchemes: CustomTabsColorSchemes.defaults(
                toolbarColor: const Color(0xFF0D1117),
              ),
            ),
          );
        } catch (_) {}
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(color: Colors.white.withOpacity(0.03), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.7), size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withOpacity(0.3),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required VoidCallback onPressed,
    required String text,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 180,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withOpacity(isPrimary ? 0.3 : 0.1),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

class WallPaperView extends StatefulWidget {
  const WallPaperView({super.key});

  @override
  State<WallPaperView> createState() => _WallPaperViewState();
}

class _WallPaperViewState extends State<WallPaperView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  GitHubStats? _stats;
  String? _errorMessage;
  Map<String, double>? _layout;
  String? _font;
  final _tokenManager = TokenManager();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _fetchData();
    _loadPrefs();
    _refreshTimer = Timer.periodic(
      const Duration(hours: 6),
      (_) => _fetchData(),
    );
  }

  Future<void> _loadPrefs() async {
    final layout = await _tokenManager.getLayoutOffsets();
    final font = await _tokenManager.getFontFamily();
    setState(() {
      _layout = layout;
      _font = font;
    });
  }

  Future<void> _fetchData() async {
    final token = await _tokenManager.getToken();
    if (token == null) return;

    try {
      final api = GitHubApi(clientId: '', clientSecret: '', redirectUri: '');
      final data = await api.fetchContributions(token);

      await _tokenManager.saveContributions(jsonEncode(data));

      final viewer = data['data']['viewer'];
      final calendar =
          viewer['contributionsCollection']['contributionCalendar'];

      final List<ContributionDay> days = [];
      for (var week in calendar['weeks']) {
        for (var day in week['contributionDays']) {
          String colorStr = day['color'] ?? '#21262d';
          if (!colorStr.startsWith('#')) colorStr = '#$colorStr';

          days.add(
            ContributionDay(
              date: day['date'],
              count: day['contributionCount'],
              color: Color(int.parse(colorStr.replaceFirst('#', '0xFF'))),
            ),
          );
        }
      }

      int currentStreak = 0;
      int longestStreak = 0;
      int tempStreak = 0;
      String longestStreakStart = '';
      String longestStreakEnd = '';
      String tempStart = '';

      for (var day in days) {
        if (day.count > 0) {
          if (tempStreak == 0) tempStart = day.date;
          tempStreak++;
          if (tempStreak > longestStreak) {
            longestStreak = tempStreak;
            longestStreakStart = tempStart;
            longestStreakEnd = day.date;
          }
        } else {
          tempStreak = 0;
        }
      }

      for (var day in days.reversed) {
        if (day.count > 0) {
          currentStreak++;
        } else if (currentStreak > 0) {
          break;
        }
      }

      final now = DateTime.now();
      final todayStr = "${now.day}/${now.month}/${now.year}";
      final streakRange = longestStreak > 0
          ? "$longestStreakStart to $longestStreakEnd"
          : "N/A";

      setState(() {
        _stats = GitHubStats(
          username: viewer['login'],
          totalContributions: calendar['totalContributions'],
          currentStreak: currentStreak,
          longestStreak: longestStreak,
          longestStreakRange: streakRange,
          todayDate: todayStr,
          days: days,
        );
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString().split('\n').first}';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: ContributionPainter(
              stats: _stats,
              animationValue: _controller.value,
              errorMessage: _errorMessage,
              layoutOffsets: _layout,
              fontFamily: _font,
            ),
          );
        },
      ),
    );
  }
}
