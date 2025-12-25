const std = @import("std");
const input = @import("input.zig");

pub const Size = struct {
    width: u32,
    height: u32,
};

pub const MouseZone = enum {
    unknown,
    viewport,
    panel_top,
    panel_bottom,
    panel_left,
    panel_right,
    panel_center,
    webview,
};

pub const KeyState = struct {
    down: bool = false,
    prev_down: bool = false,
};

pub const KeyboardState = struct {
    g: KeyState = .{},
    r: KeyState = .{},
    s: KeyState = .{},
};

pub const UIEventSink = struct {
    context: *anyopaque,
    mouse_move: ?*const fn (*anyopaque, i32, i32) void = null,
    mouse_button: ?*const fn (*anyopaque, input.MouseButton, bool, i32, i32) void = null,
    mouse_wheel: ?*const fn (*anyopaque, f32, f32, i32, i32) void = null,
};

pub const MouseState = struct {
    x: i32 = 0,
    y: i32 = 0,
    left_button_down: bool = false,
    right_button_down: bool = false,
    prev_left_button_down: bool = false,
    prev_right_button_down: bool = false,
    hover_zone: MouseZone = .unknown,
    alt_key_down: bool = false,
    delta_x: i32 = 0,
    delta_y: i32 = 0,
    prev_x: i32 = 0,
    prev_y: i32 = 0,
    wheel_delta_y_pos: f32 = 0,
    wheel_delta_y_neg: f32 = 0,
    last_ui_event_ns: i128 = 0,
};

pub const PlatformKeyAction = enum {
    down,
    repeat,
    up,
};

pub const Key = enum {
    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k,
    l,
    m,
    n,
    o,
    p,
    q,
    r,
    s,
    t,
    u,
    v,
    w,
    x,
    y,
    z,

    zero,
    one,
    two,
    three,
    four,
    five,
    six,
    seven,
    eight,
    nine,

    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,
    f13,
    f14,
    f15,
    f16,
    f17,
    f18,
    f19,
    f20,
    f21,
    f22,
    f23,
    f24,
    f25,

    kp_divide,
    kp_multiply,
    kp_subtract,
    kp_add,
    kp_0,
    kp_1,
    kp_2,
    kp_3,
    kp_4,
    kp_5,
    kp_6,
    kp_7,
    kp_8,
    kp_9,
    kp_decimal,
    kp_equal,
    kp_enter,

    enter,
    escape,
    tab,
    left_shift,
    right_shift,
    left_control,
    right_control,
    left_alt,
    right_alt,
    left_command,
    right_command,
    menu,
    num_lock,
    caps_lock,
    print,
    scroll_lock,
    pause,
    delete,
    home,
    end,
    page_up,
    page_down,
    insert,
    left,
    right,
    up,
    down,
    backspace,
    space,
    minus,
    equal,
    left_bracket,
    right_bracket,
    backslash,
    semicolon,
    apostrophe,
    comma,
    period,
    slash,
    grave,

    unknown,
};

pub const Keybind = struct {
    shift: ?bool = null,
    control: ?bool = null,
    alt: ?bool = null,
    command: ?bool = null,
    key: ?Key = null,
    also: ?[]const u8 = null,

    pub fn format(self: *const Keybind, writer: anytype) !void {
        var needs_space = false;
        if (self.control) |ctrl| {
            if (needs_space) try writer.writeByte(' ') else needs_space = true;
            if (!ctrl) try writer.writeByte('!');
            try writer.writeAll("ctrl");
        }

        if (self.command) |cmd| {
            if (needs_space) try writer.writeByte(' ') else needs_space = true;
            if (!cmd) try writer.writeByte('!');
            try writer.writeAll("cmd");
        }

        if (self.alt) |alt| {
            if (needs_space) try writer.writeByte(' ') else needs_space = true;
            if (!alt) try writer.writeByte('!');
            try writer.writeAll("alt");
        }

        if (self.shift) |shift| {
            if (needs_space) try writer.writeByte(' ') else needs_space = true;
            if (!shift) try writer.writeByte('!');
            try writer.writeAll("shift");
        }

        if (self.key) |key| {
            if (needs_space) try writer.writeByte(' ') else needs_space = true;
            try writer.writeAll(@tagName(key));
        }
    }
};

pub const Mod = enum(u16) {
    none = 0,

    lshift = 0b00000001,
    rshift = 0b00000010,

    lcontrol = 0b00000100,
    rcontrol = 0b00001000,

    lalt = 0b00010000,
    ralt = 0b00100000,

    lcommand = 0b01000000,
    rcommand = 0b10000000,

    // make non-exhaustive so that we can take combinations of the values
    _,

    pub fn has(self: Mod, other: Mod) bool {
        const s: u16 = @intFromEnum(self);
        const t: u16 = @intFromEnum(other);
        return (s & t) != 0;
    }

    //returns whether shift is the only modifier
    pub fn shiftOnly(self: Mod) bool {
        if (self == .none) return false;
        const lsh = @intFromEnum(Mod.lshift);
        const rsh = @intFromEnum(Mod.rshift);
        const mask = lsh | rsh;
        const self_int = @intFromEnum(self);
        return (self_int & mask) == self_int;
    }

    pub fn shift(self: Mod) bool {
        return self.has(.lshift) or self.has(.rshift);
    }

    pub fn control(self: Mod) bool {
        return self.has(.lcontrol) or self.has(.rcontrol);
    }

    pub fn alt(self: Mod) bool {
        return self.has(.lalt) or self.has(.ralt);
    }

    pub fn command(self: Mod) bool {
        return self.has(.lcommand) or self.has(.rcommand);
    }

    ///combine two modifiers
    pub fn combine(self: *Mod, other: Mod) void {
        const s: u16 = @intFromEnum(self.*);
        const t: u16 = @intFromEnum(other);
        self.* = @enumFromInt(s | t);
    }

    ///remove modifier
    pub fn unset(self: *Mod, other: Mod) void {
        const s: u16 = @intFromEnum(self.*);
        const t: u16 = @intFromEnum(other);
        self.* = @enumFromInt(s & (~t));
    }

    /// True if matches the named keybind ignoring Keybind.key (follows
    /// Keybind.also).  See `matchKeyBind`.
    pub fn matchBind(_: Mod) bool {
        return false;
    }

    /// True if matches the named keybind ignoring Keybind.key (ignores
    /// Keybind.also).   Usually you want `matchBind`.
    pub fn matchKeyBind(self: Mod, kb: Keybind) bool {
        return ((kb.shift == null or kb.shift.? == self.shift()) and
            (kb.control == null or kb.control.? == self.control()) and
            (kb.alt == null or kb.alt.? == self.alt()) and
            (kb.command == null or kb.command.? == self.command()));
    }

    pub fn format(self: *const Mod, writer: anytype) !void {
        try writer.writeAll("Mod(");
        var needs_separator = false;

        if (self.* == .none) {
            try writer.writeAll("none");
        } else {
            const mod_fields = comptime std.meta.fieldNames(Mod);
            inline for (mod_fields[0..9]) |field_name| {
                if (self.has(@field(Mod, field_name))) {
                    if (needs_separator) try writer.writeAll(", ") else needs_separator = true;
                    try writer.writeAll(field_name);
                }
            }
        }

        try writer.writeAll(")");
    }
};

pub const PlatformKeyEvent = struct {
    code: Key,
    action: PlatformKeyAction,
    mods: Mod,
};

pub const PlatformTextEvent = struct {
    pub const capacity: usize = 8;

    len: u8 = 0,
    buffer: [capacity]u8 = [_]u8{0} ** capacity,

    pub fn slice(self: *const PlatformTextEvent) []const u8 {
        const count: usize = @intCast(self.len);
        return self.buffer[0..count];
    }
};
