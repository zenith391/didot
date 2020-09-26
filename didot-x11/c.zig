const c = @cImport({
    @cInclude("X11/Xlib.h");
});

pub const Screen = c.Screen;
pub const _XPrivDisplay = c._XPrivDisplay;
pub const Window = c.Window;
pub const Display = c.Display;

pub extern fn XOpenDisplay([*c]const u8) ?*Display;
pub extern fn XCreateSimpleWindow(?*Display, Window, c_int, c_int, c_uint, c_uint, c_uint, c_ulong, c_ulong) Window;
pub extern fn XMapWindow(?*Display, Window) c_int;

pub inline fn ScreenOfDisplay(dpy: anytype, scr: Screen) Screen {
    return &(@import("std").meta.cast(_XPrivDisplay, dpy)).*.screens[scr];
}

pub inline fn DefaultRootWindow(dpy: anytype) @TypeOf(ScreenOfDisplay(dpy, DefaultScreen(dpy)).*.root) {
    return ScreenOfDisplay(dpy, DefaultScreen(dpy)).*.root;
}

pub inline fn WhitePixel(dpy: anytype, scr: anytype) c_ulong {
    return ScreenOfDisplay(dpy, scr).*.white_pixel;
}

pub inline fn BlackPixel(dpy: anytype, scr: anytype) c_ulong {
    return ScreenOfDisplay(dpy, scr).*.black_pixel;
}

pub inline fn DefaultScreen(dpy: anytype) c_int {
    return (@import("std").meta.cast(_XPrivDisplay, dpy)).*.default_screen;
}
