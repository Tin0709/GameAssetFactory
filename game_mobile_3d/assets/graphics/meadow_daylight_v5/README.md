# Meadow Daylight V5 — grounded block contact review

**Mốc dùng lại cho map Litematica mới — yêu cầu lưu ngày2026-10-09.**
Preset chuẩn: `res://assets/graphics/meadow_daylight_v5/preset.tres`.
Snapshot cố định: `exports/graphics/meadow_daylight_v5.zip`, kèm SHA256 và
`bundle_manifest.json`. Giữ V1 và V5; chỉnh look về sau tạo phiên bản mới.

## Công thức được lưu

Các file trong snapshot là nguồn thông số chính xác, gồm cả LUT và shader
defaults; không dựng lại look chỉ từ các con số tóm tắt này.

| Nhóm | Quy tắc hiện tại | Nguồn chính xác |
|---|---|---|
| Đèn và bóng đổ | Sun1.50, màu(1,.975,.925), góc(-50,-38,0); opacity.782, blur1.25, depth bias.12/normal bias1.2; atlas2048,32bit, PCFmedium | `preset.tres` |
| Fill/hậu kỳ | Ambient.32 màu(.56,.72,.84); exposure.96; LUTấm.05; bloom.04; haze20–60m,density.13,curve1.7 | `../meadow_daylight_v1/environment.tres` giữ cả LUT nhúng |
| Camera/renderer | Mobile, ortho14.5m, góc(-36.315886,36.869898,0), offset(12,15,16), far72, MSAA2× | `world_map.gd`, scene kế thừa và `project.godot` |
| Đất/cỏ/đá | Giữ texture/UV gốc, mipmap tuyến tính, giảm tương phản.38/.42; palette tuyến tính; noise cố định theo world; mép đường chỉ hòa ở cùng cao độ | `world_map_look.gd`, `world_map_surface_v5.gdshaderinc` |
| Tiếp xúc terrain | Lõi7.5cm; nền .28lõi+.12fill32cm, vách .22lõi+.10fill30cm; góc lõm45cm; tiếp xúc chéo liền, không viền nền phẳng/cạnh lồi | `world_map_surface_v5.gdshaderinc` |
| Cỏ/hoa và gốc | Chân cỏ lấy cùng trường màu/tiếp xúc nền, xanh dần lên ngọn; normals ngả lên; cỏ thấp cao.72× khi render; giữ bông vàng/hoa; footprint bóng gốc xuyên biên ô, đốm đất thưa strength.75 | `world_map_plants_v5.gdshader`, surface include |
| Gió/tương tác | Cỏ thấp/hoa gain2.0, cỏ cao/lá1.5;8đoạn passage, hồi.8s, lọc chênh tầng; giữ UV/UV2/COLOR gốc | `world_map_wind.gdshaderinc`, `grassland_motion.gd`, look driver |
| Bóng mây/fade | Shade field64² seed78126, gain.8–1, trôi(.48,.19); actor đồng bộ; nền đi được luôn opaque, chỉ fade phần vách cao; lá đi xuyên | clouds include, look/geometry driver, cutaway shader |

## Dùng cho map mới

1. Dùng chính bộ18GLB và hợp đồng import trong `assets/environment/world_map_v1/manifest.json`. Block1m; giữ các slab, tên vật liệu, màu tuyến tính, UV/UV2/COLOR và alpha MASK. Không export đè từ Blender để áp dụng look. Hoa periwinkle mới chỉ review Blender, chưa thuộc bộ18asset runtime này.
2. Đọc file `.litematic` mới thành dữ liệu riêng, output vào **thư mục map mới**; giữ nguyên tọa độ tương đối, block states, hướng slab và cặp tall-grass. Không ghi đè `assets/maps/world_map/runtime.json`. Xem hợp đồng map và `scripts/import_world_map.py`.
3. Importer hiện tại yêu cầu vòng RedWool100×100 và bảng block đã hỗ trợ. Map khác biên/kích thước/block cần adapter có kiểm tra rõ ràng; **preset đồ họa không tự giải quyết phần import này**. Không ép map mới thành bố cục WorldMap để dùng look.
4. Dựng geometry và collision từ dữ liệu map mới; cấp cho look driver `runtime`(source_bounds/offset/palette/cells), `geometry`, `player`, `view_mode` và các node `WorldEnvironment`, `Sun`, `Camera3D`. Driver tự dựng lại trường cao độ, viền đường, root-contact và cloud field; không tái dùng texture trường của map cũ.
5. `world_map_look.gd` và cutaway của `world_map_geometry.gd` phải cùng presetV5. Gắn driver sau khi geometry sẵn sàng và gọi `setup(level)`. Environment được duplicate lúc chạy. B giữ native A/B; V overview; H haze. Thay DATA/spawn/border của scene map riêng, không sửa main WorldMap để chuyển look.
6. Giữ camera/cỡ block khi đối chiếu ban đầu. Kiểm tra chân bậc/cạnh chéo/góc lõm, nền qua biên chunk, cỏ/hoa cùng màu nền, đi lên slab và vách fade. Bản snapshot là **bộ đồ họa + adapter để dùng trong project**, không phải một game/map độc lập có thể chạy sau khi giải nén.

Kiểm tra bằng `review_world_map_grounding_v5.gd`, `review_world_map_seams.gd`
và `validate_world_map.gd` sau khi adapter trỏ tới scene map cần kiểm tra.
Test tự động dùng `--audio-driver Dummy`; người dùng F5 giữ âm thanh bình thường.
Height field lấy mặt cao nhất từng cột, nên hang/overhang nhiều tầng cần review
riêng. Mục tiêu30FPS; chưa xác minh điện thoại. Yêu cầu lưu/reuse không tự là
duyệt mỹ thuật cuối cùng.

Current F5 WorldMap preset. V4's broad contact skirt is replaced with a
7.5cm core and weaker soft fill (ground32cm, wall30cm). Ground contact is
strongest directly at the supporting junction, recovers quickly, and still
wraps around sharp diagonal tips. Concave wall corners, flat seam protection
and matching opaque/cutaway shading remain.

V4 lighting, shadow bias, textures, palette, approved grass blend, sources,
terrain geometry/collision and all animation are preserved. This is a local
shading revision awaiting human review; phone performance is unverified.

[Reuse contract](../meadow_daylight_v1/README.md).
[Parameters and GPU evidence](../../../../docs/graphics/RESEARCH.md#worldmap--map-litematica-và-lượt-review-hiện-tại).
