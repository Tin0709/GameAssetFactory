# Preset đồ họa cho bản đồ Litematica

**Mở để chơi thử.** Mở `scenes/maps/m2_v1/MeadowBiomeReview.tscn` trong Godot và bấm **F6**. **F5** vẫn mở WorldMap với preset Forest tham chiếu. Trong map thử, **F8** đổi giữa Đồng cỏ ven rừng và Rìa rừng ẩm, **T** chọn giờ, **Shift+T** bật đồng hồ, **F6** trong cửa sổ game chuyển trời quang/nhiều mây, **H** tắt/bật sương, **B** so đồ họa gốc và **L** hiện phím điều khiển. WASD, chuột cuộn và Space dùng chung với WorldMap.

## Import map tiếp theo

1. Từ thư mục `GameAssetFactory`, chạy `python scripts/import_world_map.py "D:/Maps/MapMoi.litematic" --border bounds --output game_mobile_3d/assets/maps/map_moi`. Với bounds, cạnh ngoài lấy từ vùng chọn của schematic. Vùng đệm rỗng vẫn được giữ theo kích thước vùng chọn. Chế độ `markers` giữ hợp đồng vòng Red Wool 100 × 100 cho WorldMap. Cả hai dùng cùng mapping block và kiểm tra slab, tall grass, vùng chồng lấn và block chưa hỗ trợ.
2. Tạo một scene kế thừa `scenes/GameplayMap.tscn`, gắn `scripts/world_map.gd` lên node gốc và điền **Map Layout Path** đến `res://assets/maps/map_moi/runtime.json`.
3. Chọn **Biome Graphics** trong Inspector. Dùng `assets/graphics/biomes/meadow.tres` hoặc `humid_woodland.tres` làm điểm xuất phát. Thêm preset so sánh vào **Comparison Biomes**. Để chỉnh riêng một map, duplicate preset thành file .tres mới và gán cho map đó. Mây dùng một Weather resource riêng, có thể chia sẻ giữa các biome. Giờ khởi động, vòng ngày/đêm và thời tiết có thể điều khiển độc lập. Trong preset, các Curve theo giờ dùng trục X từ 0 đến 1 cho 00:00 đến 24:00. Giữ hai đầu bằng nhau để không nhảy khi qua nửa đêm. Giá trị 1 tại 0,5 giữ mức đã đặt cho buổi trưa.
4. Giữ nguyên asset registry và kiểm tra các block mới, mép map, chỗ spawn và đường đi sau import. Dùng F6 để test scene vừa chọn. Mặc định nếu bản đồ mới không có preset riêng, runtime chọn Đồng cỏ ven rừng.

## Phạm vi tích hợp hiện tại

- `biome_graphics_profile.gd` lưu cấu hình ánh sáng, bầu trời, sương, hậu kỳ và chu kỳ thời gian. `biome_weather_profile.gd` lưu phản ứng với trời nhiều mây. `biome_graphics.gd` áp dụng dữ liệu lên Environment của từng scene. Shader nền, cỏ, mesh và controller được dùng lại. Hai profile mẫu là thiết kế của GameAssetFactory.
- Forest dùng preset riêng với đường dẫn và hash của dữ liệu khí quyển/hậu kỳ riêng tư. Day/Night, các hàm áp nguồn sáng, fog dự phòng và glow/grade dùng chung. Field ánh sáng, ánh hắt từ geometry, volume sương, LUT PIX và các hiệu ứng chuyên biệt của Forest vẫn có điều kiện riêng. Cache theo hình học kiểm hash runtime trước khi kích hoạt. Bản đồ mẫu dùng fog tích hợp và glow chuẩn Mobile. [Hỗ trợ Godot Mobile](https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html).
- Bước tiếp theo là chuyển thêm volume và hậu kỳ nâng cao thành lựa chọn cấp preset, kiểm vật liệu không hỗ trợ shared fog, rồi thiết lập local override theo vùng. Trạng thái nhiều mây của map thử là thiết kế GAF. Bằng chứng MD2 hiện chưa đủ để đặt lịch riêng cho mưa Forest.
