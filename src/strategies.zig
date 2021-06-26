const std = @import("std");
const game = @import("game.zig");
const TREE_COUNT = @import("dice.zig").Fruit.TREE_COUNT;

/// This strategy picks from the the 
pub const InOrderPickingStrategy = struct {
    pub fn pickOne(_: @This(), g: game.Game)?usize {
        for (indexSequence(0, TREE_COUNT-1)) |idx| {
            if (g.fruit_count[idx] > 0) {
                return idx;
            }
        }
        return null;
    }
};

// helper function to generate a compile time array [first,...,last] with increment one.
// This means the resulting array has (last-first+1) elements.
fn indexSequence(comptime first : usize, comptime last : usize) [last-first+1]usize {
    return [_]usize{0,1,2,3};
}

// pub const RandomPickingStrategy = struct {
//     prng : std.

//     pub fn init(seed : )
// };