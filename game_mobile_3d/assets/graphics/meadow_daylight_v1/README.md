# Meadow Daylight V1 — bộ đồ họa tái sử dụng

Lưu theo yêu cầu người dùng ngày 2026-10-09. **Đã yêu cầu lưu để dùng cho map sau**; không tự suy diễn rằng mọi chi tiết mỹ thuật hoặc hiệu năng điện thoại đã được duyệt. WorldMap nay thử [V3 hòa màu cỏ cao](../meadow_daylight_v3/README.md), kế tiếp [V2 cỏ thấp](../meadow_daylight_v2/README.md); cả hai giữ nguyên đèn/environment V1. Preset và ZIP V1 được bảo toàn; môi trường được duplicate khi chạy để không sửa resource chung.

## Có gì trong bản lưu

- `preset.tres`: ánh sáng mặt trời, bóng, Environment và liên kết shader. `environment.tres` chứa exposure .96, LUT ấm .05, bloom nhẹ, haze và ambient xanh mát.
- Driver `world_map_look.gd`: vật liệu riêng, palette/mipmap, đường đất hòa cỏ, đất dưới bụi, bóng tiếp xúc, gió/phản ứng player và bóng mây. Shader giữ texture/UV nguồn; B phục hồi vật liệu gốc.
- `world_map_geometry.gd`: terrain/slab/chunk, lá đi xuyên, cắt mặt khuất, fade vách có bảo vệ nền. Không thay bố cục map hoặc animation nhân vật.
- 18 GLB từ `assets/environment/world_map_v1/`, hook import và manifest. Nguồn Blender vẫn ở `blender/environment/studies/dungeons_ground_style_v2/`; không nằm trong ZIP. Xem [hợp đồng asset](../../environment/world_map_v1/manifest.json).
- Snapshot độc lập `exports/graphics/meadow_daylight_v1.zip`, gồm đúng phiên bản code/shader/GLB hiện tại và SHA256 từng file trong `bundle_manifest.json`. Các đường dẫn shader đang dùng có thể được sửa ở lượt sau; **ZIP là bản V1 cố định**.

## Áp dụng cho map sau trong cùng project

1. Nếu dựng bằng cùng block library: tuân thủ [hợp đồng runtime map](../../maps/world_map/README.md), dựng geometry trước, sau đó gắn driver `world_map_look.gd` và gọi `setup(level)`. Không sao chép vị trí/cells của WorldMap để lấy phong cách.
2. Driver cần `level.runtime` (bounds/offset/palette/cells), `geometry` (terrain_chunks, vegetation_batches, cutaway helpers), `player` (position, real velocity, walk/run speed, visual), `view_mode`, và node `WorldEnvironment`, `Sun`, `Camera3D`. Giữ native material names và UV/UV2/COLOR contracts để phân loại terrain/plant đúng. Map khác schema cần adapter; đây không phải importer mọi định dạng.
3. Chỉ lấy ánh sáng: load `preset.tres`, duplicate `preset.environment` cho WorldEnvironment, rồi áp dụng từng khóa `preset.sun_settings` lên DirectionalLight3D. Driver còn thiết lập và hoàn trả shadow atlas/filter toàn renderer khi rời scene; không sửa global project settings để lấy look.
4. Camera hiện tại: orthographic size14.5, rotation(-36.315886,36.869898,0), offset(12,15,16), far72; MSAA2×, Mobile renderer. Giữ camera này khi so màu với ảnh V1. Với map/camera khác cần kiểm tra lại far/shadow coverage, không mù quáng tăng atlas.
5. Chụp cùng pose/camera, kiểm tra bậc, mép đường, contact và vách che actor. Chạy test bằng audio Dummy; F5 của người dùng có âm thanh bình thường. Mục tiêu30FPS, chưa xác nhận trên điện thoại.

Để khôi phục đúng V1, giải nén ZIP vào thư mục tạm và kiểm SHA trước; đối chiếu/chọn file cần áp dụng, không giải nén đè các thay đổi mới một cách mù quáng. `scripts/package_meadow_daylight_v1.py` tạo snapshot, kiểm nguồn và từ chối ghi đè V1 bằng nội dung khác. Các lượt mỹ thuật sau tạo phiên bản mới.

Quan sát, ảnh/clip, thông số chi tiết và giới hạn tập trung ở [RESEARCH.md](../../../../docs/graphics/RESEARCH.md), hướng mỹ thuật ở [ART_DIRECTION.md](../../../../docs/graphics/ART_DIRECTION.md); không nhân đôi báo cáo ở đây.
