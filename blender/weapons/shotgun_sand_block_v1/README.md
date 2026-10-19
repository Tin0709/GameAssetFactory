# Shotgun — Sand Block V1

Mẫu hiện tại vẫn **Pending** trong cùng `../showcase/Weapon_Showcase.blend`. Lượt chỉnh mới nhất dùng `reference_refined.png`, ảnh nhiều góc người dùng gửi sau khi nhận xét tỷ lệ chưa giống; `reference.png` giữ ảnh ban đầu. Không thay nguồn hoặc trạng thái duyệt của các khẩu khác.

Đã đối chiếu góc ngang ở cùng chiều dài, rồi dựng lại các phần lệch: báng có thanh trên dày hơn, đệm sau thấp/dày hơn và lỗ rỗng dạng bậc; cổ nối có các bậc thu gọn cùng nắp thân sau vát. Tay bơm đặt cao và tiến về trước, bề ngang giảm từ78 xuống66mm; thân liền có năm rãnh chìm khoảng2mm mỗi bên thay các gân nổi7mm trước đó. Thân tay bơm cao77mm, có mặt vát dưới rộng và gờ tan nhỏ ở đầu sau. Chiều dài được tăng nhẹ theo ảnh thay vì thu nhỏ đồng đều mọi chiều.

Tay cầm lùi50mm, ngắn hơn20%, vòng cò được thu gọn và đưa theo tay cầm; đế đen và hộp tiếp đạn ngắn được chỉnh tỷ lệ. Rail mảnh/thấp hơn, nắp thân sau và nút bên được đặt lại. Bốn viên đạn có đầu/brass tám cạnh vàng hơn; miệng hai ống dùng biên dạng tám cạnh thay lỗ gần vuông. Khoảng cách hai ống đã chỉnh ở lượt trước vẫn giữ:1.5mm tại vòng ôm và6mm ở đoạn trơn; vòng ôm/cổ tay bơm chuyển theo tay bơm mới. Hốc bên đầu nòng vẫn sâu thật.

- `Shotgun_Sand_Block_V1.blend` và `.glb`: bốn mesh cứng (thân, tay bơm, hộp tiếp đạn ngắn, bốn viên đạn),4,768 tam giác; một material/atlas256×256 được pack, texture nearest.
- Dài1.058m, rộng khoảng0.1023m tính cả giá đạn, cao0.2402m. Đây là tạo hình theo thị giác từ ảnh, không phải bản đo cơ khí.
- Blender+Y về trước/+Z lên trên; root/RightHandGrip ở0 và hiện nằm trong tay cầm thật. Hình được đặt lại quanh tay cầm sau khi dịch nó, `authoring_origin` lưu hệ tọa độ dựng để tái tạo. Mười marker theo thư viện; LeftHandGuide đi theo tay bơm mới, các vị trí được kiểm tra roundtripGLB.
- `review/`:3/4,hai bên,trên,trước và cận báng/tay cầm,thân/giá đạn,tay bơm,đầu nòng. Studio ngoài `WEAPON_EXPORT` không được nhập vào thư viện.
- `build_shotgun.py`: builder riêng. `render_details.py`: render từ nguồn đã lưu. `validate_asset.py`: mở lại nguồn/GLB, kiểm tra topology/UV/atlas, marker, kích thước và texture roundtrip, ba vị trí qua lỗ báng bậc, vòng cò, gốc tay cầm, hốc nòng/cửa bên, rãnh và kích thước tay bơm.

Nguồn trước lượt này và ảnh so ngang nằm tại `.validation/shotgun_sand_block_reference_refinement_20261019/`; `before_source/` giữ nguyên mẫu trước, `first_refinement/` giữ bước dựng trung gian. Các baseline trước (`shotgun_sand_block_v1_20261019/`, `shotgun_sand_block_close_tubes_20261019/`) vẫn giữ nguyên.

Chưa tạo animation hoặc tích hợp gameplay/Godot. Character Ready/Holster dùng snapshot có sẵn, chưa tinh chỉnh hỗ trợ tay trái cho mẫu mới. Không tự thêm hoặc commit Git.
