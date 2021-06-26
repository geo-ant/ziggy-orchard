const std = @import("std");
const game = @import("game.zig");
const assert = std.debug.assert;
const TypeInfo = std.builtin.TypeInfo;

/// a concept-like / trait like metafunction to
/// check at compile time whether a given argument's type satisfies the
/// prng interface necessary for generating a random dice throw
fn assertIsOfPrngType(arg : anytype) void {
    const prng_type = comptime switch (@typeInfo(@TypeOf(arg))) {
        .Struct => @TypeOf(arg),
        .Pointer => |ptr| ptr.child,
        else => {@compileError("Type of PRNG must be pointer or struct");}
    };

    const hasFieldRandom = std.meta.trait.hasField("random");
    comptime if (!hasFieldRandom(prng_type)) {
        @compileError("PRNG must have member field 'random'");
    };
} 

/// A variant that contains a valid dice result, either
/// * a raven
/// * a basket
/// * a fruit tree with given index
pub const DiceResult = union(enum) {
    raven: Raven,
    basket: Basket,
    fruit: Fruit,

    // create a new raven dice throw
    pub fn new_raven() @This() {
        return @This(){ .raven = .{} };
    }

    // create a new basked dice throw
    pub fn new_basket() @This() {
        return @This(){ .basket = .{} };
    }

    // create a new fruit result
    pub fn new_fruit(index: usize) !@This() {
        return @This(){ .fruit = try Fruit.new(index) };
    }

    /// generate a new random dice result using a prng
    /// # Arguments
    /// prng: must be a random number generator which has a member
    /// random and that member must have a function intRangeAtMost(comptime T:type,lower:T, upper:T)
    /// which generates an integer in the range [lower, upper].
    /// TODO: I am checking the type at compile time to provide better error messages, 
    /// but I don't know if I am doing it idiomatically.
    pub fn new_random(prng :  anytype) @This() {
        // this is to check the arg for better error messages
        assertIsOfPrngType(prng);

        const rand = prng.random.intRangeAtMost(u8, 0, game.TREE_COUNT+1);

        switch (rand) {
            0...game.TREE_COUNT-1 => |index| return .{.fruit = Fruit.new(index) catch  unreachable},
            game.TREE_COUNT => return .{.basket = .{}},
            game.TREE_COUNT+1 => return .{.raven = .{}},
            else => unreachable,
        }
    }
};


pub const Raven = struct {};
pub const Basket = struct {};
pub const Fruit = struct {
    index: usize,

    pub fn new(index: usize) !@This() {
        if (index < game.TREE_COUNT) {
            return Fruit{ .index = index };
        } else {
            return DiceError.InvalidFruitIndex;
        }
    }
};

/// An error that indicates that something went wrong when constructing a dice result
const DiceError = error{ 
    /// invalid fruit index was given 
    InvalidFruitIndex,
};

const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;
const expect = std.testing.expect;

test "DiceResult constructors: Raven, Basket" {
    try expectEqual(DiceResult.new_basket(), .basket);
    try expectEqual(DiceResult.new_raven(), .raven);
}

test "DiceResult constructor: Fruit" {
    // TODO: how can I elegantly test that the variant indeed contains the payload I want?
    // maybe I have to switch on it...
    var idx :u8 = 0;
    while (idx < game.TREE_COUNT) : (idx += 1) {
        try expectEqual(DiceResult.new_fruit(idx),DiceResult{.fruit=Fruit{.index=idx}});
    }
    
    try expectError(DiceError.InvalidFruitIndex,DiceResult.new_fruit(game.TREE_COUNT));
    try expectError(DiceError.InvalidFruitIndex,DiceResult.new_fruit(10));
}

test "DiceResult constructor: random" {
    var prng = std.rand.Xoroshiro128.init(22131342);
    // used this to see what that seed actually produces
    // var i : u32 = 0;
    // while(i < 10) : (i+=1) {
    //     std.debug.print("result is {}\n", .{DiceResult.new_random(&prng)});
    // }
    try expectEqual(DiceResult{.raven = .{}}, DiceResult.new_random(&prng));
    try expectEqual(DiceResult{.fruit=.{.index=3}}, DiceResult.new_random(&prng));
    try expectEqual(DiceResult{.basket=.{}}, DiceResult.new_random(&prng));
}