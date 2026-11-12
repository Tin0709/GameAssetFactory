'use strict';

const $ = selector => document.querySelector(selector);
const $$ = selector => [...document.querySelectorAll(selector)];
const views = {
  'Animation MD2': 'animation', 'Valorie + Sabre': 'sabre', 'Cỏ MD2': 'grass',
  'Animation Showcase': 'showcase', 'Actions & Stuff': 'actions_stuff', 'TaCZ · Gun Animations': 'tacz'
};
const initialToken = location.hash.slice(1);
if (/^[\w-]{43}$/.test(initialToken)) {
  sessionStorage.setItem('checkpoint-session', initialToken);
  history.replaceState(null, '', location.pathname);
}
const sessionHeader = {'X-Checkpoint-Token': sessionStorage.getItem('checkpoint-session') || ''};
const settingsDialog = $('#settings-dialog');
const actionDialog = $('#action-dialog');
const confirmButton = $('#action-confirm');
const logList = $('#log-list');
const toast = $('#toast');
let current = null;
let visibleDialog = null;
let noticeId = null;
let toastTimer;
let logFingerprint = '';
let logFilter = 'all';
let offline = false;

function notify(title, detail) {
  clearTimeout(toastTimer);
  $('#toast-heading').textContent = title;
  $('#toast-detail').textContent = detail;
  toast.hidden = false;
  toastTimer = setTimeout(() => { toast.hidden = true; }, 4200);
}

async function send(action, fields = {}) {
  try {
    const response = await fetch('/action', {
      method: 'POST',
      headers: {...sessionHeader, 'Content-Type': 'application/json'},
      body: JSON.stringify({action, ...fields})
    });
    if (!response.ok) throw new Error('HTTP ' + response.status);
    return true;
  } catch {
    notify('Không gửi được thao tác', 'Thử lại hoặc mở lại Git Checkpoint Manager.');
    return false;
  }
}

function setTheme(theme) {
  document.documentElement.dataset.theme = theme;
  $('#theme-icon use').setAttribute('href', theme === 'light' ? '#i-moon' : '#i-sun');
}

function showLog(logs) {
  const fingerprint = JSON.stringify([logFilter, logs]);
  if (fingerprint === logFingerprint) return;
  logFingerprint = fingerprint;
  const keepAtEnd = logList.scrollHeight - logList.scrollTop - logList.clientHeight < 20;
  const position = logList.scrollTop;
  const fragment = document.createDocumentFragment();
  for (const line of logs) {
    if (logFilter !== 'all' && line.kind !== logFilter) continue;
    const row = document.createElement('div');
    row.className = 'log-line';
    const time = document.createElement('span');
    time.className = 'log-time';
    time.textContent = line.time;
    const message = document.createElement('span');
    message.className = 'log-message';
    message.textContent = line.message;
    row.append(time, message);
    fragment.append(row);
  }
  logList.replaceChildren(fragment);
  logList.scrollTop = keepAtEnd ? logList.scrollHeight : position;
}

function renderRepositories(repos, busy) {
  for (const card of $$('.repo-card')) {
    const info = repos[card.dataset.repo];
    if (!info) continue;
    const toggle = card.querySelector('input[type=checkbox]');
    toggle.checked = info.enabled;
    toggle.disabled = info.changed === null;
    const status = card.querySelector('[data-state]');
    status.className = 'state-label' + (info.issue ? ' alert' : info.enabled ? '' : ' off');
    status.textContent = info.issue ? 'Cần kiểm tra' : info.enabled ? 'Tự commit đang bật' :
      info.changed === null ? 'Đang đọc…' : 'Đã tạm dừng';
    status.title = info.message;
    const branch = card.querySelector('.branch');
    branch.textContent = branch.title = info.branch;
    const metrics = card.querySelectorAll('.repo-metric strong');
    for (const [index, value] of [info.changed, info.ahead].entries()) {
      metrics[index].textContent = value ?? '—';
      metrics[index].classList.toggle('warn', value > 0);
    }
    card.querySelector('.repo-sync').textContent =
      (info.behind === null ? 'GitHub chưa có dữ liệu so sánh' : 'GitHub thêm ' + info.behind + ' commit') +
      (info.checkpoint === '—' ? ' · Chưa có checkpoint' : ' · Checkpoint ' + info.checkpoint);
    card.querySelector('.path-block').textContent = info.path;
    const details = [info.branch, info.head, info.upstream,
      info.eligible === null ? '—' : info.eligible + ' / ' + info.ignored,
      info.staged === null ? '—' : info.staged ? 'Có' : 'Không'];
    card.querySelectorAll('.detail-line b').forEach((node, index) => { node.textContent = details[index]; });
    card.querySelector('[data-action="repo-refresh"]').disabled = busy;
    card.querySelector('[data-action="changes"]').disabled = busy;
    card.querySelector('[data-action="commit"]').disabled = busy || !info.changed;
    card.querySelector('[data-action="push"]').disabled = busy || info.changed === null || info.ahead === 0;
  }
}

function renderDialog(dialog, busy) {
  if (!dialog) {
    visibleDialog = null;
    if (actionDialog.open) actionDialog.close();
    return;
  }
  const details = dialog.kind === 'details';
  confirmButton.disabled = busy;
  if (visibleDialog === dialog.id) return;
  visibleDialog = dialog.id;
  $('#action-title').textContent = details ? 'Thay đổi · ' + dialog.title : dialog.title;
  $('#action-desc').textContent = details ? '' : dialog.text;
  const note = $('#action-note');
  note.hidden = details || (dialog.kind === 'push' && !dialog.private);
  note.classList.toggle('modal-warning', dialog.kind === 'push' && dialog.private);
  $('#action-note-text').textContent = dialog.private
    ? 'App sẽ kiểm tra repository PRIVATE trước khi push.'
    : 'Checkpoint tạo commit cục bộ. Push được thực hiện riêng.';
  $('#diff-preview').hidden = !details;
  $('#diff-preview').textContent = details ? dialog.text : '';
  confirmButton.hidden = details;
  confirmButton.textContent = dialog.kind === 'push' ? 'Push' : 'Commit ngay';
  if (settingsDialog.open) settingsDialog.close();
  if (!actionDialog.open) actionDialog.showModal();
}

function render(state) {
  current = state;
  setTheme(state.theme);
  $('#hero-interval').textContent = state.interval;
  $('#next-scan').textContent = state.busy ? '—' : state.remaining;
  renderRepositories(state.repos, state.busy);
  const repos = Object.values(state.repos);
  const enabled = repos.filter(repo => repo.enabled).length;
  const issues = repos.filter(repo => repo.issue).length;
  const total = name => repos.every(repo => repo[name] !== null) ? repos.reduce((sum, repo) => sum + repo[name], 0) : '—';
  $('#stat-enabled').textContent = enabled + '/' + repos.length;
  $('#stat-files').textContent = total('changed');
  $('#stat-ahead').textContent = total('ahead');
  $('#sidebar-count').textContent = enabled + '/' + repos.length + ' repos';
  $('#sidebar-progress').style.width = (repos.length ? 100 * enabled / repos.length : 0) + '%';
  $('.sidebar-bottom .status-light').classList.toggle('warn', !enabled);
  const systems = $$('.system-item');
  systems[0].querySelector('small').textContent = state.godot.running ? 'Đang chạy' :
    state.godot.available ? 'Đã cấu hình' : 'Chưa tìm thấy';
  systems[0].querySelector('.status-light').classList.toggle('warn', !state.godot.available);
  const bridgeLabel = state.bridge.starting ? 'Đang khởi động…' : state.bridge.label;
  systems[1].querySelector('small').textContent = bridgeLabel;
  systems[1].querySelector('.status-light').classList.toggle('warn', !state.bridge.connected);
  systems[2].querySelector('small').textContent = issues ? issues + ' cần kiểm tra' : state.busy ? 'Đang quét' : 'Đã đọc';
  systems[2].querySelector('.status-light').classList.toggle('warn', Boolean(issues));
  $('.blender .tool-caption').textContent = state.bridge.detail;
  const hint = $('.blender .tool-hint');
  hint.lastChild.textContent = ' ' + bridgeLabel;
  hint.classList.toggle('good', state.bridge.connected);
  hint.querySelector('.status-light').classList.toggle('warn', !state.bridge.connected);
  $('[data-action="start-mcp"]').disabled = state.bridge.starting;
  showLog(state.logs);
  renderDialog(state.dialog, state.busy);
  if (state.notice && state.notice.id !== noticeId) {
    const {id, title, detail, kind} = state.notice;
    noticeId = id;
    if (kind === 'copy') {
      if (navigator.clipboard) {
        navigator.clipboard.writeText(detail).then(() => notify('Đã sao chép đường dẫn', detail))
          .catch(() => notify('Sao chép đường dẫn này', detail));
      } else {
        notify('Sao chép đường dẫn này', detail);
      }
    } else {
      notify(title, detail);
    }
  }
}

async function poll() {
  try {
    const response = await fetch('/state', {headers: sessionHeader});
    if (!response.ok) throw new Error('Disconnected');
    const state = await response.json();
    if (state.repos) render(state);
    offline = false;
  } catch {
    if (!offline) notify('Mất kết nối với app', 'Mở lại Git Checkpoint Manager nếu cửa sổ chưa tự kết nối.');
    offline = true;
  } finally {
    setTimeout(poll, 650);
  }
}

$('#toast-close').addEventListener('click', () => { toast.hidden = true; });
$('#theme-toggle').addEventListener('click', () => {
  const theme = document.documentElement.dataset.theme === 'light' ? 'dark' : 'light';
  setTheme(theme);
  send('theme', {theme});
});
for (const button of $$('[data-close-dialog]')) {
  button.addEventListener('click', () => button.closest('dialog').close());
}
actionDialog.addEventListener('close', () => {
  if (visibleDialog) send('dismiss', {dialog: visibleDialog});
  visibleDialog = null;
});
confirmButton.addEventListener('click', () => {
  if (visibleDialog) send('confirm', {dialog: visibleDialog});
});
$('#save-settings').addEventListener('click', async () => {
  const seconds = $('#scan-seconds');
  if (!seconds.reportValidity()) return;
  if (await send('settings', {seconds: Number(seconds.value)})) settingsDialog.close();
});
for (const input of $$('.repo-card input[type=checkbox]')) {
  input.addEventListener('change', () => send('toggle', {
    repo: input.closest('.repo-card').dataset.repoName, enabled: input.checked
  }));
}
for (const button of $$('[data-filter]')) {
  button.addEventListener('click', () => {
    logFilter = button.dataset.filter;
    $$('[data-filter]').forEach(item => item.classList.toggle('active', item === button));
    if (current) showLog(current.logs);
  });
}
for (const link of $$('[data-nav]')) {
  link.addEventListener('click', () => $$('[data-nav]').forEach(item => item.classList.toggle('active', item === link)));
}
for (const button of $$('[data-action]')) {
  button.addEventListener('click', async () => {
    const action = button.dataset.action;
    if (action === 'settings') {
      $('#scan-seconds').value = current?.interval ?? 10;
      settingsDialog.showModal();
    } else if (action === 'copy-log') {
      const content = (current?.logs ?? []).map(line => line.time + '  ' + line.message).join('\n');
      try {
        await navigator.clipboard.writeText(content);
        notify('Đã sao chép nhật ký', 'Nhật ký của phiên hiện tại.');
      } catch {
        notify('Không thể sao chép', 'Bạn có thể chọn và sao chép trực tiếp trong nhật ký.');
      }
    } else if (action === 'shortcut' || action === 'copy-shortcut') {
      await send(action, {view: views[button.dataset.name]});
    } else {
      const repo = button.closest('.repo-card')?.dataset.repoName;
      await send(action, repo ? {repo} : {});
    }
  });
}
poll();
