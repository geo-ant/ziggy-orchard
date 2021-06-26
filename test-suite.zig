// I don't know if this is the idiomatic way to build a test suite
// I copied that from
// https://github.com/zigimg/test-suite/blob/master/tests/tests.zig
// What I like about this, is having all tests aggregate in one location.
// However, I still have to add each file manually here, so this is not
// quite as handy as just running Rust's `cargo test`.
test "test suite" {
    _ = @import("src/main.zig");
    _ = @import("src/dice.zig");
    _ = @import("src/game.zig");
    _ = @import("src/concepts.zig");
    _ = @import("src/strategies.zig");
    _ = @import("src/simulate.zig");
}