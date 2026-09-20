const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    
    const build_dir = b.cache_root.join(b.allocator, &.{"glfw-cmake"}) catch @panic("OOM");
    const lib_path = b.pathJoin(&.{ build_dir, "src", "libglfw3.a" });

    const build_type = switch (optimize) {
        .Debug => "Debug",
        .ReleaseSafe => "RelWithDebInfo",
        .ReleaseFast => "Release",
        .ReleaseSmall => "MinSizeRel",
    };

    const cmake = b.addSystemCommand(&.{
        "sh", "-c",
        \\cmake -S "$0" -B "$1" -DCMAKE_BUILD_TYPE="$2" \
        \\    -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        \\    -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_DOCS=OFF \
        \\    -DGLFW_INSTALL=OFF -DGLFW_BUILD_WAYLAND=ON -DGLFW_BUILD_X11=ON \
        \\  && cmake --build "$1" --parallel
        ,
        b.pathFromRoot("."),
        build_dir,
        build_type,
    });
    cmake.has_side_effects = true;

    const lib = b.allocator.create(std.Build.GeneratedFile) catch @panic("OOM");
    lib.* = .{ .step = &cmake.step, .path = lib_path };

    const lib_lp: std.Build.LazyPath = .{ .generated = .{ .file = lib }};
    b.addNamedLazyPath("glfw", lib_lp);
}
