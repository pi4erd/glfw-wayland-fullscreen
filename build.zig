const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const platform = target.query.os_tag orelse builtin.target.os.tag;

    if (target.query.os_tag != null) {
        // assume os_tag == null if native, as documented
        std.log.warn("Cross-compiling. This action isn't supported or tested. " ++
            "Compile at your own risk.", .{});
    }

    const build_wayland = b.option(bool, "build_wayland", "Builds wayland support for linux platform")
        orelse (platform == .linux);
    const build_x11 = b.option(bool, "build_x11", "Builds x11 support for linux platform")
        orelse (platform == .linux);
    const build_dynamic = b.option(bool, "build_dynamic", "Builds a dynamic library") orelse false;

    const src_dir = b.path("src/");
    const include_dir = b.path("include/");
    const deps_dir = b.path("deps/");
    const wayland_dir = deps_dir.path(b, "wayland/");

    b.addNamedLazyPath("glfw-include", include_dir);

    // define files
    const common = .{
        "context.c",
        "init.c",
        "input.c",
        "monitor.c",
        "platform.c",
        "vulkan.c",
        "window.c",
        "egl_context.c",
        "osmesa_context.c",
        "null_init.c",
        "null_monitor.c",
        "null_window.c",
        "null_joystick.c",
    };

    const windows = .{
        "win32_init.c",
        "win32_joystick.c",
        "win32_module.c",
        "win32_monitor.c",
        "win32_thread.c",
        "win32_time.c",
        "win32_window.c",
        "wgl_context.c",
    };

    const macos = .{
        "cocoa_init.m", // ????
        "cocoa_joystick.m",
        "cocoa_monitor.m",
        "cocoa_window.m",
        "macos_time.c",
        "nsgl_context.m",
        "posix_module.c",
        "posix_thread.c",
    };

    const posix = .{
        "posix_module.c",
        "posix_poll.c",
        "posix_thread.c",
        "posix_time.c",
    };

    const linux = .{
        "linux_joystick.c",
    };

    const x11 = .{
        "x11_init.c",
        "x11_monitor.c",
        "x11_window.c",
        "xkb_unicode.c",
        "glx_context.c",
    };

    const wayland = .{
        "wl_init.c",
        "wl_monitor.c",
        "wl_window.c",
        "xkb_unicode.c",
    };

    var wayland_protocol: std.ArrayList(std.Build.LazyPath) = .empty;
    defer wayland_protocol.deinit(b.allocator);
    const generated_wayland_headers = b.addWriteFiles();

    if (build_wayland) {
        // Do the wayland protocol generation
        const inputs = [_][]const u8{
            "fractional-scale-v1",
            "pointer-constraints-unstable-v1",
            "viewporter",
            "xdg-activation-v1",
            "xdg-shell",
            "idle-inhibit-unstable-v1",
            "relative-pointer-unstable-v1",
            "wayland",
            "xdg-decoration-unstable-v1",
        };

        // inline for comptime concatenation
        inline for (inputs) |input| {
            const input_file = wayland_dir.path(b, input ++ ".xml");
            const header_name = input ++ "-client-protocol.h";
            const code_name = input ++ "-client-protocol-code.h";

            const scanner_header = b.addSystemCommand(&.{ "wayland-scanner", "client-header" });
            scanner_header.addFileArg(input_file);
            const header = scanner_header.addOutputFileArg(header_name);
            _ = generated_wayland_headers.addCopyFile(header, header_name);

            const scanner_code = b.addSystemCommand(&.{ "wayland-scanner", "private-code" });
            scanner_code.addFileArg(input_file);
            const code = scanner_code.addOutputFileArg(code_name);
            _ = generated_wayland_headers.addCopyFile(code, code_name);

            wayland_protocol.append(b.allocator, code) catch @panic("OOM");
        }
    }

    // start building module
    const glfw = b.addModule("glfw", .{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    if (build_wayland) {
        glfw.addIncludePath(generated_wayland_headers.getDirectory());
    }

    glfw.addCSourceFiles(.{
        .files = &common,
        .language = .c,
        .root = src_dir,
    });

    std.log.info("Building GLFW for platform {}", .{platform});

    switch (platform) {
        .macos => {
            glfw.addCSourceFiles(.{
                .files = &macos,
                .language = .objective_c,
                .root = src_dir,
            });
            glfw.addCMacro("_GLFW_COCOA", "1");

            glfw.linkFramework("Cocoa", .{});
            glfw.linkFramework("IOKit", .{});
            glfw.linkFramework("QuartzCore", .{});
            glfw.linkFramework("CoreFoundation", .{});
            glfw.linkFramework("CoreVideo", .{});
        },
        .linux => {
            glfw.addCSourceFiles(.{
                .files = &(linux ++ posix),
                .language = .c,
                .root = src_dir,
            });

            // Platform-specific
            if (build_wayland) {
                glfw.addCSourceFiles(.{
                    .files = &wayland,
                    .language = .c,
                    .root = src_dir,
                });
                glfw.addCMacro("_GLFW_WAYLAND", "1");

                for (wayland_protocol.items) |proto_code| {
                    glfw.addCSourceFile(.{
                        .file = proto_code,
                        .language = .c,
                    });
                }
            }

            if (build_x11) {
                glfw.addCSourceFiles(.{
                    .files = &x11,
                    .language = .c,
                    .root = src_dir,
                });
                glfw.addCMacro("_GLFW_X11", "1");
            }
        },
        .windows => {
            glfw.addCSourceFiles(.{
                .files = &windows,
                .language = .c,
                .root = src_dir,
            });
            glfw.addCMacro("_GLFW_WIN32", "1");

            @panic("TODO: Needs testing");
        },
        else => {
            std.debug.panic("Unsupported platform {}", .{platform});
        },
    }

    if (build_dynamic) {
        glfw.addCMacro("_GLFW_BUILD_DLL", "1");
    }

    const lib = b.addLibrary(.{
        .name = "glfw",
        .root_module = glfw,
        .linkage = if (build_dynamic) .dynamic else .static,
    });
    b.installArtifact(lib);
}
