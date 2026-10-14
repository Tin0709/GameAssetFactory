# Walking từ dữ liệu Actions & Stuff

Bản thử ngày 2026-10-14, trạng thái **Pending human review**. Action `Walk_ActionsStuff_Source_Test_v001` chuyển clip `animation.oreville_ans.tldiyl` trong gói người dùng cung cấp sang rig nguyên khối hiện có của game. Giữ nhịp chân, công thức tay/thân/đầu và các mốc keyframe của nguồn; chưa tích hợp Godot.

## Mở bản thử

File người dùng yêu cầu đã có animation mới:

`../player_animation_library_v1.blend`

Scene mặc định là `ASW_Walking_Review_v001`. Trong **Player Review → Locomotion**, chọn **Walking / Actions & Stuff source v001 [Pending]**. Space phát/dừng; Front, Side, 3/4 đổi camera. Nếu panel chưa xuất hiện, chạy Text `START_HERE_review_controls.py` một lần hoặc dùng `open_review.py` khi mở Blender.

Action cũng được đăng ký Pending trong thư viện Animation Showcase hiện có. Bản nguồn để chỉnh riêng là `walk_actions_stuff_review.blend`.

## Timing và chuyển đổi

- Playback F1–24, 30 FPS, một vòng 0.8 giây. F25 là key đóng vòng, không phát thêm frame đó.
- Chọn 0.8 giây cho bản xem thử, tương ứng đồng hồ nguồn khi tốc độ chuẩn hóa đi thẳng khoảng 0.61035. Nguồn không quy định mọi vòng đi bộ luôn dài 0.8 hay 1 giây.
- Bake 480 Hz, ưu tiên giữ các breakpoint gốc. Dịch trục và giải ngược parent/rest matrix, giữ nguyên 13 bone, mixed Euler/quaternion, mesh, UV, weights và khoảng thu vai 32 mm đã có.
- Giữ pivot xoay tay của nguồn ở dưới mép vai hai đơn vị model. ForeArm là helper khóa thẳng; không tạo khuỷu/gối, scale hoặc rebuild rig.
- Chân nguồn theo root, còn chân rig của ta theo Hips. Translation đã bù hierarchy để hông không áp chuyển động lên chân thêm lần nữa.
- Đây là clip đi bộ tiến với trọng số đầy đủ. Những controller, look direction, bob, item/weapon và điều kiện trạng thái khác của Minecraft không được mô phỏng trong bản thử này.

Mặt sàn xem trước hạ **38 mm** để khớp điểm thấp nhất của chuyển động chân nguyên bản trên model của ta. Không thêm foot lock hoặc sửa đường chân để che sai khác retarget. Vì vậy bản này ưu tiên hình dáng chuyển động từ nguồn; contact, trượt chân và chuyển state trong gameplay vẫn cần review sau.

## Kiểm tra và bảo toàn

`source_verification.json` kiểm tra 242 thời điểm transform và 241 mẫu hình học. Loop pose khép kín, scale luôn 1. Sai số phần tử matrix lớn nhất với phép retarget đã định nghĩa là khoảng `2.72e-5`; đây không phải chứng nhận khớp pixel với Minecraft.

`saved_library_verification.json` xác nhận mở lại file đã lưu: **326 Action cũ, 271 armature, 1,382 mesh cùng UV/weights và 60 mục review cũ** được giữ nguyên. Thư viện đích có 327 Action và 61 mục review. `central_registration.json` ghi thêm một mục Pending vào Animation Showcase, giữ cả 34 Action trước đó.

Các bản sao đầy đủ trước thay đổi nằm trong `.validation/actions_stuff_walk_source_v001/20261014_161407/` ở gốc dự án. Animation cũ và dữ liệu Godot được giữ nguyên.

## Xem chuyển động

[Clip góc chéo ở tốc độ thật](walking_1x.mp4) phát 6 vòng, 144 frame ở 30 FPS, tổng 4.8 giây. `three_quarter_preview.png`, `front_preview.png`, `side_preview.png` cho ba góc tĩnh. `source_walking.animation.json` giữ dữ liệu nguồn và SHA256 của gói.

Action điều khiển toàn thân; không gán đồng thời với lớp upper body cầm súng nếu chưa xác định mask. Khi đưa vào game sau này, physics cần sở hữu world travel, gait phase phải liên tục, và phải kiểm tra dừng/đảo hướng/đi–chạy/nhảy ở 30 FPS. Hiện tại chỉ là bản Blender để người dùng xem và chỉnh tiếp.
