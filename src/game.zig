
const std = @import("std");

const dice = @import("dice.zig");

const hasFn = std.meta.trait.hasFn;
/// A helper metafunction to identify if some generic type satisfies the interface / trait
/// for a picking strategy.
/// This is a crutch, because I cannot get any semantics from that function
/// See this issue for a better handling of interfaces / traits
/// https://github.com/ziglang/zig/issues/1268
pub const hasPickingStrategyTrait = std.meta.trait.multiTrait(.{hasFn("pick")});


pub const PickingStrat : type = fn(Game) ?usize;

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

pub const Game = struct {
    /// number of trees with fruit (same as on dice)
    const TREE_COUNT : usize = dice.Fruit.TREE_COUNT;
    /// the number of raven cards needed for the player to lose the game
    const RAVEN_COMPLETE_COUNT = 9;
    /// initial number of fruit on each tree
    const INITIAL_FRUIT_COUNT = 10;
    fruit_count : [TREE_COUNT]usize,
    raven_count : usize,
    turn_count : usize,

    /// a new fresh game with full fruit an no ravens
    pub fn new() @This() {
        return @This() {
            .fruit_count = [_]usize{Game.INITIAL_FRUIT_COUNT}**Game.TREE_COUNT, // see https://ziglearn.org/chapter-1/#comptime (and then search for ++ and ** operators)
            .raven_count = 0,
            .turn_count = 0,
        };
    }

    pub fn print(self : Game) void {
         std.log.info("Game: fruit = {any}, ravens = {}, turns = {}", .{self.fruit_count, self.raven_count, self.turn_count});
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


    /// pick a piece of fruit, but do not modify the turn count
    pub fn pick_one(self : * Game, index : usize) !void {
        if (index < @This().TREE_COUNT) {
            if(self.fruit_count[index]>0) {
                self.fruit_count[index]-=1;
            } else {
                return GameError.EmptyTreePick;
            }
        } else {
            GameError.FruitIndexOutOfBounds;
        }
    }

    /// Apply a single turn to a game using the given dice result and picking strat
    /// the picking strat will only be used if the dice result warrants it, i.e.
    /// it is a basket.
    pub fn applySingleTurn(self : * Game, dice_result : dice.DiceResult, player_pick : PickingStrat) !void {
        switch (dice_result) {
            DiceResult.raven => self.raven_count += 1,
            DiceResult.fruit => |fruit| { 
                // ignore errors here because the dice might pick an empty tree
                _= self.pick_one(fruit.index);},
            DiceResult.basket => {
                const _idxs = [_]u8{1,2};
                const total_fruit_before = self.totalFruitCount();
                for (_idxs) |_| {
                    if (player_pick(self)) |index| {
                        try self.pick_one(index);
                    }
                }
                // ensure that the picking strategies always decrease
                // must decrease either to zero or decrease by two pieces of fruit
                if (self.totalFruitCount() != 0 and
                    self.totalFruitCount() != total_fruit_before-2) {
                    return GameError.IllegalPickingStrategy;
                }
            },
        }
    }
};

// fn playGameToFinish() {

// }

/// Get a generator for finished games that employs the given picking strategy
pub fn GameGenerator(comptime picking_strategy :  PickingStrat, game_count : usize) type {
    
    return struct {
        current_game_count : usize,
        max_game_count : usize,
        prng : std.rand.DefaultPrng,

        /// initialize the game generator with a seed for the random number generator
        pub fn new(rng_seed : u64) @This() {
            return .{
                .current_game_count = 0, 
                .max_game_count = game_count,
                .prng = std.rand.DefaultPrng.init(rng_seed),
                };
        }

        /// generate the next game
        /// returns null if the max number of games was reached
        pub fn next(self : * @This()) ?Game {
            if (self.current_game_count+1 < self.max_game_count) {
                var game = Game.new();
                var dice_result = dice.DiceResult.new_random(&self.prng);


                return Game.new();
            } else {
                return null;
            }
        }

    };
}