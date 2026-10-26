"""Presentation only: the Git and Blender controllers remain in desktop.py."""
from pathlib import Path
import os
import tkinter as tk
from tkinter import ttk

from .blender_views import VIEW_LABELS
from .ui_widgets import (PAGE, CARD, TEXT, MUTED, Badge, Button, Disclosure,
                         RoundedCard, ScrollablePage, StatusLight, font_size)


def build_layout(app):
    root = app.root
    root.title('Git Checkpoint Manager — GameAssetFactory & MD2')
    root.geometry(f'{min(1280, root.winfo_screenwidth() - 80)}x{min(940, root.winfo_screenheight() - 100)}')
    root.minsize(960, 660)
    root.configure(background=PAGE)
    style = ttk.Style(root)
    style.theme_use('clam')
    style.configure('.', font=('Segoe UI', font_size(9)))
    style.configure('TFrame', background=PAGE)
    style.configure('Page.TFrame', background=PAGE)
    style.configure('Card.TFrame', background=CARD)
    style.configure('Line.TFrame', background='#1b2335')
    for name, options in {
        'Card': {}, 'Muted': {'foreground': MUTED, 'font': ('Segoe UI', font_size(8))},
        'CardTitle': {'font': ('Segoe UI', font_size(11), 'bold'), 'foreground': '#f8fafc'},
        'Title': {'font': ('Segoe UI', font_size(17), 'bold'), 'foreground': '#f8fafc'},
        'DialogTitle': {'font': ('Segoe UI', font_size(14), 'bold')},
        'Mono': {'foreground': '#a5b4fc', 'font': ('Consolas', font_size(8))},
        'MonoMuted': {'foreground': '#71829e', 'font': ('Consolas', font_size(8))},
    }.items():
        style.configure(name + '.TLabel', **{'background': CARD, 'foreground': TEXT, **options})
    style.configure('TCheckbutton', background=CARD, foreground=TEXT, padding=2, font=('Segoe UI', font_size(8)))
    style.map('TCheckbutton', background=[('active', CARD)], indicatorbackground=[('selected', '#4f46e5'), ('!selected', PAGE)], indicatorforeground=[('selected', '#ffffff')])
    style.configure('TSpinbox', fieldbackground=PAGE, foreground=TEXT, arrowcolor=MUTED, bordercolor='#273249', padding=3)
    style.configure('Dark.Vertical.TScrollbar', background='#26324b', troughcolor=PAGE, arrowcolor=MUTED,
                    bordercolor=PAGE, lightcolor=PAGE, darkcolor=PAGE, borderwidth=0, width=10)
    style.map('Dark.Vertical.TScrollbar', background=[('active', '#334155'), ('!active', '#26324b')])
    style.configure('Dark.Horizontal.TScrollbar', background='#26324b', troughcolor=PAGE, arrowcolor=MUTED,
                    bordercolor=PAGE, lightcolor=PAGE, darkcolor=PAGE, borderwidth=0, width=10)
    style.map('Dark.Horizontal.TScrollbar', background=[('active', '#334155'), ('!active', '#26324b')])
    app.page = ScrollablePage(root)
    app.page.pack(fill='both', expand=True)
    app.page.blocked = lambda: app.dialog.active
    page = app.page.content

    def card():
        frame = RoundedCard(page, padding=17)
        frame.pack(fill='x', pady=(0, 13))
        return frame.body

    def row(parent, **pack):
        frame = ttk.Frame(parent, style='Card.TFrame')
        frame.pack(fill='x', **pack)
        return frame

    def responsive_pair(container, left, right):
        state = {'stacked': False}
        def resize(event):
            stacked = event.width < left.winfo_reqwidth() + right.winfo_reqwidth() + 24
            if stacked == state['stacked']:
                return
            state['stacked'] = stacked
            left.pack_forget()
            right.pack_forget()
            if stacked:
                left.pack(side='top', fill='x')
                right.pack(side='top', anchor='e', pady=(12, 0))
            else:
                left.pack(side='left', fill='x', expand=True)
                right.pack(side='right', padx=(10, 0))
        container.bind('<Configure>', resize)

    header = card()
    title = row(header)
    assets = Path(__file__).with_name('assets')
    try:
        app.header_icon = tk.PhotoImage(file=str(assets / 'checkpoint-manager-v2-48.png'))
        ttk.Label(title, image=app.header_icon, style='Card.TLabel').pack(side='left', padx=(0, 12))
        if os.name == 'nt':
            root.iconbitmap(str(assets / 'checkpoint-manager-v2.ico'))
        else:
            root.iconphoto(True, app.header_icon)
    except tk.TclError:
        app.header_icon = None
    heading = ttk.Frame(title, style='Card.TFrame')
    heading.pack(side='left')
    ttk.Label(heading, text='Git Checkpoint Manager', style='Title.TLabel').pack(anchor='w')
    ttk.Label(heading, text='Checkpoint cục bộ · Push thủ công · Hai repository riêng biệt', style='Muted.TLabel').pack(anchor='w', pady=(3, 0))
    Button(title, '✓  Bật tự commit cả hai', app.resume_all, kind='success').pack(side='right')
    Button(title, '●  Tạm dừng tất cả', app.pause_all).pack(side='right', padx=8)
    ttk.Frame(header, height=1, style='Line.TFrame').pack(fill='x', pady=(15, 12))
    toolbar = row(header)
    ttk.Label(toolbar, text='Quét mỗi', style='Muted.TLabel').pack(side='left')
    ttk.Spinbox(toolbar, from_=10, to=3600, width=5, textvariable=app.interval_var).pack(side='left', padx=8)
    ttk.Label(toolbar, text='giây', style='Muted.TLabel').pack(side='left')
    Button(toolbar, 'Áp dụng', app.apply_interval, kind='subtle', small=True).pack(side='left', padx=8)
    mode = row(header, pady=(12, 0))
    app.activity_light = StatusLight(mode, panel=True)
    app.activity_light.pack(side='left', padx=(0, 6))
    app.mode_badge = Badge(mode, variable=app.mode_var, kind='neutral')
    app.mode_badge.pack(side='left')
    ttk.Label(header, textvariable=app.countdown_var, style='MonoMuted.TLabel').pack(anchor='w', pady=(7, 0))

    bridge = card()
    title = row(bridge)
    ttk.Label(title, text='Blender MCP', style='CardTitle.TLabel').pack(side='left')
    app.blender_light = StatusLight(title, panel=True)
    app.blender_light.pack(side='left', padx=12)
    app.blender_light.set('idle', 'Đang kiểm tra…')
    Button(title, 'Kiểm tra ngay', app.refresh_blender, small=True).pack(side='right')
    Button(title, 'Chạy Blender MCP', app.start_blender, kind='success', small=True).pack(side='right', padx=8)
    ttk.Label(bridge, textvariable=app.bridge_detail, style='Muted.TLabel', wraplength=980).pack(anchor='w', pady=(9, 12))
    ttk.Frame(bridge, height=1, style='Line.TFrame').pack(fill='x', pady=(0, 12))
    shortcuts = row(bridge)
    for key, label in VIEW_LABELS.items():
        group = ttk.Frame(shortcuts, style='Card.TFrame')
        group.pack(side='left', padx=(0, 12))
        button = Button(group, 'Mở ' + label, lambda view=key: app.open_blender_view(view), small=True)
        button.pack(side='left', padx=(0, 3))
        app.view_buttons[key] = button
        copy = Button(group, 'Copy path', lambda view=key: app.copy_blender_view_path(view), kind='ghost', small=True)
        copy.pack(side='left')
        app.view_copy_buttons[key] = copy
    ttk.Label(shortcuts, text='MCP kiểm tra mỗi 3 giây', style='MonoMuted.TLabel').pack(side='right')

    for index, config in enumerate(app.configs):
        panel = card()
        summary = row(panel)
        left = ttk.Frame(summary, style='Card.TFrame')
        left.pack(side='left', fill='x', expand=True)
        name = row(left)
        ttk.Label(name, text=config.name, style='CardTitle.TLabel').pack(side='left')
        light = StatusLight(name, panel=True)
        light.pack(side='left', padx=10)
        light.set('idle', 'Tạm dừng')
        app.repo_lights.append(light)
        metrics = row(left, pady=(8, 0))
        uncommitted = Badge(metrics, variable=app.uncommitted_vars[index], kind='warn')
        uncommitted.pack(side='left', padx=(0, 6))
        app.uncommitted_labels.append(uncommitted)
        pending = Badge(metrics, variable=app.pending_push_vars[index], kind='neutral')
        pending.pack(side='left', padx=(0, 8))
        app.pending_push_labels.append(pending)
        ttk.Label(metrics, textvariable=app.remote_extra_vars[index], style='MonoMuted.TLabel').pack(side='left')
        controls = ttk.Frame(summary, style='Card.TFrame')
        controls.pack(side='right', padx=(10, 0))
        ttk.Checkbutton(controls, text='Tự commit', variable=app.auto_vars[index], command=lambda i=index: app.toggle_auto(i)).pack(side='left', padx=(0, 8))
        for label, command, kind in [
            ('Làm mới', app.refresh, 'ghost'), ('Xem thay đổi', lambda i=index: app.show_changes(i), 'ghost'),
            ('Commit ngay', lambda i=index: app.commit_now(i), 'primary'), ('Push', lambda i=index: app.push_now(i), 'ghost'),
        ]:
            button = Button(controls, label, command, kind=kind, small=True)
            button.pack(side='left', padx=(3, 0))
            app.action_buttons.append(button)
        responsive_pair(summary, left, controls)
        section = Disclosure(panel, 'Chi tiết Git & ' + ('Thông báo lưu ý' if config.require_private else 'Đường dẫn thư mục'), app.branch_vars[index], expanded=config.require_private)
        app.repo_sections.append(section)
        details = section.content
        if config.require_private:
            warning = tk.Frame(details, background='#251f15', highlightbackground='#574124', highlightthickness=1, padx=10, pady=9)
            warning.pack(fill='x', pady=(0, 10))
            tk.Label(warning, text='⚠  MD2: Push kiểm tra repo PRIVATE. Dữ liệu gốc trong Release snapshot không được cập nhật bởi Git commit/push.',
                     background='#251f15', foreground='#fbbf24', font=('Segoe UI', font_size(8)), anchor='w', wraplength=930, justify='left').pack(fill='x')
        path = tk.Label(details, text='▱  ' + str(config.path), background=PAGE, foreground='#9bb4dc', anchor='w', padx=10, pady=8, font=('Consolas', font_size(8)))
        path.pack(fill='x', pady=(0, 9))
        grid = ttk.Frame(details, style='Card.TFrame')
        grid.pack(fill='x')
        grid.columnconfigure((0, 1), weight=1)
        for n, (label, variable) in enumerate([
            ('Nhánh: ', app.branch_vars[index]), ('HEAD: ', app.head_detail_vars[index]),
            ('Upstream: ', app.upstream_detail_vars[index]), ('Checkpoint trong app: ', app.checkpoint_detail_vars[index]),
        ]):
            cell = ttk.Frame(grid, style='Card.TFrame')
            cell.grid(row=n // 2, column=n % 2, sticky='w', pady=3)
            ttk.Label(cell, text=label, style='MonoMuted.TLabel').pack(side='left')
            ttk.Label(cell, textvariable=variable, style='Mono.TLabel').pack(side='left')
        ttk.Frame(details, height=1, style='Line.TFrame').pack(fill='x', pady=7)
        ttk.Label(details, textvariable=app.counts_detail_vars[index], style='Mono.TLabel').pack(anchor='w')
        ttk.Label(details, textvariable=app.repo_text[index], style='Muted.TLabel', wraplength=940).pack(anchor='w', pady=(5, 0))

    log = card()
    title = row(log)
    ttk.Label(title, text='●  NHẬT KÝ', style='Mono.TLabel').pack(side='left')
    ttk.Label(title, text='Trạng thái thời gian thực', style='MonoMuted.TLabel').pack(side='right')
    area = row(log, pady=(10, 0))
    app.log_widget = tk.Text(area, height=6, background=PAGE, foreground='#b6c5e3', insertbackground=TEXT,
                             font=('Consolas', font_size(8)), relief='flat', borderwidth=0, wrap='word', padx=10, pady=8)
    scroll = ttk.Scrollbar(area, command=app.log_widget.yview, style='Dark.Vertical.TScrollbar')
    scroll.pack(side='right', fill='y')
    app.log_widget.pack(side='left', fill='both', expand=True)
    app.log_widget.configure(yscrollcommand=scroll.set, state='disabled')
    ttk.Label(page, text='Đóng app = dừng hẹn giờ. Bỏ qua file đang ghi; không có thay đổi hợp lệ thì không tạo commit.', background=PAGE, foreground='#64748b', font=('Segoe UI', font_size(8))).pack(anchor='center', pady=(1, 8))
