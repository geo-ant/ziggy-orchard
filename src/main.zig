const std = @import("std");
const dice = @import("dice.zig");

const game = @import("game.zig");
const concepts = @import("concepts.zig");

const strategies = @import("strategies.zig");
const simulate = @import("simulate.zig");
const analyze = @import("analyze.zig");

pub fn main() anyerror!void {

    //var generator : game.GameGenerator(foo, 10) = undefined;
    var seed : u64 = undefined;
    try std.os.getrandom(std.mem.asBytes(&seed));
    var game_generator = simulate.GameGenerator(strategies.InOrderPickingStrategy{}, 100).new(seed);

    var analyzer = analyze.WinLossAnalyzer.init();
    while (try game_generator.next()) |g| {
        analyzer = try analyzer.accGame(g);
    }
    std.debug.print("Analysis = {s}", .{analyzer});

}