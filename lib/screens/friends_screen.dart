import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../friends/friend_models.dart';
import '../friends/friends_service.dart';
import '../online/auth_service.dart';
import '../titles/title_definition.dart';
import '../widgets/app_snack.dart';
import '../widgets/title_name_text.dart';
import '../widgets/uno_circle_button.dart';
import '../widgets/user_avatar.dart';

/// Màn bạn bè: danh sách + lời mời kết bạn.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFFFD54F);

  final _service = FriendsService();
  final _codeCtrl = TextEditingController();
  late final TabController _tabs;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _ensureMyFriendCode();
  }

  Future<void> _ensureMyFriendCode() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null || uid.isEmpty || AuthService().isGuest) return;
    try {
      await _service.ensureFriendCode(uid);
    } on FriendsException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (e) {
      if (mounted) {
        AppSnack.error(context, 'Không tạo được mã bạn bè. Thử lại sau.');
      }
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _addFriend() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      AppSnack.error(context, 'Nhập mã bạn bè');
      return;
    }
    setState(() => _busy = true);
    try {
      await _service.sendFriendRequestByCode(code);
      if (!mounted) return;
      _codeCtrl.clear();
      AppSnack.info(context, 'Đã gửi lời mời kết bạn');
    } on FriendsException catch (e) {
      if (mounted) AppSnack.error(context, e.message);
    } catch (e) {
      if (mounted) {
        AppSnack.error(
          context,
          e is FirebaseException
              ? FriendsService.mapFirebaseError(e)
              : 'Không gửi được lời mời. Thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A0707),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 1.2,
            colors: [Color(0xFF4A1A6A), Color(0xFF1A0505), Color(0xFF2A0707)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              _topPanel(),
              const SizedBox(height: 4),
              _tabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _friendsList(),
                    _friendRequestsList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: UnoCircleButton(
              icon: Icons.arrow_back,
              label: '',
              showLabel: false,
              size: 44,
              iconScale: 0.52,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          const TitleNamePlain(
            name: 'BẠN BÈ',
            tier: TitleTier.elite,
            accent: _gold,
            fontSize: 20,
            letterSpacing: 1.2,
            shimmer: true,
          ),
        ],
      ),
    );
  }

  Widget _topPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x662A0707),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _gold.withValues(alpha: 0.22)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _myCodeBar(compact: true),
              const SizedBox(height: 14),
              const Text(
                'Thêm bạn bằng mã',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              _addFriendBar(compact: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _myCodeBar({bool compact = false}) {
    return StreamBuilder<String?>(
      stream: _service.watchMyFriendCode(),
      builder: (context, snap) {
        final code = snap.data ?? '------';
        final child = GestureDetector(
          onTap: code.length == 6
              ? () {
                  Clipboard.setData(ClipboardData(text: code));
                  AppSnack.info(context, 'Đã sao chép mã bạn bè');
                }
              : null,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: compact ? 12 : 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0x992A0707),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gold.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Mã của bạn: ',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                if (code.length == 6) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.copy, color: Colors.white54, size: 16),
                ],
              ],
            ),
          ),
        );
        if (compact) return child;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: child,
        );
      },
    );
  }

  Widget _addFriendBar({bool compact = false}) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              letterSpacing: 4,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: 'MÃ BẠN BÈ',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                letterSpacing: 2,
                fontSize: 13,
              ),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 44,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            onPressed: _busy ? null : _addFriend,
            child: const Text(
              'Thêm',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
    if (compact) return row;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: row,
    );
  }

  Widget _tabBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: TabBar(
      controller: _tabs,
      isScrollable: true,
      tabAlignment: TabAlignment.center,
      indicatorColor: _gold,
      labelColor: _gold,
      unselectedLabelColor: Colors.white54,
      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      dividerColor: Colors.white12,
      tabs: const [
        Tab(text: 'Bạn bè'),
        Tab(text: 'Lời mời'),
      ],
      ),
    );
  }

  Widget _friendsList() {
    return StreamBuilder<List<FriendProfile>>(
      stream: _service.watchFriends(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _gold));
        }
        final friends = snap.data ?? [];
        if (friends.isEmpty) {
          return const Center(
            child: Text(
              'Chưa có bạn bè.\nNhập mã bạn bè để kết bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, height: 1.45),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: friends.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _friendTile(friends[i]),
        );
      },
    );
  }

  Widget _friendTile(FriendProfile friend) {
    final online = FriendsService.isFriendOnline(friend);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x992A0707),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        leading: UserAvatar(
          photoUrl: friend.photoUrl,
          displayName: friend.displayName,
          radius: 22,
        ),
        title: Text(
          friend.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: online ? const Color(0xFF81C784) : Colors.white38,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              online ? 'Online' : 'Offline',
              style: TextStyle(
                color: online ? const Color(0xFF81C784) : Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _friendRequestsList() {
    return StreamBuilder<List<FriendRequest>>(
      stream: _service.watchIncomingRequests(),
      builder: (context, snap) {
        final requests = snap.data ?? [];
        if (requests.isEmpty) {
          return const Center(
            child: Text(
              'Không có lời mời kết bạn.',
              style: TextStyle(color: Colors.white60),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final req = requests[i];
            return DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x992A0707),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _gold.withValues(alpha: 0.25)),
              ),
              child: ListTile(
                leading: UserAvatar(
                  photoUrl: req.fromPhotoUrl,
                  displayName: req.fromName ?? 'Người chơi',
                  radius: 22,
                ),
                title: Text(
                  req.fromName ?? 'Người chơi',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Muốn kết bạn',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Color(0xFF81C784)),
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              try {
                                await _service.acceptFriendRequest(req.id);
                                if (mounted) {
                                  AppSnack.info(
                                      this.context, 'Đã chấp nhận kết bạn');
                                }
                              } on FriendsException catch (e) {
                                if (mounted) {
                                  AppSnack.error(this.context, e.message);
                                }
                              } catch (e) {
                                if (mounted) {
                                  AppSnack.error(
                                    this.context,
                                    e is FirebaseException
                                        ? FriendsService.mapFirebaseError(e)
                                        : 'Không chấp nhận được lời mời.',
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.white38),
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              try {
                                await _service.declineFriendRequest(req.id);
                              } on FriendsException catch (e) {
                                if (mounted) {
                                  AppSnack.error(this.context, e.message);
                                }
                              } catch (e) {
                                if (mounted) {
                                  AppSnack.error(
                                    this.context,
                                    e is FirebaseException
                                        ? FriendsService.mapFirebaseError(e)
                                        : 'Không từ chối được lời mời.',
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
