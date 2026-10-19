# Pistol — Sand Block V1

Model mới dựng theo ảnh người dùng cung cấp ngày 2026-10-19, cùng phong cách và bảng màu với Rifle Sand Block V1. Đăng ký **Pending** trong cùng `../showcase/Weapon_Showcase.blend`, tự chọn mẫu mới khi mở lại viewer. Các mẫu rifle/pistol/shotgun trước đó được giữ nguyên.

Khung vàng cát, slide graphite có cạnh vát và sáu gân kéo phía sau, ô hạ thấp ở giữa slide với hood nòng nằm lùi bên trong, đầu nòng vuông có hốc sâu và viền kim loại ấm. Thước ngắm sau là khe chữ U thật; vòng cò có khoảng hở và cò đen tách rõ. Tay cầm nghiêng có panel tối, các đoạn tan ở mặt trước và đế hộp tiếp đạn màu đen. Texture pixel cụm chữ nhật đã pack.

- `Pistol_Sand_Block_V1.blend` và `.glb`: ba mesh cứng độc lập gồm thân, slide và hộp tiếp đạn; một material/atlas 256×256, 2,344 tam giác.
- Kích thước: dài 0.2792 m, rộng 0.0540 m tính cả nút điều khiển, cao 0.1814 m. Tỷ lệ được dựng theo thị giác từ các góc trong ảnh, không phải bản đo cơ khí.
- Blender +Y về trước / +Z lên trên, origin tại RightHandGrip; 10 marker theo hợp đồng thư viện, gồm MagazineFeed.
- `reference.png`: ảnh người dùng. `review/`: góc 3/4, ngang, trên, trước và cận cảnh thước ngắm/slide/nòng/tay cầm.
- `build_pistol.py`: builder riêng; `render_details.py`: render cận từ nguồn đã lưu; `validate_asset.py`: mở lại nguồn và GLB, kiểm tra topology, texture, marker, kích thước roundtrip, khe ngắm, vòng cò, hốc nòng và phần rỗng của tay cầm dưới feed seat.

Ba part tách riêng phục vụ công việc sau này; chưa tạo animation hoặc tích hợp gameplay. Ready/Holster trong viewer dùng các pose snapshot có sẵn, chưa tinh chỉnh khớp tay/holster cho model mới.

Bản sao thư viện trước cập nhật, baseline và log ở `.validation/pistol_sand_block_v1_20261019/` tại gốc dự án. Bản render đầu được giữ trong thư mục `first_pass/` của baseline.

Lượt đối chiếu tiểu tiết ngày 2026-10-19: bổ sung cụm pixel rõ hơn trên graphite của slide và tay cầm bằng texture phẳng, thay các miếng pixel hình học nổi trước đó. Thêm bậc nắp sau slide, hạ hood nòng với dải sáng hẹp trên đỉnh, chỉnh cò thành khối đứng có bậc. Hai ốp tay cầm được dựng lại thành khối liền có mặt vát rộng, kéo xuống sát đế hộp tiếp đạn và mở rộng đế cho khớp. Kích thước tổng thể, origin và toàn bộ marker giữ nguyên. Màu cát không đổi; `pistol_palette_source_256.png` là seed bất biến để builder không cộng dồn tương phản sau mỗi lần chạy. Bản trước lượt tinh chỉnh và thư viện được lưu tại `.validation/pistol_sand_block_detail_20261019/`.
