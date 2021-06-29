const std = @import("std");
const game = @import("game.zig");

/// This strategy picks from the the 
pub const InOrderPickingStrategy = struct {
    pub fn pickOne(_: @This(), g: game.Game)?usize {
        var idx : usize=0;
        while (idx < game.TREE_COUNT) :(idx+=1) {
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

const expect = std.testing.expect;

test "InOrderPickingStrategy" {
    const strat = InOrderPickingStrategy{};
    
    const new_game = game.Game.new();
    try expect(strat.pickOne(new_game).?==0);

    // game with first tree empty
    var g = new_game;
    g.fruit_count[0] = 0;
    try expect(strat.pickOne(g).?==1);
    // first and second empty
    g.fruit_count[1] = 0;
    try expect(strat.pickOne(g).?==2);
    // all empty trees
    std.mem.set(usize,&g.fruit_count,0);
    try expect(strat.pickOne(g)==null);
}