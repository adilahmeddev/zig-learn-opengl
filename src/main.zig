const std = @import("std");
const glfw = @import("mach-glfw");
const gl = @import("gl");
const glfw_log = std.log.scoped(.glfw);

fn logGLFWError(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    glfw_log.err("{}: {s}\n", .{ error_code, description });
}
const log = std.log.scoped(.Engine);

const vertexShaderSource: [:0]const u8 =
    \\#version 410 core
    \\layout (location = 0) in vec4 aPos;
    \\
    \\void main()
    \\{
    \\   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
    \\}
    \\
;

const fragmentShaderSource: [:0]const u8 =
    \\#version 410 core
    \\out vec4 a_Color;
    \\void main()
    \\{
    \\   a_Color = vec4(1.0, 0.5, 0.2, 1.0);
    \\}
    \\
;

/// Default GLFW error handling callback
fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("glfw: {}: {s}\n", .{ error_code, description });
}
var gl_procs: gl.ProcTable = undefined;
pub fn main() !void {
    var success: c_int = undefined;
    glfw.setErrorCallback(logGLFWError);

    if (!glfw.init(.{})) {
        glfw_log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        return error.GLFWInitFailed;
    }
    defer glfw.terminate();

    const window = glfw.Window.create(640, 480, "mach-glfw + OpenGL", null, null, .{
        .context_version_major = gl.info.version_major,
        .context_version_minor = gl.info.version_minor,
        .opengl_profile = .opengl_core_profile,
        .opengl_forward_compat = true,
    }) orelse {
        glfw_log.err("failed to create GLFW window: {?s}", .{glfw.getErrorString()});
        return error.CreateWindowFailed;
    };
    defer window.destroy();

    // Make the window's OpenGL context current.
    glfw.makeContextCurrent(window);
    defer glfw.makeContextCurrent(null);

    // Enable VSync to avoid drawing more often than necessary.
    glfw.swapInterval(1);

    // Initialize the OpenGL procedure table.
    if (!gl_procs.init(glfw.getProcAddress)) {
        log.err("failed to load OpenGL functions", .{});
        return error.GLInitFailed;
    }

    // Make the OpenGL procedure table current.
    gl.makeProcTableCurrent(&gl_procs);
    defer gl.makeProcTableCurrent(null);

    const vertexShader = gl.CreateShader(gl.VERTEX_SHADER);
    if (vertexShader == 0) return error.CreateVertexShaderFailed;
    defer gl.DeleteShader(vertexShader);
    gl.ShaderSource(
        vertexShader,
        1,
        (&vertexShaderSource.ptr)[0..1],
        (&@as(c_int, @intCast(vertexShaderSource.len)))[0..1],
    );
    gl.CompileShader(vertexShader);

    var info_log_buf: [512:0]u8 = undefined;
    gl.GetShaderiv(vertexShader, gl.COMPILE_STATUS, &success);
    // check for shader compile errors
    if (success == gl.FALSE) {
        gl.GetShaderInfoLog(vertexShader, info_log_buf.len, null, &info_log_buf);
        log.err("{s}", .{std.mem.sliceTo(&info_log_buf, 0)});
        return error.CompileVertexShaderFailed;
    }

    // fragment shader
    const fragmentShader = gl.CreateShader(gl.FRAGMENT_SHADER);
    if (fragmentShader == 0) return error.CreateFragmentShaderFailed;
    defer gl.DeleteShader(fragmentShader);
    gl.ShaderSource(
        fragmentShader,
        1,
        (&fragmentShaderSource.ptr)[0..1],
        (&@as(c_int, @intCast(fragmentShaderSource.len)))[0..1],
    );
    gl.CompileShader(fragmentShader);

    // check for shader compile errors
    gl.GetShaderiv(fragmentShader, gl.COMPILE_STATUS, &success);
    if (success == gl.FALSE) {
        gl.GetShaderInfoLog(fragmentShader, info_log_buf.len, null, &info_log_buf);
        log.err("{s}", .{std.mem.sliceTo(&info_log_buf, 0)});
        return error.CompileFragmentShaderFailed;
    }
    // link shaders
    const shaderProgram = gl.CreateProgram();
    if (shaderProgram == 0) return error.CreateProgramFailed;
    defer gl.DeleteProgram(shaderProgram);
    gl.AttachShader(shaderProgram, vertexShader);
    gl.AttachShader(shaderProgram, fragmentShader);
    gl.LinkProgram(shaderProgram);

    // check for linking errors
    gl.GetProgramiv(shaderProgram, gl.LINK_STATUS, &success);
    if (success == gl.FALSE) {
        gl.GetProgramInfoLog(shaderProgram, info_log_buf.len, null, &info_log_buf);
        log.err("{s}", .{std.mem.sliceTo(&info_log_buf, 0)});
        return error.CreateShaderProgramFailed;
    }
    const vertices = [_]f32{
        0.5,  0.5,  0.0,
        0.5,  -0.5, 0.0,
        -0.5, -0.5, 0.0,
        -0.5, 0.5,  0.0,
    };
    const indices = [_]u8{
        0, 1, 3,
        1, 2, 3,
    };

    var vao: c_uint = undefined;
    gl.GenVertexArrays(1, (&vao)[0..1]);
    defer gl.DeleteVertexArrays(1, (&vao)[0..1]);

    // Vertex Buffer Object (VBO), holds vertex data.
    var vbo: c_uint = undefined;
    gl.GenBuffers(1, (&vbo)[0..1]);
    defer gl.DeleteBuffers(1, (&vbo)[0..1]);

    // Index Buffer Object (IBO), maps indices to vertices (to enable reusing vertices).
    var ebo: c_uint = undefined;
    gl.GenBuffers(1, (&ebo)[0..1]);
    defer gl.DeleteBuffers(1, (&ebo)[0..1]);

    gl.BindVertexArray(vao);
    defer gl.BindVertexArray(0);
    {
        gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
        defer gl.BindBuffer(gl.ARRAY_BUFFER, 0);
        gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.STATIC_DRAW);

        const posat: c_uint = @intCast(gl.GetAttribLocation(shaderProgram, "aPos"));
        gl.EnableVertexAttribArray(posat);
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), 0);
    }
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);

    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, gl.STATIC_DRAW);

    // Wait for the user to close the window.

    while (!window.shouldClose()) {
        glfw.pollEvents();
        if (window.getKey(glfw.Key.escape) == glfw.Action.press) {
            window.setShouldClose(true);
        }

        gl.ClearColor(1, 1, 1, 1);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        gl.UseProgram(shaderProgram);
        defer gl.UseProgram(0);
        gl.BindVertexArray(vao);
        defer gl.BindVertexArray(0);

        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_BYTE, 0);
        window.swapBuffers();
    }
}
