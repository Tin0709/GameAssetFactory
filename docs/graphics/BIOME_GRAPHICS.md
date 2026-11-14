# Preset đồ họa cho bản đồ Litematica

**Mở để chơi thử.** Mở `scenes/maps/m2_v1/MeadowBiomeReview.tscn` trong Godot và bấm **F6**. **F5** mở WorldMap với preset Forest tham chiếu. Map thử mặc định dùng Rìa rừng ẩm. **J** so sánh volume với fog chuẩn trong cùng preset. **F7** so hậu kỳ khi rời buổi trưa, **Shift+F7** đổi mức chất lượng. **F8** đổi giữa Đồng cỏ ven rừng và Rìa rừng ẩm. Trên cả hai map, **T** chọn giờ, **Shift+T** bật đồng hồ và **F6** trong cửa sổ game chuyển trời quang/nhiều mây. Forest cũng có nút **Trời nhiều mây** trong Cài đặt. **H** tắt/bật sương, **B** so đồ họa gốc và **L** hiện phím điều khiển. WASD, chuột cuộn và Space dùng chung với WorldMap.

## Phần dùng chung và phần riêng của bản đồ

| Hệ thống | Chỉnh theo biome | Chỉnh theo map |
| --- | --- | --- |
| Lighting | Hướng, màu, cường độ nắng và ánh môi trường, độ mềm và độ đậm bóng nắng | Vị trí đèn cục bộ và dữ liệu ánh sáng tính từ hình học |
| Atmosphere / Fog | Màu trời, màu sương, dải độ sâu, đường cong sương, cường độ ánh sương, độ suy giảm theo cao độ và cường độ theo giờ | Tâm, kích thước, extinction và màu tán xạ của từng vùng sương |
| Bloom | Ngưỡng, cường độ, độ lan và mức thích ứng theo giờ | Chọn mức chất lượng phù hợp với cảnh và thiết bị |
| Color Grading | Tonemapper, exposure, độ tương phản, bão hòa và texture sửa màu tùy chọn | Gán hoặc duplicate preset để tinh chỉnh cục bộ |
| Day/Night | Giờ bắt đầu, độ dài chu kỳ, các track màu, góc và cường độ | Chọn preset của scene |
| Weather | Resource chuyển giữa trời quang và nhiều mây, ảnh hưởng lên nắng, sương và màu | Chọn preset hoặc đặt thời tiết lúc bắt đầu phiên chơi |

Map portable dùng chung các pass sương và bloom với WorldMap. Preset Forest tham chiếu còn nạp LUT riêng và các trường ánh sáng gắn với hình học, được xác minh theo map trước khi dùng.

`biome_render_settings.gd` áp cấu hình ánh sáng, depth fog, bloom và color grading trên cả hai map. `biome_day_night.gd` điều khiển đồng hồ và mốc giờ, `biome_weather.gd` điều khiển chuyển tiếp và phối hiệu ứng thời tiết lên pha ánh sáng hiện tại. `forest_overcast.tres`, `woodland_overcast.tres` và `meadow_overcast.tres` đặt độ dịu nắng, thay đổi ánh hắt, màu sương và mức bão hòa riêng. Forest mặc định trời quang. Ba preset mây là thiết kế của GameAssetFactory.

Map portable dùng một compositor cho camera. Sương chạy trước khi vẽ vật thể và adaptive bloom chạy ở giai đoạn hậu kỳ. Các vật liệu hỗ trợ spatial mist nhận sương từ volume. Vật liệu thông thường tiếp tục nhận depth fog. Mức Nhẹ, chế độ toàn cảnh và chế độ so sánh có đường dự phòng riêng. Các cache ánh sáng kiểm tra hình học, đèn cục bộ và vùng sương đặt theo tọa độ của map.

Đặt **Local Diffuse Region** trong Inspector của map để chọn tâm, hai bán kính và tọa độ khoảng mở. Trong **Biome Graphics → Lighting**, chỉnh **Local Diffuse Strength** và **Local Diffuse By Hour**. Resource thời tiết có **Local Diffuse Scale** để giảm chênh ánh hắt khi nhiều mây. Cả Forest và map portable dùng cùng hàm shader cho đá, địa hình, cỏ và vật liệu nhân vật hỗ trợ. Forest dùng dữ liệu ánh sáng đã dựng theo hình học. Map portable dùng màu và cường độ ambient của biome hiện tại. Cân bằng và Đầy đủ có hiệu ứng, mức Nhẹ tắt. Trên MeadowBiomeReview, đi tới cụm đá lúc 07:00 hoặc 16:30 rồi bấm **Alt+J** để so sánh.

## Import map tiếp theo

1. Từ thư mục `GameAssetFactory`, chạy lệnh dưới đây để tạo dữ liệu map và scene chơi thử. Với `bounds`, cạnh ngoài lấy từ vùng chọn của schematic và giữ cả vùng đệm rỗng. Chế độ `markers` dùng vòng Red Wool 100 × 100 của WorldMap. Cả hai kiểm tra slab, tall grass, vùng chồng lấn và block chưa hỗ trợ.

   ```powershell
   python scripts/import_world_map.py "D:/Maps/MapMoi.litematic" --border bounds --output game_mobile_3d/assets/maps/map_moi --scene game_mobile_3d/scenes/maps/MapMoi.tscn --biome humid_woodland
   ```

2. Trong Godot, mở `scenes/maps/MapMoi.tscn` và bấm **F6**. Chọn `--biome meadow` cho Đồng cỏ ven rừng hoặc `--biome humid_woodland` cho Rìa rừng ẩm. Muốn thêm biome, lưu một bản sao của preset portable dưới `assets/graphics/biomes/ten_biome.tres`, rồi truyền `--biome ten_biome`. Importer kiểm tra đây là resource `BiomeGraphicsProfile` và từ chối preset tham chiếu private trước khi ghi map. Nếu bỏ `--biome`, scene dùng Đồng cỏ ven rừng. Cả thư mục đầu ra và file scene phải là đường dẫn mới khi dùng `--scene` để giữ các chỉnh sửa trên map đã có. Để chỉ xuất dữ liệu như trước, bỏ `--scene` và `--biome`.
3. Bấm **F8** để so hai preset ngay trên scene vừa tạo. Đổi **Biome Graphics** và **Comparison Biomes** trong Inspector để dùng preset khác. Để tinh chỉnh riêng một map, duplicate preset thành file .tres mới rồi gán cho map đó. Duplicate cả resource con Day/Night hoặc Overcast nếu muốn thay đổi chúng riêng cho map. Nhiều biome có thể dùng chung một Weather resource. Giờ khởi động, vòng ngày/đêm và thời tiết điều khiển độc lập. Curve theo giờ dùng trục X từ 0 đến 1 cho 00:00 đến 24:00. Giữ hai đầu bằng nhau để chuyển mượt qua nửa đêm. Giá trị 1 tại 0,5 giữ mức đã đặt cho buổi trưa.
4. Giữ nguyên asset registry và kiểm tra các block mới, mép map, chỗ spawn và đường đi sau import. Dùng F6 để test scene vừa chọn. Mặc định nếu bản đồ mới không có preset riêng, runtime chọn Đồng cỏ ven rừng.

## Phạm vi tích hợp hiện tại

- `biome_graphics_profile.gd` lưu cấu hình ánh sáng, bầu trời, sương, hậu kỳ và chu kỳ thời gian. `biome_weather_profile.gd` lưu phản ứng với trời nhiều mây. `biome_graphics.gd` áp dụng dữ liệu lên Environment của từng scene. Shader nền, cỏ, mesh và controller được dùng lại. Hai profile mẫu là thiết kế của GameAssetFactory.
- Forest dùng preset riêng với đường dẫn và hash của dữ liệu khí quyển/hậu kỳ riêng tư. Day/Night, các hàm áp nguồn sáng, fog dự phòng và glow/grade dùng chung. Field ánh sáng, ánh hắt từ geometry, volume sương, LUT PIX và các hiệu ứng chuyên biệt của Forest vẫn có điều kiện riêng. Cache theo hình học kiểm hash runtime trước khi kích hoạt. Rìa rừng ẩm dùng volume chung trên Forward Mobile. Đồng cỏ dùng fog tích hợp. Đồng cỏ dùng glow chuẩn Mobile. Rìa rừng ẩm có adaptive bloom và local exposure vào các giờ ngoài giữa trưa. Đặt hiệu ứng này trong nhóm Bloom của profile và dùng Curve để chỉnh tỉ lệ theo giờ. [Hỗ trợ Godot Mobile](https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html).
- Spatial Mist nằm trong nhóm Atmosphere and Fog của preset. Local Mist Region và Additional Mist Region trên node map đặt tâm, bán kính, extinction và màu của từng vùng. Tắt Spatial Mist trong preset để dùng fog chuẩn. Vật liệu ngoài hợp đồng shader chung vẫn nhận fog chuẩn. LUT theo dữ liệu PIX vẫn riêng cho Forest. Preset portable giữ tone curve và grade do biome chọn. Trạng thái nhiều mây của map thử là thiết kế GAF. Bằng chứng MD2 hiện chưa đủ để đặt lịch riêng cho mưa Forest.

## Độ mềm của bóng và chiều sâu không khí

Trong **Biome Graphics → Lighting**, **Shadow Blur** và **Shadow Opacity** chỉnh bán kính lọc và độ đậm bóng nắng. Trong **Atmosphere and fog**, **Fog Depth Curve** chỉnh phân bố sương giữa hai mốc khoảng cách, **Fog Light Energy** chỉnh độ sáng của sương tích hợp. Spatial Mist vẫn dùng các tham số truyền sáng và tán xạ của vùng sương. Mức Nhẹ giữ đường cong và độ sáng của sương tích hợp.

Map thử dùng cặp **1,55 / 0,74** cho bóng và **1,45 / 0,78** cho sương. Preset Đồng cỏ lưu hành vi cũ (**1,25 / 0,782** và **1,70 / 0,75**). Các giá trị của Rìa rừng ẩm là hiệu chỉnh GAF cho map thử. B và F8 có thể dùng để kiểm tra chính xác lúc nào preset đang điều khiển hình ảnh. Các phím thử nghiệm U/P của WorldMap thuộc chế độ tham chiếu Forest. [Thuộc tính sương Godot](https://docs.godotengine.org/en/stable/classes/class_environment.html#class-environment-property-fog-depth-curve) · [Thuộc tính bóng Godot](https://docs.godotengine.org/en/stable/classes/class_light3d.html#class-light3d-property-shadow-blur).

## Chỉnh chu kỳ theo biome

Tại **Biome Graphics → Day and night**, mở **Day Night**. Preset Rìa rừng ẩm đã có resource riêng. Duplicate resource này trước khi chỉnh màu nắng, ánh trời, bầu trời hoặc sương cho biome khác. Có thể để trống từng track để dùng đường màu chung. Các màu là giá trị tuyệt đối. Track góc pitch/yaw tính bằng độ và track Exposure dùng giá trị exposure của môi trường. Các curve cường độ nắng, ánh môi trường và mật độ sương ở profile là hệ số nhân. **Ambient Energy By Hour** được áp dụng trước mức mây, với hệ số 1 nếu để trống. Preset Rìa rừng ẩm giảm ánh môi trường khi trời vừa tối và về mức cũ sau 21:15. Map có đèn cục bộ vẫn dùng đường đèn riêng.

Điểm 0,5 là 12:00. Giữ điểm 0/1 bằng nhau cho các track vòng lặp và chọn nội suy tuyến tính hoặc cubic để màu chuyển dần giữa các mốc. Với yaw qua ±180°, nhập các giá trị liên tục như 170° → 190° để hướng nắng đi qua góc ngắn. **Weather → Start Overcast** đặt mức mây lúc mở map. F8 giữ giờ và mức mây hiện tại khi hai preset đều có cấu hình Overcast. Không cần đổi shader để đổi những thông số này.

Trong **Atmosphere and fog → Spatial mist**, **Local Mist By Hour** và **Additional Mist By Hour** điều khiển hai vùng sương độc lập. Curve dùng cùng trục 0–1 theo giờ và nhân với cường độ đã chọn trong preset và mức mây. Curve để trống giữ hệ số 1. Đặt **Local Mist Region** và **Additional Mist Region** ở node map theo địa hình thực tế. Trong scene Đồng cỏ, đi tới cụm đá gần X = 4,5, Z = −11,5, bấm **T** đến 07:00 hoặc 16:30 và **J** để đối chiếu. Túi sương ở cụm đá bật theo preset Rìa rừng ẩm, về 0 trong khung quanh 12:00.

Các vị trí vùng sương và đèn, cùng dữ liệu ánh sáng đã bake theo hình học, thuộc về map. Cần đặt hoặc dựng lại khi đổi layout. Các tính năng cần texture/LUT PIX và cache chiếu sáng riêng của Forest vẫn chạy qua preset tham chiếu trên WorldMap. Map Litematica mới dùng cấu hình portable.

**Ground Haze** và **Twilight Ground Haze** nằm trong **Biome Graphics → Atmosphere and fog → Spatial mist**. Cả hai dùng cùng tài nguyên để đặt dải khoảng cách tính sau nhân vật, cao độ tính từ điểm spawn của map và cửa sổ giờ. Bốn mốc giờ là bắt đầu, đạt mức cao nhất, bắt đầu giảm và hết. Cửa sổ có bốn số 0 được bỏ qua. Khi Ground Haze đang hoạt động, nó được ưu tiên. Khi lớp này hết giờ hoặc có cường độ 0, hệ thống lấy Twilight Ground Haze. Hai lớp điều chỉnh ánh sáng tán xạ trong sương và giữ nguyên extinction.

Forest lưu thông số hai lớp sương thấp trong preset tham chiếu. **Sương & hiệu ứng → Sương theo khoảng cách** vẫn có các slider riêng của Forest. Rìa rừng ẩm mặc định có lớp tán xạ thấp từ 18:45 đến 21:09, mạnh nhất từ 19:30 đến 20:00. Đồng cỏ dùng cấu hình sương nhẹ hơn. Mở **MeadowBiomeReview**, đi tới cụm đá rồi bấm **T** để tới 18:30 hoặc dùng **Shift+T** cho thời gian chạy qua 19:30. **J** bật/tắt spatial mist và **F8** đổi biome. Mức Đầy đủ và Cân bằng chạy lớp tán xạ này. Mức Nhẹ và Compatibility dùng depth fog tích hợp. [Hỗ trợ renderer trong Godot](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)

Map import nạp khí quyển từ preset portable. Dữ liệu khí quyển Forest theo hash chỉ được đọc trên đường chạy tham chiếu. Quy trình dựng map mới dùng cùng controller và shader. Vùng sương cục bộ, vị trí đèn và các trường ánh sáng theo hình học vẫn thuộc từng scene.

## Mức chất lượng theo map và thiết bị

Chọn **Biome Quality** trong Inspector của map. **Đầy đủ** là mặc định. **Cân bằng** giữ spatial mist với lưới thưa hơn và dùng glow tích hợp. **Nhẹ** dùng depth fog và glow tích hợp. Tất cả dùng chung giờ, mây, màu, ánh sáng và tonemapping của biome. Với preset bật spatial mist, **Essential Fog Scale** chỉnh lượng depth fog dự phòng ở mức Nhẹ. So ba mức ngay trong map bằng **Shift+F7**. Phím này chỉ đổi mức của phiên đang chơi. Biome Quality áp dụng cho map portable. Forest vẫn đi qua cấu hình tham chiếu riêng.

## Đèn môi trường trên map import

Điền **Biome Path Fixture Xz** ở node map bằng tọa độ X/Z trong Godot. Đèn sẽ lấy cao độ từ địa hình ở điểm này. Trong preset, chọn **Path Fixture By Hour** để đặt giờ, **Path Fixture Energy** để chỉnh sáng bề mặt, và **Path Fixture Scatter** để chỉnh ánh sáng trong sương. Preset Rìa rừng ẩm có đèn từ chạng tối đến rạng sáng nếu map đặt tọa độ. Map thử dùng nguồn bếp lửa MD2 đã xác minh, đọc từ MD2 Research trong Godot chạy ở chế độ editor với Mobile. Thiếu nguồn hoặc sai hash thì scene bỏ qua fixture. Tài nguyên riêng không nằm trong bản phân phối.

Trong MeadowBiomeReview, bấm **T** tới 22:00 rồi đi về X = 4,5, Z = −4,5. **Shift+J** chỉ bật/tắt tán xạ của đèn, **J** so hai đường sương; **Shift+F7** thử mức Nhẹ vẫn có đèn bề mặt. Giờ và vị trí đèn tách khỏi thời tiết và mức chất lượng. Khi muốn đèn lên sớm ở chạng vạng, chỉnh **Path Fixture By Hour** của biome. Forest dùng điều khiển riêng trong **Ánh sáng → Đèn và vật phát sáng → Đèn lối rừng lúc chạng vạng** để so với bản tham chiếu cũ.
