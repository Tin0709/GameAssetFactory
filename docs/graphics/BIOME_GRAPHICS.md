# Preset đồ họa cho bản đồ Litematica

**Mở để chơi thử.** Mở `scenes/maps/m2_v1/MeadowBiomeReview.tscn` trong Godot và bấm **F6**. **F5** vẫn mở WorldMap với preset Forest tham chiếu. Map thử mặc định dùng Rìa rừng ẩm. **J** so sánh volume với fog chuẩn trong cùng preset. **F7** so hậu kỳ khi rời buổi trưa, **Shift+F7** đổi mức chất lượng. **F8** đổi giữa Đồng cỏ ven rừng và Rìa rừng ẩm, **T** chọn giờ, **Shift+T** bật đồng hồ, **F6** trong cửa sổ game chuyển trời quang/nhiều mây, **H** tắt/bật sương, **B** so đồ họa gốc và **L** hiện phím điều khiển. WASD, chuột cuộn và Space dùng chung với WorldMap.

## Import map tiếp theo

1. Từ thư mục `GameAssetFactory`, chạy `python scripts/import_world_map.py "D:/Maps/MapMoi.litematic" --border bounds --output game_mobile_3d/assets/maps/map_moi`. Với bounds, cạnh ngoài lấy từ vùng chọn của schematic. Vùng đệm rỗng vẫn được giữ theo kích thước vùng chọn. Chế độ `markers` giữ hợp đồng vòng Red Wool 100 × 100 cho WorldMap. Cả hai dùng cùng mapping block và kiểm tra slab, tall grass, vùng chồng lấn và block chưa hỗ trợ.
2. Tạo một scene kế thừa `scenes/GameplayMap.tscn`, gắn `scripts/world_map.gd` lên node gốc và điền **Map Layout Path** đến `res://assets/maps/map_moi/runtime.json`.
3. Chọn **Biome Graphics** trong Inspector. Dùng `assets/graphics/biomes/meadow.tres` hoặc `humid_woodland.tres` làm điểm xuất phát. Thêm preset so sánh vào **Comparison Biomes**. Để chỉnh riêng một map, duplicate preset thành file .tres mới và gán cho map đó. Mây dùng một Weather resource riêng, có thể chia sẻ giữa các biome. Giờ khởi động, vòng ngày/đêm và thời tiết có thể điều khiển độc lập. Trong preset, các Curve theo giờ dùng trục X từ 0 đến 1 cho 00:00 đến 24:00. Giữ hai đầu bằng nhau để không nhảy khi qua nửa đêm. Giá trị 1 tại 0,5 giữ mức đã đặt cho buổi trưa.
4. Giữ nguyên asset registry và kiểm tra các block mới, mép map, chỗ spawn và đường đi sau import. Dùng F6 để test scene vừa chọn. Mặc định nếu bản đồ mới không có preset riêng, runtime chọn Đồng cỏ ven rừng.

## Phạm vi tích hợp hiện tại

- `biome_graphics_profile.gd` lưu cấu hình ánh sáng, bầu trời, sương, hậu kỳ và chu kỳ thời gian. `biome_weather_profile.gd` lưu phản ứng với trời nhiều mây. `biome_graphics.gd` áp dụng dữ liệu lên Environment của từng scene. Shader nền, cỏ, mesh và controller được dùng lại. Hai profile mẫu là thiết kế của GameAssetFactory.
- Forest dùng preset riêng với đường dẫn và hash của dữ liệu khí quyển/hậu kỳ riêng tư. Day/Night, các hàm áp nguồn sáng, fog dự phòng và glow/grade dùng chung. Field ánh sáng, ánh hắt từ geometry, volume sương, LUT PIX và các hiệu ứng chuyên biệt của Forest vẫn có điều kiện riêng. Cache theo hình học kiểm hash runtime trước khi kích hoạt. Rìa rừng ẩm dùng volume chung trên Forward Mobile. Đồng cỏ dùng fog tích hợp. Đồng cỏ dùng glow chuẩn Mobile. Rìa rừng ẩm có adaptive bloom và local exposure vào các giờ ngoài giữa trưa. Đặt hiệu ứng này trong nhóm Bloom của profile và dùng Curve để chỉnh tỉ lệ theo giờ. [Hỗ trợ Godot Mobile](https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html).
- Spatial Mist nằm trong nhóm Atmosphere and Fog của preset. Local Mist Region và Additional Mist Region trên node map đặt tâm, bán kính, extinction và màu của từng vùng. Tắt Spatial Mist trong preset để dùng fog chuẩn. Vật liệu ngoài hợp đồng shader chung vẫn nhận fog chuẩn. LUT theo dữ liệu PIX vẫn riêng cho Forest. Preset portable giữ tone curve và grade do biome chọn. Trạng thái nhiều mây của map thử là thiết kế GAF. Bằng chứng MD2 hiện chưa đủ để đặt lịch riêng cho mưa Forest.

## Mức chất lượng theo map và thiết bị

Chọn **Biome Quality** trong Inspector của map. **Đầy đủ** là mặc định. **Cân bằng** giữ spatial mist với lưới thưa hơn và dùng glow tích hợp. **Nhẹ** dùng depth fog và glow tích hợp. Tất cả dùng chung giờ, mây, màu, ánh sáng và tonemapping của biome. Với preset bật spatial mist, **Essential Fog Scale** chỉnh lượng depth fog dự phòng ở mức Nhẹ. So ba mức ngay trong map bằng **Shift+F7**. Phím này chỉ đổi mức của phiên đang chơi. Biome Quality áp dụng cho map portable. Forest vẫn đi qua cấu hình tham chiếu riêng.

## Đèn môi trường trên map import

Điền **Biome Path Fixture Xz** ở node map bằng tọa độ X/Z trong Godot. Đèn sẽ lấy cao độ từ địa hình ở điểm này. Trong preset, chọn **Path Fixture By Hour** để đặt giờ, **Path Fixture Energy** để chỉnh sáng bề mặt, và **Path Fixture Scatter** để chỉnh ánh sáng trong sương. Preset Rìa rừng ẩm có đèn từ chạng tối đến rạng sáng nếu map đặt tọa độ. Map thử dùng nguồn bếp lửa MD2 đã xác minh, đọc từ MD2 Research trong Godot chạy ở chế độ editor với Mobile. Thiếu nguồn hoặc sai hash thì scene bỏ qua fixture. Tài nguyên riêng không nằm trong bản phân phối.

Trong MeadowBiomeReview, bấm **T** tới 22:00 rồi đi về X = 4,5, Z = −4,5. **Shift+J** chỉ bật/tắt tán xạ của đèn, **J** so hai đường sương; **Shift+F7** thử mức Nhẹ vẫn có đèn bề mặt. Giờ và vị trí đèn tách khỏi thời tiết và mức chất lượng.
