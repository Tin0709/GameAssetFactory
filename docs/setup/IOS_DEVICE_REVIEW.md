# GameAssetFactory trên iPhone

iPhone là thiết bị ưu tiên cho kiểm thử mobile. Windows tiếp tục dùng để phát triển và kiểm tra hồi quy. MacBook Pro M2 xuất bản build Godot, ký, cài lên iPhone và chạy Instruments. Ghi riêng kết quả iPhone, Mac, Windows và Android.

## Nội dung bản kiểm thử

Bản device review mở WorldMap với preset dùng chung **Rìa rừng ẩm** và nhân vật gốc có sẵn trong project. Dùng joystick để di chuyển, nút **Chạy** và **Nhảy** để xem animation, **+/−** để đổi zoom, **Đổi giờ** để qua 07:00, 12:00, 16:30, 19:30, 22:00 và **Mây** để chuyển thời tiết. **Cài đặt** mở các mức chất lượng hiện có. HUD lấy FPS và tên driver đang hoạt động trực tiếp từ Godot. Bản kiểm thử tắt âm thanh.

Ở preset **Rìa rừng ẩm**, mức **Cân bằng** và **Đầy đủ** có ánh hắt từ cỏ, đất và đá giúp thấy rõ nhân vật lúc thiếu sáng. Trong **Cài đặt → Đồ họa bản đồ → Ánh hắt từ nền**, kéo về 0% để so với ánh sáng gốc. Thử ở 07:00, 19:30 và 22:00. Nhân vật ở 12:00 dùng ánh sáng gốc.

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

Nếu có bản vá workflow chưa commit đi kèm bundle, chạy `git apply --check` với đường dẫn bản vá trên branch review trước khi chạy `git apply`. Giữ cả bundle và bản vá trong phần lưu trữ nội bộ. Với các lần đồng bộ qua Git sau đó, lấy các thay đổi bằng commit tương ứng.

## Xuất và cài lên iPhone

Chạy từ thư mục GameAssetFactory trên Mac. Nếu Godot ở một bundle khác, đặt `GODOT_BIN` trỏ tới binary bên trong bundle.

```sh
python3 scripts/ios_review.py check
export GAF_IOS_TEAM_ID='TEAM_ID_10_KY_TU'
export GAF_IOS_BUNDLE_ID='com.tenmiencuaban.gameassetfactory.review'
python3 scripts/ios_review.py build
```

Mở đường dẫn `.xcodeproj` lệnh in ra. Trong **Signing & Capabilities**, dùng **Automatically manage signing** và chọn team đã đăng nhập. Chọn đúng iPhone ở Run Destination và bấm **Run** để tạo provisioning và kiểm màn hình đầu. ID ký chỉ dùng cục bộ. Mỗi lần chạy tạo thư mục mới dưới `game_mobile_3d/builds/device_review` và để nguyên preset trong checkout chính.

Khi việc ký đã hoạt động, build, cài và mở trực tiếp bằng CLI. Lấy UDID của iPhone từ phần đầu của lệnh `devices` hoặc trong **Xcode → Window → Devices and Simulators**. Nếu `devicectl` của bản Xcode đang dùng yêu cầu ID khác, đặt `GAF_IPHONE_CORE_DEVICE_ID` theo phần CoreDevice của lệnh `devices`. Dùng `--allow-provisioning-updates` khi Xcode cần tạo hoặc cập nhật profile. Thêm `--release-template` cho phiên đo hiệu năng và dùng cùng loại build cho cả hai vế A/B. Cả hai loại template dùng chữ ký **Apple Development** cho luồng này. Khi lỗi ở bước Xcode, mở `Build.xcresult` nếu Xcode đã ghi kết quả.

```sh
python3 scripts/ios_review.py devices
export GAF_IPHONE_DEVICE_ID='UDID_CUA_IPHONE'
python3 scripts/ios_review.py build --device "$GAF_IPHONE_DEVICE_ID" --release-template
```

Trên Windows, `python scripts/ios_review.py pack` xuất PCK và chạy smoke test headless. Khi cần kiểm tra cấu trúc bộ xuất iOS trước khi đồng bộ, `python scripts/ios_review.py project --release-template` tạo dự án Xcode chưa ký nếu sẵn template `ios.zip` cùng phiên bản. Lệnh nhận cùng biến Team ID, Bundle ID và tùy chọn `--ios-template`. Dùng đối chiếu trực quan bằng Godot Mobile với `-- --gaf-device-review` ở cuối lệnh khi chạy editor binary. Lần chạy đầu trên iPhone phải có `renderer=mobile driver=metal` trong log. HUD hiển thị `metal`. Simulator chỉ phù hợp kiểm bố cục ở đường Compatibility. [Godot iOS export và simulator](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html) · [Driver theo nền tảng](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-rendering-rendering-device-driver-ios)

## Đo trên iPhone thật

1. Ghi model iPhone, iOS, commit, template Debug hay Release, renderer, chất lượng, render scale, mức pin và trạng thái nhiệt ban đầu. Dùng cùng góc máy, giờ, thời tiết và tuyến chạy khi so A/B. Kiểm khởi động, di chuyển, chạy, nhảy, zoom, đổi mây, đổi giờ rồi thử các mức đồ họa.
2. Mở app và bắt đầu ghi Instruments, sau đó bấm **Đo 10p** trong WorldMap. App lặp cùng tuyến ở lối rừng và bậc đá, đủ năm mốc giờ và có lượt 16:30 nhiều mây. Thứ tự là **Đầy đủ → Cân bằng → Cân bằng → Đầy đủ**. Mỗi đoạn có 2 giây ổn định trước khi đo, sau đó nhân vật đi, chạy, nhảy và đổi zoom. App trả lại vị trí và cài đặt khi kết thúc hoặc bấm **Dừng**. Đo GPU duration trong **Game Performance** hoặc **Metal System Trace**, memory footprint và đỉnh RAM bằng công cụ phù hợp trong Instruments. Lưu thermal state cùng các mốc đo. [Game Performance và Metal System Trace](https://developer.apple.com/documentation/xcode/analyzing-the-performance-of-your-metal-app/)
3. Lưu `.trace` cùng ảnh theo mốc giờ, ghi rõ tên vế A/B. Đối chiếu các đoạn đầu và cuối cùng mức **Đầy đủ**, với cùng địa điểm, giờ và góc máy. Mục tiêu 30 FPS cho ngân sách 33,3 ms/khung. Đối chiếu P95, GPU duration, memory footprint và thermal state trước khi kết luận nguyên nhân tụt FPS. Dùng **Game Memory** riêng khi cần truy nguồn cấp phát, và **Metal Capture** riêng cho một frame đại diện để tìm pass, pipeline hoặc texture tốn chi phí. [Game Memory](https://developer.apple.com/documentation/xcode/analyzing-the-memory-usage-of-your-metal-app) · [Metal GPU profiling](https://developer.apple.com/documentation/xcode/optimizing-gpu-performance)

```sh
xcrun xctrace list templates
python3 scripts/ios_review.py record --device "$GAF_IPHONE_DEVICE_ID" --duration 12m
```

Khi app hiện **Đã lưu kết quả đo**, tìm file JSON trong thư mục `device_review_runs` của app. Từ **Xcode → Window → Devices and Simulators**, chọn iPhone và app rồi dùng **Download Container**. Log có dòng `GAF_DEVICE_BENCH_RESULT` kèm đường dẫn. Báo cáo ghi FPS và frametime theo đoạn, GPU viewport khi Godot có mẫu, cùng đỉnh draw call và bộ nhớ do renderer báo. Bộ nhớ renderer và memory footprint của tiến trình là hai phép đo riêng. Lưu cả JSON và Instruments trace để có thể đối chiếu. [Lấy app container qua Xcode](https://developer.apple.com/documentation/metal/creating-binary-archives-from-device-built-pipeline-state-objects)

```sh
python3 scripts/ios_review.py summarize "/đường-dẫn/đến/kết-quả.json"
```

Nếu tên template hoặc bộ đếm tùy phiên bản Xcode và model iPhone, dùng **Product → Profile** để chọn tập dữ liệu thực tế thiết bị hỗ trợ. Android vẫn dùng renderer và luồng export riêng. Kết quả iPhone hoặc PC không đại diện cho Android.
