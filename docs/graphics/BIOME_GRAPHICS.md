# Preset đồ họa cho bản đồ Litematica

**Mở để chơi thử.** Mở `scenes/maps/m2_v1/MeadowBiomeReview.tscn` trong Godot và bấm **F6**. **F5** mở WorldMap với preset Forest tham chiếu. Map thử mặc định dùng Rìa rừng ẩm. Mở **⚙ Cài đặt → Đồ họa bản đồ** để chọn **Biome** và **Chất lượng** bằng chuột. **Hoàn tác** khôi phục lựa chọn trước đó. **F8** đổi biome, **Shift+F7** đổi chất lượng và **L** ẩn hoặc hiện HUD, gồm nút Cài đặt. **J** so sánh volume với fog chuẩn trong cùng preset. **F7** so hậu kỳ khi rời buổi trưa. Trên cả hai map, **T** chọn giờ, **Shift+T** bật đồng hồ và **F6** trong cửa sổ game chuyển trời quang/nhiều mây. Forest cũng có nút **Trời nhiều mây** trong Cài đặt. **H** tắt/bật sương và **B** so đồ họa gốc. WASD, chuột cuộn và Space dùng chung với WorldMap.

## Phần dùng chung và phần riêng của bản đồ

| Hệ thống | Chỉnh theo biome | Chỉnh theo map |
| --- | --- | --- |
| Lighting | Hướng, màu, cường độ nắng và ánh môi trường, độ mềm và độ đậm bóng nắng | Vị trí đèn cục bộ và dữ liệu ánh sáng tính từ hình học |
| Atmosphere / Fog | Màu trời, màu sương, dải độ sâu, đường cong sương, cường độ ánh sương, độ suy giảm theo cao độ và cường độ theo giờ | Tâm, kích thước, extinction và màu tán xạ của từng vùng sương |
| Bloom | Ngưỡng, cường độ, độ lan và mức thích ứng theo giờ | Chọn mức chất lượng phù hợp với cảnh và thiết bị |
| Color Grading | Tonemapper, exposure, độ tương phản, bão hòa và texture sửa màu tùy chọn | Gán hoặc duplicate preset để tinh chỉnh cục bộ |
| Day/Night | Giờ bắt đầu mặc định, độ dài chu kỳ, các track màu, góc và cường độ | Chọn giờ mở map hoặc kế thừa preset |
| Weather | Resource chuyển giữa trời quang và nhiều mây, ảnh hưởng lên nắng, sương và màu | Chọn preset hoặc đặt thời tiết lúc bắt đầu phiên chơi |

Map portable dùng chung các pass sương và bloom với WorldMap. Preset Forest tham chiếu còn nạp LUT riêng và các trường ánh sáng gắn với hình học, được xác minh theo map trước khi dùng.

`biome_render_settings.gd` áp cấu hình ánh sáng, depth fog, bloom và color grading trên cả hai map. `biome_day_night.gd` điều khiển đồng hồ và mốc giờ, `biome_weather.gd` điều khiển chuyển tiếp và phối hiệu ứng thời tiết lên pha ánh sáng hiện tại. `forest_overcast.tres`, `woodland_overcast.tres` và `meadow_overcast.tres` đặt độ dịu nắng, thay đổi ánh hắt, màu sương và mức bão hòa riêng. Forest mặc định trời quang. Ba preset mây là thiết kế của GameAssetFactory.

**Ánh sáng → Mặt trời và bầu trời → Giữ sắc nắng theo giờ khi nhiều mây** ở mức 100% mặc định sẽ dùng các tham số màu của preset Forest Overcast. Preset giữ 50% sắc nguồn theo giờ và dịu 35% sắc ánh trời ở đỉnh đường cong, giữ nguyên luma tuyến tính của hai nguồn. Chọn **Trời nhiều mây**, đến bậc đá lúc 07:00, 16:30 hoặc 18:30 rồi so 0% và 100%. Đường cong **Phase Color By Hour** trong resource Weather đưa hiệu ứng về 0 quanh buổi trưa và ban đêm. Biome khác có thể đặt đường cong và mức riêng. Preset ánh sáng trước v164 thiếu thanh này sẽ mở ở 0%.

Gameplay và công cụ chạy kịch bản dùng chung `world.showcase.set_hour(hour)` và `world.showcase.set_weather(overcast, seconds)` cho cả Forest và map import. `overcast` đi từ `0` (quang) đến `1` (nhiều mây). Dùng `seconds = 0` để đổi tức thì khi chụp ảnh đối chiếu. Chuyển thời tiết giữ giờ hiện tại. Đổi preset bằng **F8** giữ giờ và mức mây nếu cả hai preset có Overcast.

Map portable dùng một compositor cho camera. Sương chạy trước khi vẽ vật thể và adaptive bloom chạy ở giai đoạn hậu kỳ. Các vật liệu hỗ trợ spatial mist nhận sương từ volume. Vật liệu thông thường tiếp tục nhận depth fog. Mức Nhẹ, chế độ toàn cảnh và chế độ so sánh có đường dự phòng riêng. Các cache ánh sáng kiểm tra hình học, đèn cục bộ và vùng sương đặt theo tọa độ của map.

Đặt **Local Diffuse Region** trong Inspector của map để chọn tâm, hai bán kính và tọa độ khoảng mở. Trong **Biome Graphics → Lighting**, chỉnh **Local Diffuse Strength** và **Local Diffuse By Hour**. Resource thời tiết có **Local Diffuse Scale** để giảm chênh ánh hắt khi nhiều mây. Cả Forest và map portable dùng cùng hàm shader cho đá, địa hình, cỏ và vật liệu nhân vật hỗ trợ. Forest dùng dữ liệu ánh sáng đã dựng theo hình học. Map portable dùng màu và cường độ ambient của biome hiện tại. Cân bằng và Đầy đủ có hiệu ứng, mức Nhẹ tắt. Trên MeadowBiomeReview, đi tới cụm đá lúc 07:00 hoặc 16:30 rồi bấm **Alt+J** để so sánh.

Nếu map có hai khoảng mở, đặt thêm **Additional Local Diffuse Region** trong Inspector với tâm, bán kính và vị trí nguồn riêng. Hai vùng dùng chung shader. Tại chỗ chồng lấn, shader hòa trộn theo độ ảnh hưởng của từng vùng. Với map import, cả hai cùng dùng **Local Diffuse Strength**, đường cong giờ và thời tiết của preset. Trong WorldMap, **Địa hình & cây cỏ → Đá và mặt đất → Ánh hắt ở bậc đá** cho phép so sánh riêng vùng thứ hai. Điểm dễ quan sát nằm gần X = −22,5, Z = −40,5 lúc 07:00 hoặc 16:30.

## Import map tiếp theo

1. Từ thư mục `GameAssetFactory`, chạy lệnh dưới đây để tạo dữ liệu map và scene chơi thử. Với `bounds`, cạnh ngoài lấy từ vùng chọn của schematic và giữ cả vùng đệm rỗng. Chế độ `markers` dùng vòng Red Wool 100 × 100 của WorldMap. Cả hai kiểm tra slab, tall grass, vùng chồng lấn và block chưa hỗ trợ.

   ```powershell
   python scripts/import_world_map.py "C:/Maps/MapMoi.litematic" --border bounds --output game_mobile_3d/assets/maps/map_moi --scene game_mobile_3d/scenes/maps/MapMoi.tscn --biome humid_woodland
   ```

2. Trong Godot, mở `scenes/maps/MapMoi.tscn` và bấm **F6**. Chọn `--biome meadow` cho Đồng cỏ ven rừng hoặc `--biome humid_woodland` cho Rìa rừng ẩm. Muốn thêm biome, lưu một bản sao của preset portable dưới `assets/graphics/biomes/ten_biome.tres`, rồi truyền `--biome ten_biome`. Importer kiểm tra đây là resource `BiomeGraphicsProfile` và từ chối preset tham chiếu private trước khi ghi map. Nếu bỏ `--biome`, scene dùng Đồng cỏ ven rừng. Cả thư mục đầu ra và file scene phải là đường dẫn mới khi dùng `--scene` để giữ các chỉnh sửa trên map đã có. Để chỉ xuất dữ liệu như trước, bỏ `--scene` và `--biome`.
3. Dùng **Cài đặt → Biome** hoặc **F8** để so các preset ngay trên scene vừa tạo. Lựa chọn trong game áp dụng cho phiên hiện tại. Để lưu mặc định, đặt **Biome Graphics** và **Biome Quality** trong Inspector rồi lưu scene. Thêm preset đối chiếu vào **Comparison Biomes**. Mục **Biome Map Overrides** ở node gốc cho phép đặt **Start Hour** (giờ thập phân, ví dụ `19.5` là 19:30), **Start Overcast** (`0` quang đến `1` nhiều mây) và **Atmosphere Base Y** (cao độ mốc theo hệ tọa độ Godot, tính bằng mét). `-1` kế thừa giờ hoặc mây từ preset. `inf` lấy cao độ điểm xuất phát. Đổi biome trong game giữ giờ và, nếu cả hai preset đều có Overcast, mức mây đang chạy.
4. Giữ nguyên asset registry và kiểm tra các block mới, mép map, chỗ spawn và đường đi sau import. Trong cửa sổ game, **V** mở góc nhìn từ trên xuống và tự căn theo ranh giới của map import. Bấm **V** lần nữa để về góc chơi và mức zoom trước đó.

Quy trình trên đã chạy với `Testing.litematic` (50 × 50 m, 5.632 cell) trên Godot Forward Mobile/D3D12. Cùng scene chạy Rìa rừng ẩm và Đồng cỏ với cùng shader. Đã kiểm tra năm mốc giờ, trời quang/nhiều mây, đi lại, mức Nhẹ và góc toàn cảnh. OpenGL Compatibility đã qua bài kiểm tra depth fog dự phòng. Kiểm thử điện thoại và các kiểu thời tiết ngoài quang/nhiều mây còn mở.

Khi chuyển sang preset không dùng spatial mist hoặc bloom thích ứng, renderer giải phóng bộ đệm riêng của hiệu ứng đó và dùng fog/glow tích hợp theo preset mới. Chuyển lại dựng lại hiệu ứng trên cùng camera. Với `Testing.litematic` ở 19:30 trên Forward Mobile/D3D12 (640 × 360), đổi sang Đồng cỏ giải phóng 2.017.840 byte bộ đệm do hai hiệu ứng quản lý. Quay lại Rìa rừng ẩm giữ giờ và khôi phục ảnh trùng từng pixel trong bài đo camera cố định.

### Kiểm tra map mới trước khi chỉnh riêng

- Chạy scene vừa sinh và kiểm tra map với preset đã chọn, trước khi thêm đèn hoặc vùng sương. Rìa rừng ẩm có thể chạy spatial mist và adaptive bloom ngay từ scene do importer tạo. Dữ liệu bake của Forest thuộc bố cục Forest. Nếu map mới cần bake, dựng dữ liệu từ hình học của map đó.
- Đứng yên ở một góc nhìn có cả đất, cỏ, đá và nhân vật. So hai preset bằng **F8** ở sáng, trưa, chiều và tối. Dùng **F6** trong cửa sổ game để thử nhiều mây tại cùng một giờ. **Shift+F7** kiểm tra đường dự phòng cho máy yếu. Khi chốt, lưu **Biome Graphics** và **Biome Quality** trong Inspector của scene.

Đã chạy lại luồng import sạch từ `Testing.litematic` vào thư mục thử riêng. Scene sinh tự động nạp đủ 5.632 cell và chạy chung shader với map review, kể cả khi chưa đặt vùng sương hay đèn. Trên Windows, 65 kiểm tra Forward Mobile/D3D12, 28 kiểm tra Compatibility và 15 kiểm tra importer đều qua. Bộ 12 ảnh của `MeadowBiomeReview` dùng cùng camera để so hai preset ở năm mốc giờ và một lượt trời nhiều mây.

### Thêm và kiểm tra một preset mới

- Duplicate `humid_woodland.tres` nếu biome cần spatial mist, local exposure và adaptive bloom. Duplicate `meadow.tres` nếu biome dùng depth fog và glow tích hợp. Đặt tên file riêng và đổi **Display Name** để dễ chọn. Duplicate cả resource Day/Night hoặc Weather nếu chỉ muốn thay đổi cho biome mới.
- Giữ LUT, track thời gian và cấu hình thời tiết có thể đi cùng project. `--biome` kiểm tra các file tham chiếu trực tiếp và các file tham chiếu lồng trong `.tres` hoặc `.tscn` trước khi ghi map. Đường dẫn riêng của một máy hoặc dependency bị thiếu sẽ báo tên preset và đường dẫn lỗi.
- Thêm tính năng mới vào controller hoặc shader dùng chung, với thông số trong preset. Đặt vị trí đèn, vùng sương và dữ liệu bake theo hình học trong scene tương ứng. Kiểm tra preset mới mở cùng map import ở ít nhất hai giờ, chuyển quang/nhiều mây, rồi đổi mức **Nhẹ**. Khi thay shader hoặc hệ thống dùng chung, chạy cả bài `validate_biome_render_reuse.gd` và `validate_biome_day_weather.gd`.

Một preset thử tạo từ Rìa rừng ẩm đã mở scene mới mặc định lúc 19:30 và dùng giá trị nắng/contrast riêng. Scene do importer tạo qua 50 kiểm tra Forward Mobile và 36 kiểm tra Compatibility. Đổi sang Đồng cỏ giữ giờ, mức mây, vị trí nhân vật và địa hình. Ảnh đối chiếu lấy trực tiếp từ scene vừa import.

## Địa hình trang trí ở rìa map

Trong WorldMap, vào **L → Cài đặt → Sương & hiệu ứng → Sương theo khoảng cách → Địa hình xa sau bậc đá** để so bật/tắt. Lớp địa hình này nhận sắc ánh môi trường của biome và sương tại độ sâu của chính nó. Nó bật mặc định trong Kết hợp. Preset lưu trước phiên bản 158 tắt lớp này khi thiếu tùy chọn để tái hiện hình đã lưu.

**Dịu mép địa hình khi zoom xa** chuyển dần màu mép ngoài về màu nền của Environment ở góc rộng. Hiệu ứng lên dần khi size camera từ 27 đến 34 m và dùng fog của biome trên Forward Mobile. Lớp địa hình vẫn ghi depth. 0% giữ mép gốc. Preset trước phiên bản 159 mở ở 0% nếu thiếu trường này.

**Sương & hiệu ứng → Exposure và màu cuối → Ổn định sáng tối khi zoom xa** điều chỉnh phần local exposure tham chiếu của Forest. Ở size 29–40 m, nó giảm dần trọng số mẫu rộng về 30% giá trị gốc, giữ lưới sáng cục bộ và cùng chế độ bloom. Buổi trưa và góc chơi gần giữ công thức cũ. Preset trước phiên bản 160 mở ở 0% nếu thiếu trường.

Để dùng cùng pipeline trên một map import, đặt **Cliff Vista Origin**, **Cliff Vista Scale**, **Cliff Vista Mesh Anchor** và **Cliff Vista Sections** trong Inspector, rồi gán **Distant Terrain Layout Sha** bằng SHA-256 của JSON layout hiện tại. Các section phải nằm trong gói mesh MD2 cục bộ đã được loader kiểm chứng. Đặt chúng ngoài phần chơi và kiểm từ các góc zoom mà map cho phép. Cấu hình map chọn hình học và vị trí. Preset biome tiếp tục quyết định ánh sáng, sương và thời tiết. Chế độ Nhẹ của map portable, Compatibility và bản xuất dùng nền thông thường.

## Phạm vi tích hợp hiện tại

- `biome_graphics_profile.gd` lưu cấu hình ánh sáng, bầu trời, sương, hậu kỳ và chu kỳ thời gian. `biome_weather_profile.gd` lưu phản ứng với trời nhiều mây. `biome_graphics.gd` áp dụng dữ liệu lên Environment của từng scene. Shader nền, cỏ, mesh và controller được dùng lại. Hai profile mẫu là thiết kế của GameAssetFactory.
- Forest dùng preset riêng với đường dẫn và hash của dữ liệu khí quyển/hậu kỳ riêng tư. Day/Night, các hàm áp nguồn sáng, fog dự phòng và glow/grade dùng chung. Field ánh sáng, ánh hắt từ geometry, volume sương, LUT PIX và các hiệu ứng chuyên biệt của Forest vẫn có điều kiện riêng. Cache theo hình học kiểm hash runtime trước khi kích hoạt. Rìa rừng ẩm dùng volume chung trên Forward Mobile. Đồng cỏ dùng fog tích hợp. Đồng cỏ dùng glow chuẩn Mobile. Rìa rừng ẩm có adaptive bloom và local exposure vào các giờ ngoài giữa trưa. Đặt hiệu ứng này trong nhóm Bloom của profile và dùng Curve để chỉnh tỉ lệ theo giờ. [Hỗ trợ Godot Mobile](https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html).
- Spatial Mist nằm trong nhóm Atmosphere and Fog của preset. Local Mist Region và Additional Mist Region trên node map đặt tâm, bán kính, extinction và màu của từng vùng. Tắt Spatial Mist trong preset để dùng fog chuẩn. Vật liệu ngoài hợp đồng shader chung vẫn nhận fog chuẩn. LUT theo dữ liệu PIX vẫn riêng cho Forest. Preset portable giữ tone curve và grade do biome chọn. Trạng thái nhiều mây của map thử là thiết kế GAF. Bằng chứng MD2 hiện chưa đủ để đặt lịch riêng cho mưa Forest.

## Độ mềm của bóng và chiều sâu không khí

Trong **Biome Graphics → Lighting**, **Shadow Blur** và **Shadow Opacity** chỉnh bán kính lọc và độ đậm bóng nắng. Trong **Atmosphere and fog**, **Fog Depth Curve** chỉnh phân bố sương giữa hai mốc khoảng cách, **Fog Light Energy** chỉnh độ sáng của sương tích hợp. Spatial Mist vẫn dùng các tham số truyền sáng và tán xạ của vùng sương. Mức Nhẹ giữ đường cong và độ sáng của sương tích hợp.

Map thử dùng cặp **1,55 / 0,74** cho bóng và **1,45 / 0,78** cho sương. Preset Đồng cỏ lưu hành vi cũ (**1,25 / 0,782** và **1,70 / 0,75**). Các giá trị của Rìa rừng ẩm là hiệu chỉnh GAF cho map thử. B và F8 có thể dùng để kiểm tra chính xác lúc nào preset đang điều khiển hình ảnh. Các phím thử nghiệm U/P của WorldMap thuộc chế độ tham chiếu Forest. [Thuộc tính sương Godot](https://docs.godotengine.org/en/stable/classes/class_environment.html#class-environment-property-fog-depth-curve) · [Thuộc tính bóng Godot](https://docs.godotengine.org/en/stable/classes/class_light3d.html#class-light3d-property-shadow-blur).

Trong Forest, **Ánh sáng → Bóng và tương phản → Dịu sắc xanh trong bóng ban ngày** mặc định 50%. Lớp này phục hồi một phần màu trung tính trong bóng khi phần chỉnh màu tham chiếu làm nó quá xanh. Độ sáng tuyến tính của bóng được giữ. So 0% và 50% ở bậc đá gần X = −22,5, Z = −40,5 lúc 07:00 hoặc 16:30. **Shadow Grade Recovery By Hour** trong nhóm Color Grading của preset đặt cửa sổ hiệu lực, với hai đỉnh lúc 07:00 và 16:30. Preset biome dùng hậu kỳ portable tiếp tục áp chỉnh màu trong Environment. Preset lưu trước v162 thiếu thanh mới sẽ mở ở 0%.

**Địa hình & cây cỏ → Đá và mặt đất → Ánh phản xạ trên vách đá trong bóng** mặc định 50% trong Forest. Thanh này dùng trường ánh nắng hắt có sẵn của map để tăng độ đọc trên mặt đá đứng bị che. Hiệu ứng lên rõ nhất ở 07:00 và 16:30, yếu đi khi trời nhiều mây. Thông số **Shadowed Wall Return Scale** trong preset điều khiển biên độ. Map cần trường ánh sáng đã tính theo hình học và hướng nắng hợp lệ. Preset lưu trước v163 thiếu thanh này sẽ mở ở 0%.

**Ánh trời trong bóng sâu của đá** mặc định 50% trong cùng nhóm. So 0% và 50% tại bậc đá X = −22,5, Z = −40,5 lúc 07:00 hoặc 16:30. Hiệu ứng dùng sắc trời tại mặt đứng để nâng phần bóng sâu khi ánh hắt đã tính theo pha còn thấp. Khi bật trời nhiều mây, nhiều mặt đá đủ điều kiện hơn. Buổi trưa và ban đêm dùng đường chiếu sáng của các pha đó. **Sheltered Stone Return Scale** điều khiển biên độ trong preset. Shader dùng chung lấy dữ liệu từ trường ánh sáng khớp hình học và hướng nắng của scene. Hiện WorldMap Forest có đường cấp dữ liệu này. Các preset của map Litematica dùng depth fog, spatial mist và lighting chung như trước. Preset lưu trước v165 thiếu thanh này sẽ mở ở 0%.

**Ánh sáng → Mặt trời và bầu trời → Ánh trời sáng và chiều** mặc định 100% trong Forest. Mức này dùng đường cong **Ambient Energy By Hour** của biome với đỉnh +35% lúc 07:00 và 16:30. Cỏ, đá và nhân vật cùng nhận ánh sáng môi trường theo địa hình. 0% trở về ánh trời trước thay đổi. Hệ số về 1 từ 10:30 đến 14:00 và ngoài 05:30–18:45. Biome nhập từ Litematica áp dụng đường cong riêng trong cùng thuộc tính. Preset ánh sáng trước v167 thiếu thanh mới sẽ mở ở 0%.

**Ánh sáng → Bóng và tương phản → Dịu màu cỏ và lá trong bóng** mặc định 65% trong Forest. So 0% và 65% ở lối rừng X = −23,5, Z = 17,5 lúc 07:00 hoặc 16:30. Lượt chỉnh màu tham chiếu phục hồi nhẹ sắc đỏ và độ sáng ở vùng xanh tối. Hiệu ứng phân loại theo màu và độ sáng của từng pixel, nên áp dụng được trên cỏ và lá cùng màu mà không cần mask riêng cho map. **Daylight Green Grade Scale** đặt biên độ trong preset, còn **Shadow Grade Recovery By Hour** đặt cửa sổ giờ dùng chung. Hiệu ứng cần Reference finish. Preset Litematica tiếp tục dùng grade của biome. Preset lưu trước v166 thiếu thanh mới sẽ mở ở 0%.

## Chỉnh chu kỳ theo biome

Khi muốn đổi đặc tính ánh sáng, sương, hậu kỳ hoặc vòng ngày đêm cho riêng một map, duplicate preset thành file `.tres` mới rồi gán cho map đó. Duplicate cả resource con Day/Night hoặc Overcast nếu cần sửa các track riêng. Nhiều biome có thể dùng chung một Weather resource.

Tại **Biome Graphics → Day and night**, mở **Day Night**. Preset Rìa rừng ẩm đã có resource riêng. Duplicate resource này trước khi chỉnh màu nắng, ánh trời, bầu trời hoặc sương cho biome khác. Có thể để trống từng track để dùng đường màu chung. Các màu là giá trị tuyệt đối. Track góc pitch/yaw tính bằng độ và track Exposure dùng giá trị exposure của môi trường. Các curve cường độ nắng, ánh môi trường và mật độ sương ở profile là hệ số nhân. **Ambient Energy By Hour** được áp dụng trước mức mây, với hệ số 1 nếu để trống. Preset Rìa rừng ẩm giảm ánh môi trường khi trời vừa tối và về mức cũ sau 21:15. Map có đèn cục bộ vẫn dùng đường đèn riêng.

WorldMap Forest dùng **Afternoon Key By Hour** trên preset tham chiếu để phối dần màu và cường độ nắng từ các khung PIX cuối ngày. Trong **L → Cài đặt → Ánh sáng → Mặt trời và bầu trời**, kéo **Nắng cuối chiều** về 0% để so. Mức 100% dùng toàn bộ đường cong của preset, đạt tối đa 65% độ pha với chuỗi đo. Giờ xem được gán cho WorldMap và ảnh hưởng nằm trong 14:00–19:30. Giờ trưa và chạng vạng đã lưu giữ mốc cũ. Bản portable tiếp tục chỉnh màu nắng và cường độ qua **Day Night** và **Key Energy By Hour**.

Điểm 0,5 là 12:00. Giữ điểm 0/1 bằng nhau cho các track vòng lặp và chọn nội suy tuyến tính hoặc cubic để màu chuyển dần giữa các mốc. Với yaw qua ±180°, nhập các giá trị liên tục như 170° → 190° để hướng nắng đi qua góc ngắn. Curve cường độ nắng hay mật độ sương vừa tạo mà chưa đặt điểm giữ hệ số 1. **Weather → Start Overcast** đặt mức mây lúc mở map. F8 giữ giờ và mức mây hiện tại khi hai preset đều có cấu hình Overcast. Không cần đổi shader để đổi những thông số này.

Trong **Atmosphere and fog → Spatial mist**, **Local Mist By Hour** và **Additional Mist By Hour** điều khiển hai vùng sương độc lập. Curve dùng cùng trục 0–1 theo giờ và nhân với cường độ đã chọn trong preset và mức mây. Curve để trống giữ hệ số 1. Đặt **Local Mist Region** và **Additional Mist Region** ở node map theo địa hình thực tế. Trong scene Đồng cỏ, đi tới cụm đá gần X = 4,5, Z = −11,5, bấm **T** đến 07:00 hoặc 16:30 và **J** để đối chiếu. Túi sương ở cụm đá bật theo preset Rìa rừng ẩm, về 0 trong khung quanh 12:00.

Vùng sương cục bộ được tính theo tâm và bán kính trong không gian thế giới. Nếu một tia nhìn đi qua vùng đó ở cả hai phía của mốc bắt đầu lớp sương xa, cả hai đoạn đều đóng góp vào độ truyền sáng và màu tán xạ. Bạn có thể đặt vùng sương phía sau bậc đá hoặc qua một lòng trũng, rồi đổi `Fog Depth M` theo biome.

**Alternate Mist Region** cho phép đổi vị trí sương cục bộ theo giờ. Đặt vùng trên node map và thêm **Alternate Mist By Hour** trong preset. Vùng này dùng chung slot với **Local Mist Region** và chỉ chạy khi vùng chính không hoạt động. Để chuyển mượt, đặt hai curve về 0 tại giờ chuyển giao. **Additional Mist Region** có slot riêng. Trên WorldMap, chọn **Dùng nhanh → Sương chân cây · 20:15** rồi thử **Sương & hiệu ứng → Sương cục bộ → Sương chân cây sau chạng vạng** ở 42% và 0%.

Các vị trí vùng sương và đèn, cùng dữ liệu ánh sáng đã bake theo hình học, thuộc về map. Cần đặt hoặc dựng lại khi đổi layout. Các tính năng cần texture/LUT PIX và cache chiếu sáng riêng của Forest vẫn chạy qua preset tham chiếu trên WorldMap. Map Litematica mới dùng cấu hình portable.

Ở bậc đá WorldMap, vị trí vân sam và hai trường ánh trời, tán xạ định hướng nằm cùng hồ sơ private. **Forest Basin Layout Profile** nạp bố cục hiện tại dựa trên hash của map, nguồn cây và bộ bake. Khi thiếu hoặc không khớp, **Forest Basin Fallback Profile** nạp bố cục đã kiểm chứng trước đó. Khi cả hai hồ sơ đều thiếu, grove giữ 12 cây gốc. Trên máy có bộ nghiên cứu mới, xem lối lên bậc gần X = −22,5, Z = −40,5 lúc **07:00** hoặc **16:30** để thấy vệt nắng đi qua Valorie và các mặt đá sát đó.

**Local Actor Bounce Profile** là trường tùy chọn do map gán. Bộ nạp kiểm hash của profile, bố cục cây và atlas tán xạ đang dùng. Forest mở rộng ánh nắng hắt lên Valorie tới bậc đá. Điều chỉnh bằng **Nhân vật → Ánh sáng trên nhân vật → Ánh nắng hắt lên nhân vật**. Mức mặc định là 50%. Độ mạnh giảm về 0 ở biên vùng, còn ở lối rừng vẫn dùng trường gốc. Buổi trưa ưu tiên đường nắng đã duyệt. Các map portable tiếp tục dùng cấu hình biome của chúng.

**Ground Haze** và **Twilight Ground Haze** nằm trong **Biome Graphics → Atmosphere and fog → Spatial mist**. Cả hai dùng cùng tài nguyên để đặt dải khoảng cách tính sau nhân vật, cao độ tính từ **Atmosphere Base Y** của map và cửa sổ giờ. Sương thấp dùng cùng mốc cao độ, hữu ích khi spawn trên sườn đồi nhưng sương cần nằm dưới thung lũng. **Local Mist Region** và **Additional Mist Region** vẫn dùng tâm và bán kính theo tọa độ tuyệt đối. Bốn mốc giờ là bắt đầu, đạt mức cao nhất, bắt đầu giảm và hết. Cửa sổ có bốn số 0 được bỏ qua. Khi Ground Haze đang hoạt động, nó được ưu tiên. Khi lớp này hết giờ hoặc có cường độ 0, hệ thống lấy Twilight Ground Haze. Hai lớp điều chỉnh ánh sáng tán xạ trong sương và giữ nguyên extinction.

Forest lưu thông số hai lớp sương thấp trong preset tham chiếu. **Sương & hiệu ứng → Sương theo khoảng cách** vẫn có các slider riêng của Forest. Rìa rừng ẩm mặc định có lớp tán xạ thấp từ 18:45 đến 21:09, mạnh nhất từ 19:30 đến 20:00. Đồng cỏ dùng cấu hình sương nhẹ hơn. Mở **MeadowBiomeReview**, đi tới cụm đá rồi bấm **T** để tới 18:30 hoặc dùng **Shift+T** cho thời gian chạy qua 19:30. **J** bật/tắt spatial mist và **F8** đổi biome. Mức Đầy đủ và Cân bằng chạy lớp tán xạ này. Mức Nhẹ và Compatibility dùng depth fog tích hợp. [Hỗ trợ renderer trong Godot](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)

Map import nạp khí quyển từ preset portable. Dữ liệu khí quyển Forest theo hash chỉ được đọc trên đường chạy tham chiếu. Quy trình dựng map mới dùng cùng controller và shader. Vùng sương cục bộ, vị trí đèn và các trường ánh sáng theo hình học vẫn thuộc từng scene.

**Grove Mist By Hour** đặt độ nhận sương của thân và tán cho những map dùng hệ thống cây Grove. Forest chuyển mượt về cách đã duyệt quanh 12:00 và dùng độ nhận sương đầy đủ như terrain ở 09:30 và 14:15. Curve trống giữ cách cũ. Trong WorldMap, **Sương & hiệu ứng → Sương cục bộ → Sương đồng nhất trên cây** điều chỉnh mức pha trộn với curve. Map Meadow hiện dùng hệ cây khác.

**Projected Opening Recovery By Hour** đặt mức phục hồi vệt nắng qua khe trong preset Forest tham chiếu. Forest dùng mạnh nhất lúc 09:30 và 14:15 trời quang, rồi giảm qua các mốc lân cận. **Ánh sáng → Mặt trời và bầu trời → Nắng qua khe tán** điều chỉnh cường độ trong game. Mẫu chiếu Forest thuộc WorldMap. Các scene import dùng ánh nắng, bóng hình học và phản ứng thời tiết của preset portable.

**Day Grass Shadow Compactness** đặt mặc định cho map dùng adapter vật liệu cỏ. Trên Forest, **Địa hình & cây cỏ → Cỏ và tương tác → Bóng cỏ sáng / chiều** mặc định 200%, so với mức trước là 100%. Lúc 07:00 và 16:30, đỉnh bụi cỏ trong lượt vẽ bóng nắng dùng 70% chiều cao hiển thị. Mức rút giảm mượt về 0 tại 12:00 và 19:00. Các preset cũ giữ giá trị đã lưu. Phần cỏ hiển thị, bóng cây và cấu hình Meadow giữ nguyên.

## Mức chất lượng theo map và thiết bị

Chọn **Biome Quality** trong Inspector của map. **Đầy đủ** là mặc định. **Cân bằng** giữ spatial mist với lưới thưa hơn và dùng glow tích hợp. **Nhẹ** dùng depth fog và glow tích hợp. Tất cả dùng chung giờ, mây, màu, ánh sáng và tonemapping của biome. Với preset bật spatial mist, **Essential Fog Scale** chỉnh lượng depth fog dự phòng ở mức Nhẹ. So ba mức ngay trong map bằng **Shift+F7**. Phím này chỉ đổi mức của phiên đang chơi. Biome Quality áp dụng cho map portable. Forest vẫn đi qua cấu hình tham chiếu riêng.

## Đèn môi trường trên map import

Điền **Biome Path Fixture Xz** ở node map bằng tọa độ X/Z trong Godot. Đèn sẽ lấy cao độ từ địa hình ở điểm này. Trong preset, chọn **Path Fixture By Hour** để đặt giờ, **Path Fixture Energy** để chỉnh sáng bề mặt, và **Path Fixture Scatter** để chỉnh ánh sáng trong sương. Preset Rìa rừng ẩm có đèn từ chạng tối đến rạng sáng nếu map đặt tọa độ. Map thử dùng nguồn bếp lửa MD2 đã xác minh, đọc từ MD2 Research trong Godot chạy ở chế độ editor với Mobile. Thiếu nguồn hoặc sai hash thì scene bỏ qua fixture. Tài nguyên riêng không nằm trong bản phân phối.

Trong MeadowBiomeReview, bấm **T** tới 22:00 rồi đi về X = 4,5, Z = −4,5. **Shift+J** chỉ bật/tắt tán xạ của đèn, **J** so hai đường sương; **Shift+F7** thử mức Nhẹ vẫn có đèn bề mặt. Giờ và vị trí đèn tách khỏi thời tiết và mức chất lượng. Khi muốn đèn lên sớm ở chạng vạng, chỉnh **Path Fixture By Hour** của biome. Forest dùng điều khiển riêng trong **Ánh sáng → Đèn và vật phát sáng → Đèn lối rừng lúc chạng vạng** để so với bản tham chiếu cũ.

Để dùng cột đèn ForestA1 trên một map khác, đặt **Biome Path Lamp Xz** và **Biome Path Lamp Yaw Degrees** trên node map. Chân cột cần một mặt bằng ngang. Mesh và collider thân cột hiện cả ban ngày. Biome dùng **Path Fixture By Hour**, **Energy** và **Scatter** để điều khiển phát sáng, đèn điểm và tán xạ. Khi có cả hai vị trí, cột đèn được ưu tiên và bếp lửa là fallback. Trên WorldMap, mục **Cột đèn lối rừng** ở **Ánh sáng → Đèn và vật phát sáng** chuyển giữa hai bố trí. Cột cũng cần các file riêng tư đã xác minh và chạy trong editor Mobile.

## Bậc thấp cạnh đường rừng

**F5** mở WorldMap với bậc thấp mặc định trong bản chơi thử private dùng Forward Mobile. Bấm **L**, mở **Cài đặt** và dùng **Bậc thấp cạnh đường rừng** để so riêng bậc, vị trí chân cỏ và va chạm. **B** so toàn bộ đồ họa với bản gốc. Nếu nhân vật ở trong phần sẽ xuất hiện, bước ra ngoài mép để bậc được bật lại.

Vị trí, collider, cao độ chân cỏ và mẫu che ánh trời thuộc bản đồ. Node WorldMap gán **Playable Terrace Profile** và SHA-256 của file đặt bậc. Trình nạp kiểm tra hash của cả profile và dữ liệu map, rồi dùng chung mesh package, atlas đã xác minh và shader sương hiện có. Map import dùng preset biome bình thường. Bản dựng phân phối và renderer Compatibility dùng mặt bằng gốc. Muốn đặt bậc ở vị trí mới, dựng và kiểm lại dữ liệu hỗ trợ theo layout mới trước khi gán profile.

Cột đèn cạnh bậc dùng **Biome Path Lamp Xz** tại X = −29,5, Z = 17,5. Bán kính 3,5 m, màu và chu kỳ lên đèn đi theo cấu hình Forest hiện có. Có thể xem vị trí trước bằng cách đặt X = −27,5, Z = 21,5 trong Inspector rồi chạy lại scene. Kiểm tra bốn điểm chân, khoảng cách tới thân cây và tuyến đi bộ trước khi đổi vị trí trên map khác.

WorldMap private Forward Mobile đặt cụm đá ForestA1 ở X = −19, Z = 24. Trong **L → Cài đặt**, **Cụm đá ven đường rừng** so riêng đá, va chạm và những cụm cỏ dưới đá. **B** chuyển toàn bộ đồ họa về bản gốc. Nếu nhân vật đang đứng trong vị trí đặt đá, bật lại sẽ đợi nhân vật bước ra. Shader đá lấy ánh sáng từ cảnh và dùng chung sương terrain. Mesh và atlas được đọc từ MD2 Research theo hash.

Vị trí, hướng và hash của layout nằm ở các thuộc tính **Playable Boulder** trên node WorldMap. Khi dời đá, kiểm tra nền dưới cả footprint, tuyến chạy, cỏ và hướng đáp. Bộ nạp hiện nằm trong adapter Forest private. Các map portable dùng chuẩn Lighting và Fog chung. Bản phân phối và Compatibility bỏ qua cụm đá.
