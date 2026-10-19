# Rifle — Sand Block V1

Model mới theo ảnh người dùng cung cấp ngày 2026-10-19; chọn **Rifle — Sand Block V1** trong cùng Weapon Library. Trạng thái **Pending**, chờ nhận xét hình ảnh.

Thân và báng vàng cát, texture pixel cụm chữ nhật, báng dạng bậc, scope khối có kính hổ phách, bảy khe vuông thật ở mỗi bên ốp tay, ray trên/dưới, thước ngắm trước và đầu nòng khối vát góc có hốc. Hộp tiếp đạn tách riêng, nghiêng nhẹ về trước. Tỷ lệ được đối chiếu với góc ngang trong ảnh; ảnh minh họa có sai khác phối cảnh giữa các góc nên đây là bản dựng theo thị giác, không phải bản đo CAD.

- Nguồn: `Rifle_Sand_Block_V1.blend`; xuất riêng: `Rifle_Sand_Block_V1.glb`.
- Dài 1.205 m, rộng 0.119 m, cao 0.4298 m; 4,648 tam giác, hai mesh, một material, atlas 256×256 đã pack.
- Blender +Y về trước, +Z lên trên; origin tại tay cầm. Chín marker theo hợp đồng thư viện hiện có.
- `reference.png`: ảnh gốc người dùng; `review/`: render thật góc 3/4, ngang, trên và trước.
- `build_rifle.py`: dựng nguồn riêng bằng background Blender; `validate_asset.py`: mở lại nguồn/GLB, kiểm tra topology, texture, marker, kích thước roundtrip và 14 ray qua khe thoáng.

Đăng ký trong `../showcase/Weapon_Showcase.blend` bằng workflow hiện có, tự chọn mẫu mới khi mở viewer. Các mẫu cũ, animation và Godot được giữ nguyên. Ready/Holster của thư viện là preview pose có sẵn; việc khớp tay và gameplay cho rifle này cần được đánh giá riêng nếu dùng về sau.

Baseline, bản sao thư viện trước cập nhật và log nằm trong `.validation/rifle_sand_block_v1_20261019/` ở gốc dự án.
