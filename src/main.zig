const std = @import("std");
const glfw = @import("mach-glfw");
const gl = @import("zgl");

const log = std.log.scoped(.Engine);

const vertexShaderSource = [_][]const u8{
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\void main()
    \\{
    \\   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
    \\}
};

const fragmentShaderSource = [_][]const u8{
    \\#version 330 core
    \\out vec4 FragColor;
    \\void main()
    \\{
    \\   FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
    \\}
};

/// Default GLFW error handling callback
fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("glfw: {}: {s}\n", .{ error_code, description });
}

pub fn main() !void {
    const window = try init();
    defer glfw.terminate();
    defer window.destroy();

    const vertexShader = gl.createShader(gl.ShaderType.vertex);
    defer gl.deleteShader(vertexShader);
    gl.shaderSource(vertexShader, 1, &vertexShaderSource);
    gl.compileShader(vertexShader);

    var buffer: [100]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    // check for shader compile errors
    if (gl.getShader(vertexShader, gl.ShaderParameter.compile_status) == 0) {
        std.log.err("ERROR::SHADER::VERTEX::COMPILATION_FAILED\n{!s}\n", .{
            gl.getShaderInfoLog(vertexShader, allocator),
        });
    }

    // fragment shader
    const fragmentShader = gl.createShader(gl.ShaderType.fragment);
    defer gl.deleteShader(fragmentShader);
    gl.shaderSource(fragmentShader, 1, &fragmentShaderSource);
    gl.compileShader(fragmentShader);

    // check for shader compile errors
    if (gl.getShader(fragmentShader, gl.ShaderParameter.compile_status) == 0) {
        std.log.err("ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n{!s}\n", .{
            gl.getShaderInfoLog(fragmentShader, allocator),
        });
    }

    // link shaders
    const shaderProgram = gl.createProgram();
    defer gl.deleteProgram(shaderProgram);
    gl.attachShader(shaderProgram, vertexShader);
    gl.attachShader(shaderProgram, fragmentShader);
    gl.linkProgram(shaderProgram);

    // check for linking errors
    if (gl.getProgram(shaderProgram, gl.ProgramParameter.link_status) == 0) {
        std.log.err("ERROR::SHADER::PROGRAM::LINKING_FAILED\n{!s}\n", .{
            gl.getProgramInfoLog(shaderProgram, allocator),
        });
    }

    const vertices = [_]f32{
        0.5,  0.5,  0.0,
        0.5,  -0.5, 0.0,
        -0.5, -0.5, 0.0,
        -0.5, 0.5,  0.0,
    };
    const indices = [_]i32{
        0, 1, 3,
        1, 2, 3,
    };

    const vao = gl.genVertexArray();
    const vbo = gl.genBuffer();
    const ebo = gl.genBuffer();
    defer {
        gl.deleteVertexArray(vao);
        gl.deleteBuffer(vbo);
        gl.deleteBuffer(ebo);
    }

    gl.bindVertexArray(vao);

    gl.bindBuffer(vbo, gl.BufferTarget.array_buffer);
    gl.bufferData(gl.BufferTarget.array_buffer, f32, &vertices, gl.BufferUsage.static_draw);

    gl.bindBuffer(ebo, gl.BufferTarget.element_array_buffer);
    gl.bufferData(gl.BufferTarget.element_array_buffer, i32, &indices, gl.BufferUsage.static_draw);

    gl.vertexAttribPointer(0, 3, gl.Type.float, false, 3 * @sizeOf(f32), 0);
    gl.enableVertexAttribArray(0);
    // Wait for the user to close the window.

    while (!window.shouldClose()) {
        if (window.getKey(glfw.Key.escape) == glfw.Action.press) {
            window.setShouldClose(true);
        }

        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(.{ .color = true });

        gl.useProgram(shaderProgram);
        gl.bindVertexArray(vao);

        gl.bindBuffer(ebo, gl.BufferTarget.element_array_buffer);
        gl.drawElements(gl.PrimitiveType.triangles, 6, gl.ElementType.u32, 0);

        gl.bindVertexArray(gl.VertexArray.invalid);
        window.swapBuffers();
        glfw.pollEvents();
    }
}
fn glGetProcAddress(p: glfw.GLProc, proc: [:0]const u8) ?gl.binding.FunctionPointer {
    _ = p;
    return glfw.getProcAddress(proc);
}
fn init() !glfw.Window {
    glfw.setErrorCallback(errorCallback);
    if (!glfw.init(.{})) {
        std.log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    }

    // Create our window
    const window = glfw.Window.create(640, 480, "Hello, mach-glfw!", null, null, .{}) orelse {
        std.log.err("failed to create GLFW window: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    };
    glfw.makeContextCurrent(window);

    const proc: glfw.GLProc = undefined;
    try gl.loadExtensions(proc, glGetProcAddress);
    return window;
}
