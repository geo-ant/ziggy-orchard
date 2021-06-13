const std = @import("std");
const dice = @import("dice.zig");

const game = @import("game.zig");

fn dummy_picking_strat(g :game.Game) ?usize {
    const indices = [_]u8{0,1,2,3};
    for (indices) |idx| {
        if (g.fruit_count[idx] > 0) {
            std.log.info("Select index = {}", .{idx});
            return idx;
        }
    }
    return null;
}

pub fn main() anyerror!void {
    std.log.info("All your codebase are belong to us.", .{});
    var trees = dice.Fruit.TREE_COUNT;

    var dr1 = dice.DiceResult.new_basket();
    var dr2 : dice.DiceResult = try dice.DiceResult.new_fruit(2);

    var out = 
    switch (dr2) {
        dice.DiceResult.basket => "basket",
        dice.DiceResult.fruit =>  "fruit",
        dice.DiceResult.raven => "raven",
    };

    //var generator : game.GameGenerator(foo, 10) = undefined;
    var seed : u64 = undefined;
    try std.os.getrandom(std.mem.asBytes(&seed));
    var game_generator = game.GameGenerator(dummy_picking_strat, 12).new(seed);
    var g = game_generator.next().?;
    g.print();

    std.log.info("Dice = {s}", .{out});

    
}

const expect = std.testing.expect;

test "something" {
    //try expect(false);
}