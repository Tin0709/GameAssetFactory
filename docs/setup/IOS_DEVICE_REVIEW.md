# GameAssetFactory trên iPhone

iPhone là thiết bị ưu tiên cho kiểm thử mobile. Windows tiếp tục dùng để phát triển và kiểm tra hồi quy. MacBook Pro M2 xuất bản build Godot, ký, cài lên iPhone và chạy Instruments. Ghi riêng kết quả iPhone, Mac, Windows và Android.

## Nội dung bản kiểm thử

Bản device review mở WorldMap với preset dùng chung **Rìa rừng ẩm** và nhân vật gốc có sẵn trong project. Dùng joystick để di chuyển, nút **Chạy** và **Nhảy** để xem animation, **+/−** để đổi zoom, **Đổi giờ** để qua 07:00, 12:00, 16:30, 19:30, 22:00 và **Mây** để chuyển thời tiết. **Cài đặt** mở các mức chất lượng hiện có. HUD lấy FPS và tên driver đang hoạt động trực tiếp từ Godot. Bản kiểm thử tắt âm thanh.

MD2/A&S, Sabre, Kai và các reference LUT hoặc trường ánh sáng editor-private cần dữ liệu ngoài repository. Chúng tiếp tục dùng trong bản F5 private. Mọi phép đo trên iPhone phải ghi rõ đang chạy nội dung device review. Dữ liệu private và mã adapter chỉ dùng trong editor nằm ngoài bản xuất. Các export khác chỉ chọn chế độ review nếu bật feature `gaf_device_review`.

## Chuẩn bị một lần trên Mac

1. Cài Xcode đầy đủ và iOS platform support. Mở Xcode, chấp nhận license và chọn Xcode trong **Settings → Locations → Command Line Tools**. Cài Godot standard **4.7.2.stable.official.ed1daf0bf** và bộ export templates cùng phiên bản trong **Editor → Manage Export Templates**. [Xuất iOS bằng Godot](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html) · [Công cụ dòng lệnh Xcode](https://developer.apple.com/documentation/xcode/xcode-command-line-tool-reference)
2. Mở **Xcode → Settings → Accounts** và thêm Apple Account của mình. Dùng team và bundle ID riêng cho bản review. Kết nối iPhone với Mac qua USB, mở khóa, xác nhận Trust và bật Developer Mode khi Xcode yêu cầu. [Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
3. Đồng bộ checkout trên Mac theo [hướng dẫn MacBook](MACBOOK_SETUP.md) và chạy `git lfs pull`. Luôn ghi lại `git rev-parse --short HEAD` trên hai máy trước khi so. Với commit đang giữ riêng trên Windows, có thể chuyển phần lịch sử chưa đẩy bằng Git bundle. Bundle không mang theo LFS objects mới. Lấy các object đó qua quy trình Git LFS đang dùng.

```powershell
git bundle create "$env:USERPROFILE/Desktop/GameAssetFactory-review.bundle" origin/main..main
```

Chép bundle qua thư mục chia sẻ đang dùng hoặc thiết bị lưu trữ. Trên Mac chạy lệnh dưới đây trong checkout đã có commit gốc tương ứng. Branch review tách riêng để giữ công việc đang làm trên Mac.

```sh
git bundle verify ~/Downloads/GameAssetFactory-review.bundle
git fetch ~/Downloads/GameAssetFactory-review.bundle main
git switch -c iphone-review FETCH_HEAD
```

Sau lần đầu, dùng `git switch iphone-review` và `git merge --ff-only FETCH_HEAD` cho bản đồng bộ tiếp theo. Nếu branch không thể fast-forward, xem lại lịch sử hai máy trước khi hợp nhất.

## Xuất và cài lên iPhone

Chạy từ thư mục GameAssetFactory trên Mac. Nếu Godot ở một bundle khác, đặt `GODOT_BIN` trỏ tới binary bên trong bundle.

```sh
python3 scripts/ios_review.py check
python3 scripts/ios_review.py devices
export GAF_IOS_TEAM_ID='TEAM_ID_10_KY_TU'
export GAF_IOS_BUNDLE_ID='com.tenmiencuaban.gameassetfactory.review'
python3 scripts/ios_review.py build --team-id "$GAF_IOS_TEAM_ID" --bundle-id "$GAF_IOS_BUNDLE_ID"
```

Mở đường dẫn `.xcodeproj` lệnh in ra. Trong **Signing & Capabilities**, dùng **Automatically manage signing** và chọn team đã đăng nhập. Chọn đúng iPhone ở Run Destination và bấm **Run** để tạo provisioning và kiểm màn hình đầu. ID ký chỉ dùng cục bộ. Mỗi lần chạy tạo thư mục mới dưới `game_mobile_3d/builds/device_review` và để nguyên preset trong checkout chính.

Khi việc ký đã hoạt động, build/cài/mở trực tiếp bằng CLI. Lấy ID thật của iPhone từ Xcode. Cờ `--allow-provisioning-updates` cho phép Xcode cập nhật profile khi cần. Thêm `--release-template` cho phiên đo hiệu năng, dùng cùng loại build cho cả hai vế A/B.

```sh
python3 scripts/ios_review.py build --team-id "$GAF_IOS_TEAM_ID" --bundle-id "$GAF_IOS_BUNDLE_ID" \
  --device "$GAF_IPHONE_DEVICE_ID" --allow-provisioning-updates --release-template
```

Nếu cần chạy trên Windows trước, dùng `python scripts/ios_review.py pack` để xuất PCK và khởi chạy headless từ PCK. Dùng đối chiếu trực quan bằng Godot Mobile với `-- --gaf-device-review` ở cuối lệnh khi chạy editor binary. Kết quả này xác nhận đường export và hành vi project trên PC. Lần chạy đầu trên iPhone phải thấy `renderer=mobile driver=metal` trong log hoặc HUD. Simulator chỉ phù hợp kiểm bố cục ở đường Compatibility. [Godot iOS export và simulator](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html) · [Driver theo nền tảng](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-rendering-rendering-device-driver-ios)

## Đo trên iPhone thật

1. Ghi model iPhone, iOS, commit, template Debug hay Release, renderer, chất lượng, render scale, mức pin và trạng thái nhiệt ban đầu. Dùng cùng góc máy, giờ, thời tiết và tuyến chạy khi so A/B. Kiểm khởi động, di chuyển, chạy, nhảy, zoom, đổi mây, đổi giờ rồi thử các mức đồ họa.
2. Chạy tuyến bậc đá và lối rừng trong 10 phút. Ghi FPS và frame pacing sau lúc tải, so đoạn đầu và đoạn cuối. Đo GPU duration trong **Game Performance** hoặc **Metal System Trace**, memory footprint và đỉnh RAM bằng công cụ phù hợp trong Instruments. Lưu thermal state cùng các mốc đo. Đặt app chạy trước khi ghi trace bằng CLI. [Game Performance và Metal System Trace](https://developer.apple.com/documentation/xcode/analyzing-the-performance-of-your-metal-app/)
3. Lưu `.trace` cùng ảnh theo mốc giờ, ghi rõ tên vế A/B. Dùng Xcode Metal Capture cho một frame đại diện khi cần tìm pass, pipeline hoặc texture tốn chi phí. Dùng phiên chơi liên tục khi đo hiệu năng duy trì. [Metal GPU profiling](https://developer.apple.com/documentation/xcode/optimizing-gpu-performance)

```sh
xcrun xctrace list templates
python3 scripts/ios_review.py record --device "$GAF_IPHONE_DEVICE_ID" --duration 10m
```

Nếu tên template hoặc bộ đếm tùy phiên bản Xcode và model iPhone, dùng **Product → Profile** để chọn tập dữ liệu thực tế thiết bị hỗ trợ. Android vẫn dùng renderer và luồng export riêng. Kết quả iPhone hoặc PC không đại diện cho Android.
