from kitty.fast_data_types import wcswidth, get_boss, add_timer, set_os_window_title
import datetime
import json
import os
import fcntl

_timer_id = None

# OS window ID -> automatically assigned number
_os_ids = {}

# OS window ID -> tab ID -> display number
_tab_numbers = {}

# OS window ID -> last applied OS title
_last_os_titles = {}

# Shared label storage
_LABELS_PATH = os.path.expanduser(
    "~/.config/kitty/os-window-labels.json"
)
_INSTANCE_ID = str(os.getpid())
_LOCK_PATH = _LABELS_PATH + ".lock"

_os_labels = {}
_labels_mtime = object()


def allocate_number(used):
    number = 0
    while number in used:
        number += 1
    return number


def refresh_os_labels():
    global _labels_mtime, _os_labels

    try:
        mtime = os.stat(_LABELS_PATH).st_mtime_ns
    except OSError:
        mtime = None

    if mtime == _labels_mtime:
        return

    try:
        with open(_LOCK_PATH, "a+", encoding="utf-8") as lock:
            fcntl.flock(lock, fcntl.LOCK_SH)

            with open(_LABELS_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)

        _os_labels = data if isinstance(data, dict) else {}

    except (OSError, ValueError):
        _os_labels = {}

    try:
        _labels_mtime = os.stat(_LABELS_PATH).st_mtime_ns
    except OSError:
        _labels_mtime = None

def get_os_label(os_id):
    key = f"{_INSTANCE_ID}:{os_id}"
    return _os_labels.get(key, str(_os_ids[os_id]))

def cleanup_os_labels(live_os_ids):
    global _os_labels, _labels_mtime

    live_ids = {str(os_id) for os_id in live_os_ids}

    try:
        with open(_LOCK_PATH, "a+", encoding="utf-8") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)

            try:
                with open(_LABELS_PATH, "r", encoding="utf-8") as f:
                    labels = json.load(f)
            except (OSError, ValueError):
                labels = {}

            if not isinstance(labels, dict):
                labels = {}

            cleaned = {}

            for key, value in labels.items():
                if ":" not in key:
                    continue

                pid, os_id = key.split(":", 1)

                # 다른 Kitty 프로세스의 라벨은 살아 있을 때만 유지
                if pid != _INSTANCE_ID:
                    try:
                        os.kill(int(pid), 0)
                        cleaned[key] = value
                    except PermissionError:
                        cleaned[key] = value
                    except (ProcessLookupError, ValueError, OverflowError):
                        pass

                # 현재 Kitty 프로세스의 창은 실제 존재 여부 확인
                elif os_id in live_ids:
                    cleaned[key] = value

            if cleaned != labels:
                with open(_LABELS_PATH, "w", encoding="utf-8") as f:
                    json.dump(cleaned, f, ensure_ascii=False, indent=2)

            _os_labels = cleaned

    except OSError as e:
        print(f"[kitty-label] Failed to clean labels: {e}")

    try:
        _labels_mtime = os.stat(_LABELS_PATH).st_mtime_ns
    except OSError:
        _labels_mtime = None

def sync_numbers(boss=None):
    if boss is None:
        boss = get_boss()

    if boss is None:
        return

    refresh_os_labels()

    live_os_ids = set(boss.os_window_map.keys())
    cleanup_os_labels(live_os_ids)

    # Remove closed OS windows
    for os_id in list(_os_ids):
        if os_id not in live_os_ids:
            del _os_ids[os_id]
            _tab_numbers.pop(os_id, None)
            _last_os_titles.pop(os_id, None)

    # Assign IDs to new OS windows
    used = set(_os_ids.values())

    for os_id in boss.os_window_map:
        if os_id not in _os_ids:
            number = allocate_number(used)
            _os_ids[os_id] = number
            used.add(number)

    # Assign stable tab numbers
    for os_id, tm in boss.os_window_map.items():
        live_ids = {tab.id for tab in tm}
        numbers = _tab_numbers.setdefault(os_id, {})

        for tab_id in list(numbers):
            if tab_id not in live_ids:
                del numbers[tab_id]

        used = set(numbers.values())

        for tab_id in sorted(live_ids):
            if tab_id not in numbers:
                number = allocate_number(used)
                numbers[tab_id] = number
                used.add(number)


def update_os_window_title(os_id, tm):
    active_tab = tm.active_tab
    tab_title = active_tab.name if active_tab else ""

    label = get_os_label(os_id)
    title = f"{label}({tab_title})"

    if _last_os_titles.get(os_id) != title:
        set_os_window_title(os_id, title)
        _last_os_titles[os_id] = title


def redraw_tab_bar(timer_id=None):
    boss = get_boss()
    if boss is None:
        return

    sync_numbers(boss)

    for os_id, tm in boss.os_window_map.items():
        tm.mark_tab_bar_dirty()
        update_os_window_title(os_id, tm)


def ensure_clock_timer():
    global _timer_id

    if _timer_id is None:
        _timer_id = add_timer(redraw_tab_bar, 1.0, True)


# Catppuccin Mocha
BAR_BG = "#1e1e2e"

ACTIVE_INDEX_BG = "#cba6f7"
ACTIVE_INDEX_FG = "#1e1e2e"

INACTIVE_INDEX_BG = "#9399b2"
INACTIVE_INDEX_FG = "#1e1e2e"

INACTIVE_TITLE_BG = "#313244"
INACTIVE_TITLE_FG = "#cdd6f4"

ACTIVE_TITLE_BG = "#45475a"
ACTIVE_TITLE_FG = "#cdd6f4"


def rgb(color):
    return tuple(int(color[i:i+2], 16) for i in (1, 3, 5))


def style(screen, fg, bg):
    fr, fg_, fb = rgb(fg)
    br, bg_, bb = rgb(bg)

    sgr = (
        f"22;23;38;2;{fr};{fg_};{fb};"
        f"48;2;{br};{bg_};{bb}"
    )

    screen.apply_sgr(sgr)


def fit_text(text, width):
    if width <= 0:
        return ""

    if wcswidth(text) <= width:
        return text

    result = ""

    for char in text:
        if wcswidth(result + char + "…") > width:
            break
        result += char

    return result + "…"


def draw_tab(
    draw_data,
    screen,
    tab,
    before,
    max_tab_length,
    index,
    is_last,
    extra_data
):
    ensure_clock_timer()

    boss = get_boss()
    if boss is None:
        return screen.cursor.x

    sync_numbers(boss)

    # Find the OS window containing this tab
    os_id = next(
        (
            os_id
            for os_id, tm in boss.os_window_map.items()
            if any(t.id == tab.tab_id for t in tm)
        ),
        None
    )

    if os_id is None:
        return screen.cursor.x

    active = tab.is_active

    index_bg = ACTIVE_INDEX_BG if active else INACTIVE_INDEX_BG
    index_fg = ACTIVE_INDEX_FG if active else INACTIVE_INDEX_FG

    title_bg = ACTIVE_TITLE_BG if active else INACTIVE_TITLE_BG
    title_fg = ACTIVE_TITLE_FG if active else INACTIVE_TITLE_FG

    number = str(_tab_numbers[os_id][tab.tab_id])

    gap = 0 if is_last else 1
    available = max(0, max_tab_length - gap)

    # OS window label before the first tab
    if index == 1:
        label = f"[{get_os_label(os_id)}] "
        style(screen, "#cdd6f4", BAR_BG)
        screen.draw(label)

    # Tab number
    index_text = fit_text(f" {number} ", available)

    style(screen, index_fg, index_bg)
    screen.draw(index_text)

    available -= wcswidth(index_text)

    # Tab title
    if available > 0:
        if active:
            kitty_tab = boss.tab_for_id(tab.tab_id)
            window = kitty_tab.active_window if kitty_tab else None
            display_title = window.title if window else tab.title
        else:
            display_title = tab.title

        title_text = fit_text(f" {display_title} ", available)

        style(screen, title_fg, title_bg)
        screen.draw(title_text)

    # Separator
    if gap:
        style(screen, BAR_BG, BAR_BG)
        screen.draw(" " * gap)

    # Right-side status
    if is_last:
        active_tab = boss.active_tab
        tab_title = active_tab.name if active_tab else ""

        clock = datetime.datetime.now().strftime("%H:%M %d-%b-%y")
        status = f"\"{tab_title}\" {clock}"

        status_width = wcswidth(status)

        if screen.cursor.x + status_width + 2 < screen.columns:
            screen.cursor.x = screen.columns - status_width
            style(screen, "#cdd6f4", BAR_BG)
            screen.draw(status)

    return screen.cursor.x