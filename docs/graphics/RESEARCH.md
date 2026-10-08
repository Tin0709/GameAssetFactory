# Nghiên cứu đồ hoạ và bằng chứng thực nghiệm

2026-10-09 · Asia/Saigon. Mục tiêu **30 FPS (33.3 ms/frame)** do người dùng xác nhận; chưa chỉ định điện thoại tối thiểu. Hướng đã chấp nhận và đề xuất nằm riêng trong [ART_DIRECTION.md](ART_DIRECTION.md). Kết quả mỹ thuật của cảnh mới **chờ người dùng đánh giá**.

## Hiện trạng đã kiểm tra

Repo chứa cả nguồn asset (`blender`, `exports`) và game. `game` là prototype 2D, `godot_test` là test asset; đích hiện tại là `game_mobile_3d`. `project.godot` chọn **Grassland_50x50.tscn**, renderer **Mobile**. Đã chạy executable xác nhận **Godot 4.7.2 stable / D3D12 / RTX 4070 Ti SUPER** và **Blender 5.2.2 LTS**. Các tài liệu cũ mô tả `Grassland.tscn` hoặc `CuboidGameplayTest.tscn` làm scene mặc định không còn phản ánh cấu hình này.

| Thành phần | Sự thật trong tài nguyên/code hiện tại |
|---|---|
| Camera | Orthographic 14.5, far 60, offset (12,15,16) theo player; canvas 1280×720. Canvas-items không tự cố định độ phân giải render trên màn hình điện thoại. |
| Player | `CuboidPlayer.tscn` → `player_combat_strafe_r15.gd` + `r15/player_r15_combat_strafe_v1.glb`; 96 tam giác, 11 joints, 36 clip. Vật liệu nonmetal roughness .54. Giữ tay đầy đủ; không có chuỗi bone bàn tay/cẳng tay riêng trong rig runtime. |
| Zombie | `CuboidZombie.tscn` → `zombie_animation_secondary.gd` + `zombie_animation_v2.glb`; 72 tam giác, 10 joints; roughness .59. Attack hiện là procedural lunge, chưa có pose attack tác giả đầy đủ. |
| Môi trường | 50×50, 25 terrain chunks; 695 grass patches, 56 rocks, 312 flower clumps, 48 dirt props ở seed 8055. Manifest scatter có 18 mẫu, chưa tìm thấy asset cây. V4 có 36 lá cỏ chữ nhật/216 tam giác mỗi patch. |
| Ánh sáng | `setup_presentation` ghi đè Gameplay.tres bằng bản sao: sun 1.10, ambient .52, Linear; sương tắt. Không kết luận từ `.tres` dùng chung vì script có override. |
| Công cụ | Godot console/headless/GPU và viewport PNG/Movie Maker đã chạy. Blender MCP kết nối được; scene đang trống chưa lưu, không đụng scene của người dùng. Blender background chỉ dùng mã hoá clip Godot, không phải bằng chứng render asset bằng Blender trong lượt này. |
| Điện thoại | ADB trong sandbox không khởi động; kiểm tra ngoài sandbox thành công nhưng **danh sách thiết bị rỗng**. Chưa có export_presets.cfg; thư mục export_templates dự án rỗng. Chưa build/chạy Android hoặc iOS; máy Windows không có môi trường Xcode để xác thực iOS. |

Pipeline hiện tại: `.blend` tác giả → script export GLB/manifest/hash → `.glb.import` và post-import adapter → PackedScene/Skeleton → các lớp animation runtime. Đổi trục Blender Z-up sang glTF/Godot Y-up một lần. R15 giữ rest rig R13, lọc lower tracks, phối upper carry/recoil. Đừng sửa trực tiếp cache `.godot` hay ghi đè nguồn đã chọn. Xem [R15 integration](../superpowers/plans/2026-10-08-combat-strafe-game-review.md), [V4](../GRASSLAND_V4.md), [scatter source](../../blender/environment/studies/environment_scatter_set_v1/README.md).

## Nhóm tham chiếu nhỏ đã trực tiếp xem

**U1 — tham chiếu chính do người dùng gửi sau lượt thử đầu:** [ảnh gốc](references/user-dungeons2-2026-10-09.png), ngày 2026-10-09; người dùng nói “mình rất thích kiểu đồ họa này”. Xác nhận sở thích tổng thể, chưa phê duyệt kết quả scene của ta. Ảnh có badge ESRB, không HUD, camera thấp; chưa có URL/timestamp gốc để xác định gameplay/cinematic. Không dùng để suy camera gameplay hoặc công nghệ Dungeons II.

| Quan sát U1 | Suy luận/cách thử tiếp · chưa kiểm chứng |
|---|---|
| Tán tối che góc trên trái; kiến trúc đá bên phải; trung cảnh mở và nền xa sáng | Tạo lớp và dẫn mắt bằng khối lớn; chuyển bố cục sang camera chéo hiện tại, kiểm tra che actor khi di chuyển. |
| Thảm cỏ thấp dày, vài cụm lá cao; hoa hồng/tím là điểm nhỏ; bề mặt khối có biến thiên pixel | Độ phong phú đến từ nhiều cỡ hình khối và phân cụm, không chỉ số lá. Thử một cụm cây–cỏ tác giả thay proxy, giữ vùng chiến đấu ít nhiễu. |
| Mặt lá/cạnh khối nhận ánh sáng vàng; bóng xanh tối; lớp xa ít tương phản | Cần phân tách key/fill và contact tốt hơn QualitySlice. Có thể thử bake/probe trên khu cố định; hình không chứng minh GI, fog, translucency hay soft-shadow cụ thể. Sương vẫn hoãn theo quyết định trước. |

QualitySlice hiện có được dựng **trước khi nhận U1**: mới thử bố cục, light và AA, chưa phải bản tái hiện ảnh. Khoảng cách nổi bật so U1 là tán/cỏ còn thô và đều, thiếu tầng cao thấp, contact/shadow chưa mềm sạch, thiếu chiều sâu nền xa. Ưu tiên chuyển các điểm này thành lượt asset/lighting nhỏ; không đổi cả renderer hoặc camera vì ảnh mới.

[Gallery chính thức Dungeons II](https://www.minecraft.net/en-us/about-dungeons-ii) được mở trong browser; ba ảnh dưới là ảnh **in-engine dùng quảng bá, không HUD**. Không gọi chúng là capture phiên chơi đã xác thực. Phân tích camera dùng góc nhìn của từng ảnh, không suy thành camera gameplay cố định.

| ID / nguồn cụ thể | Quan sát trực tiếp | Ước lượng/suy luận và cách dùng |
|---|---|---|
| R1 [Cổng rừng, ảnh 05](https://www.minecraft.net/content/dam/minecraftnet/games/spicewood/key-art/Dungeons-II_Lightbox-A_05_1920xx1080.jpg) | Lối đi sáng, khối tường/tán xanh đậm hai bên, mảng cỏ cam, nguồn sáng xanh thành điểm. Nhân vật tách khỏi chi tiết quanh rìa. | Silhouette người khoảng 8–12% chiều cao ảnh, chỉ ước lượng. Chọn làm tham chiếu bố cục/lane; không đo pitch/FOV từ ảnh này. |
| R2 [Portal, ảnh 09](https://www.minecraft.net/content/dam/minecraftnet/games/spicewood/key-art/Dungeons-II_Lightbox-A_09_1920x1080.jpg) | Bậc cao thấp, mặt vách và nền xa tạo chiều sâu; cyan portal mạnh, đá hồng/cây lạnh. | Góc có tính trình diễn, không dùng làm chuẩn zoom chơi. Bài học: chiều sâu từ hình khối và phân lớp trước khi đòi hỏi fog/GI. |
| R3 [Combat đông, ảnh 02](https://www.minecraft.net/content/dam/minecraftnet/games/spicewood/key-art/Dungeons-II_Lightbox-A_02_1920xx1080.jpg) | Nền xanh tím tối, các burst cam/vàng và tia cyan chiếm nhiều vùng chiến đấu. | Hữu ích để nghiên cứu tương phản VFX, đồng thời cho thấy frame cao trào có thể che actor. Không sao chép mật độ hiệu ứng sang mobile. |

[Official Gameplay Trailer](https://www.youtube.com/watch?v=vBNE3bKMpu8), được [Mojang liên kết](https://www.minecraft.net/en-us/article/minecraft-dungeons-ii-gameplay-trailer): đã phát/quan sát khung khoảng **0:28 và 0:37**, có địch, damage numbers và hiệu ứng trong gameplay, kèm chữ quảng bá của trailer. Đây là dựng phim gameplay, không phải benchmark hay clip chơi liên tục; chưa phân tích frame-by-frame toàn video. Tách nó khỏi key art hình đội nhân vật/logo và cảnh cinematic.

Chưa có bằng chứng công khai đã đọc để xác nhận shader, GI, thuật toán sương, budget render hay pipeline nội bộ của **Dungeons II**. Nội dung về **Dungeons I** dưới đây chỉ là bài học thiết kế từ bản đầu.

## Nguồn → bài học → áp dụng → phép thử

Các nguồn Godot dưới đây đã đọc bản **4.7**. Blender manual **5.2 LTS** đã đọc qua browser (web crawler lỗi, đường dẫn mới nằm ở `addons/scene_gltf2.html`).

| Nguồn đã đọc | Bài học và quyết định thử trong dự án | Kiểm chứng / phương án thấp hơn |
|---|---|---|
| [Dungeons I: Back to the Nether](https://www.minecraft.net/sv-se/article/back-nether), art director Daniel Björkefors và level designer Laura de Llorens, 2021 | Góc nhìn từ trên xuống đòi hỏi props/texture được thiết kế cho góc đó; nghiên cứu địa hình, chọn palette và hình khối đặc trưng theo biome trước khi hoàn thiện. Đây là chia sẻ về **bản đầu**, không là chứng cứ pipeline phần II. | Áp dụng: dựng các khối cây/đá ở camera gameplay trước, rồi tác giả hoá một asset đại diện và so cùng môi trường. Cây proxy đã thử; asset cây hoàn thiện chưa làm. |
| [Blender 5.2 glTF](https://docs.blender.org/manual/en/5.2/addons/scene_gltf2.html) | Export nhận các node/material hỗ trợ, không chuyển cả cách render Blender. Flat normals/UV seams tách vertex; Area/World lighting không theo GLB. Dùng Principled + texture chuẩn, roughness/metal/normal Non-Color; xây light lại trong Godot. | So GLB với source dưới lighting trung tính, kiểm tra normals, UV, clip, rig, sRGB và scale. Giảm shader custom nếu không ánh xạ ổn định. |
| [Godot renderer matrix 4.7](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html) | Mobile có LightmapGI, MSAA, glow, fog thường; thiếu SSAO/SSIL/SDFGI/volumetric fog/TAA. Không đưa các hiệu ứng thiếu vào kế hoạch hiện tại. | Bật từng tính năng trong bản thử và đo trên máy đích; fallback sun + ambient + màu/contact có chủ đích. |
| [LightmapGI](https://docs.godotengine.org/en/4.7/tutorials/3d/global_illumination/using_lightmap_gi.html) | Terrain tĩnh cần UV2 không chồng; probe cho actor nhận indirect baked. Chuyển động vẫn cần direct light/shadow phù hợp. | Bake một khu cố định, kiểm tra seam/contact/actor đi qua vùng probe và memory. Nếu map chỉnh lúc chơi, không dùng bake cố định cho phần thay đổi. **Chưa thử bake.** |
| [Light3D](https://docs.godotengine.org/en/4.7/classes/class_light3d.html) | Bias là cân bằng acne với bóng rời chân. PCSS directional thuộc Forward+, không dùng light_angular_distance để hứa bóng mềm Mobile. | Probe thật tắt shadow/bias giữ cùng scene; xem cả cây và chân người. **Đã thử bias**, vẫn còn alias ở cạnh bóng. |
| [3D AA](https://docs.godotengine.org/en/4.7/tutorials/3d/3d_antialiasing.html) | MSAA xử lý cạnh hình học; không chữa mọi shimmer texture/alpha-cutout. | **Đã so 0×/2×** trên desktop; thử pan và alpha-to-coverage riêng nếu cần. Fallback tắt AA/giảm render scale sau đo thiết bị. |
| [Environment/post-processing 4.7](https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html) | Linear nhanh nhưng clip highlight; tonemap khác thay tương phản/saturation. Glow lan vùng sáng, không tự tạo chiếu sáng lên vật khác. SSR không có trên Mobile. | Giữ Linear trong lượt này để cô lập light. Sau này so một điểm emissive dưới Linear/Filmic, glow bật/tắt và chi phí GPU; fallback emissive không glow. Phản sáng nhẹ thử sky/probe riêng, tránh cập nhật reflection động toàn cảnh. Fog thường có thể phân lớp xa nhưng đang hoãn; hiện dùng hình khối/value. **Chưa thử các thay đổi này.** |
| [BaseMaterial3D](https://docs.godotengine.org/en/4.7/classes/class_basematerial3d.html), [standard materials](https://docs.godotengine.org/en/4.7/tutorials/3d/standard_material_3d.html) | Pixel texture không buộc phải bỏ mipmaps; atlas cần padding. Opaque/scissor tránh một phần vấn đề blended overlap; vẫn có chi phí fragment/two-sided. | Dùng nearest+mipmap trên bản sao, kiểm tra bleeding và wind shimmer ở gameplay zoom. Chưa thay atlas/filtering trong lượt này. |
| [MultiMesh](https://docs.godotengine.org/en/4.7/classes/class_multimesh.html), [3D optimization](https://docs.godotengine.org/en/4.7/tutorials/performance/optimizing_3d_performance.html) | Batch có culling chung, không gom toàn map thành một đối tượng. Số object/triangle không bằng draw cost; Mobile cần MultiMesh chủ động. | Giữ chunk hiện có; kiểm tra bounds lúc gió, draw/primitives và overdraw khi đông quái. Ưu tiên giảm trang trí/caster xa trước khi đụng silhouette người. |
| [Wolfire: physics-based animation](https://www.wolfire.com/blog/2005/08/physics-based-animation/), [Riot: skeletal animation](https://www.riotgames.com/en/news/compressing-skeletal-animation-data) | Trọng lượng gắn với trọng tâm và chân đỡ; sai số bone tổ tiên có thể thành trượt chân. Áp dụng là suy luận cho rig khối hộp của ta, không sao chép hệ thống họ. | Đo sole/corner world space sau mọi layer, đồng bộ nhịp với actual velocity và phase chân đỡ. **Chưa đo trượt chân runtime mới.** |
| [GDC: In Your Hands, Ubisoft](https://media.gdcvault.com/gdc2015/presentations/Therriault_David_InYourHands.pdf) | Tách cơ chế súng, recoil vũ khí, thân và camera giúp điều khiển nhịp. Giữ một nơi ghi mỗi bone/socket trong runtime hiện tại. | Clip ba phát bắn–hồi, xem súng/vai/thân cùng frame sát thương. Không thêm camera shake mặc định vào camera mobile cố định. |
| [Android AGI](https://developer.android.com/agi/frame-trace/frame-profiler), [Thermal API](https://developer.android.com/games/optimize/adpf/thermal) | Tối ưu pass đo được; thiết bị nóng có thể đổi budget. Khả năng đọc thermal khác giữa máy, không suy “mát” từ dữ liệu thiếu. | Máy thật: khung thường/đông quái, A/B shadow/VFX/resolution, chạy 15–20 phút. Godot timings là fallback nếu AGI không hỗ trợ. **Chưa kiểm chứng trên thiết bị.** |

Đối với iOS, cần Mac/Xcode và Metal profiling trên thiết bị; [Apple performance entry](https://developer.apple.com/documentation/xcode/analyzing-the-performance-of-your-metal-app) được xác định nhưng công cụ web chỉ trả trang yêu cầu JavaScript, chưa đọc hướng dẫn chi tiết. Không ghi đây là phương pháp đã thực hành.

## Khoảng cách quan trọng nhất

| Ưu tiên | Bằng chứng/khoảng cách | Ảnh hưởng · công sức · chi phí dự kiến |
|---|---|---|
| 1 | Baseline có lane nhưng gần như một lớp đất cỏ; hoa nhỏ nhiều, thiếu tán cây/khối cao thấp và vùng yên cho mắt | Rất lớn · vừa · có thể tăng caster/draw, có thể giảm trang trí nhỏ. Cảnh thử giải quyết một phần. |
| 2 | Chuyển Walk/strafe/backward dùng chu kỳ khác nhau; clip trung gian authored không tự được giữ bởi crossfade runtime | Rất lớn khi chơi · vừa/cao · đo rồi sửa phase/contact trước khi tăng bone hay hiệu ứng. |
| 3 | Fill khá đều; contact trên props mới và biên bóng chưa sạch; zombie xanh dễ hoà nền cỏ | Lớn · vừa · sun/fill và material đơn giản trước; bake là thử sau. |
| 4 | Cỏ/hoa/atlas chi tiết nhỏ có shimmer; cây proxy chưa đạt ngôn ngữ texture V3 | Vừa/lớn · vừa · mip/padding và giảm micro-detail có lợi; không thêm texture lớn vô điều kiện. |
| 5 | Chưa có dữ liệu máy Android/iOS tối thiểu hoặc nhiệt dài hạn | Chặn chốt budget · cần thiết bị · chưa thể quyết cấu hình mobile cuối. |

R14 Pass2 từng báo near-floor excursion lớn ở transition preview; đó **không phải số đo R15 đang chạy**. Walk/Sprint hiện 4.25/6.25 m/s; reference gait có rate gần cố định khi đang di chuyển. Trong nhánh reference, `_evaluate_locomotion_pose` return sớm nên tuning spring legacy không chắc tác động gait hiện tại. Ưu tiên clip và đo pose cuối, không dựa vào việc có code “spring”.

## Map Litematica: đã có nền tảng tốt, chưa cần đổi kiến trúc

`litematic_m2_map.gd` nạp JSON và dựng map một lần trong `_ready`; chưa thấy API sửa block lúc chơi. Như vậy **hiện tại map cố định, dù mesh dựng lúc chạy**. Đã có chunk 10×10, loại mặt bị block solid che kể cả qua biên chunk, collision tĩnh, vertex-color corner occlusion và MultiMesh cây cỏ. Giữ block IDs/toạ độ nguồn tách khỏi mesh tối ưu; validation cần đối chiếu occupancy, exposed-face count, rìa chunk và collision với schematic.

M2 script tự đặt shadow 2048/medium và MSAA2×, khác cấu hình global 1024. Đừng trộn budget M2 với Grassland. Muốn bake cần xuất/cache mesh tĩnh trước bake và tạo UV2 terrain; **UV2 cỏ đang là root coordinates cho gió**, không unwrap toàn bộ. Nếu sau này phá/xây block, chỉ rebuild chunk bị đổi cùng biên láng giềng và chọn lại giải pháp lighting; đây là đề xuất tương lai, chưa triển khai.

## Thử nghiệm có thể tái hiện: QualitySlice

Scene [QualitySlice.tscn](../../game_mobile_3d/scenes/QualitySlice.tscn) kế thừa scene đang chơi. Không sửa scene mặc định, source Blender, shader cỏ/terrain, actor, weapon hay animation production. Nền 50×50 giữ nguyên để tái sử dụng hệ thống; phần mỹ thuật thử chỉ quanh một giao lộ nhỏ. Rock mới dùng `scatter_material` hiện có (18 palette PNG trùng SHA-256); đã phục hồi thay đổi auto-import texture ngoài ý muốn, không đổi compression asset production.

| Bước | Thay đổi so bước trước |
|---|---|
| F1 / stage 0 | Baseline hiện tại; props mới ẩn/collision tắt, mật độ hoa gốc, light/AA gốc. |
| F2 / stage 1 | Bốn cây proxy nguyên bản opaque (84 tam giác/cây), bốn instance rock GLB có sẵn, giảm visible flowers còn ceil(25%) mỗi batch. Bias .10/normal1.5 cho các mặt caster lớn. |
| F4 / stage 2 | Ambient .52→.34, màu (.53,.69,.78); sun 1.12, (1,.92,.79), shadow opacity .86. |
| F5 / stage 3 | MSAA2×; các phần khác giữ stage2. Tab so stage0↔3; F3 bị vô hiệu trong study để tránh làm sai baseline. |

WASD/Shift di chuyển; 1/2/3 chọn súng, 0 cất; T/K thêm 1/5 zombie; R về giữa. Launcher [launch_quality_slice.ps1](../../scripts/launch_quality_slice.ps1) mở **có âm thanh** cho người dùng. Test tự động dùng Dummy audio và mute trong process test; không thay bus/project/system audio lâu dài.

Bằng chứng bền trong repo: [so sánh](../validation/quality_slice/comparison.jpg), [stage0](../validation/quality_slice/stage_0.png), [stage1](../validation/quality_slice/stage_1.png), [stage2](../validation/quality_slice/stage_2.png), [stage3](../validation/quality_slice/stage_3.png), [clip Godot 9.1 s](../validation/quality_slice/gameplay.mp4), [12 khung và cận cảnh](../validation/quality_slice/motion_contact_sheet.jpg), [metadata capture](../validation/quality_slice/captures.json), [metadata clip](../validation/quality_slice/movie.json). Clip H.264 không tiếng; AVI gốc/các lượt thử ở `.validation/quality_slice` trong game, bị Git ignore.

Đã tự xem PNG cả bốn bước và 12 khung clip: giảm hoa làm vùng giữa ít nhiễu; tán tối và bóng bổ sung lớp không gian; nhân vật vẫn đọc được. Lượt đầu cây nhạt/vệt bóng và cây nằm trên lane không được giữ làm bản tốt nhất. Probe tắt shadow loại vệt; tăng bias giảm acne; chuyển vertex-color sRGB sửa cây bị nhạt. **Còn hạn chế:** cây thô chưa texture, bóng răng cưa/viền hở ở vài chỗ, nền phẳng, zombie còn lẫn cỏ; MSAA2× không giải quyết toàn bộ. Không tuyên bố đã đạt mức Dungeons II.

Clip ghi từ production controller/combat, có hai kill, peak 7 effect nodes và 2 projectile nodes. Đã kiểm tra các khung mẫu, không dùng việc tạo file/console sạch để kết luận motion tự nhiên; chưa phân tích liên tục từng frame hay đo contact foot. Chưa sửa gait/attack/VFX trong lượt này.

## Đo hiệu năng và giới hạn bằng chứng

Kết quả mới nhất nằm trong `docs/validation/quality_slice/profile_stage_{0,2,3}.json`. Mỗi stage chạy process riêng nối tiếp, Mobile/D3D12, RTX 4070 Ti SUPER, 1280×720, VSync tắt; warmup 3 s, idle 5 s; warmup combat 3 s, combat 8 s. Fixture 12 zombie HP cao giữ tải ổn định, súng/effect/attack thật; không phải khuyến cáo số quái cho điện thoại. Không Movie Maker/readback hoặc phiên capture khác trong cửa sổ đo. Audio dùng Dummy, không đại diện chi phí đầu ra âm thanh của máy thật.

Số median của lượt cuối, theo thứ tự **idle / combat 12 zombie**:

| Stage | Draw calls | Primitives | Render CPU ms | Render GPU ms | Video memory MiB |
|---|---:|---:|---:|---:|---:|
| 0 baseline | 110 / 137 | 145044 / 146794 | .074 / .094 | .107 / .154 | 92.47 / 98.34 |
| 2 bố cục + light | 121 / 147 | 142904 / 144646 | .077 / .092 | .103 / .153 | 92.47 / 98.34 |
| 3 thêm MSAA2× | 121 / 147 | 142904 / 144646 | .078 / .095 | .100 / .129 | 112.72 / 118.59 |

Tăng 11/10 draw với props; giảm primitive nhờ bớt hoa. MSAA tăng bộ đếm video memory khoảng **20.25 MiB** ở viewport này. GPU sub-ms dao động giữa lượt: **không kết luận MSAA làm nhanh hơn** từ chênh lệch nhỏ. Stage3 wall-clock combat median .713 ms, p95 1.132 ms, max 15.745 ms (stage0 max 2.226 ms); chưa truy được nguyên nhân spike. Static allocator trước lấy mẫu khoảng 76.9 MiB idle/80.4 MiB combat, không phải tổng RAM tiến trình. Số đo ngắn này không chứng minh không có leak hay stutter dài hạn.

Frame interval đo theo wall clock từng frame, có scheduler/harness; viewport render CPU/GPU lấy từ Godot, không phải profiler phần cứng toàn thiết bị. Memory static lấy **trước** cấp phát buffer mẫu; không dùng độ tăng của buffer làm bằng chứng leak/game memory. Video memory là bộ đếm renderer, không phải Android RAM/iOS resident footprint. Baseline stage0 vẫn giữ tài nguyên props ẩn cho A/B, nên không dùng chênh lệch memory đó để suy chi phí asset thật.

Không suy desktop sub-ms thành cam kết 30 FPS điện thoại. Chưa đo CPU/GPU máy thật, nhiệt/battery, tải dài, notch/touch hay Android/iOS export. Cấu hình AA/render-scale/texture compression và mức quái phải chốt sau khi có máy tối thiểu.

## Kiểm tra và cách chạy lại

`validate_quality_slice.gd`: phục hồi A/B, không fog/bóng cỏ, không sửa Environment dùng chung, camera/player giữ nguyên, đi trên sàn và súng thật gây damage; đã bắt được lỗi F3 làm sai baseline trước khi sửa. Đã chạy headless và GPU Mobile. Các kiểm tra nền `validate_grassland_e2.gd`, `validate_grassland_motion.gd` và baseline `review_grassland_e2.gd` cũng được chạy; xem `checks.json` ở thư mục evidence để biết kết quả cuối. Không tuyên bố toàn bộ các suite lịch sử đều pass.

Từ repo root, dùng executable Godot 4.7.2 đã cài, `--path game_mobile_3d --audio-driver Dummy --rendering-method mobile --rendering-driver d3d12 --script res://tests/review_quality_slice.gd`. Không tham số: bốn ảnh cùng camera/pose/gió frozen; `-- --profile --stage=3`: profile real time; `--fixed-fps 30 --write-movie <absolute.avi> ... -- --clip`: clip offline, **không dùng để đo hiệu năng**. `package_quality_review.py` chạy bằng Blender background để encode video và lấy khung mẫu; không render lại asset/game bằng Blender.

## Trạng thái Git và tiếp tục

Kiểm tra 2026-10-09: branch **main**, HEAD ban đầu `faa319de9d7ff1d847679a68160946c0d442aed1`; `.git` bằng common dir, chỉ một checkout/worktree. Thay đổi nằm ngay working tree của main, chưa commit/push; không cần merge/cherry-pick từ worktree khác. Sau review, stage đúng AGENTS, hai tài liệu graphics, thư mục evidence và các file QualitySlice/launcher rồi commit trên main, hoặc dùng một branch review nếu quy trình nhóm yêu cầu. Không tự đổi nhánh hay gộp cả những thay đổi ngoài phạm vi.

Lượt tiếp theo: đo và sửa **một** handoff Walk↔strafe trong clip gameplay/cận chân; sau đó làm một cây tác giả thay proxy; tiếp đến thử bake/contact và mipmap riêng. Người dùng quyết định giữ hướng màu/bố cục sau khi xem bằng chứng. Ghi xác nhận cụ thể vào ART_DIRECTION, không nâng giả thuyết thành quyết định chính thức.
