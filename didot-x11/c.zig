//! Manually redefined bindings for X11 (as the generated one are bugged)
const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("GL/glx.h");
});
const std = @import("std");

pub const Screen = c.Screen;
pub const _XPrivDisplay = c._XPrivDisplay;
pub const XSetWindowAttributes = c.XSetWindowAttributes;
pub const XWindowAttributes = c.XWindowAttributes;
pub const Window = c.Window;
pub const Display = c.Display;
pub const XEvent = c.XEvent;
pub const Colormap = c.Colormap;
pub const Visual = c.Visual;

pub const CWBackPixmap = @as(c_long, 1) << 0;
pub const CWBackPixel = @as(c_long, 1) << 1;
pub const CWBorderPixmap = @as(c_long, 1) << 2;
pub const CWBorderPixel = @as(c_long, 1) << 3;
pub const CWBitGravity = @as(c_long, 1) << 4;
pub const CWWinGravity = @as(c_long, 1) << 5;
pub const CWBackingStore = @as(c_long, 1) << 6;
pub const CWBackingPlanes = @as(c_long, 1) << 7;
pub const CWBackingPixel = @as(c_long, 1) << 8;
pub const CWOverrideRedirect = @as(c_long, 1) << 9;
pub const CWSaveUnder = @as(c_long, 1) << 10;
pub const CWEventMask = @as(c_long, 1) << 11;
pub const CWDontPropagate = @as(c_long, 1) << 12;
pub const CWColormap = @as(c_long, 1) << 13;
pub const CWCursor = @as(c_long, 1) << 14;

pub const KeyPressMask = @as(c_long, 1) << 0;
pub const KeyReleaseMask = @as(c_long, 1) << 1;
pub const ButtonPressMask = @as(c_long, 1) << 2;
pub const ButtonReleaseMask = @as(c_long, 1) << 3;
pub const EnterWindowMask = @as(c_long, 1) << 4;
pub const LeaveWindowMask = @as(c_long, 1) << 5;
pub const PointerMotionMask = @as(c_long, 1) << 6;
pub const PointerMotionHintMask = @as(c_long, 1) << 7;
pub const Button1MotionMask = @as(c_long, 1) << 8;
pub const Button2MotionMask = @as(c_long, 1) << 9;
pub const Button3MotionMask = @as(c_long, 1) << 10;
pub const Button4MotionMask = @as(c_long, 1) << 11;
pub const Button5MotionMask = @as(c_long, 1) << 12;
pub const ButtonMotionMask = @as(c_long, 1) << 13;
pub const KeymapStateMask = @as(c_long, 1) << 14;
pub const ExposureMask = @as(c_long, 1) << 15;
pub const VisibilityChangeMask = @as(c_long, 1) << 16;
pub const StructureNotifyMask = @as(c_long, 1) << 17;
pub const ResizeRedirectMask = @as(c_long, 1) << 18;
pub const SubstructureNotifyMask = @as(c_long, 1) << 19;
pub const SubstructureRedirectMask = @as(c_long, 1) << 20;
pub const FocusChangeMask = @as(c_long, 1) << 21;
pub const PropertyChangeMask = @as(c_long, 1) << 22;
pub const ColormapChangeMask = @as(c_long, 1) << 23;
pub const OwnerGrabButtonMask = @as(c_long, 1) << 24;

pub const None = c.None;
pub const CopyFromParent = c.CopyFromParent;
pub const AllocNone = c.AllocNone;
pub const NotUseful = c.NotUseful;
pub const WhenMapped = c.WhenMapped;
pub const Always = c.Always;
pub const ForgetGravity = c.ForgetGravity;
pub const NorthWestGravity = c.NorthWestGravity;
pub const InputOutput = c.InputOutput;

// GLX
pub const GLint = c.GLint;
pub const GLXContext = c.GLXContext;
pub const GLXDrawable = c.GLXDrawable;
pub const XVisualInfo = c.XVisualInfo;
pub const GL_TRUE = c.GL_TRUE;
pub const GLX_RGBA = c.GLX_RGBA;
pub const GLX_DEPTH_SIZE = c.GLX_DEPTH_SIZE;
pub const GLX_DOUBLEBUFFER = c.GLX_DOUBLEBUFFER;

pub extern fn XOpenDisplay([*c]const u8) ?*Display;
pub extern fn XCreateSimpleWindow(?*Display, Window, c_int, c_int, c_uint, c_uint, c_uint, c_ulong, c_ulong) Window;
pub extern fn XMapWindow(?*Display, Window) c_int;
pub extern fn XMoveWindow(?*Display, Window, c_int, c_int) c_int;
pub extern fn XFlush(?*Display) c_int;
pub extern fn XInitThreads() c_int;
pub extern fn XCreateColormap(?*Display, Window, [*c]Visual, c_int) Colormap;
pub extern fn XCreateWindow(?*Display, Window, c_int, c_int, c_uint, c_uint, c_uint, c_int, c_uint, [*c]Visual, c_ulong, [*c]XSetWindowAttributes) Window;
pub extern fn XStoreName(?*Display, Window, [*c]const u8) c_int;
pub extern fn XGetWindowAttributes(?*Display, Window, [*c]XWindowAttributes) c_int;
pub extern fn XNextEvent(?*Display, [*c]XEvent) c_int;
pub extern fn XPending(?*Display) c_int;
pub extern fn XDestroyWindow(?*Display, Window) c_int;

pub extern fn glXChooseVisual(dpy: ?*Display, screen: c_int, attribList: [*c]c_int) [*c]XVisualInfo;
pub extern fn glXCreateContext(dpy: ?*Display, vis: [*c]XVisualInfo, shareList: GLXContext, direct: c_int) GLXContext;
pub extern fn glXMakeCurrent(dpy: ?*Display, drawable: GLXDrawable, ctx: GLXContext) c_int;
pub extern fn glXSwapBuffers(dpy: ?*Display, drawable: GLXDrawable) void;

pub inline fn ScreenOfDisplay(dpy: anytype, scr: c_int) [*c]Screen {
    return &(std.meta.cast(_XPrivDisplay, dpy)).*.screens[@intCast(usize, scr)];
}

pub inline fn DefaultRootWindow(dpy: anytype) Window {
    return ScreenOfDisplay(dpy, DefaultScreen(dpy)).*.root;
}

pub inline fn WhitePixel(dpy: anytype, scr: anytype) c_ulong {
    return ScreenOfDisplay(dpy, scr).*.white_pixel;
}

pub inline fn BlackPixel(dpy: anytype, scr: anytype) c_ulong {
    return ScreenOfDisplay(dpy, scr).*.black_pixel;
}

pub inline fn DefaultScreen(dpy: anytype) c_int {
    return (std.meta.cast(_XPrivDisplay, dpy)).*.default_screen;
}
