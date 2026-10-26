# Git Checkpoint Manager

App desktop tiếng Việt quản lý riêng hai repository hiện có:

- `C:\Users\ADMIN\Desktop\Dev\GameAssetFactory`
- `C:\Users\ADMIN\Desktop\MD2 Research`

## Mở app

Nhấp đúp **Git Checkpoint Manager** trên Desktop. Hoặc chạy từ GameAssetFactory:

```powershell
py -3 scripts/git_checkpoint_manager.py
```

App dùng Python/Tkinter đã có sẵn. Không tạo web server, repo mới, task đăng nhập
Windows hoặc dịch vụ tự khởi động. Đóng app sẽ dừng hẹn giờ Git. Mỗi lần mở app, tự commit
được tắt để bạn có thể kiểm tra trước; chỉ cho phép một cửa sổ app hoạt động.

Icon riêng được áp dụng cho shortcut, cửa sổ và taskbar. File PNG gốc và ICO
nhiều kích cỡ nằm trong `scripts/checkpoint_manager/assets/`; PNG được tạo bằng
built-in imagegen, ICO chỉ là chuyển định dạng/kích thước từ cùng ảnh gốc.

## Blender MCP và đèn trạng thái

Bấm **Chạy Blender MCP** để chạy đúng phiên bản `v1.0.3` bằng uvx, với server
HTTP `127.0.0.1:8000` và add-on Blender `localhost:9876`. App dùng danh sách đối
số trực tiếp, không cần bạn dán lệnh PowerShell. Server đã có sẽ được dùng lại;
app không mở trùng và không chiếm cổng của dịch vụ khác.

App kiểm tra nền khoảng mỗi 3 giây, bằng worker riêng để Git không làm đứng phần
trạng thái Blender. **Kiểm tra ngay** yêu cầu một lượt kiểm tra mới.

- **Xanh:** server đúng Blender MCP, add-on phản hồi và lệnh kiểm tra chỉ đọc qua
  HTTP MCP thành công. Không chỉ dựa vào cổng mở.
- **Vàng:** đang khởi động, đang chờ Blender/add-on hoặc chưa xác minh được toàn
  tuyến. Blender đang render/bận có thể chưa phản hồi kịp; app giãn nhịp thử lại.
- **Xám:** MCP chưa kết nối/sẵn sàng.

Kiểm tra không chỉnh sửa scene hoặc lưu file Blender. App không tự mở Blender;
bạn mở Blender với add-on MCP như trước. Đóng app sẽ dừng theo dõi, nhưng server
MCP đã được yêu cầu khởi động tiếp tục chạy để các client khác còn dùng được.
Không có đăng ký Startup/Task Scheduler cho tính năng này.

Hai nút mở nhanh trong cùng khu vực Blender:

- **Mở Animation MD2:** mở `MD2_Animation_Library_BrowserFixed.blend` và nạp
  `scripts/md2_blender_library.py`.
- **Mở Valorie + Sabre:** mở `MD2_Valorie_Sabre_Source_Showcase.blend` và nạp
  `source_preview_ui.py`.

Các nút dùng đúng file/script của hai launcher `.cmd` có sẵn nhưng gọi trực tiếp
Blender, nên không mở thêm terminal. Không tự lưu hoặc sửa file `.blend`. Mỗi
lần bấm mở một cửa sổ Blender; thiếu file sẽ được báo trong nhật ký của app.
Nút **Copy path** cạnh mỗi nút mở sẽ copy đường dẫn đầy đủ của file `.blend`
tương ứng vào clipboard, không mở Blender và không hiện hộp thoại.

Nhật ký tiến trình MCP: `%LOCALAPPDATA%\GAFGitCheckpointManager\blender-mcp.stdout.log`
và `blender-mcp.stderr.log`. Nhật ký được tạo khi app thực sự chạy một server mới.

Các nút Git giữ nguyên màu khi quét, không đổi xám/bật lại theo chu kỳ nữa. Chấm
đèn cạnh mỗi repo cho biết tạm dừng, đang xử lý, tự commit bật hoặc cần kiểm tra.
Nút bấm trong lúc thao tác Git đang chạy không xếp chồng lệnh mới.

Lệnh Git, tiến trình kiểm tra file lớn và uvx do app gọi được chạy không tạo
console trên Windows. Bộ kiểm tra file lớn cũng áp dụng chế độ này cho các Git
con do chính nó gọi, để tránh terminal lóe lên trong mỗi lượt commit. Lỗi và
tiến độ vẫn được hiển thị trong nhật ký của app.

## Thông số từng thư mục

- **Chưa commit: N file** — số đường dẫn thay đổi được Git báo ở máy, gồm cả
  file chưa được theo dõi. Dòng Hợp lệ/Bỏ qua cho biết phần app sẽ lấy vào commit.
- **Chưa push: N commit** — số commit của nhánh tại máy chưa có trong bản ghi
  upstream được máy biết. Màu vàng nếu còn commit; xanh nếu bằng 0.
- **GitHub có thêm: N commit** — số commit trong bản ghi upstream mà nhánh tại
  máy chưa có; app không tự merge/pull chúng.

Các số so sánh commit dựa trên lần đồng bộ GitHub gần nhất, không phải truy vấn
GitHub trực tiếp sau mỗi 10 giây. Không có upstream hoặc dữ liệu so sánh thì app
hiển thị chưa xác định, thay vì đoán là 0. Sau Push thành công, app đọc lại trạng
thái để cập nhật số commit chưa push.

Trên Windows, khóa ứng dụng dùng thêm named mutex để không mở hai manager cùng
lúc ngay cả khi chúng nhận các đường dẫn LOCALAPPDATA khác nhau từ runtime.

## Tự commit mỗi 10 giây

1. Đợi app đọc xong trạng thái hai thư mục.
2. Bấm **Xem thay đổi** để kiểm tra danh sách file và các file bị bỏ qua.
3. Bấm **Bật tự commit cả hai**, hoặc bật **Tự commit** riêng từng repo.
4. Cứ **10 giây**, app quét và tạo commit trên nhánh hiện tại nếu có thay đổi
   hợp lệ. Không có thay đổi thì không tạo commit rỗng. Khoảng quét có thể chỉnh.

Không còn thời gian chờ 60 giây. App so sánh nhanh hai mẫu trạng thái cách nhau
250 ms trước khi stage; nếu file vẫn thay đổi thì bỏ qua lượt đó và thử lại ở
lượt quét tiếp theo. File lớn hoặc hook chậm có thể khiến một lượt mất hơn
10 giây; app không chạy thêm thao tác Git chồng lên lượt đang làm.

**Commit ngay** cũng sử dụng các kiểm tra an toàn, nhưng không cần bật hẹn giờ.
Commit là checkpoint công việc đang làm, không phải xác nhận hoàn thành hay
phê duyệt asset/animation.

### Mô tả commit trên GitHub

Commit mới có tiêu đề theo loại file và phần mô tả chi tiết từ diff đã stage:

```text
docs: change 2 docs files

Modified: 2.
Text lines: +16 / -6; binary files: 0.

- Modify: "docs/setup/WINDOWS_HANDOFF_2026_10_25.md"
- Modify: "docs/superpowers/plans/2026-10-25-windows-handoff.md"

Repository: GameAssetFactory
Branch: codex/sword-combat-v001
Checkpoint: 2026-10-26T12:00:00+07:00
```

Đây là ví dụ định dạng; số liệu và đường dẫn của từng commit được tính thật.
App phân loại docs/test/assets/game/code hoặc nhóm thay đổi hỗn hợp; không đoán
mục đích sửa lỗi/tính năng. LFS được tính vào file asset, không cộng dòng pointer
vào thay đổi text. File đổi vị trí được mô tả thành đường dẫn xóa và đường dẫn
thêm. Tên file được đặt trong dấu ngoặc kép và escape ký tự đặc biệt.

Phần mô tả xuất hiện dưới tiêu đề khi mở chi tiết commit trên GitHub sau Push.
Commit cũ giữ nguyên. Nội dung được truyền qua stdin UTF-8 để danh sách file dài
không vượt giới hạn dòng lệnh Windows.

Khi muốn chủ động mở app và bật tự commit sau lượt đọc trạng thái đầu tiên:

```powershell
py -3 scripts/git_checkpoint_manager.py --auto-commit
```

Flag này không tự Push. Shortcut bình thường vẫn mở tạm dừng. Nút Tạm dừng hủy
cả yêu cầu bật tự commit đang chờ đọc trạng thái.

## Push

**Push** chạy ngay khi bạn bấm nút, không mở hộp thoại xác nhận. App gửi các commit đã
có lên đúng upstream hiện tại, dùng đích remote đã cấu hình sẵn. Thay đổi chưa
commit không được gửi. Không tự pull, merge, đổi nhánh hoặc force-push.

Repo MD2 phải được GitHub xác nhận là **PRIVATE** trước mỗi Push. App dùng
đăng nhập Git Credential Manager hiện có, hoặc token trong môi trường tiến
trình; không lưu token vào file cấu hình hoặc nhật ký. Nếu chưa đăng nhập hoặc
không xác minh được quyền riêng tư, Push MD2 sẽ dừng.

Git LFS và các hook hiện có vẫn được sử dụng. File Git thông thường vượt 100 MiB
và LFS pointer sai sẽ bị chặn; app không tự thêm tracking hoặc migrate lịch sử.
Sau Push, app đọc lại SHA nhánh từ xa. Xác minh ref không có nghĩa là đã tải
xuống và kiểm chứng độc lập mọi object LFS từ GitHub.

## Tạm dừng và lỗi

Trước khi bạn, terminal hay session khác chạy lệnh Git ghi vào hai repo, bấm
**Tạm dừng tất cả** và đợi thao tác hiện tại kết thúc. App không thể khóa các
công cụ Git bên ngoài. File lock hoặc trạng thái merge/rebase sẽ khiến app dừng.

Nếu đã có file staged, app giữ nguyên index và chờ bạn xử lý; không lấy chúng
vào checkpoint khác. Nếu hook/commit thất bại sau khi stage, app giữ nguyên file
và index, tắt tự commit cho repo đó và ghi lỗi. Kiểm tra bằng Git trước khi bật lại;
không tự xóa lock, reset hoặc unstage để che lỗi.

Đóng cửa sổ khi Git đang chạy sẽ chờ thao tác hiện tại xong, không nhận lượt mới.
Tạm dừng giữa hai repo sẽ bỏ qua giao dịch kế tiếp.

## Phạm vi backup MD2

Git commit/push không cập nhật bản snapshot dữ liệu gốc trong GitHub Release.
`extracted/`, `source_snapshot/` và staging backup tiếp tục tuân theo `.gitignore`
hiện có. Nút Push không thay thế quy trình `scripts/research_backup.py`.

App hiển thị những file cache/khóa riêng/backup tạm bị loại khỏi checkpoint;
không xóa chúng và không tự sửa `.gitignore`. Những file đã được theo dõi vẫn
được kiểm tra riêng để không âm thầm bỏ qua công việc hiện có.

Cấu hình khoảng quét và nhật ký xoay vòng lưu ngoài Git:
`%LOCALAPPDATA%\GAFGitCheckpointManager`. Ahead/behind trong UI là trạng thái
remote đã fetch gần nhất; app không âm thầm fetch sau mỗi 10 giây.

## Kiểm thử dành cho phát triển

```powershell
py -3 -m unittest discover -s scripts/tests -p "test_checkpoint_manager*.py" -v
```

Các kiểm thử commit/push chỉ sử dụng repo tạm và remote local, không commit/push
vào GameAssetFactory hay MD2 Research thật. UI cũng được thử với hai repo tạm.

Kiểm tra Windows ngày 2026-10-26: 25 kiểm thử riêng cho app đạt; toàn bộ helper
suite 94 kiểm thử đạt với bốn optional skip có sẵn. Knowledge suite 14 kiểm thử
đạt với một skip do quyền tạo symlink trên Windows. Đã xem giao diện thật, mở app
tạm dừng, xác minh PRIVATE bằng API chỉ đọc và đối chiếu HEAD/index hai repo thật
không đổi. Chưa Push lên GitHub bằng app hoặc kiểm chứng độc lập LFS từ xa.

Bản bổ sung icon/MCP/thông số: helper suite 106 kiểm thử đạt, bốn optional skip;
đã kiểm tra SSE chậm, timeout toàn yêu cầu, gói UTF-8 bị chia nhỏ, nút giữ nguyên
màu và bộ đếm hai commit trở về 0 sau Push vào remote tạm. Kết nối Blender thật
đã phản hồi lệnh chỉ đọc qua HTTP MCP. Trong quá trình nâng cấp, cửa sổ manager
khác được mở và tạo checkpoint tự động; những commit đó được giữ nguyên, không
reset/rewrite. Phiên bản hiện tại khóa cả ứng dụng Windows để tránh hai cửa sổ
manager dùng các thư mục trạng thái runtime khác nhau cùng ghi Git.
