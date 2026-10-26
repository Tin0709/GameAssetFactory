"""Small native widgets for the compact dark desktop interface."""
import tkinter as tk
import math
import sys
from tkinter import font as tkfont, ttk
try:
    from PIL import Image, ImageDraw, ImageTk, ImageGrab, ImageFilter
except ImportError:  # A portable native fallback if Pillow is unavailable.
    Image = ImageDraw = ImageTk = None

PAGE = '#181818'
CARD = '#202020'
BORDER = '#343434'
TEXT = '#ededed'
MUTED = '#a4a4a4'


def font_size(points):
    """Two successive user-requested 20% readability increases."""
    return round(points * 1.2 * 1.2)


def rounded(canvas, x, y, w, h, radius, **kwargs):
    radius = min(radius, w / 2, h / 2)
    if Image is not None:
        # Tk polygons have jagged one-pixel corners. Supersample only the
        # surface; text and interaction remain native, sharp and accessible.
        size = (max(1, round(w + x * 2)), max(1, round(h + y * 2)))
        background = canvas.cget('background')
        backdrop = getattr(canvas, 'backdrop', None)
        origin = (canvas.winfo_x(), canvas.winfo_y()) if backdrop is not None else None
        key = (size, x, y, w, h, radius, background, kwargs.get('fill'), kwargs.get('outline'), kwargs.get('width', 1), id(backdrop), origin)
        if getattr(canvas, '_rounded_key', None) != key:
            scale = 3
            if backdrop is not None:
                left, top = origin
                bitmap = backdrop.crop((left, top, left + size[0], top + size[1])).resize((size[0] * scale, size[1] * scale))
            else:
                bitmap = Image.new('RGB', (size[0] * scale, size[1] * scale), background)
            draw = ImageDraw.Draw(bitmap)
            draw.rounded_rectangle((x * scale, y * scale, (x + w) * scale, (y + h) * scale),
                                   radius=radius * scale, fill=kwargs.get('fill'), outline=kwargs.get('outline'),
                                   width=max(1, round(kwargs.get('width', 1) * scale)))
            canvas._rounded_photo = ImageTk.PhotoImage(bitmap.resize(size, Image.Resampling.LANCZOS), master=canvas)
            canvas._rounded_key = key
        return canvas.create_image(0, 0, image=canvas._rounded_photo, anchor='nw', tags=kwargs.get('tags', ()))
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
        self.backdrop = getattr(parent, '_blurred_backdrop', None)
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
                18, fill=self.color, outline=self.outline, width=1, tags='surface')
        self.tag_lower('surface')


class Button(tk.Canvas):
    PALETTES = {
        'normal': ('#2c2c2c', '#343434', '#dedede', '#424242'),
        'primary': ('#245a9a', '#3474bd', '#ffffff', '#2e6caf'),
        'success': ('#265c48', '#36785c', '#ffffff', '#2d6b52'),
        'subtle': ('#303030', '#3a3a3a', '#e0e0e0', '#484848'),
        'ghost': (CARD, '#2a2a2a', '#dedede', BORDER),
    }

    def __init__(self, parent, text, command, kind='normal', background=CARD, small=False):
        self.text, self.command, self.kind = text, command, kind
        self._hover = False
        self._font = tkfont.Font(root=parent, family='Segoe UI', size=font_size(8 if small else 9),
                                 weight='bold' if kind in {'primary', 'success'} else 'normal')
        width = self._font.measure(text) + (18 if small else 24)
        super().__init__(parent, width=width, height=39 if small else 43,
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
        rounded(self, .5, .5, width - 1, height - 1, 9,
                fill=hover if self._hover else base, outline='#9dbbe2' if self.focus_get() == self else border, width=1)
        self.create_text(width / 2, height / 2, text=self.text, fill=foreground, font=self._font)

    def invoke(self):
        if not self.instate(['disabled']):
            return self.command()

    def instate(self, states):
        disabled = super().cget('state') == 'disabled'
        return all(disabled if state == 'disabled' else not disabled if state == '!disabled' else True for state in states)

    def cget(self, key):
        return self.text if key == 'text' else super().cget(key)


class NumberInput(tk.Canvas):
    """Rounded editable seconds field; arrow keys and −/+ are equivalent."""
    def __init__(self, parent, variable, on_apply, minimum=10, maximum=3600):
        super().__init__(parent, width=160, height=43, background=CARD, highlightthickness=0, borderwidth=0)
        self.variable, self.minimum, self.maximum = variable, minimum, maximum
        self.entry = tk.Entry(self, textvariable=variable, justify='center', font=('Segoe UI', font_size(9)),
                              background='#2c2c2c', foreground=TEXT, insertbackground=TEXT,
                              selectbackground='#245a9a', borderwidth=0, highlightthickness=0)
        self.create_window(80, 21, width=68, height=30, window=self.entry)
        self.minus = Button(self, '−', lambda: self.step(-1), small=True, background='#2c2c2c')
        self.plus = Button(self, '+', lambda: self.step(1), small=True, background='#2c2c2c')
        self.create_window(22, 21, window=self.minus)
        self.create_window(138, 21, window=self.plus)
        self.entry.bind('<Up>', lambda event: self.step(1))
        self.entry.bind('<Down>', lambda event: self.step(-1))
        self.entry.bind('<Return>', lambda event: on_apply())
        self.entry.bind('<FocusIn>', lambda event: self._draw())
        self.entry.bind('<FocusOut>', lambda event: self._draw())
        self.bind('<Configure>', lambda event: self._draw())
        self._draw()

    def step(self, amount):
        try:
            value = int(self.variable.get()) + amount
        except ValueError:
            value = self.minimum
        self.variable.set(str(min(self.maximum, max(self.minimum, value))))
        return 'break'

    def _draw(self):
        self.delete('surface')
        rounded(self, .5, .5, 159, 42, 11, fill='#2c2c2c',
                outline='#9dbbe2' if self.focus_get() == self.entry else '#454545', tags='surface')
        self.tag_lower('surface')


class Toggle(tk.Canvas):
    def __init__(self, parent, variable, command, text='Tự commit'):
        self.variable, self.command, self.text = variable, command, text
        self._font = tkfont.Font(root=parent, family='Segoe UI', size=font_size(8))
        super().__init__(parent, width=self._font.measure(text) + 57, height=43, background=CARD,
                         highlightthickness=0, borderwidth=0, cursor='hand2', takefocus=True)
        self._trace = variable.trace_add('write', lambda *args: self._draw())
        self.bind('<ButtonRelease-1>', lambda event: self.invoke())
        self.bind('<space>', lambda event: self.invoke())
        self.bind('<Return>', lambda event: self.invoke())
        self.bind('<FocusIn>', lambda event: self._draw())
        self.bind('<FocusOut>', lambda event: self._draw())
        self._draw()

    def invoke(self):
        self.focus_set()
        self.variable.set(not self.variable.get())
        self.command()
        return 'break'

    def _draw(self):
        self.delete('all')
        enabled = self.variable.get()
        fill = '#245a9a' if enabled else '#3a3a3a'
        border = '#9dbbe2' if self.focus_get() == self else '#3474bd' if enabled else '#606060'
        if Image is not None:
            scale = 3
            bitmap = Image.new('RGB', (43 * scale, 43 * scale), CARD)
            draw = ImageDraw.Draw(bitmap)
            draw.rounded_rectangle((2*scale, 10*scale, 40*scale, 32*scale), radius=11*scale, fill=fill, outline=border, width=scale)
            x = 21 if enabled else 5
            draw.ellipse((x*scale, 13*scale, (x+16)*scale, 29*scale), fill='#f4f4f4' if enabled else '#c0c0c0')
            self._track_photo = ImageTk.PhotoImage(bitmap.resize((43,43), Image.Resampling.LANCZOS), master=self)
            self.create_image(0, 0, image=self._track_photo, anchor='nw')
        else:
            rounded(self, 2, 10, 38, 22, 11, fill=fill, outline=border)
            x = 21 if enabled else 5
            self.create_oval(x, 13, x+16, 29, fill=TEXT, outline='')
        self.create_text(49, 21, text=self.text, anchor='w', font=self._font, fill=TEXT)

    def destroy(self):
        self.variable.trace_remove('write', self._trace)
        super().destroy()


class Badge(tk.Canvas):
    PALETTES = {
        'neutral': ('#2b2b2b', '#c0c0c0', '#424242'),
        'success': ('#21392e', '#7ed4a4', '#365848'),
        'warn': ('#3b321f', '#e9c46b', '#655332'),
        'error': ('#3e2528', '#f19198', '#644047'),
        'accent': ('#233449', '#97bce7', '#3b526c'),
    }

    def __init__(self, parent, text='', variable=None, kind='neutral', dot=False, background=CARD):
        super().__init__(parent, height=33, background=background, borderwidth=0, highlightthickness=0)
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
        rounded(self, .5, .5, width - 1, 32, 16 if self.with_dot else 7, fill=fill, outline=border, width=1)
        if self.with_dot:
            self.create_oval(8, 13, 14, 19, fill=foreground, outline='')
        self.create_text(22 if self.with_dot else 8, 16, text=text, anchor='w', fill=foreground, font=self._font)

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
    def __init__(self, root, host=None):
        self.root, self.card, self.timer = root, None, None
        self.host = host or (lambda: root)
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
        self.card = RoundedCard(self.host(), padding=18, outline='#644047' if kind == 'error' else '#4c5e74')
        self.card.place(relx=1, x=-24, y=22, anchor='ne', width=540)
        row = ttk.Frame(self.card.body, style='Card.TFrame')
        row.pack(fill='x')
        ttk.Label(row, text=title, style='CardTitle.TLabel', foreground='#f19198' if kind == 'error' else '#9dbbe2').pack(side='left')
        Button(row, '×', self.close, kind='ghost', small=True).pack(side='right')
        ttk.Label(self.card.body, text=display, style='Card.TLabel', wraplength=500, justify='left').pack(fill='x', pady=(10, 0))
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
        self.on_open = lambda: None
        self.on_close = lambda: None
        self.backdrop_photo = None
        self._blurred_source = None

    @property
    def active(self):
        return self.frame is not None

    def _open(self, title, kind):
        self.close()
        self.on_open()
        self.previous_focus = self.root.focus_get()
        self.root.update_idletasks()
        self._blurred_source = None
        if Image is not None and sys.platform == 'win32' and self.root.winfo_ismapped():
            try:
                # Capture this Tk client HWND only, never the desktop/other
                # windows. Kept in memory and discarded when the panel closes.
                snapshot = ImageGrab.grab(window=self.root.winfo_id())
                self._blurred_source = snapshot.filter(ImageFilter.GaussianBlur(10))
            except (OSError, ValueError, tk.TclError):
                pass
        self.kind = kind
        self.frame = tk.Frame(self.root, background=PAGE)
        self.frame._blurred_backdrop = self._blurred_source
        self.frame.place(x=0, y=0, relwidth=1, relheight=1)
        self.frame.lift()
        self.background_label = tk.Label(self.frame, borderwidth=0, background=PAGE)
        self.background_label.place(x=0, y=0, relwidth=1, relheight=1)
        if self._blurred_source is not None:
            self.backdrop_photo = ImageTk.PhotoImage(self._blurred_source, master=self.frame)
            self.background_label.configure(image=self.backdrop_photo)
        self.frame.bind('<Configure>', self._resize_backdrop)
        self.card = RoundedCard(self.frame, padding=20, outline='#484848', background=PAGE)
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

    def _resize_backdrop(self, event):
        if event.widget != self.frame or event.width < 2 or event.height < 2 or not hasattr(self, 'card'):
            return
        if self._blurred_source is not None:
            size = (event.width, event.height)
            current = self.frame._blurred_backdrop
            if current.size != size:
                current = self._blurred_source.resize(size, Image.Resampling.LANCZOS)
                self.frame._blurred_backdrop = current
                self.backdrop_photo = ImageTk.PhotoImage(current, master=self.frame)
                self.background_label.configure(image=self.backdrop_photo)
                self.card.backdrop = current
        self.card.place_configure(width=min(800, max(440, event.width - 64)))
        self.card._draw()

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
        self.text_widget = tk.Text(area, height=rows, width=88, wrap='none', background='#181818', foreground='#dedede',
                                   selectbackground='#285d99', font=('Consolas', font_size(9)), relief='flat', borderwidth=0, padx=10, pady=10)
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
            self.on_close()
            try:
                self.frame.grab_release()
            except tk.TclError:
                pass
            self.frame.destroy()
            self.frame = None
            self.backdrop_photo = None
            self._blurred_source = None
            previous = getattr(self, 'previous_focus', None)
            if previous is not None and previous.winfo_exists():
                previous.focus_set()
        self.focusables = []
