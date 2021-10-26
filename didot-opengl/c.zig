const c = @cImport({
    @cInclude("GL/gl.h");
});
pub usingnamespace c;

pub extern fn glGenBuffers(n: c.GLsizei, buffers: [*c]c.GLuint) void;
pub extern fn glGenVertexArrays(n: c.GLsizei, arrays: [*c]c.GLuint) void;
pub extern fn glBindBuffer(target: c.GLenum, buffer: c.GLuint) void;
pub extern fn glBufferData(target: c.GLenum, size: c.GLsizeiptr, data: ?*c_void, usage: c.GLenum) void;
pub extern fn glCreateShader(shader: c.GLenum) c.GLuint;
pub extern fn glShaderSource(shader: c.GLuint, count: c.GLsizei, string: *[:0]const c.GLchar, length: ?*c_int) void;
pub extern fn glCompileShader(shader: c.GLuint) void;
pub extern fn glCreateProgram() c.GLuint;
pub extern fn glAttachShader(program: c.GLuint, shader: c.GLuint) void;
pub extern fn glLinkProgram(program: c.GLuint) void;
pub extern fn glUseProgram(program: c.GLuint) void;
pub extern fn glGetAttribLocation(program: c.GLuint, name: [*:0]const c.GLchar) c.GLint;
pub extern fn glBindFragDataLocation(program: c.GLuint, colorNumber: c.GLuint, name: [*:0]const c.GLchar) void;
pub extern fn glVertexAttribPointer(index: c.GLuint, size: c.GLint, type: c.GLenum, normalized: c.GLboolean, stride: c.GLsizei, offset: c.GLint) void;
pub extern fn glBindVertexArray(array: c.GLuint) void;
pub extern fn glGetShaderiv(shader: c.GLuint, pname: c.GLenum, params: *c.GLint) void;
pub extern fn glEnableVertexAttribArray(index: c.GLuint) void;
pub extern fn glGetShaderInfoLog(shader: c.GLuint, maxLength: c.GLsizei, length: *c.GLsizei, infoLog: [*]c.GLchar) void;
pub extern fn glGetUniformLocation(shader: c.GLuint, name: [*:0]const c.GLchar) c.GLint;
pub extern fn glUniform1i(location: c.GLint, v0: c.GLint) void;
pub extern fn glUniform1f(location: c.GLint, v0: c.GLfloat) void;
pub extern fn glUniform3f(location: c.GLint, v0: c.GLfloat, v1: c.GLfloat, v2: c.GLfloat) void;
pub extern fn glUniformMatrix4fv(location: c.GLint, count: c.GLsizei, transpose: c.GLboolean, value: *const c.GLfloat) void;
