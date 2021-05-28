const std = @import("std");
const dice = @import("dice.zig");

pub fn main() anyerror!void {
    std.log.info("All your codebase are belong to us.", .{});
    var trees = dice.Fruit.TREE_COUNT;

    var dr1 = dice.DiceResult.new_basket();
    var dr2 : dice.DiceResult = try dice.DiceResult.new_fruit(2);
}
