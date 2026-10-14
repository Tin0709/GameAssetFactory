# Mobs Animation Library — Zombie V1

Đây là thư viện review mob riêng của GameAssetFactory. Hiện có **năm Action**: bốn Action Idle/Walk giữ nguyên trạng thái Pending và một Attack mới **Reference Only**; thêm một mục kết quả nghiên cứu Hurt, không phải Action. Chưa tích hợp Godot. File player showcase và các Action/source cũ không được ghi bởi tác vụ này.

Để xem hướng giống pack, chọn **Idle / A&S source v001** hoặc **Walk / A&S source v001** trong sidebar. Hai bản này được đánh dấu **RESEARCH ONLY**, không dùng cho production/export/Godot. Chi tiết preset và sai khác ở `research/actions_stuff_zombie_v001/README.md`.

File chính nay chứa dữ liệu chuyển động tái dựng riêng tư. Thư mục research có local Git exclude. File chính đã được một checkpoint song song đưa vào tracked files; ignore rule không tự bỏ tracking, nên không coi rule này là bảo đảm file chính không được commit. Tác vụ này không tạo commit hoặc sửa lịch sử Git. Không dùng các Action research trong production exports. Hai bản Original vẫn giữ nguyên trong file chính và được lưu riêng tại `originals/Mobs_Animation_Library_Original_V1.blend`, chỉ chứa dữ liệu nguyên bản của ta.

Mở bằng Terminal:

```bash
open -na "Blender" --args "/Users/tin/Desktop/Game Dev/GameAssetFactory/blender/animation/showcase/Mobs_Animation_Library.blend"
```

Trong viewport, nhấn **N → Mobs Animation Library**, chọn **Zombie**, rồi bấm tên Idle hoặc Walk. **Play/Pause** phát/dừng, **Restart** về đầu, **Loop playback** lặp. **Front / 3/4 / Side** đổi góc nhìn. Sidebar hiển thị tên, thời lượng, FPS và trạng thái.

Add-on riêng `gaf_mobs_animation_library.py` đã được cài và bật trong Blender 5.2 của máy này. File không cần Python text tự chạy. Nếu mang sang máy khác hoặc preferences bị reset, mở `mobs_library/Open_Mobs_Animation_Library.command`; launcher nạp bản add-on đi kèm trong phiên Blender đó mà không thay preferences. Có thể cài file `.py` qua Preferences → Add-ons → Install from Disk để giữ giao diện trên máy khác.

## Hai animation Original ban đầu

| Action | Phát ở 30 FPS | Key đóng vòng, không phát thêm | Định hướng |
|---|---|---|---|
| Zombie_Idle_Original_V1 | F1–120, 4,00 s | F121 | Hai chân cố định hơi lệch nhau; chuyển trọng tâm nhẹ, vai/tay rũ không đều, đầu và ngực phản hồi trễ. |
| Zombie_Walk_Original_V1 | F1–42, 1,40 s | F43 | Shamble thấp, tay trái/phải khác nhau; mỗi bước có giai đoạn gót → bàn chân phẳng → mũi chân, nhấc chân không đều. |

Giữ nguyên mesh 48 vertex, sáu khối, atlas gốc và rest rig 10 bone của `blender/animation_v2/zombie_animation_v2.blend`. Không có khuỷu/gối, scale deformation, constraint hay driver. Root cố định. Poses, timing và đường cong mới được tác giả hóa độc lập; generator không đọc `.mcpack` hay bảng animation bên thứ ba.

Walk là in-place; tốc độ tham chiếu tương lai **0,52 m/s**, stride **0,728 m** mỗi vòng. Translation cục bộ của chân bù chuyển động hông để giữ cạnh chân trụ. Không thêm world travel vào Action. Gameplay sau này cần đồng bộ travel/playback và kiểm tra chuyển trạng thái; crossfade tự nó không đảm bảo chân không trượt.

## Review và phiên bản

**Set Review Status** hỗ trợ Pending / Approved / Rejected / Backup / Reference Only. Trạng thái review không gỡ cờ research_only/production_allowed=false. Thay đổi trạng thái do người review chủ động chọn; **Ctrl-S** để lưu. **New Revision Copy** tạo một Action mới Pending với tên V2/V3… và giữ nguyên Action cũ. Tên trùng bị từ chối. Không sửa đè Action đã Approved; luôn dùng revision copy trước.

Registry sống trong scene property `mobs_registry`, gồm mob → collection/rig và clip → native Action/slot/range/FPS/status. Load handler khôi phục danh sách và binding khi mở file. Không có manifest ngoài cần đồng bộ thủ công. `installation.json` và các file validation là bằng chứng của lần bàn giao, không phải nguồn trạng thái review hiện tại.

## Tổ chức và mở rộng

`Preview Environment` chứa ground, ba camera và light. `Mobs/MOB_Zombie` chứa rig/model Zombie. Chỉ collection của mob được chọn hiển thị. Không có Skeleton/Spider hoặc animation của mob khác trong file bàn giao.

Mỗi mob mới có collection/armature riêng và có thể có tên bone, hierarchy và số bone khác hoàn toàn. Không retarget mọi mob vào rig Zombie. API add-on:

```python
register_mob(scene, mob_id, label, collection, rig)
register_clip(scene, mob_id, action, start, end, fps, action_slot)
rebuild(scene)
```

ID, rig và collection phải riêng; object không được chia sẻ giữa hai mob. V1 nhận các curve location/rotation/scale trên pose bone có thật của rig đó. Object travel, custom-property curves và animation hệ thống khác cần bake/adapter riêng; chúng bị từ chối thay vì để state rò sang clip kế tiếp. Rig có procedural constraints/secondary systems cần adapter hoặc bake trước; V1 hiện được kiểm chứng với rig zombie không constraints/drivers.

## So sánh và kiểm tra

`review/` có sáu MP4 30 FPS tốc độ thật: Idle/Walk × Front/3/4/Side, mỗi clip ba vòng liên tục. Hai video `Existing_vs_Original_V1` đặt clip cũ bên trái và V1 bên phải, cùng camera/material/ánh sáng, giữ tốc độ gốc từng clip. Idle cũ 3 s so với V1 4 s; Walk cũ 1,6 s so với V1 1,4 s. Cũ không được đổi timing hoặc curve để phục vụ so sánh.

`validation_geometry.json`: 481 mẫu Idle và 169 mẫu Walk, gồm subframe; rest rig/mesh/UV/weights giữ nguyên, pose seam bằng 0, scale bằng 1, Root cố định. Idle drift khoảng 0,0064 mm; sai lệch cạnh chân Walk đã bù travel tham chiếu khoảng 0,0243 mm. Đo cạnh gót/mũi trong stance; vùng đổi cạnh khi bàn chân phẳng được xét bằng độ cao tiếp xúc, không tuyên bố một vertex đứng yên xuyên suốt quá trình rocking. Đáy chân có allowance 0,5 mm trên mặt phẳng; không có floor penetration trong các mẫu kiểm tra.

Tangent seam tối đa khoảng 3,6e-7 đơn vị/frame. Sai lệch tốc độ từ phép vi phân mesh float32 ở hai phía seam được ghi riêng trong JSON; nó không phải kết quả đo hiệu năng mobile. UI test có lưu rồi mở lại Approved/revision trong file scratch, kiểm tra binding/reset, trùng tên và một skeleton khác. `validation_gui.json` ghi Play/Pause, Restart, hai lần wrap ở mỗi clip, dừng khi tắt Loop, save/reopen và hai trạng thái Pending. Fixture/test revision không nằm trong file bàn giao.

Chờ bạn review hình ảnh. Chưa chứng minh chuyển Idle↔Walk trong gameplay, terrain, Godot import hoặc hiệu năng điện thoại. Giai đoạn Idle/Walk ban đầu không tạo Chase/Attack/Hit/Death. Attack nguồn được bổ sung riêng trong lần cập nhật combat bên dưới; chưa tạo Hurt/Chase/Death.


## Zombie combat reference — 2026-10-14

Chọn **Zombie → Attack / A&S reference** để xem `Zombie_Attack_Player_A&S_Reference_v001`, **Reference Only**. Nguồn đã xác minh: `animation.oreville_ans.craixf`, controller `aioksj`; clip 0,75 giây. Preset: adult variant0, đứng tại chỗ, đã giơ tay target, grounded, gaze trung tính. Idle procedural vẫn chạy. Toàn bộ mốc nguồn dạng số thập phân được giữ, Catmull–Rom được tính trước khi bake 960 Hz lên rig nghiên cứu riêng.

Dùng **Play/Pause**, **Restart**, **Loop playback** và **Time (seconds)**. Các nút **Start / Raise / Swing / Follow / End** nhảy đến pose có timestamp chính xác, gồm F23,5 ở cuối. **Front / 3/4 / Side** đổi góc. Panel Play dùng đồng hồ 0,75 giây, không kéo giãn clip thành 23 hoặc 24 frame. Attack là one-shot; bật Loop chỉ lặp để review, không tạo một seam giả. Timeline/Action Editor vẫn cho phép xem curve/key; marker timeline làm tròn để hiển thị và có ghi timestamp nguồn trong tên.

Chọn **Hurt / Hit Reaction — findings → Open Source Findings** để đọc điều tra. Không tìm thấy skeletal Hurt clip trong hệ zombie base/SP0/SP1. Hurt-color renderer chuyển cờ sang âm thanh giáp; không điều khiển pose xương. Không tạo `Zombie_Hurt_A&S_Reference_v001` giả định. Chưa có footage gameplay zombie bị đánh đã xác minh để dựng runtime knockback/hurt transform.

Collection **Research Only — NO EXPORT / REFERENCE_Zombie** chứa bản sao rig/model gốc dùng cho cả ba Action nguồn. Rest rig/model gốc và tất cả Action cũ giữ nguyên. Helper `Reference_RightItem` chỉ thêm trên rig bản sao để giữ kênh vật cầm nguồn; nhân vật không cầm đồ nên helper không có mesh. **Production — Originals Only** view layer loại collection research; `production_clips()`/production manifest chỉ cho phép hai Action Original. Xuất production từ archive Original-only, không dùng All Actions của file review nghiên cứu.

Bằng chứng riêng tư: `research/actions_stuff_zombie_combat_v001/FINDINGS.txt`, `combat_manifest.json`, `validation_combat.json`, `gui_validation_combat.json`. Kiểm tra 738 mẫu matrix, sai số tối đa 0,0001024 phần tử matrix; rig/rest/mesh/UV/weights/atlas gốc nguyên vẹn. Đã chạy GUI phát/dừng, hai lần wrap, scrub fractional, ba camera, mở Hurt findings và mở lại rồi phát tới F23,5. Đây là xác minh dữ liệu nguồn và retarget, không phải chứng nhận khớp từng pixel với Minecraft runtime. Không tạo comparison video, không sửa player/Godot hoặc commit pack.
