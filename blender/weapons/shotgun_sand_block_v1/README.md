# Shotgun — Sand Block V1

Mẫu hiện tại vẫn **Pending** trong cùng `../showcase/Weapon_Showcase.blend`. Lượt mới nhất dùng `reference_refined.png`, ảnh nhiều góc người dùng gửi sau khi nhận xét tỷ lệ chưa giống. `reference.png` giữ ảnh ban đầu. Nguồn và trạng thái duyệt của các khẩu khác được giữ nguyên.

Đã đối chiếu góc ngang ở cùng chiều dài, rồi dựng lại các phần lệch: báng có thanh trên dày hơn, đệm sau thấp/dày hơn và lỗ rỗng dạng bậc; cổ nối có các bậc thu gọn cùng nắp thân sau vát. Tay bơm đặt cao và tiến về trước, bề ngang giảm từ 78 xuống 66 mm; thân liền có năm rãnh chìm khoảng 2 mm mỗi bên thay các gân nổi 7 mm trước đó. Thân tay bơm cao 77 mm, có mặt vát dưới rộng và gờ tan nhỏ ở đầu sau. Chiều dài tăng nhẹ theo ảnh thay vì thu nhỏ đồng đều mọi chiều.

Tay cầm lùi 50 mm, ngắn hơn 20%; vòng cò thu gọn và đưa theo tay cầm. Đế đen và hộp tiếp đạn ngắn được chỉnh tỷ lệ. Rail mảnh/thấp hơn, nắp thân sau và nút bên đặt lại. Bốn viên đạn có đầu/brass tám cạnh vàng hơn; miệng hai ống dùng biên dạng tám cạnh thay lỗ gần vuông. Khoảng cách hai ống vẫn giữ 1.5 mm tại vòng ôm và 6 mm ở đoạn trơn; vòng ôm/cổ tay bơm đi theo tay bơm mới. Hốc bên đầu nòng vẫn sâu thật. Chân thước ngắm trước/sau được nối sát vào đế, có raycast kiểm tra các khe hở đã đóng.

- `Shotgun_Sand_Block_V1.blend` và `.glb`: bốn mesh cứng (thân, tay bơm, hộp tiếp đạn ngắn, bốn viên đạn), 4,812 tam giác; một material/atlas 256×256 được pack, texture nearest.
- Dài 1.058 m, rộng khoảng 0.1023 m tính cả giá đạn, cao 0.2402 m. Đây là tạo hình theo thị giác từ ảnh, không phải bản đo cơ khí.
- Blender +Y về trước / +Z lên trên; root/RightHandGrip ở 0 và nằm trong tay cầm thật. Sau khi dịch tay cầm, hình được đặt lại quanh điểm nắm mới; `authoring_origin` lưu hệ tọa độ dựng để tái tạo. Mười marker theo thư viện; LeftHandGuide đi theo tay bơm mới, vị trí marker được kiểm tra roundtrip GLB.
- `review/`: 3/4, hai bên, trên, trước và cận báng/tay cầm, thân/giá đạn, tay bơm, đầu nòng. Studio ngoài `WEAPON_EXPORT` không được nhập vào thư viện.
- `build_shotgun.py`: builder riêng. `render_details.py`: render từ nguồn đã lưu. `validate_asset.py`: mở lại nguồn/GLB, kiểm tra topology/UV/atlas, marker, kích thước/texture roundtrip, ba vị trí qua lỗ báng bậc, vòng cò, gốc tay cầm, hốc nòng/cửa bên, rãnh và kích thước tay bơm, chân thước ngắm.

Nguồn trước lượt này và ảnh so ngang nằm tại `.validation/shotgun_sand_block_reference_refinement_20261019/`; `before_source/` giữ nguyên mẫu trước, `first_refinement/` giữ bước trung gian, `sight_mount/` giữ bản trước chỉnh chân ngắm. Các baseline trước (`shotgun_sand_block_v1_20261019/`, `shotgun_sand_block_close_tubes_20261019/`) vẫn giữ nguyên. Chỉ swatch brass số 13 thay màu; các pixel cát/graphite/đỏ được đối chiếu giữ nguyên.

Chưa tạo animation hoặc tích hợp gameplay/Godot. Character Ready/Holster dùng snapshot có sẵn, chưa tinh chỉnh hỗ trợ tay trái cho mẫu mới. Không tự thêm hoặc commit Git.
