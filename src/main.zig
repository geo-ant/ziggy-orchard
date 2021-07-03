const std = @import("std");
const dice = @import("dice.zig");

const game = @import("game.zig");
const concepts = @import("concepts.zig");

const strategies = @import("strategies.zig");
const simulate = @import("simulate.zig");
const analyze = @import("analyze.zig");

pub fn main() anyerror!void {
    std.log.info("All your codebase are belong to us.", .{});

    // //var dr1 = dice.DiceResult.new_basket();
    // var dr2 : dice.DiceResult = try dice.DiceResult.new_fruit(2);

    // var out = 
    // switch (dr2) {
    //     dice.DiceResult.basket => "basket",
    //     dice.DiceResult.fruit =>  "fruit",
    //     dice.DiceResult.raven => "raven",
    // };

    //var generator : game.GameGenerator(foo, 10) = undefined;
    var seed : u64 = undefined;
    try std.os.getrandom(std.mem.asBytes(&seed));
    var game_generator = simulate.GameGenerator(strategies.InOrderPickingStrategy{}, 100).new(seed);

    var analyzer = analyze.WinLossAnalyzer.init();
    while (try game_generator.next()) |g| {
        analyzer = try analyzer.accGame(g);
    }
    std.debug.print("Analysis = {s}", .{analyzer});

    //std.log.info("Dice = {s}", .{out});

    //const Us = transform(&[_]type{i32,u32,u32}, identity);
}