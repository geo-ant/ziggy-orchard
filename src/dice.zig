const std = @import("std");

// This is a threadlocal global rng, I really hope it does what I think it does :D
threadlocal var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
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

    pub fn new_random() @This() {
        const rnd = prng.intRangeAtMost(u8, 0,(Fruit.TREE_COUNT-1)+2);
        switch (rnd) {
            0...Fruit.TREE_COUNT-1 => |index| return .{.fruit = Fruit.new(index) catch  unreachable},
            TREE_COUNT => return .{.basket = .{}},
            TREE_COUNT+1 => return .{.raven = .{}},
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
