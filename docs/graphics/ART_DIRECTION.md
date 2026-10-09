# Hướng mỹ thuật — zombie sinh tồn khối hộp

Cập nhật 2026-10-09, Asia/Saigon. Tài liệu định hướng lâu dài; bằng chứng, nguồn và cách tái hiện ở [RESEARCH.md](RESEARCH.md). **Gameplay chính hiện tại là WorldMap; màu/ánh sáng mới vẫn chờ review**, không là phong cách đã duyệt. ForestMeadowV3 và GameplayMap được giữ làm lịch sử so sánh.

## Điều đã được người dùng chấp nhận hoặc yêu cầu

| Ràng buộc | Căn cứ / phạm vi |
|---|---|
| Zombie sinh tồn 3D, Android/iOS; tham chiếu chính Minecraft Dungeons II | Yêu cầu nghiên cứu ngày 2026-10-09. Học cách tổ chức hình ảnh, không sao chép asset/gameplay. |
| Thích tổng thể hình ảnh rừng/vườn trong ảnh Dungeons II người dùng gửi | Xác nhận trực tiếp “mình rất thích kiểu đồ họa này” ngày 2026-10-09; lưu [ảnh gốc U1](references/user-dungeons2-2026-10-09.png). Đây là **tham chiếu thị giác chính**, không phải duyệt QualitySlice, camera thấp, fog hay một kỹ thuật cụ thể. |
| Giữ hình dáng/tỷ lệ đã chọn, đầy đủ tay và bàn tay | Yêu cầu hiện tại. Dùng actor R15 đang hoạt động; không quay lại tỷ lệ của tài liệu cũ. R12 ghi nhận vai thu vào 32 mm mỗi bên đã được duyệt. |
| Texture có cụm pixel chữ nhật bất quy tắc, bảng màu gọn; cỏ xanh, đất nâu vàng, đá xanh xám | [STYLE_APPROVED_V3.txt](../../blender/environment/studies/dungeons_ground_style_v2/STYLE_APPROVED_V3.txt) ghi xác nhận 2026-10-08. |
| Cỏ v4 bản rộng; không bóng cỏ; sương hoãn | [GRASSLAND_V4.md](../GRASSLAND_V4.md). Đây là ràng buộc đã ghi từ lượt trước, không phải phê duyệt mọi bố cục v4/50×50. |
| Mục tiêu 30 FPS, test tự động không tiếng, trả lại tiếng khi người dùng test | Xác nhận trực tiếp trong chat 2026-10-09. Chưa chọn điện thoại tối thiểu. |
| Lưu cây/bụi cây để reuse; nhảy lên/xuống block phải làm và review trong Blender trước | Yêu cầu trực tiếp 2026-10-09. Chưa phê duyệt bộ cây mới hoặc motion nhảy. |
| ForestQualitySlice là scene chính để mở project và bấm F5 review | Yêu cầu trực tiếp tiếp theo ngày 2026-10-09; cho phép đổi `run/main_scene`, không đồng nghĩa đã duyệt mọi chi tiết mỹ thuật. |
| **Mọi cập nhật đồ họa đi vào gameplay chính để F5 review liên tục** | Yêu cầu ngày2026-10-09. Mới nhất: dựng đúng `World Map.litematic`, dùng asset từ `dungeons_ground_style_v2.blend`; scene chính là **WorldMap**, thay nền thử GameplayMap. Giữ các scene trước để đối chiếu. Đưa vào gameplay không đồng nghĩa đã duyệt mỹ thuật. |
| **Nền cỏ dịu, vành vách đất–đá và cột thấp phía trong** | Yêu cầu tiếp theo: [cỏ ô liu ít tương phản](references/user_flat_grass_2026-10-09.png), [vách cao nhấp nhô bao quanh map](references/user_map_cliffs_2026-10-09.png), từ 10 block trở lên; thêm cột phía trong từ 2 block. Vật cản che nhân vật cần mờ đi như ảnh người dùng. GameplayMap đang thực hiện để review, chưa duyệt kết quả. |
| Nắng dịu, hơi bloom; tránh cả chói lẫn quá tối | Người dùng phản hồi V3 đầu quá chói, lượt giảm sáng tiếp theo quá tối. Đây là mục tiêu chỉnh, không phải phê duyệt bộ thông số hiện tại. |
| **Tạm bật bóng cỏ để review** | Yêu cầu tiếp theo ngày 2026-10-09 thay thế quy tắc không bóng cỏ trong bản thử V3; mặc định bật, G bật/tắt. Chưa quyết định giữ lâu dài hoặc áp dụng trên điện thoại. |
| **Thử không khí có lớp sương mỏng, nắng dịu để tự nhiên hơn** | Yêu cầu tiếp theo cùng ngày, [ảnh tham chiếu](references/user-dungeons2-atmosphere-2026-10-09.png). Thay thế việc hoãn sương trong study V3; H bật/tắt. Đây là mục tiêu hình ảnh được yêu cầu, không xác nhận Dungeons II dùng fog cụ thể hoặc duyệt thông số thử. |
| **Mức tăng sắc ấm hiện tại chỉ +5%** | Người dùng đã xem +15% và thấy quá ấm, yêu cầu giảm còn +5%. Đây là strength của color grade thử, không phải tăng độ sáng hoặc phần trăm nhiệt độ vật lý. Kết quả +5% vẫn chờ review. |
| Chỉ bổ sung animation nhảy; giữ nguyên toàn bộ animation cũ | Người dùng nhắc rõ trong lúc review nhảy ngày 2026-10-09. Không thay Walk/Sprint/Idle/weapon/combat bằng các đoạn di chuyển minh hoạ trong study. |
| **Yêu cầu mới nhất: tạm bỏ nhảy trong game; tự đi lên bậc mượt bằng animation cũ** | Người dùng đổi hướng sau khi cho phép thử tích hợp. Giữ study Blender V2 để bổ sung nhảy sau; không bật clip nhảy hoặc xung lực bật lên trong game hiện tại. |

Việc tích hợp R13/R15 được cho phép không đồng nghĩa mọi chuyển động đã được duyệt là tự nhiên. Những dòng “AWAITING HUMAN REVIEW” ở các báo cáo cũ vẫn cần được tôn trọng. Không gán phần trăm giống game tham chiếu.

**Yêu cầu mới nhất cho WorldMap:** bám [màu/ánh sáng, cỏ/hoa](references/user-world-map-look-2026-10-09.png), [mặt đất mượt](references/user-world-map-ground-2026-10-09.png), mép đường đất hòa vào cỏ và chút noise màu nhẹ trên toàn map. Lá đi xuyên được; cỏ/hoa phản ứng khi đi qua rồi hồi lại. Tăng biên độ gió50% cho cỏ cao/lá,100% cho cỏ nhỏ/hoa; tăng độ đậm bóng15%; thêm bóng mây thưa trôi, không vẽ mây. Đây là các **yêu cầu đã xác nhận**, còn kết quả/thông số hiện tại vẫn là bản thử. Giữ+5%warmth, exposure.96, vị trí block/hoa và toàn bộ nguồn Blender. Xem [hợp đồng map và reuse](../../game_mobile_3d/assets/maps/world_map/README.md).

Yêu cầu tiếp theo bổ sung bóng tiếp xúc nhẹ tại chân bậc, gốc cỏ/hoa và đốm đất quanh bụi. Người dùng thấy lượt đốm đất đầu quá ít/nhạt, yêu cầu **nhiều và đậm hơn**; bản hiện tại tăng mật độ và đất nâu sẫm, mép thưa dần, vẫn chờ review.

Lượt tiếp theo dùng [ảnh chiều sâu ánh sáng](references/user-world-map-depth-2026-10-09.png): thử nắng dịu tách khỏi bóng mát xanh, nền bớt ô liu, đường đất vàng hơn và đầu cỏ cao bớt trắng. Người dùng yêu cầu [bóng sát gốc cỏ rõ hơn](references/user-world-map-root-contact-2026-10-09.png) để bụi có cảm giác cắm vào đất; bóng lan mềm qua ranh giới ô, không viền vuông. Đây vẫn là **bản thử chờ review**, không tăng LUT ấm vượt .05. Các đường vuông do làm mờ vách ảnh hưởng nền là lỗi cần sửa, không là hiệu ứng mỹ thuật.

## Đề xuất hướng hình ảnh: khoảng chiến đấu sáng trong môi trường xanh trầm

**Xác nhận mới nhất về cỏ (2026-10-09):** sau khi thử hòa chân cỏ thấp với màu/shading nền và chuyển xanh nhẹ lên ngọn, người dùng nói “rất đẹp” và gửi [ảnh kết quả](references/user-world-map-short-grass-approved-2026-10-09.png). Đây là xác nhận cho phần cỏ thấp của V2, không phải duyệt lại toàn bộ ánh sáng/hiệu năng. Người dùng yêu cầu áp dụng tương tự cho cỏ cao; V3 giữ bông vàng, hoa và cỏ thấp đã thích, còn phần thân/lá cỏ cao mới chờ review. Chi tiết và ảnh/clip ở [RESEARCH](RESEARCH.md#worldmap--map-litematica-và-lượt-review-hiện-tại).

Tham chiếu chính U1: tán cây tối làm khung, cỏ thấp dày xen cụm lá cao, hoa hồng/tím thưa, công trình đá xám; ánh sáng ấm và lớp xa sáng/nhạt hơn. Những đặc điểm này là phân tích ảnh để thử, không phải toàn bộ đã được duyệt thành quy tắc. Ảnh góc thấp không HUD có badge ESRB, phù hợp tham chiếu không khí/material; chưa xác định là gameplay hay cinematic. Giữ camera chơi hiện tại trong lượt thử.

Đề xuất, **chưa duyệt**: camera chéo từ trên xuống, nhân vật đọc rõ giữa một vùng nền ít chi tiết; cụm cây/đá tạo khung và lớp gần–giữa–xa. Xanh trầm ở tán cây, xanh dịu ở đất cỏ, đường đất ấm dẫn mắt. Bóng tạo các mảng lớn; điểm phát sáng dành cho tương tác/đòn đánh. Không tăng độ bóng, neon hoặc số chi tiết trên toàn cảnh để tìm cảm giác “hoàn thiện”.

| Hạng mục | Quy tắc làm việc đề xuất | Cách đánh giá |
|---|---|---|
| Camera/tỷ lệ | Giữ camera gameplay hiện tại trước: orthographic size 14.5, góc X −36.316°, Y 36.870°. Nhân vật đứng khoảng 80 px trong ảnh cao 720 px; đây là số đo xấp xỉ cảnh hiện tại, không là thông số Dungeons II. | Cùng camera, thử đứng/di chuyển/đông quái; kiểm tra silhouette ở kích thước điện thoại thực. Cận cảnh chỉ để chẩn đoán. |
| Bố cục | Dùng ít khối lớn bất đối xứng; dành khoảng trống xung quanh nhân vật; gom hoa thành điểm phụ. Giữ tán cây khỏi đường đi và vùng địch áp sát. | Ảnh màu và thang xám, đi qua các hướng, xem có mất nhân vật sau cây không. |
| Hình học | Cạnh cứng, tỷ lệ nhất quán; bevel chỉ khi nhìn thấy ở camera gameplay. Quy ước block 1 m, origin giữa đáy. Cây QualitySlice là proxy, chưa là chuẩn asset cây. | Silhouette trước texture; kiểm tra normals, mặt kín, tỷ lệ GLB trong engine. |
| Texture | Giữ cụm pixel có ý đồ, tránh nhiễu li ti/nhẫn đồng tâm; đồng nhất mật độ chi tiết giữa cỏ–đá–súng–nhân vật theo khoảng nhìn. | Xem cả cận và gameplay; pan chậm để thấy shimmer, thử mipmap riêng với atlas padding trước khi áp dụng. |
| Vật liệu | Môi trường chủ yếu matte; phản sáng nhẹ chỉ nơi cần đọc mặt/kim loại. Không sửa roughness nhân vật chỉ để khớp một screenshot. | Cùng vật thể dưới key/fill và bóng, kiểm tra highlight không làm mất palette. |
| Ánh sáng | Một sun có bóng, ambient lạnh vừa đủ đọc mặt tối; điều chỉnh light/value trước hậu kỳ. Theo yêu cầu mới, thử haze mỏng tăng theo khoảng cách, giữ vùng actor rõ. | Kiểm tra mảng sáng tối, chân tiếp đất, tự bóng/đứt bóng và bật/tắt haze cùng camera. Đừng dùng blur để che shadow acne. |
| Animation | Đọc được tư thế chịu lực → đẩy → hồi; kiểm tra chân cuối cùng trong world space sau mọi lớp blend/recoil. Không tăng bounce trước khi xử lý tiếp xúc chân. | Clip start/walk/stop, forward–diagonal–side, backward–diagonal–side, sprint–release–draw, recoil–settle. |
| Combat/VFX | Muzzle/impact sắc, ngắn; hồi thân chậm hơn cú giật súng; silhouette khối/pixel thống nhất. Không tăng diện tích flash che mục tiêu. | Xem cùng cảnh một và nhiều zombie; tách nhịp anticipation, sát thương và recovery. |

## Lựa chọn thực hiện và đường lui

- **Bộ dùng lại đã được yêu cầu lưu:** [Meadow Daylight V1](../../game_mobile_3d/assets/graphics/meadow_daylight_v1/README.md), preset đang dùng ở gameplay và snapshot V1 cố định cho map sau. Đây là xác nhận lưu/tái sử dụng đồ họa hiện tại; không tự nâng trạng thái mọi thử nghiệm thành đã duyệt mỹ thuật hoặc hiệu năng.

- **Lượt đầu đã thử:** scene riêng kế thừa 50×50; actor/đất/cỏ/đá hiện có, bốn cây proxy opaque; ít hoa hơn, ambient giảm, sun ấm, MSAA 2×. Giữ bản gốc bằng F1 và từng bước bằng F2/F4/F5. Kết quả chỉ chứng minh được các thay đổi cụ thể trong ảnh, chưa đạt chất lượng mục tiêu cuối.
- **Lượt hai đã thử:** ForestQualitySlice dùng cây tác giả, địa hình bậc, tường đá đổ, cỏ theo cụm; so hình học dưới đèn cũ rồi đèn mới với PCF/Filmic. F1 bản QualitySlice trước, F2 hình học mới/đèn cũ, F4 bản mới, Tab A/B. Camera/tỷ lệ actor giữ nguyên. Bộ cây có màu vertex, chưa phải texture atlas chuẩn cuối; xem [nguồn Blender, GLB và cách reuse](../../blender/environment/studies/forest_canopy_v2/README.md).
- **Lượt ba đang review:** ForestMeadowV3 có tán lá chia cụm bất đối xứng, cỏ thấp và đầu lá dịu, mép cỏ–đất ngắt quãng, vách đất/đá phân tầng. [Bộ cây V3 tái sử dụng](../../blender/environment/studies/forest_canopy_v3/README.md). Ánh sáng đã nâng lại giữa hai mức bị phản hồi chói/tối, thêm bloom nhẹ, bóng cỏ và haze mỏng theo yêu cầu tiếp theo. F1 là QualitySlice đầu, không phải V2; G so bóng cỏ, H so haze trong V3. Chưa duyệt hình ảnh.
- **Di chuyển lên bậc:** theo yêu cầu mới nhất, dùng chuyển động lên bậc liên tục và gait R15 cũ. Motion nhảy V2 được lưu riêng để dùng sau, chưa duyệt nghệ thuật và không hoạt động trong game. Không sửa các clip gait/weapon/combat hoặc GLB nhân vật cũ. Walk↔strafe/foot contact vẫn là vấn đề riêng còn mở.
- **Ánh sáng bake:** chỉ thử ở một khu terrain/prop cố định đã chuẩn bị UV2. Actor dùng probe và bóng trực tiếp. Không unwrap đè UV2 của cỏ vì UV2 đang chứa gốc uốn. Chưa bake trong lượt này.
- **Nếu vượt 33.3 ms trên điện thoại:** đo pass gây tốn, thử tắt MSAA hoặc giảm 3D render scale, giảm mật độ vật trang trí và số caster. Giữ silhouette nhân vật và nhịp combat trước. Đây là thứ tự thử, chưa phải cấu hình tối thiểu đã chứng minh.
- **Chưa có lý do đổi engine:** Mobile hỗ trợ các công cụ cơ bản cần cho hướng này. Nâng engine, đổi renderer/engine hoặc thay cấu trúc map là đề xuất riêng cần bài toán, chi phí, lợi ích và bằng chứng thiết bị.

## Quy trình dùng khi nhận một ảnh mới

1. Xác định ảnh gameplay, cinematic hay quảng bá; lưu URL/timestamp và ghi quan sát/ước lượng/chưa biết riêng.
2. Kiểm tra trạng thái scene và hướng đã duyệt; nêu 1–3 khoảng cách có ảnh hưởng lớn nhất.
3. Chụp baseline. Chọn một nhóm: camera → hình khối/bố cục → value/màu → light/material → animation → VFX.
4. Thử trong scene riêng, chụp cùng camera/tư thế; quay clip nếu thay chuyển động. Tự xem và ghi điểm tốt lẫn xấu; giữ bản tốt nhất, không ghi “đã duyệt” thay người dùng.
5. Đo riêng không screenshot/movie readback, rồi kiểm tra điện thoại 30 FPS và tải kéo dài khi có thiết bị. Cập nhật mục kết quả trong RESEARCH, không tạo báo cáo trùng.
