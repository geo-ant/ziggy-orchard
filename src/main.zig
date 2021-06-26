const std = @import("std");
const dice = @import("dice.zig");

const game = @import("game.zig");
const concepts = @import("concepts.zig");

const strategies = @import("strategies.zig");
const simulate = @import("simulate.zig");

pub fn main() anyerror!void {
    std.log.info("All your codebase are belong to us.", .{});

    //var dr1 = dice.DiceResult.new_basket();
    var dr2 : dice.DiceResult = try dice.DiceResult.new_fruit(2);

    var out = 
    switch (dr2) {
        dice.DiceResult.basket => "basket",
        dice.DiceResult.fruit =>  "fruit",
        dice.DiceResult.raven => "raven",
    };

    //var generator : game.GameGenerator(foo, 10) = undefined;
    var seed : u64 = undefined;
    try std.os.getrandom(std.mem.asBytes(&seed));
    var game_generator = simulate.GameGenerator(strategies.InOrderPickingStrategy{}, 12).new(seed);
    var g = (try game_generator.next()).?;
    std.debug.print("Game = {s}", .{g});

    std.log.info("Dice = {s}", .{out});

    //const Us = transform(&[_]type{i32,u32,u32}, identity);
}

const expect = std.testing.expect;

test "something" {
    //try expect(false);
}

// fn transform(comptime Ts : [] const type, comptime f : fn(type)type) [Ts.len] type {
    
//     var Us = [_]type{undefined}**(Ts.len);
    
//     inline for (Ts) |T,idx| {
//         Us[idx] = f(T);
//     } 

//     return Us;
// }
