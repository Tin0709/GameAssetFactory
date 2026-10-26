"""Small native widgets for the compact dark desktop interface."""
import tkinter as tk
import math
from tkinter import font as tkfont, ttk

PAGE = '#090d16'
CARD = '#0d1322'
BORDER = '#1e293b'
TEXT = '#e2e8f0'
MUTED = '#94a3b8'


def font_size(points):
    """User requested all interface text 20% larger."""
    return round(points * 1.2)


def rounded(canvas, x, y, w, h, radius, **kwargs):
    radius = min(radius, w / 2, h / 2)
    points = []
    for cx, cy, start in [(x + w - radius, y + radius, -90), (x + w - radius, y + h - radius, 0),
                           (x + radius, y + h - radius, 90), (x + radius, y + radius, 180)]:
        for angle in range(start, start + 91, 10):
            radians = math.radians(angle)
            points.extend((round(cx + radius * math.cos(radians)), round(cy + radius * math.sin(radians))))
    return canvas.create_polygon(points, **kwargs)


class RoundedCard(tk.Canvas):
    def __init__(self, parent, padding=16, color=CARD, outline=BORDER, background=PAGE, body_style='Card.TFrame', **kwargs):
        super().__init__(parent, background=background, highlightthickness=0, borderwidth=0, height=1, **kwargs)
        self.padding, self.color, self.outline = padding, color, outline
        self.body = ttk.Frame(self, style=body_style)
        self.window = self.create_window(padding, padding, anchor='nw', window=self.body)
        self.body.bind('<Configure>', self._body_changed)
        self.bind('<Configure>', self._resized)
        # A 1px canvas initially clips its embedded frame before Tk maps it,
        # so no body Configure event arrives until we request its first height.
        self._initial_layout = self.after_idle(self._first_layout)

    def _first_layout(self):
        self._initial_layout = None
        self._body_changed()

    def destroy(self):
        if self._initial_layout:
            self.after_cancel(self._initial_layout)
        super().destroy()

    def _body_changed(self, event=None):
        height = self.body.winfo_reqheight() + self.padding * 2
        if int(float(self.cget('height'))) != height:
            self.configure(height=height)
        self._draw()

    def _resized(self, event):
        self.itemconfigure(self.window, width=max(1, event.width - self.padding * 2))
        self._draw()

    def _draw(self):
        self.delete('surface')
        rounded(self, .5, .5, max(1, self.winfo_width() - 1), max(1, self.winfo_height() - 1),
                14, fill=self.color, outline=self.outline, width=1, tags='surface')
        self.tag_lower('surface')


class Button(tk.Canvas):
    PALETTES = {
        'normal': ('#151e32', '#1e293b', '#cbd5e1', '#2b374d'),
        'primary': ('#4f46e5', '#6366f1', '#ffffff', '#6159ee'),
        'success': ('#047857', '#059669', '#ffffff', '#078565'),
        'subtle': ('#25234c', '#33305f', '#b8b6ff', '#393568'),
        'ghost': (CARD, '#162036', '#cbd5e1', BORDER),
    }

    def __init__(self, parent, text, command, kind='normal', background=CARD, small=False):
        self.text, self.command, self.kind = text, command, kind
        self._hover = False
        self._font = tkfont.Font(root=parent, family='Segoe UI', size=font_size(8 if small else 9),
                                 weight='bold' if kind in {'primary', 'success'} else 'normal')
        width = self._font.measure(text) + (18 if small else 24)
        super().__init__(parent, width=width, height=32 if small else 36,
                         background=background, highlightthickness=0, borderwidth=0,
                         cursor='hand2', takefocus=True)
        self.bind('<Configure>', lambda event: self._draw())
        self.bind('<Enter>', lambda event: self._set_hover(True))
        self.bind('<Leave>', lambda event: self._set_hover(False))
        self.bind('<Button-1>', lambda event: self.focus_set())
        self.bind('<ButtonRelease-1>', self._click)
        self.bind('<Return>', lambda event: self.invoke())
        self.bind('<space>', lambda event: self.invoke())
        self.bind('<FocusIn>', lambda event: self._draw())
        self.bind('<FocusOut>', lambda event: self._draw())
        self._draw()

    def _set_hover(self, value):
        self._hover = value
        self._draw()

    def _click(self, event):
        if 0 <= event.x < self.winfo_width() and 0 <= event.y < self.winfo_height():
            self.invoke()

    def _draw(self):
        self.delete('all')
        base, hover, foreground, border = self.PALETTES[self.kind]
        width = max(self.winfo_width(), int(self.cget('width')))
        height = max(self.winfo_height(), int(self.cget('height')))
        rounded(self, .5, .5, width - 1, height - 1, 7,
                fill=hover if self._hover else base, outline='#a5b4fc' if self.focus_get() == self else border, width=1)
        self.create_text(width / 2, height / 2, text=self.text, fill=foreground, font=self._font)

    def invoke(self):
        if not self.instate(['disabled']):
            return self.command()

    def instate(self, states):
        disabled = super().cget('state') == 'disabled'
        return all(disabled if state == 'disabled' else not disabled if state == '!disabled' else True for state in states)

    def cget(self, key):
        return self.text if key == 'text' else super().cget(key)


class Badge(tk.Canvas):
    PALETTES = {
        'neutral': ('#151e2e', '#a5b4cb', '#29364b'),
        'success': ('#092a25', '#34d399', '#16483d'),
        'warn': ('#2c2414', '#fbbf24', '#59451e'),
        'error': ('#321421', '#fb7185', '#602239'),
        'accent': ('#211f48', '#b3b0ff', '#3c376c'),
    }

    def __init__(self, parent, text='', variable=None, kind='neutral', dot=False, background=CARD):
        super().__init__(parent, height=27, background=background, borderwidth=0, highlightthickness=0)
        self.text, self.variable, self.kind, self.with_dot = text, variable, kind, dot
        self._font = tkfont.Font(root=parent, family='Segoe UI', size=font_size(8), weight='bold')
        self._trace = variable.trace_add('write', self._variable_changed) if variable else None
        self._draw()

    def _variable_changed(self, *args):
        self._draw()

    def set_kind(self, kind):
        if kind != self.kind:
            self.kind = kind
            self._draw()

    def set_text(self, text):
        if text != self.text:
            self.text = text
            self._draw()

    def _draw(self):
        text = self.variable.get() if self.variable else self.text
        width = max(22, self._font.measure(text) + 16 + (12 if self.with_dot else 0))
        if int(float(super().cget('width'))) != width:
            self.configure(width=width)
        self.delete('all')
        fill, foreground, border = self.PALETTES[self.kind]
        rounded(self, .5, .5, width - 1, 26, 12 if self.with_dot else 6, fill=fill, outline=border, width=1)
        if self.with_dot:
            self.create_oval(8, 11, 13, 16, fill=foreground, outline='')
        self.create_text(20 if self.with_dot else 8, 13, text=text, anchor='w', fill=foreground, font=self._font)

    def destroy(self):
        if self.variable is not None and self._trace:
            try:
                self.variable.trace_remove('write', self._trace)
            except tk.TclError:
                pass
        super().destroy()


class StatusLight(Badge):
    def __init__(self, parent, panel=False):
        super().__init__(parent, dot=True, background=CARD if panel else PAGE)
        self.state = 'idle'

    def set(self, state, text=''):
        self.state = state
        self.set_kind({'idle': 'neutral', 'working': 'warn', 'ok': 'success', 'error': 'error'}[state])
        self.set_text(text)


class ScrollablePage(ttk.Frame):
    def __init__(self, root):
        super().__init__(root, style='Page.TFrame')
        self.canvas = tk.Canvas(self, background=PAGE, highlightthickness=0, borderwidth=0)
        scrollbar = ttk.Scrollbar(self, orient='vertical', command=self.canvas.yview, style='Dark.Vertical.TScrollbar')
        scrollbar.pack(side='right', fill='y')
        self.canvas.pack(side='left', fill='both', expand=True)
        self.canvas.configure(yscrollcommand=scrollbar.set)
        self.content = ttk.Frame(self.canvas, padding=(20, 16), style='Page.TFrame')
        self.window = self.canvas.create_window(0, 0, anchor='nw', window=self.content)
        self.content.bind('<Configure>', lambda event: self.canvas.configure(scrollregion=self.canvas.bbox('all')))
        self.canvas.bind('<Configure>', lambda event: self.canvas.itemconfigure(self.window, width=event.width))
        self.blocked = lambda: False
        root.bind('<MouseWheel>', self._wheel, add='+')

    def _wheel(self, event):
        if self.blocked() or isinstance(event.widget, tk.Text):
            return
        self.canvas.yview_scroll(-int(event.delta / 120), 'units')
        return 'break'


class Disclosure:
    def __init__(self, parent, title, branch_variable, expanded=False):
        self.frame = ttk.Frame(parent, style='Card.TFrame')
        self.frame.pack(fill='x', pady=(10, 0))
        ttk.Frame(self.frame, height=1, style='Line.TFrame').pack(fill='x', pady=(0, 5))
        row = ttk.Frame(self.frame, style='Card.TFrame')
        row.pack(fill='x')
        self.title = title
        self.button = Button(row, '', self.toggle, kind='ghost', small=True)
        self.button.pack(side='left')
        ttk.Label(row, textvariable=branch_variable, style='MonoMuted.TLabel').pack(side='right')
        self.content = ttk.Frame(self.frame, style='Card.TFrame')
        self.expanded = not expanded
        self.set_expanded(expanded)

    def toggle(self):
        self.set_expanded(not self.expanded)

    def set_expanded(self, value):
        self.expanded = value
        self.button.text = ('▾  ' if value else '▸  ') + self.title
        self.button.configure(width=self.button._font.measure(self.button.text) + 20)
        self.button._draw()
        if value:
            self.content.pack(fill='x', pady=(7, 0))
        else:
            self.content.pack_forget()


class Notifications:
    def __init__(self, root):
        self.root, self.card, self.timer = root, None, None
        self.kind, self.message = '', ''

    def show(self, title, message, kind='info'):
        self.close()
        self.kind, self.message = kind, message
        # Full command output stays in the log/details view, never a screen-
        # sized toast that hides its own close button.
        lines = str(message).splitlines()
        display = '\n'.join(lines[:7])[:800]
        if display != str(message):
            display += '\n… Xem nhật ký để đọc đầy đủ.'
        self.card = RoundedCard(self.root, padding=14, outline='#623047' if kind == 'error' else '#3b3a6b')
        self.card.place(relx=1, x=-24, y=22, anchor='ne', width=470)
        row = ttk.Frame(self.card.body, style='Card.TFrame')
        row.pack(fill='x')
        ttk.Label(row, text=title, style='CardTitle.TLabel', foreground='#fb7185' if kind == 'error' else '#a5b4fc').pack(side='left')
        Button(row, '×', self.close, kind='ghost', small=True).pack(side='right')
        ttk.Label(self.card.body, text=display, style='Card.TLabel', wraplength=438, justify='left').pack(fill='x', pady=(8, 0))
        self.card.tk.call('raise', self.card._w)
        if kind != 'error':
            self.timer = self.root.after(4500, self.close)

    def close(self):
        if self.timer:
            try:
                self.root.after_cancel(self.timer)
            except tk.TclError:
                pass
            self.timer = None
        if self.card:
            self.card.destroy()
            self.card = None


class InAppDialog:
    def __init__(self, root):
        self.root, self.frame, self.kind = root, None, ''
        self.bindings = []
        self.focusables = []
        self.text_widget = None

    @property
    def active(self):
        return self.frame is not None

    def _open(self, title, kind):
        self.close()
        self.previous_focus = self.root.focus_get()
        self.kind = kind
        self.frame = tk.Frame(self.root, background='#070a12')
        self.frame.place(x=0, y=0, relwidth=1, relheight=1)
        self.frame.lift()
        self.card = RoundedCard(self.frame, padding=20, outline='#343451', background='#070a12')
        self.card.place(relx=.5, rely=.5, anchor='center', width=min(800, max(440, self.root.winfo_width() - 64)))
        row = ttk.Frame(self.card.body, style='Card.TFrame')
        row.pack(fill='x')
        ttk.Label(row, text=title, style='DialogTitle.TLabel').pack(side='left')
        close = Button(row, '×', self.close, kind='ghost', small=True)
        close.pack(side='right')
        self.focusables = [close]
        self.bindings = [(key, self.root.bind(key, callback, add='+')) for key, callback in [
            ('<Escape>', lambda event: self.close()), ('<Tab>', self._tab),
            ('<Shift-Tab>', lambda event: self._tab(event, reverse=True))]]
        self.frame.grab_set()
        close.focus_set()

    def _tab(self, event, reverse=False):
        current = self.root.focus_get()
        index = self.focusables.index(current) if current in self.focusables else 0
        self.focusables[(index + (-1 if reverse else 1)) % len(self.focusables)].focus_set()
        return 'break'

    def show_details(self, title, text):
        self._open(title, 'details')
        area = ttk.Frame(self.card.body, style='Card.TFrame')
        area.pack(fill='both', expand=True, pady=(15, 12))
        text_font = tkfont.Font(root=self.root, family='Consolas', size=font_size(9))
        rows = min(20, max(7, int((self.root.winfo_height() - 220) / text_font.metrics('linespace'))))
        area.columnconfigure(0, weight=1)
        self.text_widget = tk.Text(area, height=rows, width=88, wrap='none', background='#080e18', foreground='#cbd5e1',
                                   selectbackground='#3730a3', font=('Consolas', font_size(9)), relief='flat', borderwidth=0, padx=10, pady=10)
        scrollbar = ttk.Scrollbar(area, orient='vertical', command=self.text_widget.yview, style='Dark.Vertical.TScrollbar')
        scrollbar.grid(row=0, column=1, sticky='ns')
        horizontal = ttk.Scrollbar(area, orient='horizontal', command=self.text_widget.xview, style='Dark.Horizontal.TScrollbar')
        horizontal.grid(row=1, column=0, sticky='ew')
        self.text_widget.grid(row=0, column=0, sticky='nsew')
        self.text_widget.configure(yscrollcommand=scrollbar.set, xscrollcommand=horizontal.set)
        self.text_widget.insert('1.0', text)
        self.text_widget.configure(state='disabled')
        button = Button(self.card.body, 'Đóng', self.close, kind='primary')
        button.pack(anchor='e')
        self.focusables.extend([self.text_widget, button])

    def show_confirm(self, title, message, callback):
        self._open(title, 'confirm')
        ttk.Label(self.card.body, text=message, style='Card.TLabel', wraplength=710, justify='left').pack(fill='x', pady=(18, 20))
        row = ttk.Frame(self.card.body, style='Card.TFrame')
        row.pack(fill='x')
        def accept():
            if callback() is not False:
                self.close()
        self.confirm_button = Button(row, 'Commit ngay', accept, kind='primary')
        self.confirm_button.pack(side='right')
        self.cancel_button = Button(row, 'Hủy', self.close, kind='ghost')
        self.cancel_button.pack(side='right', padx=8)
        self.focusables.extend([self.cancel_button, self.confirm_button])
        self.cancel_button.focus_set()

    def close(self):
        for key, identifier in self.bindings:
            if identifier:
                self.root.unbind(key, identifier)
        self.bindings = []
        if self.frame:
            try:
                self.frame.grab_release()
            except tk.TclError:
                pass
            self.frame.destroy()
            self.frame = None
            previous = getattr(self, 'previous_focus', None)
            if previous is not None and previous.winfo_exists():
                previous.focus_set()
        self.focusables = []
