import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../online/auth_service.dart';
import '../widgets/app_snack.dart';
import '../daily_quests/daily_quest_store.dart';
import '../titles/title_store.dart';
import '../widgets/home_quest_hub.dart';
import '../widgets/home_title_card.dart';
import '../user/user_session.dart';
import '../friends/presence_service.dart';
import '../widgets/background_image.dart';
import '../widgets/google_account_gate.dart';
import '../widgets/sign_out_dialog.dart';
import '../widgets/user_avatar.dart';
import '../widgets/home_footer.dart';
import '../widgets/uno_circle_button.dart';
import '../game/game_limits.dart';
import 'game_screen.dart';
import 'friends_screen.dart';
import 'leaderboard_screen.dart';
import 'online/online_menu_screen.dart';
import 'settings_screen.dart';
import 'titles_screen.dart';

/// Menu chính sau đăng nhập.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _card = Color(0xFF2A0707);
  static const _gold = Color(0xFFFFC400);

  final _presence = PresenceService.instance;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _presence.stop();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final user = AuthService().currentUser;
    // Đảm bảo profile Google (photoURL) đã populated trước khi render.
    try {
      await user?.reload();
    } catch (_) {}
    await UserSession.activate(AuthService().currentUser);
    final uid = AuthService().currentUser?.uid;
    if (uid != null && uid.isNotEmpty && !AuthService().isGuest) {
      await _presence.start(uid);
    }
    if (!mounted) return;
    setState(() {});
    if (UserSession.lastCloudSyncFailed) {
      AppSnack.warning(
        context,
        'Chưa đồng bộ được tiến độ lên đám mây — kiểm tra kết nối mạng.',
        duration: const Duration(milliseconds: 2600),
      );
    }
  }

  void _openTitles(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const TitlesScreen()))
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final name = auth.displayName;
    final photoUrl = auth.photoUrl;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF2A0707)),
          const BackgroundImage(
            assetPath: 'assets/images/background/homescreen.png',
            fit: BoxFit.cover,
            alignment: Alignment(0, -0.12),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(0, 0.38),
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x550D0202),
                  Color(0xCC0D0202),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                ListenableBuilder(
                  listenable: DailyQuestStore.instance,
                  builder: (context, _) {
                    final store = DailyQuestStore.instance;
                    return _topBar(
                      context,
                      auth,
                      name,
                      photoUrl,
                      coins: store.coins,
                      claimable: store.claimableCount,
                    );
                  },
                ),
                const SizedBox(height: 10),
                ListenableBuilder(
                  listenable: TitleStore.instance,
                  builder: (context, _) =>
                      HomeTitleCard(onTap: () => _openTitles(context)),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: ListenableBuilder(
                    listenable: DailyQuestStore.instance,
                    builder: (context, _) => HomeQuestHub(
                      onPlayOffline: () => _showBotPicker(context),
                      onPlayOnline: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const OnlineMenuScreen(),
                          ),
                        );
                      },
                      onLeaderboard: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LeaderboardScreen(),
                          ),
                        );
                      },
                      onFriends: () async {
                        if (!await requireGoogleAccount(context)) return;
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const FriendsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                HomeFooter(
                  onRules: () => _showInfo(
                    context,
                    'Luật chơi UNO',
                    '• 2–${GameLimits.maxPlayers} người · chia 7 lá mỗi người.\n'
                        '• Đánh lá cùng màu, số hoặc loại với lá trên cùng.\n'
                        '• Wild / +4: chọn màu mới.\n'
                        '• Skip · Reverse · +2 theo luật chuẩn.\n'
                    '• Còn 2 lá: hô UNO! khi đánh lá áp chót — quên bị bắt rút 2 lá.\n'
                        '• +2/+4 có thể cộng dồn (đánh đè +2/+4).\n'
                        '• Mỗi lượt chỉ đánh 1 lá.\n'
                        '• Hết bài trước = thắng.',
                  ),
                  onTerms: () => _showInfo(
                    context,
                    'Điều khoản sử dụng',
                    'Bằng việc chơi game, bạn đồng ý tuân thủ luật chơi '
                        'công bằng và không gian thân thiện.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(
    BuildContext context,
    AuthService auth,
    String name,
    String? photoUrl, {
    required int coins,
    required int claimable,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final avatarRadius = compact ? 16.0 : 20.0;
        final actionSize = compact ? 34.0 : 40.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(compact ? 10 : 16, 8, compact ? 8 : 12, 0),
          child: Row(
            children: [
              UserAvatar(
                photoUrl: photoUrl,
                displayName: name,
                radius: avatarRadius,
              ),
              SizedBox(width: compact ? 6 : 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 13 : 15,
                          fontWeight: FontWeight.w600,
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 8),
                      _coinsChip(coins, claimable),
                    ],
                  ],
                ),
              ),
              SizedBox(width: compact ? 4 : 6),
              UnoCircleButton(
                icon: Icons.settings,
                label: '',
                showLabel: false,
                size: actionSize,
                iconScale: 0.5,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              SizedBox(width: compact ? 2 : 4),
              UnoCircleButton(
                icon: Icons.logout,
                label: '',
                showLabel: false,
                size: actionSize,
                iconScale: 0.5,
                onTap: () async {
                  if (!await confirmSignOut(context)) return;
                  await auth.signOut();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _coinsChip(int coins, int claimable) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x662A0707),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x55FFD54F)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on_rounded, color: _gold, size: 14),
          const SizedBox(width: 4),
          Text(
            '$coins',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (claimable > 0) ...[
            const SizedBox(width: 5),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFFD32F2F),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static void _showInfo(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x44FFD54F)),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(
          body,
          style: const TextStyle(color: Colors.white70, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng', style: TextStyle(color: _gold)),
          ),
        ],
      ),
    );
  }

  void _showBotPicker(BuildContext context) {
    var bots = AppSettings.instance.defaultBotCount;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A0505),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chọn số bot',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${bots + 1} người chơi (tối đa ${GameLimits.maxPlayers})',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Slider(
                    value: bots.toDouble(),
                    min: GameLimits.minBots.toDouble(),
                    max: GameLimits.maxBots.toDouble(),
                    divisions: GameLimits.maxBots - GameLimits.minBots,
                    label: '$bots',
                    activeColor: const Color(0xFFFFC107),
                    onChanged: (v) => setLocal(() => bots = v.round()),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC400),
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GameScreen(botCount: bots),
                          ),
                        );
                      },
                      child: const Text(
                        'Bắt đầu',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
