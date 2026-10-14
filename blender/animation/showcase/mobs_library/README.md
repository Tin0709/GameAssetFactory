# Mobs Animation Library — Zombie V1

Đây là thư viện review mob riêng của GameAssetFactory. Hai Action mới đều **Pending**, chưa tích hợp Godot. File player showcase và các Action/source cũ không được ghi bởi tác vụ này.

Mở bằng Terminal:

```bash
open -na "Blender" --args "/Users/tin/Desktop/Game Dev/GameAssetFactory/blender/animation/showcase/Mobs_Animation_Library.blend"
```

Trong viewport, nhấn **N → Mobs Animation Library**, chọn **Zombie**, rồi bấm tên Idle hoặc Walk. **Play/Pause** phát/dừng, **Restart** về đầu, **Loop playback** lặp. **Front / 3/4 / Side** đổi góc nhìn. Sidebar hiển thị tên, thời lượng, FPS và trạng thái.

Add-on riêng `gaf_mobs_animation_library.py` đã được cài và bật trong Blender 5.2 của máy này. File không cần Python text tự chạy. Nếu mang sang máy khác hoặc preferences bị reset, mở `mobs_library/Open_Mobs_Animation_Library.command`; launcher nạp bản add-on đi kèm trong phiên Blender đó mà không thay preferences. Có thể cài file `.py` qua Preferences → Add-ons → Install from Disk để giữ giao diện trên máy khác.

## Hai animation mới

| Action | Phát ở 30 FPS | Key đóng vòng, không phát thêm | Định hướng |
|---|---|---|---|
| Zombie_Idle_Original_V1 | F1–120, 4,00 s | F121 | Hai chân cố định hơi lệch nhau; chuyển trọng tâm nhẹ, vai/tay rũ không đều, đầu và ngực phản hồi trễ. |
| Zombie_Walk_Original_V1 | F1–42, 1,40 s | F43 | Shamble thấp, tay trái/phải khác nhau; mỗi bước có giai đoạn gót → bàn chân phẳng → mũi chân, nhấc chân không đều. |

Giữ nguyên mesh 48 vertex, sáu khối, atlas gốc và rest rig 10 bone của `blender/animation_v2/zombie_animation_v2.blend`. Không có khuỷu/gối, scale deformation, constraint hay driver. Root cố định. Poses, timing và đường cong mới được tác giả hóa độc lập; generator không đọc `.mcpack` hay bảng animation bên thứ ba.

Walk là in-place; tốc độ tham chiếu tương lai **0,52 m/s**, stride **0,728 m** mỗi vòng. Translation cục bộ của chân bù chuyển động hông để giữ cạnh chân trụ. Không thêm world travel vào Action. Gameplay sau này cần đồng bộ travel/playback và kiểm tra chuyển trạng thái; crossfade tự nó không đảm bảo chân không trượt.

## Review và phiên bản

**Set Review Status** hỗ trợ Pending / Approved / Rejected / Backup. Thay đổi trạng thái do người review chủ động chọn; **Ctrl-S** để lưu. **New Revision Copy** tạo một Action mới Pending với tên V2/V3… và giữ nguyên Action cũ. Tên trùng bị từ chối. Không sửa đè Action đã Approved; luôn dùng revision copy trước.

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

Chờ bạn review hình ảnh. Chưa chứng minh chuyển Idle↔Walk trong gameplay, terrain, Godot import hoặc hiệu năng điện thoại. Không tạo Chase/Attack/Hit/Death.
