# GameAssetFactory · Image-to-3D PoC với Scout

## Kết luận

Hunyuan3D-2mv Turbo phù hợp để dựng khối ban đầu từ turnaround. Dùng Blender để dựng các lớp cần chuyển động độc lập, nhất là hood, khăn, tóc và áo choàng. Giữ xương và tay chân thẳng từ rig Showcase, rồi vẽ UV 64 × 64 bằng cụm pixel. Mesh sinh tự động giúp đọc chiều sâu và vị trí các lớp áo. Mắt, viền mũ, ranh giới thắt lưng và mép vải vẫn cần sửa trước khi dùng làm asset.

Mức cải thiện rõ nhất nằm ở hai mặt nghiêng. Góc 3/4 vẫn chưa vượt bản thủ công rõ rệt. Cả hai bản có màu vẫn khác concept ở kết cấu tóc, khối mũ và nếp choàng. Bản mô-đun còn giao nhau ở quần và choàng trong clip thử.

## Công cụ

| Công cụ | Kết quả trên máy |
|---|---|
| Create 3D Model | Skill Codex cài trong thư mục người dùng. Pin df175e38106687c6b872d0c88ca527d674ee5d2f. Validator nhận 29 mô-đun và 26 helper. Chạy đăng ký góc ảnh và so đường bao từ render thật. Giấy phép MIT, giữ LICENSE và UPSTREAM_LICENSE. |
| Blender Image-to-3D | Kiểm tra commit 9d6d85e173d9ca2838fd6d038f17cf1543d02591 (MIT). Chạy init và resume cho crop Scout. Runtime ghi SHA-256 và bước tiếp theo. Giữ checkout để tham khảo quy trình, không đăng ký skill trùng vai trò. |
| Blender MCP hiện có | Codex đọc phiên Blender 5.2.3 và danh sách scene, mesh, armature từ file PoC qua add-on. Tool background thiếu BLENDER_PATH trên server hiện tại. Phiên stdio có đường dẫn đúng đã được thử và timeout ở bước chạy Blender. Pipeline dùng Blender CLI cho render, export và kiểm tra animation. |
| BlendRelay | Pin febf506e4c5dc868b431579f20f5eca8bf95c692. Runtime MIT, extension GPL-3.0-or-later. 9 ca kiểm thử giao thức đạt, stdio liệt kê 24 tool. Add-on đòi Blender 4.5 trở lên. Phiên thử không bật extension hoặc tự khởi chạy bridge. Mã nguồn có API sửa scene, thực thi Python và khởi chạy bridge trên Windows, nên không đăng ký thêm khi MCP hiện có đủ chức năng. |
| Tripo | npm tripo-cli 0.11.2 được cài trong vendor với lifecycle scripts tắt. CLI MIT, Node 22. MCP local liệt kê 26 tool với analytics tắt và API trỏ loopback. Cấu hình tripo.disabled.toml để sẵn. Xác thực, gửi ảnh và sinh model chờ bạn cho phép. |
| Hunyuan3D-2 | Pin nguồn Tencent f8db63096c8282cb27354314d896feba5ba6ff8a. Hai checkpoint fp16 safetensors đối chiếu SHA-256 Hugging Face. PyTorch 2.10.0 + CUDA 12.8 trên Python 3.13.5. Shape generation thành công offline trên Windows. Lần smoke đầu tạm bỏ import PyMeshLab trong checkout riêng khi pip còn tải, sau đó phục hồi nguồn và chạy nhánh bốn góc với dependency đầy đủ. |

Hunyuan dùng Tencent Hunyuan 3D 2.0 Community License có giới hạn lãnh thổ, cách phân phối và cách dùng. PoC chạy ở Việt Nam. Trọng số và dữ liệu thử nghiệm được quản lý bên ngoài Git. Xem giấy phép gốc để xác định quyền phân phối hoặc sử dụng trong dịch vụ. Máy chỉ tải mã, gói và trọng số công khai. Ảnh Scout được xử lý local.

[Create 3D Model](https://github.com/CheshireJCat/create-3d-model-skill) · [Blender Image-to-3D](https://github.com/usedhonda/blender-image-to-3d) · [BlendRelay](https://github.com/shefq/blendrelay-mcp) · [Tripo MCP](https://developers.tripo3d.ai/en/mcp) · [Giấy phép Hunyuan3D-2](https://github.com/Tencent-Hunyuan/Hunyuan3D-2/blob/f8db63096c8282cb27354314d896feba5ba6ff8a/LICENSE)

## Kết quả Scout

IoU là phần đường bao giao nhau chia cho phần hợp. Căn theo chiều cao và tâm đế của từng ảnh. Số đo nhạy với góc camera và tư thế minh họa. Bản so sánh giữ ánh sáng của từng model và dùng alpha chỉ phủ nhân vật.

| Bản | Chính diện | 3/4 | Nghiêng phải | Sau | Nghiêng trái |
|---|---:|---:|---:|---:|---:|
| Bản dựng thủ công Rogue Archer | 90,6% | 86,5% | 83,7% | 91,4% | 82,7% |
| Hunyuan mini Turbo, ảnh hero | 71,1% | 87,4% | 67,8% | 71,8% | 67,0% |
| Hunyuan mv Turbo, bốn góc | 91,9% | 86,0% | 89,2% | 92,8% | 90,8% |
| Hunyuan mv qua Blender và màu thử | 91,9% | 85,9% | 89,2% | 92,8% | 90,8% |
| Blender mô-đun, UV 64 × 64 | 92,4% | 86,5% | 91,0% | 93,0% | 89,4% |

- **Một ảnh.** 10,45 giây sinh mesh sau khi load, 4,74 GiB CUDA reserved, 458.468 tam giác. Mặt khuất phía sau mũ bị suy ra thành búi tóc lớn và vải gồ ghề.
- **Bốn góc.** 11,69 giây sinh mesh sau khi load, 5,77 GiB CUDA reserved, 184.144 tam giác. Thể tích khăn, vai, túi và bốt đọc đúng ở nhiều góc hơn. Hai mắt cần tô lại. Tóc và vải vẫn liền thân.
- **Bản Blender từ Hunyuan.** Loại mảnh rời nhỏ, giảm còn 40.000 tam giác, thêm bốn UV 64 × 64 theo các góc concept để kiểm tra vị trí màu. Màu thử còn chuyển mặt cứng và giữ bóng của reference. GLB nhập lại được với 40.000 tam giác và bốn ảnh màu.
- **Bản Blender mô-đun.** Dựa trên Canonical Silhouette, chỉnh ba vòng về UV, màu mũ, lớp vải và độ hở choàng. Có 135 mesh gắn vào rig 13 xương và ba atlas 64 × 64 packed. Idle, Walk, Run và Jump được thử trên rig bản sao. Sai số độ cứng transform tay chân dưới 0,000001. BVH còn phát hiện giao nhau giữa quần và vạt choàng. Xem private/rig-audit-3.json.

## Chạy với concept mới

1. Cung cấp ảnh hero hoặc turnaround. Với ảnh gộp, Codex xác định vùng crop và đường bao để tạo JSON cùng dạng scout-views.json. Dùng prepare.py để tách nền theo đường bao và lưu các crop RGBA.
2. Chạy run-local.ps1 với tham số -Views trỏ tới thư mục các crop. Auto chọn bốn góc khi có front.png, right.png, back.png và left.png. Nếu chỉ có một ảnh, dùng hero.png.
3. Pipeline sinh mesh, render năm góc, giảm mesh và thêm màu thử cho bản bốn góc. Khi có cả ảnh hero, pipeline dựng ảnh so sánh và overlay. Dùng -ManualBaseline để thêm bản cũ vào phép so. Codex đọc kết quả để sửa các thể tích triển vọng, tách bộ phận, tạo UV riêng và kiểm tra animation.
4. Bản màu thử dùng để tìm lỗi đăng ký. Khi hoàn thiện asset, vẽ UV theo bộ phận và đánh giá mặt, chất liệu cùng silhouette qua các góc.

Dùng uv tạo .venv313 với Python 3.13. Cài torch 2.10.0 và torchvision 0.25.0 từ index https://download.pytorch.org/whl/cu128. Cài những package còn lại theo requirements-lock.txt. Checkout Hunyuan theo commit trên vào vendor/hunyuan. Chạy download_weights.py một lần để tải và xác thực hai checkpoint. resume_weights.py tiếp tục các file tải dở do downloader tạo và kiểm tra SHA-256 đầy đủ.

## File để duyệt

- private/comparison/Scout - PoC overview.png có front, hero và back. Scout - comparison.png và Scout - other views.png có toàn bộ các ứng viên. silhouette.json chứa số đo.
- private/tailoring-3/Scout pixel tailoring.blend có năm camera dạng timeline marker. Frame 2 dùng pose hero.
- private/multi-refined/Scout generated review.glb và bản Blender trong cùng thư mục.
- private/artifact-verification.json xác nhận cấu trúc, atlas và dữ liệu GLB nhập lại.
- SHA-256 Animation_Showcase.blend trước và sau thử nghiệm đều là 6DE4412AD8074CAB0EA46BD71493B736DE8D3A9A77C9675C5C45725CA7D442A6.

