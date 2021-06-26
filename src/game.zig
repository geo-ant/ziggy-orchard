const std = @import("std");

const dice = @import("dice.zig");
const concepts = @import("concepts.zig");

//TODO: maybe remove because we don't need that
//const hasFn = std.meta.trait.hasFn;
/// A helper metafunction to identify if some generic type satisfies the interface / trait
/// for a picking strategy.
/// This is a crutch, because I cannot get any semantics from that function
/// See this issue for a better handling of interfaces / traits
/// https://github.com/ziglang/zig/issues/1268
//pub const hasPickingStrategyTrait = std.meta.trait.multiTrait(.{hasFn("pick")});

//TODO correct this to include Self thing
pub const isPickingStrategy = concepts.hasFn(fn(Game)?usize, "pick");

fn static_assert(comptime ok : bool, comptime message : []const u8) void{
    if(!ok) {
        @compileError("static assertion failed: " ++ message);
    }
}

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
    const TREE_COUNT: usize = dice.Fruit.TREE_COUNT;
    /// the number of raven cards needed for the player to lose the game
    const RAVEN_COMPLETE_COUNT = 9;
    /// initial number of fruit on each tree
    const INITIAL_FRUIT_COUNT = 10;
    fruit_count: [TREE_COUNT]usize,
    raven_count: usize,
    turn_count: usize,

    /// a new fresh game with full fruit an no ravens
    pub fn new() @This() {
        return @This(){
            .fruit_count = [_]usize{Game.INITIAL_FRUIT_COUNT} ** Game.TREE_COUNT, // see https://ziglearn.org/chapter-1/#comptime (and then search for ++ and ** operators)
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
        return self.raven_count >= @TypeOf(self).RAVEN_COMPLETE_COUNT;
    }

    /// pick a piece of fruit, but do not modify the turn count
    pub fn pick_one(self: *Game, index: usize) !void {
        if (index < @This().TREE_COUNT) {
            if (self.fruit_count[index] > 0) {
                self.fruit_count[index] -= 1;
            } else {
                return GameError.EmptyTreePick;
            }
        } else {
            return GameError.FruitIndexOutOfBounds;
        }
    }

    /// Apply a single turn to a game using the given dice result and picking strat
    /// the picking strat will only be used if the dice result warrants it, i.e.
    /// it is a basket.
    /// each single turn increases the turn count by one.
    /// # Arguments
    /// * `self` 
    /// * `dice_result` the dice result
    /// * `strategy` a picking strategy that is invoked on a basket dice result. It must be
    /// a container that exposes a method `fn pick (Game)?usize`.
    pub fn applySingleTurn(self: *Game, dice_result: dice.DiceResult, strategy: anytype) !void {
        //TODO comment this back in
        //comptime static_assert(isPickingStrategy(@TypeOf(strategy)), "Strategy parameter must have the strategy interface");

        std.log.info("Dice = {s}", .{dice_result});

        switch (dice_result) {
            dice.DiceResult.raven => self.raven_count += 1,
            dice.DiceResult.fruit => |fruit| {
                std.log.info("Fruit = {s}", .{fruit});

                // ignore errors here because the dice might pick an empty tree
                self.pick_one(fruit.index) catch {};
            },
            dice.DiceResult.basket => {
                const _idxs = [_]u8{ 1, 2 };
                const total_fruit_before = self.totalFruitCount();
                for (_idxs) |_| {
                    if (strategy.pick(self.*)) |index| {
                        try self.pick_one(index);
                    }
                }
                // ensure that the picking strategies always decrease
                // must decrease either to zero or decrease by two pieces of fruit
                if (self.totalFruitCount() != 0 and
                    self.totalFruitCount() != total_fruit_before - 2)
                {
                    return GameError.IllegalPickingStrategy;
                }
            },
        }
        self.turn_count +=1;
    }
};



/// Get a generator for finished games that employs the given picking strategy
pub fn GameGenerator(comptime picking_strategy: anytype, game_count: usize) type {
    //TODO make sure that this is a picking strategy
    
    return struct {
        current_game_count: usize,
        max_game_count: usize,
        prng: std.rand.DefaultPrng,

        /// initialize the game generator with a seed for the random number generator
        pub fn new(rng_seed: u64) @This() {
            return .{
                .current_game_count = 0,
                .max_game_count = game_count,
                .prng = std.rand.DefaultPrng.init(rng_seed),
            };
        }

        /// generate the next game which is played from new game to finish
        /// returns null if the max number of games was reached
        /// this iterator uses !?Game as the return type because the iteration
        /// could potentially fail if invalid values are used inside the game
        /// this is nothing the user has control over and indicates a programming error
        /// so from this point of view just crashing and returning ?Game would be fine.
        /// I just wanted to work with !? iterators...
        pub fn next(self: *@This()) !?Game {
            if (self.current_game_count + 1 < self.max_game_count) {
                self.current_game_count +=1;
                var game = Game.new();
                try self.playGameToFinish(&game);
                return game;
            } else {
                return null;
            }
        }

        // internal helper function to help play a game to finish
        fn playGameToFinish(self: *@This(), game: *Game ) !void {
            var dice_result  = dice.DiceResult.new_random(&self.prng);
            while (!(game.isWon() or game.isLost())) : (dice_result = dice.DiceResult.new_random(&self.prng)) {
                try game.applySingleTurn(dice_result, &picking_strategy);
            }
            if (game.isWon() == game.isLost()) {
                return GameError.IllegalGameState;
            }
        }
    };
}


const expectEqual = std.testing.expectEqual;
const expect = std.testing.expect;

const DiceResult = dice.DiceResult;

test "Game: default construction" {
    try expectEqual(Game{.fruit_count = [_]usize{10} ** Game.TREE_COUNT, .raven_count = 0, .turn_count = 0}, Game.new());
}

test "Game: win and loss" {
    try expect(!Game.new().isWon());
    try expect(!Game.new().isLost());

    try expect((Game{.fruit_count = [_]usize{0} ** Game.TREE_COUNT, .raven_count = Game.RAVEN_COMPLETE_COUNT-1, .turn_count = 0}).isWon());
    try expect(!(Game{.fruit_count = [_]usize{1} ** Game.TREE_COUNT, .raven_count = Game.RAVEN_COMPLETE_COUNT, .turn_count = 0}).isWon());
    try expect((Game{.fruit_count = [_]usize{1} ** Game.TREE_COUNT, .raven_count = Game.RAVEN_COMPLETE_COUNT, .turn_count = 0}).isLost());
}


// a dummy strategy that always returns a null index
const NullPickingStrategy = struct {
    pub fn pick(self : *@This(),game:Game) ?usize {
        _ = self;
        _ = game;
        return null;
    }
};


// adds a raven, increases turn count, leave fruit untouched
test "Game: applying a single turn given Dice Result: Raven" {


    var g = Game.new();
    try expect(g.raven_count == 0);
    try expect(g.turn_count == 0);
    try expect(g.totalFruitCount() == dice.Fruit.TREE_COUNT*Game.INITIAL_FRUIT_COUNT);

    var strat = NullPickingStrategy{};
    try g.applySingleTurn(DiceResult.new_raven(), &strat);
    try expect(g.turn_count == 1);
    try expect(g.raven_count == 1);
    try expect(g.totalFruitCount() == dice.Fruit.TREE_COUNT*Game.INITIAL_FRUIT_COUNT);
}

// take one piece from the given tree and leave others untouched, increase turn count
test "Game: applying a single turn given Dice Result: Fruit" {
    var g = Game.new();

    var strat = NullPickingStrategy{};
    try g.applySingleTurn(try DiceResult.new_fruit(1), &strat);
    try expect(g.turn_count == 1);
    try expect(g.raven_count == 0);
    try expect(g.totalFruitCount() == dice.Fruit.TREE_COUNT*Game.INITIAL_FRUIT_COUNT-1);
    try expect(g.fruit_count[1] == Game.INITIAL_FRUIT_COUNT-1);
}


test "Game: applying a single turn given Dice Result: Basket" {

}