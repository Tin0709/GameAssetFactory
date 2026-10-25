# Tiếp tục GameAssetFactory trên Windows — 25/10/2026

Trạng thái hiện tại: nhánh **`codex/sword-combat-v001`**, remote `git@github.com:Tin0709/GameAssetFactory.git`. Lab đang dùng Sword/Rifle, SOLDIER, Fiery private reference, map100×100 và cỏ. F5/WorldMap và các asset đã duyệt được giữ nguyên. Đây là hướng dẫn chuyển máy, không phải thay đổi approval hay cấp phép phát hành research.

## 1. Trên Mac: kiểm tra rồi push nhánh hiện tại

Các thay đổi đã chuẩn bị trong checkout hiện tại. Không merge main, force-push hay rewrite history. Repo hiện **public**: gói PRIVATE trên Desktop không được đưa vào Git hay upload công khai.

```sh
cd "$HOME/Desktop/Game Dev/GameAssetFactory"
git status --short
python3 scripts/git_large_file_guard.py
git log --oneline origin/codex/sword-combat-v001..HEAD
git push -u origin codex/sword-combat-v001
```

Nếu còn thay đổi chưa commit, tạm dừng bộ automatic checkpoint trước khi tự stage/commit, kiểm tra diff và chỉ chọn file dự định. Không dùng `git add -f` hoặc bỏ qua hook. Đợt chuẩn bị này không tự push; SHA có thể tiến thêm do checkpoint manager đang hoạt động.

## 2. Trên Windows: công cụ và clone

Ưu tiên dùng lại **Godot4.7.2** và **Blender5.2.2** đã dùng cho dự án; máy Mac hiện báo đúng các bản đó. Cần Python3.10+ có lệnh `py -3`, Git for Windows và Git LFS. Không copy ứng dụng `.app`, `.godot`, Python venv hoặc credential từ Mac. Nguồn chính thức: [Git](https://git-scm.com/install/windows), [Git LFS](https://docs.github.com/en/repositories/working-with-files/managing-large-files/installing-git-large-file-storage?platform=windows), [Python](https://www.python.org/downloads/windows/), [Godot](https://godotengine.org/download/windows/), [Blender](https://www.blender.org/download/).

Đề xuất đường dẫn ngắn ngoài OneDrive: `C:\Dev\GameAssetFactory`. Clone nhánh này sau khi push hoàn tất:

```powershell
git lfs install
New-Item -ItemType Directory -Force C:\Dev | Out-Null
git clone --branch codex/sword-combat-v001 git@github.com:Tin0709/GameAssetFactory.git C:\Dev\GameAssetFactory
Set-Location C:\Dev\GameAssetFactory
git lfs pull
git lfs fsck --objects --pointers HEAD
py -3 scripts/install_git_hooks.py
```

Nếu chưa cấu hình SSH GitHub trên Windows, thiết lập credential tại máy đó hoặc clone URL HTTPS của cùng repo; không chuyển private SSH key từ Mac vào dự án. Git clone có khoảng7.5GiB dữ liệu checkout hiện tại; lịch sử Git/LFS có thể lớn hơn nhiều. Dự trù ít nhất30GiB trống cho clone, cache và import, chưa tính phần mềm và archive lịch sử tùy chọn. Tránh dùng GitHub “Download ZIP” làm môi trường làm việc vì cần Git/LFS đầy đủ.

## 3. Chỉ định executable trên máy Windows

Ví dụ dưới đây phải đổi thành **đúng đường dẫn file đã cài** của bạn. Không cần sửa file trong repo:

```powershell
$env:GODOT_BIN = 'C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe'
$env:BLENDER_BIN = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
py -3 scripts/dev.py doctor
```

Các biến này áp dụng cho terminal hiện tại. Có thể thêm vào profile PowerShell của riêng máy; không commit đường dẫn máy cá nhân. Launcher cũng tìm Blender/Godot trên PATH và các vị trí đã hỗ trợ. Không cần cài các thư viện trong `requirements-research.txt` để chơi lab hoặc mở viewer; chúng chỉ dành cho tác vụ phân tích tương ứng.

## 4. Chuyển dữ liệu PRIVATE riêng

Folder trên Desktop Mac: **`GameAssetFactory_Cleanup_Windows_2026-10-25`**. Chỉ cần mang `PRIVATE_Windows_Research.zip` sang máy Windows qua ổ ngoài/kênh riêng. ZIP có manifest SHA256, helper restore và viewer launcher; không có credential hay chương trình từ archive MD2.

Giải nén ZIP vào một thư mục tạm **ngoài clone**, rồi chạy helper bằng Python:

```powershell
Expand-Archive 'D:\Transfer\PRIVATE_Windows_Research.zip' 'C:\Dev\GAF_Private_Transfer'
py -3 C:\Dev\GAF_Private_Transfer\restore_private.py --repo C:\Dev\GameAssetFactory
py -3 C:\Dev\GAF_Private_Transfer\restore_private.py --repo C:\Dev\GameAssetFactory --apply
```

Lần đầu là dry-run. Helper xác minh checksum, từ chối ghi đè nội dung khác và chỉ restore workspace overlay vào những đường dẫn đã bị Git ignore. Fiery được đặt ở **`C:\Dev\private_research\fiery_combat_20261025`**, nằm bên cạnh clone, ngoài `res://` và Git. Giữ quan hệ thư mục này nếu clone vào ổ khác. Không cần mang file RAR game hoặc cài Unreal/REA.

Gói còn giữ các input validation nhỏ/được code tham chiếu và private Mobs research đã có sẵn nhưng không qua Git. Media/checkpoint lớn đã archive không bắt buộc cho lab hiện tại; muốn phục hồi nghiên cứu cũ dùng manifest/restore trong folder archive riêng. Các đường dẫn Mac còn xuất hiện trong metadata provenance/lịch sử không phải executable path của lab. Một số authoring script lịch sử cần chỉnh đường dẫn khi thực sự sử dụng; không bulk-rewrite source đã duyệt.

## 5. Mở đúng lab và thư viện

```powershell
py -3 scripts/dev.py godot --scene combat --weapon sword
py -3 scripts/dev.py godot --scene combat --editor
py -3 scripts/open_blender_viewer.py soldier
py -3 scripts/open_blender_viewer.py animation
py -3 scripts/open_blender_viewer.py weapon
py -3 scripts/open_blender_viewer.py mobs
```

Có thể chạy `.\Open_Combat_Lab.cmd` trong terminal đã đặt biến môi trường ở trên. Bấm đúp file này từ Explorer chỉ khi tool được tìm thấy trên PATH/vị trí tự nhận diện hoặc biến môi trường cấp user. Trong editor, mở `ActionsStuffWalkRunTest.tscn` rồi **F6**; F5 vẫn là WorldMap. Sword/Rifle ở dưới màn hình hoặc Tab đổi vũ khí; E/chuột trái chém, chuột phải guard/parry, F Roll, WASD/Shift/Space di chuyển. Khởi chạy user playtest dùng audio bình thường.

Windows launcher giữ Mobile renderer với D3D12. Nếu GPU/driver không chạy được D3D12, thử override **cho process đó**:

```powershell
py -3 scripts/dev.py godot --scene combat --weapon sword --driver vulkan
```

Không đổi project sang Compatibility chỉ để bỏ lỗi vì hình ảnh/hiệu năng sẽ khác bài test hiện tại. Mobile cần GPU/API phù hợp; xem [yêu cầu Godot chính thức](https://docs.godotengine.org/en/stable/about/system_requirements.html). Performance trên Windows phải đo lại, không suy từ M2 Pro.

## 6. Checklist trước khi làm tiếp

- `git status --short` sạch; `git lfs fsck` đạt; không còn LFS pointer thay cho `.blend`/`.glb`.
- Lab hiển thị **FIERY PRIVATE** khi Sword được chọn. Nếu chỉ thấy SWORD và warning private unavailable, kiểm tra folder bên cạnh clone; đừng tưởng fallback original là Fiery.
- Chém đủ ba đòn, Roll, guard/parry và đổi Rifle; E Rifle vẫn bắn liên tục. Spawn/Kill All, jump và camera hoạt động.
- SOLDIER/Animation/Weapon/Mobs/Grass viewers mở bằng bootstrap của repo, không thiếu texture và approval không đổi. Fiery viewer riêng dùng `open_fiery_viewer_portable.py` trong thư mục private.
- Mở repo trong Codex trên Windows; các connector/MCP và executable config là theo máy, cần cấu hình lại nếu dùng. Gameplay và các viewer không đòi MCP.
- Giữ **Actions & Stuff Research Export Guard** bật. Private source study không phải asset thương mại; chưa phát hành hoặc chuyển dữ liệu riêng vào public repo.

Nếu cần Blender MCP, dùng lại addon đáng tin cậy đã cài trên Windows và đặt `BLENDER_MCP_ADDON` tới đúng **thư mục chứa `mcp_to_blender_server.py`**, không phải file `__init__.py`; host/port phải khớp client. Ví dụ cấu hình theo máy, không commit:

```powershell
$env:BLENDER_MCP_ADDON = 'C:\duong-dan-addon-da-cai\mcp_bridge'
$env:BLENDER_MCP_HOST = '127.0.0.1'
$env:BLENDER_MCP_PORT = '9876'
py -3 scripts/dev.py bridge --viewer animation
```

Chỉ dùng khi port đang trống; không mở thêm bridge nếu đã có một instance. Hướng dẫn này không cài addon, đổi thiết lập bảo mật hoặc mang credential/config người dùng qua Git.

Đã kiểm tra trên Mac: launcher/guard contracts, Git/LFS, tên/path Windows,6viewer dependency inventories và byte-preservation. Chưa chạy native Windows trên máy đích; checklist này là bước smoke-test bắt buộc ở đó.
