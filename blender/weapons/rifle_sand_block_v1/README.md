# Rifle — Sand Block V1

Model mới theo ảnh người dùng cung cấp ngày 2026-10-19; chọn **Rifle — Sand Block V1** trong cùng Weapon Library. Trạng thái **Pending**, chờ nhận xét hình ảnh.

**Sửa kính scope 2026-10-19:** bỏ các mặt kim loại bịt đầu/lòng ống, mở thông toàn bộ vỏ scope và thêm hai thấu kính lồi mỏng độc lập, nằm lùi trong vòng giữ kính. Theo phản hồi tiếp theo, cả kính trước và sau đổi sang **đỏ cam** như ảnh mẫu; giữ transmission 0.96, IOR 1.46 và phản chiếu nhẹ. Cả nguồn Blender lẫn GLB giữ hai lớp kính thật; không còn dùng khối cam đặc để giả kính. `validate_optics.py` kiểm tra năm đường xuyên lòng vỏ, hai mặt kính, sắc đỏ cam và dữ liệu transmission/alpha trong GLB. Các render `detail_scope_front.png`, `detail_scope_rear.png`, `scope_through_rear.png` dùng để kiểm tra từ hai đầu.

**Lượt rà chi tiết 2026-10-19:** đối chiếu lại ảnh gốc và bổ sung panel ốp tay liền có mép vát quanh bảy ô thoáng cao hơn, rãnh lõm trên ray, ô hở trước/bên ở thước ngắm, viền kính scope và đầu nòng màu kim loại ấm, đường ghép báng, hai gờ tay cầm và đường ghép đáy hộp tiếp đạn. Kính hổ phách rõ hơn, pixel nhỏ hơn và màu vàng cát dịu hơn. Giữ nguyên kích thước tổng thể, marker và cùng mục chọn V1. Hốc đầu nòng sâu 42 mm; viền trang trí mở thông vào hốc, không bị một nắp đặc che lại.

Thân và báng vàng cát, texture pixel cụm chữ nhật, báng dạng bậc, scope khối có kính hổ phách, bảy khe vuông thật ở mỗi bên ốp tay, ray trên/dưới, thước ngắm trước và đầu nòng khối vát góc có hốc. Hộp tiếp đạn tách riêng, nghiêng nhẹ về trước. Tỷ lệ được đối chiếu với góc ngang trong ảnh; ảnh minh họa có sai khác phối cảnh giữa các góc nên đây là bản dựng theo thị giác, không phải bản đo CAD.

- Nguồn: `Rifle_Sand_Block_V1.blend`; xuất riêng: `Rifle_Sand_Block_V1.glb`.
- Dài 1.205 m, rộng 0.119 m, cao 0.4298 m; 6,200 tam giác, ba mesh (thân, hộp tiếp đạn, hai thấu kính) và ba material (atlas, kính trước, kính sau). Atlas 256×256 đã pack.
- Blender +Y về trước, +Z lên trên; origin tại tay cầm. Chín marker theo hợp đồng thư viện hiện có.
- `reference.png`: ảnh gốc người dùng; `review/`: render thật góc 3/4, ngang, trên và trước.
- `build_rifle.py`: dựng nguồn riêng bằng background Blender; `validate_asset.py`: mở lại nguồn/GLB, kiểm tra topology, texture, marker, kích thước roundtrip, 42 ray qua khe thoáng, 9 ray ở rãnh ray và ô hở thước ngắm trước/bên.

Đăng ký trong `../showcase/Weapon_Showcase.blend` bằng workflow hiện có, tự chọn mẫu mới khi mở viewer. Các mẫu cũ, animation và Godot được giữ nguyên. Ready/Holster của thư viện là preview pose có sẵn; việc khớp tay và gameplay cho rifle này cần được đánh giá riêng nếu dùng về sau.

Baseline, bản sao thư viện trước cập nhật và log nằm trong `.validation/rifle_sand_block_v1_20261019/` ở gốc dự án.

Bản V1 trước lượt rà chi tiết, thư viện/manifest trước cập nhật và các log mới được giữ tại `.validation/rifle_sand_block_detail_20261019/`.

Bản trước khi sửa scope và ảnh phản hồi mới của người dùng được giữ tại `.validation/rifle_sand_block_optics_20261019/`.
