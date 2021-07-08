const std = @import("std");

//const concepts = @import("concepts.zig");

//TODO: maybe remove because we don't need that
//const hasFn = std.meta.trait.hasFn;
/// A helper metafunction to identify if some generic type satisfies the interface / trait
/// for a picking strategy.
/// This is a crutch, because I cannot get any semantics from that function
/// See this issue for a better handling of interfaces / traits
/// https://github.com/ziglang/zig/issues/1268
//pub const hasPickingStrategyTrait = std.meta.trait.multiTrait(.{hasFn("pick")});

// //TODO correct this to include Self thing
// pub const isPickingStrategy = concepts.hasFn(fn(Game)?usize, "pick");

// fn static_assert(comptime ok : bool, comptime message : []const u8) void{
//     if(!ok) {
//         @compileError("static assertion failed: " ++ message);
//     }
// }

pub const GameError = error{
    /// a picking strat did an illegal move (i.e. take more than one piece of fruit per pick)
    IllegalPickingStrategy,
    /// the game state is illegal, i.e. both won and lost
    IllegalGameState,
    /// fruit index for picking is out of bounds
    FruitIndexOutOfBounds,
    /// tried to pick empty tree
    EmptyTreePick,
};

/// number of trees with fruit (same as on dice)
pub const TREE_COUNT: usize = 4;
/// the number of raven cards needed for the player to lose the game
pub const RAVEN_COMPLETE_COUNT = 9;
/// initial number of fruit on each tree
pub const INITIAL_FRUIT_COUNT = 10;

pub const Game = struct {
    fruit_count: [TREE_COUNT]usize,
    raven_count: usize,
    turn_count: usize,

    /// a new fresh game with full fruit an no ravens
    pub fn new() @This() {
        return @This(){
            .fruit_count = [_]usize{INITIAL_FRUIT_COUNT} ** TREE_COUNT, // see https://ziglearn.org/chapter-1/#comptime (and then search for ++ and ** operators)
            .raven_count = 0,
            .turn_count = 0,
        };
    }

    /// the total number of fruit left in the game
    pub fn totalFruitCount(self: @This()) usize {
        var total: usize = 0;
        for (self.fruit_count) |count| {
            total += count;
        }
        return total;
    }

    /// check if the game is won (i.e. fruit count is zero)
    /// ATTN: if the game is not played according to the rules,
    /// then isWon() and isLost() can both be true
    pub fn isWon(self: @This()) bool {
        return self.totalFruitCount() == 0;
    }

    /// check if the game is lost (i.e. raven is complete)
    /// ATTN: if the game is not played according to the rules,
    /// then isWon() and isLost() can both be true
    pub fn isLost(self: @This()) bool {
        return self.raven_count >= RAVEN_COMPLETE_COUNT;
    }

    /// pick a piece of fruit, but do not modify the turn count
    pub fn pickOne(self: *Game, index: usize) !void {
        if (index < TREE_COUNT) {
            if (self.fruit_count[index] > 0) {
                self.fruit_count[index] -= 1;
            } else {
                return GameError.EmptyTreePick;
            }
        } else {
            return GameError.FruitIndexOutOfBounds;
        }
    }
};



const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;
const expect = std.testing.expect;

const DiceResult = dice.DiceResult;

test "Game.new" {
    const new_game = Game.new();
    try expectEqual(Game{.fruit_count = [_]usize{10} ** TREE_COUNT, .raven_count = 0, .turn_count = 0}, new_game);
    try expect(new_game.totalFruitCount() == INITIAL_FRUIT_COUNT*TREE_COUNT);
}

test "Game.isWon and Game.isLost" {
    try expect(!Game.new().isWon());
    try expect(!Game.new().isLost());

    try expect((Game{.fruit_count = [_]usize{0} ** TREE_COUNT, .raven_count = RAVEN_COMPLETE_COUNT-1, .turn_count = 0}).isWon());
    try expect(!(Game{.fruit_count = [_]usize{1} ** TREE_COUNT, .raven_count = RAVEN_COMPLETE_COUNT, .turn_count = 0}).isWon());
    try expect((Game{.fruit_count = [_]usize{1} ** TREE_COUNT, .raven_count = RAVEN_COMPLETE_COUNT, .turn_count = 0}).isLost());
}

test "Game.pickOne" {
    var game = Game.new();
    try game.pickOne(1);
    try expect(game.totalFruitCount() == INITIAL_FRUIT_COUNT*TREE_COUNT-1);
    try expect(game.fruit_count[1] == INITIAL_FRUIT_COUNT-1);
    std.mem.set(usize, &game.fruit_count, 0);
    try expectError(error.EmptyTreePick, game.pickOne(0));
}
