# Phát hành APK qua GitHub Actions

Workflow [`.github/workflows/release-apk.yml`](../.github/workflows/release-apk.yml) tự build APK release và đăng lên **GitHub Releases** khi bạn push tag `v*`.

## 1. Secret bắt buộc

Vào repo GitHub → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**:

| Secret | Nội dung |
|--------|----------|
| `GOOGLE_SERVICES_JSON` | Toàn bộ nội dung file `android/app/google-services.json` (copy nguyên file) |

> File này không có trên git — lấy từ Firebase Console hoặc máy dev local.

## 2. Secret ký APK (khuyến nghị, tùy chọn)

Không set → CI ký bằng **debug key** (test được, không phù hợp phát hành lâu dài).

| Secret | Nội dung |
|--------|----------|
| `ANDROID_KEYSTORE_BASE64` | File `.jks` encode base64 (PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks"))`) |
| `ANDROID_KEYSTORE_PASSWORD` | Mật khẩu keystore |
| `ANDROID_KEY_ALIAS` | Alias (vd: `upload`) |
| `ANDROID_KEY_PASSWORD` | Mật khẩu key |

Sau khi thêm keystore release, lấy **SHA-1 / SHA-256** và thêm vào Firebase (Android app) để đăng nhập Google hoạt động trên APK release.

## 3. Tạo bản release

1. Tăng version trong `pubspec.yaml` (vd `1.0.1+2`)
2. Commit và push lên GitHub
3. Tạo tag và push:

```bash
git tag v1.0.1
git push origin v1.0.1
```

4. Vào **Actions** — workflow **Release APK** chạy tự động
5. Khi xong, file `uno-game-v1.0.1.apk` nằm trong **Releases**

Link tải cho người chơi:

`https://github.com/<user>/<repo>/releases/latest`

## 4. Build thủ công (không tag)

GitHub → **Actions** → **Release APK** → **Run workflow**

APK nằm trong **Artifacts** của run đó (không tạo Release).

## 5. Người chơi cài APK

1. Mở link Releases trên điện thoại
2. Tải file `.apk`
3. Cho phép cài từ nguồn không xác định (nếu Android hỏi)
4. Cài đặt và mở app **UNO**
