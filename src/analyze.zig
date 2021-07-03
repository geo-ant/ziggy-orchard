const game = @import("game.zig");

/// Simple analyzer which counts wins and losses
pub const WinLossAnalyzer = struct {
    // number of total turns
    turns : usize ,
    // number of games lost
    losses : usize ,
    // number of games won
    wins : usize ,

    pub fn init() @This() {
        return @This() {.wins = 0, .losses = 0, .turns = 0};
    }

    /// accumulate two analyzers and create a new one with the
    /// cumulative wins, losses, and turns
    pub fn accAnalyzer(self : @This(), other: @This()) @This() {
        return WinLossAnalyzer {
            .turns = self.turns+ other.turns, .losses = self.losses + other.losses, .wins = self.wins + other.wins
        };
    }

    /// accumulate a game and create a new analyzer with the 
    /// new number of wins, losses, and turns
    /// returns an error if the given game is both won and lost
    pub fn accGame(self : @This(), g : game.Game) !@This() {
        const new_turns = self.turns+g.turn_count;
        var new_losses = self.losses;
        var new_wins = self.wins;
        const won = g.isWon();
        const lost = g.isLost();
        if (won and lost) {
            return error.IllegalGameState;
        }

        if (won) {
            new_wins +=1;
        } else {
            new_losses +=1;
        }
        return WinLossAnalyzer {
            .turns = new_turns, .wins = new_wins, .losses = new_losses
        };
    }
};

const std = @import("std");
const concepts = @import("concepts.zig");

test "WinLossAnalyzer.init()" {
    const wla = WinLossAnalyzer.init();
    try std.testing.expect(std.meta.eql(wla, .{.wins = 0, .losses = 0, .turns = 0}));
}

test "WinLossAnalyzer.accAnalyzer" {
    const anal1  = WinLossAnalyzer{.turns = 1, .wins = 2, .losses = 3};
    const anal2  = WinLossAnalyzer{.turns = 2, .wins = 4, .losses = 6};
    try std.testing.expect(std.meta.eql(anal1.accAnalyzer(anal2),anal2.accAnalyzer(anal1)));
    try std.testing.expect(std.meta.eql(anal1.accAnalyzer(anal2),.{.turns = 3, .wins = 6, .losses = 9}));
}

test "WinLossAnalyzer.accGame" {
    const anal  = WinLossAnalyzer{.turns = 1, .wins = 2, .losses = 3};

    const gwon = game.Game{.fruit_count = [_]usize{0}**game.TREE_COUNT, .raven_count = 0, .turn_count = 12};
    try std.testing.expect(gwon.isWon() and !gwon.isLost());
    try std.testing.expect(std.meta.eql(anal.accGame(gwon) catch unreachable,.{.turns=13,.wins = 3,.losses = 3}));

    const glost = game.Game{.fruit_count = [1]usize{1}**game.TREE_COUNT, .raven_count = game.RAVEN_COMPLETE_COUNT, .turn_count = 123};
    try std.testing.expect(!glost.isWon() and glost.isLost());
    try std.testing.expect(std.meta.eql(anal.accGame(glost) catch unreachable,.{.turns=124,.wins = 2,.losses = 4}));

    const gillegal = concepts.structUpdate(gwon,.{.raven_count = game.RAVEN_COMPLETE_COUNT});
    try std.testing.expect(gillegal.isWon() and gillegal.isLost());
    try std.testing.expectError(error.IllegalGameState, anal.accGame(gillegal));
}