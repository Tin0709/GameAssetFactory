# The Forager · Étude thân trên

Chính diện là chuẩn tỷ lệ và bố trí trên mặt. Góc 3/4 quyết định độ sâu, nét gập và ánh sáng. Hình nghiêng kiểm tra phần sau của mũ. Áo choàng dưới lưng bị cuộn vải và balo che khuất trong concept, nên mảng lưng của bản thử được nối từ nếp vai và đường mép nhìn thấy ở góc nghiêng.

| Bộ phận | Hình khối và chất liệu | Cách dựng |
| --- | --- | --- |
| Mũ | Đỉnh mũ như hộp vát, hai má loe xuống, một lớp lót sâu màu olive đậm. Viền mật ong bậc thang. Chữ thập nhỏ như đường vá bên hông. | Nối các tiết diện kín để có thể tích và lòng mũ. Viền dùng chung biên với vải. Đặt các mảng olive theo từng hướng mặt phẳng. |
| Mặt và tóc | Mắt dọc, lông mày tối, mũi miệng ít pixel. Mái nâu đậm gãy thành vài mảng lớn. Bím tóc dày chạy qua vai phải của nhân vật. | Vẽ mặt trực tiếp ở 64 × 64. Dựng mái rời theo tiết diện vát, bím tóc nối bằng các đoạn xen nhau và có buộc vải. |
| Khăn | Một đường olive hẹp ở cằm, dưới là khăn cam đất gối lớp. | Hai nếp có thể tích, xiên nhẹ ở phía trước, với độ nhám của vải. |
| Vai và áo choàng | Vai olive có mép cam bậc thang và đường vá sáng. Lớp áo choàng olive rủ về sau, đậm hơn mặt trước. | Mảng vai và áo choàng có độ dày, tiết diện lớn giữ góc vuông. Dùng mặt phẳng và pixel để gợi nếp vải. |
| Thân áo | Áo lót màu lanh và thân áo nâu nhiều lớp. Dây chéo và khóa vuông là các chi tiết nằm trên thân áo. | Dựng riêng áo lót, vạt nâu, gờ may và khóa. Bề mặt da sần nhẹ, khóa kim loại xước. |

Dùng bản sao armature Showcase_Player_Rig theo dáng nghỉ và một tư thế duyệt nhẹ ở vai. Khung hình kết thúc quanh eo. Dựng hình thủ công theo ảnh cho phép kiểm soát viền, khe, lớp lót và các đường may chính xác. Một mesh tổng hợp từ cả tờ concept dễ gộp các lớp áo hoặc kéo phụ kiện vào silhouette. Các texture được vẽ riêng cho bản thử và đóng gói trong Blender. Studio dùng nguồn sáng chính ấm từ trên trái, sáng phụ sát mặt và rim ấm nhẹ.

Mốc duyệt là render thân trên từ chính diện và góc 3/4. Dùng bản clay để so silhouette và chiều sâu. Dùng bản màu để xem nét mặt, độ rõ từng chất liệu và trọng tâm sáng tối. Các phụ kiện rời và phần thân dưới nằm ngoài giai đoạn này.


## Bảng màu và đối chiếu bản duyệt

Các ô màu trên tờ concept cho olive `#836B3B`, viền mật ong `#CE9153`, khăn đất nung `#AB5232`, da nâu `#7F4C39` và tông da sáng `#E2B598`. Đây là các màu đo trên ảnh đã chiếu sáng. Atlas dùng các tông nền dịu hơn để ánh sáng và bóng từ geometry tạo ra độ sáng ở những mặt hướng về đèn.

Bản clay từ chính diện và 3/4 cho thấy viền có chiều sâu, bím tóc chia múi và đường gấp vai chạy quanh tay. Lượt sửa cuối nối kín phần áo choàng trên lưng. Model dùng 94 mesh kín, 13 xương có ma trận nghỉ trùng rig nguồn và 13 texture 64 × 64 đã đóng gói, dùng lọc Nearest. Bản thử dùng tư thế duyệt tĩnh.

Bản màu đặt trọng tâm vào khuôn mặt giữa mũ olive và khăn cam đất. Mũ còn đầy hơn ở góc 3/4, góc vát đỉnh ít gắt hơn concept và vùng mắt sáng hơn. Phần áo choàng sau lưng được suy ra từ đoạn nhìn thấy ở vai. Các chi tiết rời được dành cho một giai đoạn sau khi duyệt.

Ảnh và model thử nằm trong thư mục private. Trình ghi tự động của checkout đã chụp một số bản nháp vào lịch sử Git cục bộ trước khi thêm quy tắc bỏ qua. Các file private đã được bỏ theo dõi ở trạng thái hiện tại, giữ nguyên trên ổ đĩa. Thử nghiệm chạy cục bộ.
