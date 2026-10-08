# Hướng mỹ thuật — zombie sinh tồn khối hộp

Cập nhật 2026-10-09, Asia/Saigon. Tài liệu định hướng lâu dài; bằng chứng, nguồn và cách tái hiện ở [RESEARCH.md](RESEARCH.md). **Thử nghiệm QualitySlice chưa được người dùng duyệt mỹ thuật.**

## Điều đã được người dùng chấp nhận hoặc yêu cầu

| Ràng buộc | Căn cứ / phạm vi |
|---|---|
| Zombie sinh tồn 3D, Android/iOS; tham chiếu chính Minecraft Dungeons II | Yêu cầu nghiên cứu ngày 2026-10-09. Học cách tổ chức hình ảnh, không sao chép asset/gameplay. |
| Thích tổng thể hình ảnh rừng/vườn trong ảnh Dungeons II người dùng gửi | Xác nhận trực tiếp “mình rất thích kiểu đồ họa này” ngày 2026-10-09; lưu [ảnh gốc U1](references/user-dungeons2-2026-10-09.png). Đây là **tham chiếu thị giác chính**, không phải duyệt QualitySlice, camera thấp, fog hay một kỹ thuật cụ thể. |
| Giữ hình dáng/tỷ lệ đã chọn, đầy đủ tay và bàn tay | Yêu cầu hiện tại. Dùng actor R15 đang hoạt động; không quay lại tỷ lệ của tài liệu cũ. R12 ghi nhận vai thu vào 32 mm mỗi bên đã được duyệt. |
| Texture có cụm pixel chữ nhật bất quy tắc, bảng màu gọn; cỏ xanh, đất nâu vàng, đá xanh xám | [STYLE_APPROVED_V3.txt](../../blender/environment/studies/dungeons_ground_style_v2/STYLE_APPROVED_V3.txt) ghi xác nhận 2026-10-08. |
| Cỏ v4 bản rộng; không bóng cỏ; sương hoãn | [GRASSLAND_V4.md](../GRASSLAND_V4.md). Đây là ràng buộc đã ghi từ lượt trước, không phải phê duyệt mọi bố cục v4/50×50. |
| Mục tiêu 30 FPS, test tự động không tiếng, trả lại tiếng khi người dùng test | Xác nhận trực tiếp trong chat 2026-10-09. Chưa chọn điện thoại tối thiểu. |

Việc tích hợp R13/R15 được cho phép không đồng nghĩa mọi chuyển động đã được duyệt là tự nhiên. Những dòng “AWAITING HUMAN REVIEW” ở các báo cáo cũ vẫn cần được tôn trọng. Không gán phần trăm giống game tham chiếu.

## Đề xuất hướng hình ảnh: khoảng chiến đấu sáng trong môi trường xanh trầm

Tham chiếu chính U1: tán cây tối làm khung, cỏ thấp dày xen cụm lá cao, hoa hồng/tím thưa, công trình đá xám; ánh sáng ấm và lớp xa sáng/nhạt hơn. Những đặc điểm này là phân tích ảnh để thử, không phải toàn bộ đã được duyệt thành quy tắc. Ảnh góc thấp không HUD có badge ESRB, phù hợp tham chiếu không khí/material; chưa xác định là gameplay hay cinematic. Giữ camera chơi hiện tại trong lượt thử.

Đề xuất, **chưa duyệt**: camera chéo từ trên xuống, nhân vật đọc rõ giữa một vùng nền ít chi tiết; cụm cây/đá tạo khung và lớp gần–giữa–xa. Xanh trầm ở tán cây, xanh dịu ở đất cỏ, đường đất ấm dẫn mắt. Bóng tạo các mảng lớn; điểm phát sáng dành cho tương tác/đòn đánh. Không tăng độ bóng, neon hoặc số chi tiết trên toàn cảnh để tìm cảm giác “hoàn thiện”.

| Hạng mục | Quy tắc làm việc đề xuất | Cách đánh giá |
|---|---|---|
| Camera/tỷ lệ | Giữ camera gameplay hiện tại trước: orthographic size 14.5, góc X −36.316°, Y 36.870°. Nhân vật đứng khoảng 80 px trong ảnh cao 720 px; đây là số đo xấp xỉ cảnh hiện tại, không là thông số Dungeons II. | Cùng camera, thử đứng/di chuyển/đông quái; kiểm tra silhouette ở kích thước điện thoại thực. Cận cảnh chỉ để chẩn đoán. |
| Bố cục | Dùng ít khối lớn bất đối xứng; dành khoảng trống xung quanh nhân vật; gom hoa thành điểm phụ. Giữ tán cây khỏi đường đi và vùng địch áp sát. | Ảnh màu và thang xám, đi qua các hướng, xem có mất nhân vật sau cây không. |
| Hình học | Cạnh cứng, tỷ lệ nhất quán; bevel chỉ khi nhìn thấy ở camera gameplay. Quy ước block 1 m, origin giữa đáy. Cây QualitySlice là proxy, chưa là chuẩn asset cây. | Silhouette trước texture; kiểm tra normals, mặt kín, tỷ lệ GLB trong engine. |
| Texture | Giữ cụm pixel có ý đồ, tránh nhiễu li ti/nhẫn đồng tâm; đồng nhất mật độ chi tiết giữa cỏ–đá–súng–nhân vật theo khoảng nhìn. | Xem cả cận và gameplay; pan chậm để thấy shimmer, thử mipmap riêng với atlas padding trước khi áp dụng. |
| Vật liệu | Môi trường chủ yếu matte; phản sáng nhẹ chỉ nơi cần đọc mặt/kim loại. Không sửa roughness nhân vật chỉ để khớp một screenshot. | Cùng vật thể dưới key/fill và bóng, kiểm tra highlight không làm mất palette. |
| Ánh sáng | Một sun có bóng, ambient lạnh vừa đủ đọc mặt tối; điều chỉnh light/value trước hậu kỳ. Tôn trọng sương đang hoãn. | Kiểm tra mảng sáng tối, chân tiếp đất, tự bóng/đứt bóng. Đừng dùng blur để che shadow acne. |
| Animation | Đọc được tư thế chịu lực → đẩy → hồi; kiểm tra chân cuối cùng trong world space sau mọi lớp blend/recoil. Không tăng bounce trước khi xử lý tiếp xúc chân. | Clip start/walk/stop, forward–diagonal–side, backward–diagonal–side, sprint–release–draw, recoil–settle. |
| Combat/VFX | Muzzle/impact sắc, ngắn; hồi thân chậm hơn cú giật súng; silhouette khối/pixel thống nhất. Không tăng diện tích flash che mục tiêu. | Xem cùng cảnh một và nhiều zombie; tách nhịp anticipation, sát thương và recovery. |

## Lựa chọn thực hiện và đường lui

- **Lượt đầu đã thử:** scene riêng kế thừa 50×50; actor/đất/cỏ/đá hiện có, bốn cây proxy opaque; ít hoa hơn, ambient giảm, sun ấm, MSAA 2×. Giữ bản gốc bằng F1 và từng bước bằng F2/F4/F5. Kết quả chỉ chứng minh được các thay đổi cụ thể trong ảnh, chưa đạt chất lượng mục tiêu cuối.
- **Lượt kế tiếp nên ưu tiên:** một chuyển tiếp locomotion/strafe có đo tiếp xúc chân, đồng thời hoàn thiện một cây thật với texture cùng ngôn ngữ V3. Làm riêng từng lượt để biết nguyên nhân cải thiện. Chưa sửa animation hoặc tái xuất nhân vật trong nghiên cứu này.
- **Ánh sáng bake:** chỉ thử ở một khu terrain/prop cố định đã chuẩn bị UV2. Actor dùng probe và bóng trực tiếp. Không unwrap đè UV2 của cỏ vì UV2 đang chứa gốc uốn. Chưa bake trong lượt này.
- **Nếu vượt 33.3 ms trên điện thoại:** đo pass gây tốn, thử tắt MSAA hoặc giảm 3D render scale, giảm mật độ vật trang trí và số caster. Giữ silhouette nhân vật và nhịp combat trước. Đây là thứ tự thử, chưa phải cấu hình tối thiểu đã chứng minh.
- **Chưa có lý do đổi engine:** Mobile hỗ trợ các công cụ cơ bản cần cho hướng này. Nâng engine, đổi renderer/engine hoặc thay cấu trúc map là đề xuất riêng cần bài toán, chi phí, lợi ích và bằng chứng thiết bị.

## Quy trình dùng khi nhận một ảnh mới

1. Xác định ảnh gameplay, cinematic hay quảng bá; lưu URL/timestamp và ghi quan sát/ước lượng/chưa biết riêng.
2. Kiểm tra trạng thái scene và hướng đã duyệt; nêu 1–3 khoảng cách có ảnh hưởng lớn nhất.
3. Chụp baseline. Chọn một nhóm: camera → hình khối/bố cục → value/màu → light/material → animation → VFX.
4. Thử trong scene riêng, chụp cùng camera/tư thế; quay clip nếu thay chuyển động. Tự xem và ghi điểm tốt lẫn xấu; giữ bản tốt nhất, không ghi “đã duyệt” thay người dùng.
5. Đo riêng không screenshot/movie readback, rồi kiểm tra điện thoại 30 FPS và tải kéo dài khi có thiết bị. Cập nhật mục kết quả trong RESEARCH, không tạo báo cáo trùng.
