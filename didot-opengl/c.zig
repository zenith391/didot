pub usingnamespace @cImport({
    @cInclude("GLFW/glfw3.h");
    @cInclude("GL/gl.h");
}); 

pub extern fn glGenBuffers(n: GLsizei, buffers: [*c]GLuint) void;
pub extern fn glGenVertexArrays(n: GLsizei, arrays: [*c]GLuint) void;
pub extern fn glBindBuffer(target: GLenum, buffer: GLuint) void;
pub extern fn glBufferData(target: GLenum, size: GLsizeiptr, data: ?*c_void, usage: GLenum) void;
pub extern fn glCreateShader(shader: GLenum) GLuint;
pub extern fn glShaderSource(shader: GLuint, count: GLsizei, string: *[:0]const GLchar, length: ?*c_int) void;
pub extern fn glCompileShader(shader: GLuint) void;
pub extern fn glCreateProgram() GLuint;
pub extern fn glAttachShader(program: GLuint, shader: GLuint) void;
pub extern fn glLinkProgram(program: GLuint) void;
pub extern fn glUseProgram(program: GLuint) void;
pub extern fn glGetAttribLocation(program: GLuint, name: [*:0]const GLchar) GLint;
pub extern fn glBindFragDataLocation(program: GLuint, colorNumber: GLuint, name: [*:0]const GLchar) void;
pub extern fn glVertexAttribPointer(index: GLuint, size: GLint, type: GLenum, normalized: GLboolean, stride: GLsizei, offset: GLint) void;
pub extern fn glBindVertexArray(array: GLuint) void;
pub extern fn glGetShaderiv(shader: GLuint, pname: GLenum, params: *GLint) void;
pub extern fn glEnableVertexAttribArray(index: GLuint) void;
pub extern fn glGetShaderInfoLog(shader: GLuint, maxLength: GLsizei, length: *GLsizei, infoLog: [*]GLchar) void;
pub extern fn glGetUniformLocation(shader: GLuint, name: [*:0]const GLchar) GLint;
pub extern fn glUniform1i(location: GLint, v0: GLint) void;
pub extern fn glUniformMatrix4fv(location: GLint, count: GLsizei, transpose: GLboolean, value: *const GLfloat) void;
