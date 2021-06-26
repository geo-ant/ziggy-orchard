const std = @import("std");
const game = @import("game.zig");
const Game = game.Game;
const GameError =game.GameError;
const dice = @import("dice.zig");

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
                var g = Game.new();
                try playGameToFinish(&self.prng,&g, &picking_strategy);
                return g;
            } else {
                return null;
            }
        }

    };
}

// internal helper function to help play a game to finish
fn playGameToFinish(prng : anytype, g: *Game, strategy : anytype) !void {
    var dice_result  = dice.DiceResult.new_random(prng);
    while (!(g.isWon() or g.isLost())) : (dice_result = dice.DiceResult.new_random(prng)) {
        try applySingleTurn(g,dice_result, strategy);
    }
    if (g.isWon() == g.isLost()) {
        return GameError.IllegalGameState;
    }
}



/// Apply a single turn to a game using the given dice result and picking strat
/// the picking strat will only be used if the dice result warrants it, i.e.
/// it is a basket.
/// each single turn increases the turn count by one.
/// # Arguments
/// * `game` 
/// * `dice_result` the dice result
/// * `strategy` a picking strategy that is invoked on a basket dice result. It must be
/// a container that exposes a method `fn pick (Game)?usize`.
pub fn applySingleTurn(g: *Game, dice_result: dice.DiceResult, strategy: anytype) !void {
    //TODO comment this back in
    //comptime static_assert(isPickingStrategy(@TypeOf(strategy)), "Strategy parameter must have the strategy interface");

    std.log.info("Dice = {s}", .{dice_result});

    switch (dice_result) {
        dice.DiceResult.raven => g.raven_count += 1,
        dice.DiceResult.fruit => |fruit| {
            std.log.info("Fruit = {s}", .{fruit});

            // ignore errors here because the dice might pick an empty tree
            g.pick_one(fruit.index) catch {};
        },
        dice.DiceResult.basket => {
            const _idxs = [_]u8{ 1, 2 };
            const total_fruit_before = g.totalFruitCount();
            for (_idxs) |_| {
                if (strategy.pickOne(g.*)) |index| {
                    try g.pick_one(index);
                }
            }
            // ensure that the picking strategies always decrease
            // must decrease either to zero or decrease by two pieces of fruit
            if (g.totalFruitCount() != 0 and
                g.totalFruitCount() != total_fruit_before - 2)
            {
                return GameError.IllegalPickingStrategy;
            }
        },
    }
    g.turn_count +=1;
}


// a dummy strategy that always returns a null index
const NullPickingStrategy = struct {
    pub fn pickOne(self : *@This(),g:Game) ?usize {
        _ = self;
        _ = g;
        return null;
    }
};


const expect = std.testing.expect;

// adds a raven, increases turn count, leave fruit untouched
test "Game: applying a single turn given Dice Result: Raven" {

    var g = Game.new();
    try expect(g.raven_count == 0);
    try expect(g.turn_count == 0);
    try expect(g.totalFruitCount() == dice.Fruit.TREE_COUNT*Game.INITIAL_FRUIT_COUNT);

    var strat = NullPickingStrategy{};
    try applySingleTurn(&g,dice.DiceResult.new_raven(), &strat);
    try expect(g.turn_count == 1);
    try expect(g.raven_count == 1);
    try expect(g.totalFruitCount() == dice.Fruit.TREE_COUNT*Game.INITIAL_FRUIT_COUNT);
}

// take one piece from the given tree and leave others untouched, increase turn count
test "Game: applying a single turn given Dice Result: Fruit" {
    var g = Game.new();

    var strat = NullPickingStrategy{};
    try applySingleTurn(&g, try dice.DiceResult.new_fruit(1), &strat);
    try expect(g.turn_count == 1);
    try expect(g.raven_count == 0);
    try expect(g.totalFruitCount() == dice.Fruit.TREE_COUNT*Game.INITIAL_FRUIT_COUNT-1);
    try expect(g.fruit_count[1] == Game.INITIAL_FRUIT_COUNT-1);
}


test "Game: applying a single turn given Dice Result: Basket" {

}
