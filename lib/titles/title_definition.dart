import 'package:flutter/material.dart';

enum TitleStatType {
  gamesPlayed,
  offlineWins,
  onlineJoins,
  onlineWins,
}

enum TitleTier {
  /// Dễ mở — chơi vài ván.
  starter,
  /// Mua bằng xu UNO (trang trí).
  shop,
  /// Thành tích offline / online cơ bản.
  achievement,
  /// Cao cấp — chỉ thắng online, không bán xu.
  elite,
}

/// Định nghĩa một danh hiệu (catalog cố định trong app).
class TitleDefinition {
  const TitleDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.tier,
    this.price,
    this.stat,
    this.statTarget,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final TitleTier tier;
  final int? price;
  final TitleStatType? stat;
  final int? statTarget;

  bool get canPurchase => price != null && tier == TitleTier.shop;
  bool get hasAchievement => stat != null && statTarget != null;
  bool get isOnlineExclusive =>
      tier == TitleTier.elite && stat == TitleStatType.onlineWins;
}

/// Danh sách danh hiệu.
const kTitleCatalog = <TitleDefinition>[
  // --- Khởi đầu ---
  TitleDefinition(
    id: 'rookie',
    name: 'Chiếu mới trải bàn',
    description: 'Chơi ván UNO đầu tiên trong đời',
    icon: Icons.play_circle_outline_rounded,
    color: Color(0xFF81C784),
    tier: TitleTier.starter,
    stat: TitleStatType.gamesPlayed,
    statTarget: 1,
  ),
  TitleDefinition(
    id: 'first_win',
    name: 'Bắt nạt máy',
    description: 'Thắng ván offline đầu tiên, khởi đầu một thế lực',
    icon: Icons.celebration_rounded,
    color: Color(0xFFAED581),
    tier: TitleTier.starter,
    stat: TitleStatType.offlineWins,
    statTarget: 1,
  ),
  TitleDefinition(
    id: 'online_explorer',
    name: 'Chào thế giới ảo',
    description: 'Bước chân vào phòng online — ping go brr',
    icon: Icons.public_rounded,
    color: Color(0xFF4DD0E1),
    tier: TitleTier.starter,
    stat: TitleStatType.onlineJoins,
    statTarget: 1,
  ),
  TitleDefinition(
    id: 'bot_hunter',
    name: 'Khắc tinh của AI',
    description: 'Hạ 5 bot — không thương xót',
    icon: Icons.smart_toy_rounded,
    color: Color(0xFF64B5F6),
    tier: TitleTier.starter,
    stat: TitleStatType.offlineWins,
    statTarget: 5,
  ),
  TitleDefinition(
    id: 'casual',
    name: 'Làm ván nữa rồi ngủ',
    description: 'Cày cuốc đủ 10 ván (nhưng thường là không dừng lại được)',
    icon: Icons.casino_rounded,
    color: Color(0xFFFFCC80),
    tier: TitleTier.starter,
    stat: TitleStatType.gamesPlayed,
    statTarget: 10,
  ),

  // --- Cửa hàng xu (trang trí) ---
  TitleDefinition(
    id: 'lucky_star',
    name: 'Hào quang rực rỡ',
    description: 'Danh hiệu lấp lánh mua bằng "sức mạnh đồng tiền"',
    icon: Icons.star_half_rounded,
    color: Color(0xFFFFF176),
    tier: TitleTier.shop,
    price: 150,
  ),
  TitleDefinition(
    id: 'red_spark',
    name: 'Tay thối đổi vận',
    description: 'Một chút sắc đỏ phong thủy cho bớt bốc bài',
    icon: Icons.bolt_rounded,
    color: Color(0xFFEF5350),
    tier: TitleTier.shop,
    price: 250,
  ),
  TitleDefinition(
    id: 'blue_wave',
    name: 'Chúa tể lật kèo',
    description: 'Màu xanh của hy vọng, lật ngược thế cờ phút chót',
    icon: Icons.waves_rounded,
    color: Color(0xFF42A5F5),
    tier: TitleTier.shop,
    price: 250,
  ),
  TitleDefinition(
    id: 'party_king',
    name: 'Vua phạt bài',
    description: 'Ném lá +4 vào mặt bạn bè không chút do dự',
    icon: Icons.celebration_outlined,
    color: Color(0xFFFF7043),
    tier: TitleTier.shop,
    price: 400,
  ),
  TitleDefinition(
    id: 'gold_leaf',
    name: 'Đại gia phố bài',
    description: 'Đổi màu bài phong cách hoàng gia, sặc mùi tiền',
    icon: Icons.eco_rounded,
    color: Color(0xFFFFD54F),
    tier: TitleTier.shop,
    price: 600,
  ),

  // --- Thành tích ---
  TitleDefinition(
    id: 'veteran',
    name: 'Dân chơi hệ gạo cội',
    description: 'Đã kinh qua 30 ván bài, nhìn thấu hồng trần',
    icon: Icons.military_tech_rounded,
    color: Color(0xFFFFB74D),
    tier: TitleTier.achievement,
    stat: TitleStatType.gamesPlayed,
    statTarget: 30,
  ),
  TitleDefinition(
    id: 'bot_master',
    name: 'Bố của Bot',
    description: 'Thắng máy 20 lần, thuật toán cũng phải chào thua',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFBA68C8),
    tier: TitleTier.achievement,
    stat: TitleStatType.offlineWins,
    statTarget: 20,
  ),
  TitleDefinition(
    id: 'bot_legend',
    name: 'Ác mộng của bot',
    description: '50 lần bán hành cho máy, cô đơn trên đỉnh cao offline',
    icon: Icons.psychology_rounded,
    color: Color(0xFF7E57C2),
    tier: TitleTier.achievement,
    stat: TitleStatType.offlineWins,
    statTarget: 50,
  ),
  TitleDefinition(
    id: 'online_first_win',
    name: 'Chiến thắng đầu đời',
    description: 'Cảm giác hạ gục người chơi thật nó sướng gì đâu',
    icon: Icons.wifi_tethering_rounded,
    color: Color(0xFF26C6DA),
    tier: TitleTier.achievement,
    stat: TitleStatType.onlineWins,
    statTarget: 1,
  ),
  TitleDefinition(
    id: 'net_fighter',
    name: 'Chiến thần Internet',
    description: 'Thắng 5 trận online, bắt đầu có số có má trên mạng',
    icon: Icons.sports_esports_rounded,
    color: Color(0xFF29B6F6),
    tier: TitleTier.achievement,
    stat: TitleStatType.onlineWins,
    statTarget: 5,
  ),
  TitleDefinition(
    id: 'room_regular',
    name: 'Gương mặt thân quen',
    description: 'Vào phòng 15 lần — như về nhà',
    icon: Icons.groups_rounded,
    color: Color(0xFF4DB6AC),
    tier: TitleTier.achievement,
    stat: TitleStatType.onlineJoins,
    statTarget: 15,
  ),

  // --- Độc quyền online (không bán xu) ---
  TitleDefinition(
    id: 'arena_ace',
    name: 'Sát thủ phòng chờ',
    description: '15 trận thắng online, ai thấy tên cũng phải rén',
    icon: Icons.shield_rounded,
    color: Color(0xFF5C6BC0),
    tier: TitleTier.elite,
    stat: TitleStatType.onlineWins,
    statTarget: 15,
  ),
  TitleDefinition(
    id: 'crimson_legend',
    name: 'Gà nhà người ta',
    description: 'Bá chủ 30 trận online, đối thủ nhìn bài tự động đầu hàng',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFE53935),
    tier: TitleTier.elite,
    stat: TitleStatType.onlineWins,
    statTarget: 30,
  ),
  TitleDefinition(
    id: 'storm_champion',
    name: 'Cơn ác mộng +4',
    description: 'Thắng 50 trận online bằng cả chiến thuật lẫn độ lươn lẹo',
    icon: Icons.thunderstorm_rounded,
    color: Color(0xFF7E57C2),
    tier: TitleTier.elite,
    stat: TitleStatType.onlineWins,
    statTarget: 50,
  ),
  TitleDefinition(
    id: 'galaxy_master',
    name: 'Nhà tiên tri sắc màu',
    description: '75 trận thắng mạng, hô màu nào là màu đó ra bài',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFFAB47BC),
    tier: TitleTier.elite,
    stat: TitleStatType.onlineWins,
    statTarget: 75,
  ),
  TitleDefinition(
    id: 'uno_emperor',
    name: 'Độc cô cầu bại',
    description: '100 trận thắng online, đỉnh cao không lối thoát',
    icon: Icons.workspace_premium_rounded,
    color: Color(0xFFFFC400),
    tier: TitleTier.elite,
    stat: TitleStatType.onlineWins,
    statTarget: 100,
  ),
  TitleDefinition(
    id: 'immortal_uno',
    name: 'Thần bài phương Đông',
    description: '150 ván thắng mạng, ghi danh vào sử sách UNO',
    icon: Icons.diamond_rounded,
    color: Color(0xFFE1BEE7),
    tier: TitleTier.elite,
    stat: TitleStatType.onlineWins,
    statTarget: 150,
  ),
  TitleDefinition(
    id: 'world_conqueror',
    name: 'Vô địch server',
    description: '200 thắng online — đỉnh của chóp',
    icon: Icons.public_off_rounded,
    color: Color(0xFFFF6F00),
    tier: TitleTier.elite,
    stat: TitleStatType.onlineWins,
    statTarget: 200,
  ),
  TitleDefinition(
    id: 'goat',
    name: 'GOAT',
    description: '500 trận thắng online — out trình tuyệt đối',
    icon: Icons.stars_rounded,
    color: Color(0xFFFF3D00),
    tier: TitleTier.elite,
    stat: TitleStatType.onlineWins,
    statTarget: 500,
  ),
];

TitleDefinition? titleById(String id) {
  for (final t in kTitleCatalog) {
    if (t.id == id) return t;
  }
  return null;
}

String tierLabel(TitleTier tier) {
  switch (tier) {
    case TitleTier.starter:
      return 'Tập sự';
    case TitleTier.shop:
      return 'Mua cho oai';
    case TitleTier.achievement:
      return 'Cày cuốc';
    case TitleTier.elite:
      return 'Boss online';
  }
}
