#!/usr/bin/env python3
"""
lib/clean/clean_tui.py — Interactive dropdown accordion TUI for Clean Mac.
Supports mouse clicks on category headings, arrow keys, and hotkeys.
"""

import sys
import os
import curses

def parse_items(tsv_file):
    categories = {}
    if not os.path.exists(tsv_file):
        return categories

    with open(tsv_file, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            parts = line.strip("\r\n").split("\t")
            if len(parts) < 7:
                continue
            cat, label, folder, size_h, size_kb_str, path, mode = parts[:7]
            try:
                size_kb = int(size_kb_str)
            except ValueError:
                size_kb = 0

            if cat not in categories:
                categories[cat] = {
                    "name": cat,
                    "expanded": False,
                    "selected": True,
                    "total_kb": 0,
                    "items": []
                }

            # Build display name: label + folder name (no whole path)
            display = label
            if folder and folder != label and folder not in label:
                display = f"{label}: {folder}"

            categories[cat]["total_kb"] += size_kb
            categories[cat]["items"].append({
                "label": label,
                "folder": folder,
                "display": display,
                "size_h": size_h,
                "size_kb": size_kb,
                "path": path,
                "mode": mode,
                "selected": True
            })

    return categories

def format_size(kb):
    if kb >= 1048576:
        return f"{kb / 1048576:.1f} GB"
    elif kb >= 1024:
        return f"{kb / 1024:.1f} MB"
    elif kb > 0:
        return f"{kb} KB"
    else:
        return "0 B"

def _confirm_clean(stdscr, item_count, total_kb):
    """Modal yes/no prompt. Returns True only on an explicit 'y'."""
    h, w = stdscr.getmaxyx()
    msg1 = f" Clean {item_count} item{'s' if item_count != 1 else ''} (~{format_size(total_kb)})? "
    msg2 = " [y] Yes, delete   [n / any other key] Cancel "
    box_w = max(len(msg1), len(msg2)) + 4
    box_h = 4
    y0 = max(0, (h - box_h) // 2)
    x0 = max(0, (w - box_w) // 2)
    try:
        win = curses.newwin(box_h, box_w, y0, x0)
        win.attrset(curses.color_pair(3) | curses.A_BOLD)
        win.box()
        win.addstr(1, (box_w - len(msg1)) // 2, msg1, curses.A_BOLD)
        win.addstr(2, (box_w - len(msg2)) // 2, msg2, curses.A_DIM)
        win.refresh()
        key = win.getch()
    except curses.error:
        key = -1
    return key in (ord('y'), ord('Y'))

def main(stdscr, tsv_file, out_file):
    curses.curs_set(0)
    stdscr.keypad(True)
    curses.mousemask(curses.ALL_MOUSE_EVENTS | curses.REPORT_MOUSE_POSITION)

    # Initialize colors if supported
    if curses.has_colors():
        curses.start_color()
        curses.use_default_colors()
        curses.init_pair(1, curses.COLOR_CYAN, -1)     # Cyan header/icons
        curses.init_pair(2, curses.COLOR_GREEN, -1)    # Green checked
        curses.init_pair(3, curses.COLOR_YELLOW, -1)   # Yellow warning/size
        curses.init_pair(4, curses.COLOR_BLACK, curses.COLOR_CYAN) # Inverted cursor
        curses.init_pair(5, curses.COLOR_MAGENTA, -1)  # Hotkeys
    
    cat_dict = parse_items(tsv_file)
    cat_list = list(cat_dict.values())

    # Start fully collapsed — items are already pre-selected, so the list is
    # scannable by category size/name alone without wading through every item.
    for c in cat_list:
        c["expanded"] = False

    cursor_idx = 0
    scroll_top = 0

    while True:
        stdscr.erase()
        h, w = stdscr.getmaxyx()

        # Build flat visible rows: (type, cat_idx, item_idx)
        # type: 'cat' or 'item'
        rows = []
        for c_idx, c in enumerate(cat_list):
            rows.append(('cat', c_idx, -1))
            if c["expanded"]:
                for i_idx in range(len(c["items"])):
                    rows.append(('item', c_idx, i_idx))

        # Clamp cursor
        if not rows:
            cursor_idx = 0
        else:
            cursor_idx = max(0, min(cursor_idx, len(rows) - 1))

        # Header area (3 lines)
        title = " MacCleanUp — Clean Mac "
        banner = " ↑↓ Move   →/l Open   ←/h Close   Space Select   c Clean "
        stdscr.addstr(0, 0, title[:w].center(w), curses.A_BOLD | curses.color_pair(1))
        stdscr.addstr(1, 0, banner[:w].center(w), curses.A_DIM)

        # Summary calculations
        sel_kb = sum(
            it["size_kb"]
            for c in cat_list
            for it in c["items"]
            if it["selected"]
        )
        total_kb = sum(c["total_kb"] for c in cat_list)
        summary_str = f" Selected to Clean: ~{format_size(sel_kb)} of ~{format_size(total_kb)} "
        stdscr.addstr(2, 2, summary_str[:w-4], curses.A_BOLD | curses.color_pair(3))

        stdscr.hline(3, 0, curses.ACS_HLINE, w)

        content_h = max(1, h - 6)

        # Handle scrolling
        if cursor_idx < scroll_top:
            scroll_top = cursor_idx
        elif cursor_idx >= scroll_top + content_h:
            scroll_top = cursor_idx - content_h + 1

        # Visible line mapping for mouse clicks: display_y -> row_idx
        click_map = {}

        # Render rows
        for line_y in range(content_h):
            r_idx = scroll_top + line_y
            if r_idx >= len(rows):
                break
            screen_y = 4 + line_y
            click_map[screen_y] = r_idx

            rtype, c_idx, i_idx = rows[r_idx]
            cat = cat_list[c_idx]
            is_cursor = (r_idx == cursor_idx)
            attr = curses.color_pair(4) if is_cursor else curses.A_NORMAL

            if rtype == 'cat':
                arrow = "▼" if cat["expanded"] else "▶"
                check = "●" if cat["selected"] else "○"
                c_size = format_size(cat["total_kb"])
                count_str = f"({len(cat['items'])} items)"
                prefix = f" {arrow} [{c_idx+1}] {check} {cat['name']} "
                suffix = f" {c_size:>9} {count_str:>11} "

                dots_len = max(1, w - len(prefix) - len(suffix) - 1)
                line_str = prefix + ("·" * dots_len) + suffix
                try:
                    stdscr.addstr(screen_y, 0, line_str[:w-1], attr | curses.A_BOLD)
                except curses.error:
                    pass

            elif rtype == 'item':
                item = cat["items"][i_idx]
                is_last = (i_idx == len(cat["items"]) - 1)
                tree_char = "└──" if is_last else "├──"
                check = "●" if item["selected"] else "○"
                i_size = item["size_h"]
                # ONLY folder display name, no path!
                prefix = f"     {tree_char} {check} {item['display']} "
                suffix = f" {i_size:>10} "
                dots_len = max(1, w - len(prefix) - len(suffix) - 1)
                line_str = prefix + (" " * dots_len) + suffix
                try:
                    stdscr.addstr(screen_y, 0, line_str[:w-1], attr)
                except curses.error:
                    pass

        # Footer actions
        stdscr.hline(h - 2, 0, curses.ACS_HLINE, w)
        footer = " [e] Expand All  [x] Collapse All  [a] Select/Deselect All  [c] Clean Selected  [q] Quit "
        try:
            stdscr.addstr(h - 1, 0, footer[:w-1], curses.A_DIM)
        except curses.error:
            pass

        stdscr.refresh()

        # Input handling
        try:
            key = stdscr.getch()
        except KeyboardInterrupt:
            return 2  # Cancelled

        if key in (ord('q'), ord('Q'), 27):  # 'q' or ESC
            return 2

        elif key == curses.KEY_MOUSE:
            try:
                _, mx, my, _, bstate = curses.getmouse()
                if my in click_map:
                    clicked_r = click_map[my]
                    cursor_idx = clicked_r
                    rtype, c_idx, i_idx = rows[clicked_r]
                    if rtype == 'cat':
                        # If clicked on header, toggle dropdown (or checkbox if clicked on check)
                        cat = cat_list[c_idx]
                        if 4 <= mx <= 12:  # Clicked near checkbox
                            cat["selected"] = not cat["selected"]
                            for it in cat["items"]:
                                it["selected"] = cat["selected"]
                        else:  # Clicked on arrow/title -> Toggle dropdown!
                            cat["expanded"] = not cat["expanded"]
                    elif rtype == 'item':
                        it = cat_list[c_idx]["items"][i_idx]
                        it["selected"] = not it["selected"]
                        # Update category select status
                        cat_list[c_idx]["selected"] = any(x["selected"] for x in cat_list[c_idx]["items"])
            except curses.error:
                pass

        elif key in (curses.KEY_UP, ord('k')):
            cursor_idx = max(0, cursor_idx - 1)

        elif key in (curses.KEY_DOWN, ord('j')):
            cursor_idx = min(len(rows) - 1, cursor_idx + 1)

        elif key == curses.KEY_PPAGE:
            cursor_idx = max(0, cursor_idx - content_h)

        elif key == curses.KEY_NPAGE:
            cursor_idx = min(len(rows) - 1, cursor_idx + content_h)

        elif key in (curses.KEY_RIGHT, ord('l'), ord('L')):  # Open dropdown
            if rows:
                rtype, c_idx, i_idx = rows[cursor_idx]
                if rtype == 'cat':
                    cat_list[c_idx]["expanded"] = True

        elif key in (curses.KEY_LEFT, ord('h'), ord('H')):  # Close dropdown
            if rows:
                rtype, c_idx, i_idx = rows[cursor_idx]
                if rtype == 'cat':
                    cat_list[c_idx]["expanded"] = False
                elif rtype == 'item':
                    # Collapse the parent category and jump the cursor to its header
                    cat_list[c_idx]["expanded"] = False
                    for r_idx2, r in enumerate(rows):
                        if r[0] == 'cat' and r[1] == c_idx:
                            cursor_idx = r_idx2
                            break

        elif key in (10, 13, curses.KEY_ENTER):  # Enter key
            if rows:
                rtype, c_idx, i_idx = rows[cursor_idx]
                if rtype == 'cat':
                    # Dropdown toggle!
                    cat_list[c_idx]["expanded"] = not cat_list[c_idx]["expanded"]
                elif rtype == 'item':
                    # Toggle item selection
                    it = cat_list[c_idx]["items"][i_idx]
                    it["selected"] = not it["selected"]

        elif key == ord(' '):  # Space key -> toggle selection
            if rows:
                rtype, c_idx, i_idx = rows[cursor_idx]
                if rtype == 'cat':
                    cat = cat_list[c_idx]
                    cat["selected"] = not cat["selected"]
                    for it in cat["items"]:
                        it["selected"] = cat["selected"]
                elif rtype == 'item':
                    it = cat_list[c_idx]["items"][i_idx]
                    it["selected"] = not it["selected"]
                    cat_list[c_idx]["selected"] = any(x["selected"] for x in cat_list[c_idx]["items"])

        elif key in (ord('e'), ord('E')):  # Expand all
            for c in cat_list:
                c["expanded"] = True

        elif key in (ord('x'), ord('X')):  # Collapse all
            for c in cat_list:
                c["expanded"] = False

        elif key in (ord('a'), ord('A')):  # Select / Deselect all
            all_sel = all(c["selected"] for c in cat_list)
            for c in cat_list:
                c["selected"] = not all_sel
                for it in c["items"]:
                    it["selected"] = not all_sel

        elif ord('1') <= key <= ord('9'):  # Number hotkey to toggle dropdown
            target_num = key - ord('1')
            if target_num < len(cat_list):
                cat_list[target_num]["expanded"] = not cat_list[target_num]["expanded"]

        elif key in (ord('c'), ord('C')):  # Clean Selected — asks for confirmation first
            sel_items = [it for c in cat_list for it in c["items"] if it["selected"]]
            if not sel_items:
                continue
            sel_kb_confirm = sum(it["size_kb"] for it in sel_items)
            if _confirm_clean(stdscr, len(sel_items), sel_kb_confirm):
                with open(out_file, "w", encoding="utf-8") as out:
                    for it in sel_items:
                        out.write(f"{it['path']}\t{it['mode']}\t{it['display']}\t{it['size_h']}\t{it['size_kb']}\n")
                return 0  # Confirmed, proceed to delete

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: clean_tui.py <input_tsv> <output_approved>")
        sys.exit(1)

    tsv_in = sys.argv[1]
    out_target = sys.argv[2]

    try:
        exit_code = curses.wrapper(main, tsv_in, out_target)
        sys.exit(exit_code)
    except Exception as e:
        sys.exit(1)
