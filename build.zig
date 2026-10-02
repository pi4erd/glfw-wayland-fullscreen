const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const build_wayland = b.option(bool, "build_wayland", "Builds wayland support for linux platform")
        orelse true;
    const build_x11 = b.option(bool, "build_x11", "Builds x11 support for linux platform")
        orelse true;
    const build_dynamic = b.option(bool, "build_dynamic", "Builds a dynamic library")
        orelse false;
    
    const src_dir = b.path("src/");
    const include_dir = b.path("include/");

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

    // start building module
    const glfw = b.addModule("glfw", .{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    glfw.addCSourceFiles(.{
        .files = &common,
        .language = .c,
        .root = src_dir,
    });

    const platform = target.query.os_tag orelse builtin.target.os.tag;

    if(target.query.os_tag != null) {
        // assume os_tag == null, as documented
        std.log.warn(
            "Cross-compiling. This action isn't supported or tested. " ++
            "Compile at your own risk.", .{}
        );
    }

    std.log.info("Building GLFW for platform {}", .{platform});

    switch(platform) {
        .macos => {
            glfw.addCSourceFiles(.{
                .files = &macos,
                .language = .objective_c,
                .root = src_dir,
            });
            glfw.addCMacro("_GLFW_COCOA", "1");

            glfw.linkFramework("Cocoa", .{});
            glfw.linkFramework("IOKit", .{});
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
            if(build_wayland) {
                glfw.addCSourceFiles(.{
                    .files = &wayland,
                    .language = .c,
                    .root = src_dir,
                });
                glfw.addCMacro("_GLFW_WAYLAND", "1");

                glfw.linkSystemLibrary("wayland-client", .{});

                @panic("TODO: Generate protocol files before building");
            }

            if(build_x11) {
                glfw.addCSourceFiles(.{
                    .files = &x11,
                    .language = .c,
                    .root = src_dir,
                });
                glfw.addCMacro("_GLFW_X11", "1");

                glfw.linkSystemLibrary("X11", .{});
                @panic("TODO: Needs testing");
            }
        },
        .windows => {
            glfw.addCSourceFiles(.{
                .files = &windows,
                .language = .c,
                .root = src_dir,
            });
            glfw.addCMacro("_GLFW_WIN32", "1");

            glfw.linkSystemLibrary("gdi32", .{});

            @panic("TODO: Needs testing");
        },
        else => {
            std.debug.panic("Unsupported platform {}", .{platform});
        }
    }

    if(build_dynamic) {
        glfw.addCMacro("_GLFW_BUILD_DLL", "1");
    }

    const lib = b.addLibrary(.{
        .name = "glfw",
        .root_module = glfw,
        .linkage = if(build_dynamic) .dynamic else .static,
    });
    b.installArtifact(lib);
}
