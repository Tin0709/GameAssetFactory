# Shotgun — Sand Block V1

Mẫu shotgun tactical dựng theo ảnh người dùng cung cấp ngày 2026-10-19. Nguồn riêng, đăng ký **Pending** trong cùng `../showcase/Weapon_Showcase.blend`; mẫu mới được chọn khi mở lại viewer. Giữ nguyên nguồn các khẩu trước. Pistol Sand Block V1 được ghi nhận Approved trong metadata theo lời người dùng “ok tốt rồi”, không thay đổi nguồn hoặc tích hợp gameplay.

Báng cát có khoảng rỗng và thanh giằng dạng bậc, đệm báng graphite, tay cầm nghiêng, vòng cò rỗng, thân graphite với cửa bên lõm, rail nhiều nấc và thước ngắm. Tay bơm màu cát có sáu gân và năm rãnh sâu thật, mép dưới liền khối. Nòng trên có hốc vuông sâu/viền vát; ống dưới có đầu lõm và bốn vòng ôm. Giá bên thân giữ bốn viên đạn đỏ với đầu brass vàng. Đây là tạo hình game prop theo thị giác từ ảnh, không phải bản đo hoặc mô phỏng cơ khí.

- `Shotgun_Sand_Block_V1.blend` và `.glb`: bốn mesh cứng gồm thân, tay bơm, hộp tiếp đạn ngắn và nhóm bốn viên đạn; 5,168 tam giác, một material/atlas 256×256, texture nearest và được pack.
- Dài khoảng 1.058 m, rộng 0.105 m tính cả giá đạn, cao 0.2668 m. Blender +Y về trước, +Z lên trên, origin ở RightHandGrip; 10 marker theo thư viện.
- `shotgun_palette_source_256.png`: palette cát/graphite được sao từ pistol đã duyệt. Builder chỉ đổi ba swatch phụ cho đỏ/brass; mảng pixel đen giữ tương phản rõ theo phản hồi trước.
- `reference.png`: ảnh người dùng. `review/`: góc 3/4, hai bên, trên, trước và cận báng/tay cầm, thân/giá đạn, tay bơm, đầu nòng.
- `build_shotgun.py`: builder riêng. `render_details.py`: đọc nguồn đã lưu và render cận. `validate_asset.py`: mở lại nguồn và GLB; kiểm tra topology/UV/texture, marker, kích thước roundtrip, báng và vòng cò rỗng, hốc nòng, độ sâu rãnh tay bơm, cửa bên thân và đủ bốn viên đạn.

Chưa tạo animation, gameplay hoặc optic gắn trên rail. Các chi tiết phụ tách rời ở mép phải ảnh được dùng để hiểu phong cách; cấu hình súng chính theo hình lớn. Character Ready/Holster trong viewer dùng pose snapshot hiện có, chưa tinh chỉnh khớp tay cho mẫu mới.

Baseline, bản dựng đầu, backup thư viện và log kiểm tra: `.validation/shotgun_sand_block_v1_20261019/` tại gốc dự án. Không tự thêm hoặc commit Git.

Lượt kiểm tra cận cuối sửa hai ô bên hông đầu nòng thành hốc sâu thật, thay miếng đen nổi. Kiểm tra raycast xác nhận hốc bên sâu khoảng 4 mm từ viền ngoài, không làm kín lòng nòng. Bản trước lượt này được giữ trong `muzzle_refinement/` của baseline. Nguồn và GLB khớp kích thước/texture; thư viện được mở lại và thử đủ 90 tổ hợp mẫu/chế độ/góc nhìn.
