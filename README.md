# UNO Game

Game UNO Flutter — chơi offline với bot, online qua Firebase, tiếng Việt, theme đỏ/vàng.

**Nền tảng hỗ trợ:** Android (máy thật), Web (dev/test trên PC). Không build iOS.

## Tính năng

- Offline: 2–10 người (1 bạn + bot)
- Online: phòng 6 ký tự, bạn bè, mời chơi
- Luật: hô/bắt UNO, combo +2/+4 (house rule)
- Quest ngày/tuần, danh hiệu, bảng xếp hạng
- Đăng nhập Google hoặc chơi khách

## Yêu cầu

- Flutter SDK ^3.12
- Tài khoản Firebase (project đã cấu hình FlutterFire)

## Cài đặt lần đầu

```bash
flutter pub get
```

### Firebase

1. Tạo project trên [Firebase Console](https://console.firebase.google.com).
2. Chạy `flutterfire configure` (chọn **Android** và **Web**).
3. Copy `google-services.json` vào `android/app/` (file gitignore — không push).
4. Deploy Firestore rules:

```bash
firebase deploy --only firestore:rules
```

### Chạy dev

```bash
# Android emulator / máy thật
flutter run

# Web (có Device Preview khi debug)
flutter run -d chrome
```

### Build Android cho tester

```bash
flutter build apk --release
```

Xem [android/SIGNING.md](android/SIGNING.md) để ký release đúng cách.

## Assets (ảnh)

- Nền: `assets/images/background/` — xem README trong thư mục
- Lá bài: `assets/images/cards/` — thiếu ảnh vẫn chạy (placeholder)

## Cấu trúc chính

| Thư mục | Mô tả |
|---------|--------|
| `lib/models/game_state.dart` | Engine luật UNO |
| `lib/game/` | Offline controller + bot |
| `lib/online/` | Phòng Firestore, auth |
| `lib/screens/` | UI màn hình |
| `firestore.rules` | Bảo mật Firestore |

## Bảo mật online

Rules giới hạn: chỉ chủ phòng bắt đầu/chơi lại; nước đi game chỉ người đang lượt (hoặc bắt UNO); stats user chỉ tăng trong ngưỡng cho phép.

> Gian lận hoàn toàn chặn được cần Cloud Functions — hiện tại phù hợp nhóm bạn bè.

## Test

```bash
flutter test
flutter analyze
```
