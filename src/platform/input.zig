pub const MouseButton = enum {
    left,
    middle,
    right,
    back,
    forward,

    pub const max = MouseButton.forward;
};

pub const CursorType = enum {
    auto,
    default,
    none,

    pointer,
    context_menu,
    help,

    text,
    vertical_text,
    select,

    grab,
    grabbing,
    copy,
    move,
    alias,
    not_allowed,

    resize_all,
    resize_col,
    resize_row,
    resize_n,
    resize_ne,
    resize_nw,
    resize_s,
    resize_se,
    resize_sw,
    resize_e,
    resize_w,

    scroll_all,

    zoom_in,
    zoom_out,

    wait,
    progress,

    crosshair,
    cell,
};
