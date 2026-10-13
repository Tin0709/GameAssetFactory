# Actions & Stuff — hồ sơ bằng chứng 2026-10-14

**Research only; chờ review.** Đọc [báo cáo chính](../../ACTIONS_AND_STUFF_PLAYER_DEEP_RESEARCH.md) để xem kết luận, giới hạn và ba thí nghiệm đề xuất. Không có Action/rig/gameplay mới trong đợt này. Thư mục này lưu bằng chứng phân tích, không phải asset sản xuất hoặc keyframe trích xuất.

## Đọc theo nhu cầu

| Câu hỏi | Hồ sơ |
|---|---|
| Oreville công bố gì, nguồn nào đã đọc? | [PUBLIC_SOURCES](PUBLIC_SOURCES.md), [source register](source_register_public.json) |
| Kỹ thuật tương đương nào khả thi? | [TECHNICAL_STRATEGIES](TECHNICAL_STRATEGIES.md), [technical register](source_register_technical.json) |
| Hiện project có gì, controller nào chạy ở F5? | [LOCAL_AUDIT](LOCAL_AUDIT.md), [hash ledger](local_evidence.json), [comparison media ledger](compare_decode.json) |
| Hai video mới bổ sung điều gì? | [045502 — chuyển động/đổi hướng/tay trống](SHOWCASE_SUPPLEMENT.md), [043804 — cầm đuốc và đổi hình bước](SUPPLEMENT2.md) |
| Đâu là dữ liệu đo, đâu là giới hạn? | [cycles](cycles.json), [frame observations](frame_observations.csv), [measurement limits](measurement_limits.json), [statistics](proxy_statistics.json) |

## Atlas Walk/Run gốc

Nguồn [walking.mp4](C:/Users/ADMIN/Desktop/walking.mp4) và [Running.mp4](C:/Users/ADMIN/Desktop/Running.mp4); [metadata/hash](source_media.json). Cả hai ghi 30 FPS; pack version/settings và tốc độ playback gốc chưa xác minh. Frame nguồn tính từ **0**, timestamp = frame/30. Pha = 100 × (frame − start)/(closing − start). Frame đóng chu kỳ được đưa vào bảng để so pose; không có video loop mới chèn lặp endpoint.

| Đoạn | Ba chu kỳ liên tiếp | Context phía sau |
|---|---|---|
| Walk | [F30–50](walk_cycle_1_F30_50.jpg), [F50–70](walk_cycle_2_F50_70.jpg), [F70–90](walk_cycle_3_F70_90.jpg) | [F160–199](walk_rear_context_F160_199.jpg) |
| Run | [F40–57](run_cycle_1_F40_57.jpg), [F57–74](run_cycle_2_F57_74.jpg), [F74–91](run_cycle_3_F74_91.jpg) | [F160–199](run_rear_context_F160_199.jpg) |

![Các họ tư thế theo pha](reference_timeline.png)

117 hàng quan sát = 63 Walk + 54 Run, có các endpoint dùng chung giữa chu kỳ. Đây không phải 117 frame nguồn khác nhau. Contact là ứng viên độ tin cậy thấp; screen-left/right là chính, anatomical side còn phụ thuộc video có mirror hay không. Support/flight vật lý, hip height và bone angles để unknown khi không quan sát được.

- [Walk body curves](walk_screen_proxy_curves.png) / [Run body curves](run_screen_proxy_curves.png): cap/shirt pixel proxy; raw và optical-flow-corrected tách riêng.
- [Walk limb diagnostics](walk_limb_proxies.png) / [Run limb diagnostics](run_limb_proxies.png): item/hem/shoe segmentation, không phải bone tracking. Shoe traces bị loại khỏi suy luận contact/path/velocity vì merge và occlusion.
- [Screen data JSON](screen_proxies.json), [Walk CSV](walk_screen_proxies.csv), [Run CSV](run_screen_proxies.csv), [observations JSON](frame_observations.json).

Ba draft sheet dùng Run F37–53/F53–69/F69–85 đã bỏ khỏi thư mục hiện hành sau khi kiểm tra lại cho thấy recurrence khoảng 17 frame ở đoạn F40–91. Bản sửa không tuyên bố Run của pack luôn có period 17 frame. Camera correction cũng không phải camera solve; dữ liệu drift được giữ để người đọc biết vì sao không đổi pixel sang mm.

## Media khác và phạm vi xem

`compare_*.jpg`: 12 sheet so Approved Walk, V027, V028, OneStep v001/v002; decode 652 frame từ 10 video đã tồn tại, xem 268 panel ở 134 thời điểm front/side. Đọc ledger để biết cycle length/speed khác nhau. Báo cáo kiểm tra hình học cũ là lịch sử, không phải các suite vừa chạy lại.

`showcase_*`: video 045502 có 638 frame; xem liên tiếp 518 frame cùng index toàn clip mỗi 6 frame. Hai khoảng F360–419/F480–539 chỉ được lấy mẫu, không tuyên bố xem từng frame ở đó. [Timeline riêng](showcase_timeline.csv).

`supplement2_*`: video 043804 có 193 frame, đã xem toàn bộ; player F0–178, villager từ F179. File khác nguồn Walk 241-frame cũ theo SHA256. Cả hai supplement giữ skin/camera/state riêng; không ghép với Walk/Run gốc để tính một chu kỳ.

Không phân tích audio, không thử điều khiển, không suy FPS mobile từ video. Những con số 30 FPS ở đây là metadata recording; mục tiêu 30 FPS của game cần kiểm tra thiết bị riêng.

## Tái tạo và tiếp tục

`build_atlas.py` tạo decode/proxies/sheets, `annotate_atlas.py` thêm nhãn quan sát và timeline. `showcase_decode.py`, `showcase_sheets.py`, `supplement2_decode.py` tạo media phụ. Dùng Python với OpenCV, Pillow, NumPy, Matplotlib; đường dẫn nguồn được ghi trong script/manifest. Các script chỉ xuất analytical media vào thư mục nghiên cứu này; nhãn thị giác vẫn cần người xem xác nhận, không phải output của contact detector.

Trước khi tái tạo, so hash nguồn và lưu phiên bản evidence hiện hành. Đọc phần giới hạn trước khi dùng centroid/nhãn trong phép đo mới. Đừng lặp toàn bộ nghiên cứu khi chỉ bổ sung một nguồn: thêm provenance, đoạn đã xem, kết luận thay đổi và điều còn unknown.

Người dùng yêu cầu **duyệt findings và chiến lược trước khi triển khai A/B/C**. OneStep v002 và các thử nghiệm Snappy vẫn Pending; approved assets giữ trạng thái cũ.

## Kiểm tra và Git

[verify_research.py](verify_research.py) / [kết quả](verification.json) kiểm tra JSON/CSV, phase/timestamp, ảnh, đích liên kết, SHA256 của bốn video và 25 source đã audit, cùng phạm vi diff. Đây là kiểm tra tính toàn vẹn tài liệu, không phải chạy lại geometry suite, gameplay hay đánh giá nghệ thuật. Một lượt đọc độc lập cũng rà đủ 16 mục yêu cầu; đã sửa cách diễn đạt nhân quả và phạm vi số đo centroid.

Workspace hiện ở `main`, một worktree `C:/Users/ADMIN/Desktop/GameAssetFactory`; tài liệu nằm ngay nhánh làm việc chính nên không cần merge/cherry-pick. HEAD đã tiến do commit từ bên ngoài tác vụ trong khi nghiên cứu; không có lệnh commit/reset/merge do tác vụ này thực hiện. Trước khi lưu commit tiếp theo, xem diff hiện hành và chỉ chọn `AGENTS.md`, báo cáo chính cùng thư mục bằng chứng này. Không cần chuyển các animation Pending vào production để dùng tài liệu nghiên cứu.
