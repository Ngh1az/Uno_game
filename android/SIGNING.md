# Ký APK release (Android)

Debug build dùng debug keystore. **APK release** cần keystore riêng trước khi phát cho nhiều người.

## 1. Tạo keystore (một lần)

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Lưu file **ngoài** git (ví dụ `C:\Users\<you>\upload-keystore.jks`).

## 2. Tạo `android/key.properties` (gitignore)

```properties
storePassword=<mật khẩu>
keyPassword=<mật khẩu>
keyAlias=upload
storeFile=C:\\Users\\<you>\\upload-keystore.jks
```

## 3. Sửa `android/app/build.gradle.kts`

Thêm đọc `key.properties` và gán `signingConfigs.release` cho `buildTypes.release`.

## 4. Build

```bash
flutter build apk --release
```

APK: `build/app/outputs/flutter-apk/app-release.apk`

> **Lưu ý:** Mất keystore = không cập nhật được app đã cài trên máy tester (phải gỡ cài lại).
