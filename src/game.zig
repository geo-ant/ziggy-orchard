
const std = @import("std");

const dice = @import("dice.zig");

const hasFn = std.meta.trait.hasFn;
/// A helper metafunction to identify if some generic type satisfies the interface / trait
/// for a picking strategy.
/// This is a crutch, because I cannot get any semantics from that function
/// See this issue for a better handling of interfaces / traits
/// https://github.com/ziglang/zig/issues/1268
pub const hasPickingStrategyTrait = std.meta.trait.multiTrait(.{hasFn("pick")});

pub const Game = struct {
    /// number of trees with fruit (same as on dice)
    const TREE_COUNT : usize = dice.Fruit.TREE_COUNT;
    /// the number of raven cards needed for the player to lose the game
    const RAVEN_COMPLETE_COUNT = 9;
    /// initial number of fruit on each tree
    const INITIAL_FRUIT_COUNT = 10;
    fruit_count : [TREE_COUNT]usize,
    raven_count : usize,

    /// a new fresh game with full fruit an no ravens
    pub fn new() @This() {
        return @This() {
            .fruit_count = [_]usize{Game.INITIAL_FRUIT_COUNT}**Game.TREE_COUNT, // see https://ziglearn.org/chapter-1/#comptime (and then search for ++ and ** operators)
            .raven_count = 0,
        };
    }

    pub fn print(self : Game) void {
         std.log.info("Game: fruit = {any}, ravens = {}", .{self.fruit_count, self.raven_count});
    }

    /// the total number of fruit left in the game
    pub fn totalFruitCount(self : @This()) usize {
        var total : usize = 0;
        for (self.fruit_count) |count| {
            total += count;
        }
        return total;
    }

    /// check if the game is won (i.e. fruit count is zero)
    /// ATTN: if the game is not played according to the rules,
    /// then isWon() and isLost() can both be true
    pub fn isWon(self : @This()) bool {
        return self.totalFruitCount() == 0;
    }

    /// check if the game is lost (i.e. raven is complete)
    /// ATTN: if the game is not played according to the rules,
    /// then isWon() and isLost() can both be true
    pub fn isLost(self : @This()) bool {
        return self.raven_count >= self.RAVEN_COMPLETE_COUNT;
    }

    pub fn playToFinish(self : Game, picking_strategy : fn(Game)Game) Game {
        return Game.new();
    }
};

fn playGameToFinish(game : Game, picking_strategy : fn(Game)Game) Game {
    //TODO: CHANGE THIS!!!!!!!!
    return Game.new();
}

/// Get a generator for finished games that employs the given picking strategy
pub fn GameGenerator(comptime picking_strategy :  fn(Game)Game, game_count : usize) type {
    
    
    return struct {
        current_game_count : usize,
        max_game_count : usize,

        pub fn new() @This() {
            return .{.current_game_count = 0, .max_game_count = game_count};
        }

        /// generate the next game
        /// returns null if the max number of games was reached
        pub fn next(self : * @This()) ?Game {
            if (self.current_game_count+1 < self.max_game_count) {
                self.current_game_count += 1;
                return Game.new().playToFinish(picking_strategy);
            } else {
                return null;
            }
        }

    };
}