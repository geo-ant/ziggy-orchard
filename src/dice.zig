const std = @import("std");
const assert = comptime std.debug.assert;
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

    const hasRngFunction = std.meta.trait.hasFn("intRangeAtMost");
    comptime if (!hasFieldRandom(prng_type)) {
        @compileError("PRNG member field 'random' must have member function 'intRangeAtMost'");
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

    pub fn new_raven() @This() {
        return @This(){ .raven = .{} };
    }

    pub fn new_basket() @This() {
        return @This(){ .basket = .{} };
    }

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

        const rand = prng.random.intRangeAtMost(u8, 0, Fruit.TREE_COUNT+1);


        switch (rand) {
            0...Fruit.TREE_COUNT-1 => |index| return .{.fruit = Fruit.new(index) catch  unreachable},
            Fruit.TREE_COUNT => return .{.basket = .{}},
            Fruit.TREE_COUNT+1 => return .{.raven = .{}},
            else => unreachable,
        }
    }
};


pub const Raven = struct {};
pub const Basket = struct {};
pub const Fruit = struct {
    index: usize,
    pub const TREE_COUNT: usize = 4;

    pub fn new(index: usize) !@This() {
        if (index < TREE_COUNT) {
            return Fruit{ .index = index };
        } else {
            return DiceError.InvalidFruitIndex;
        }
    }
};

/// An error that indicates that something went wrong when constructing a dice result
const DiceError = error{ 
    /// invalid fruit index was given 
    InvalidFruitIndex
};


test "something" {

}