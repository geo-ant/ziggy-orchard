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
};

const Raven = struct {};
const Basket = struct {};
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
