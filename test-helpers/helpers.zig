const MatchError = error {
    IncorrectVariant,
};



/// helper function that asserts that `arg` matches the given variant
/// # Returns
/// void if the match is true, otherwise an error
pub fn expectMatches(arg: anytype, comptime Variant : anytype) MatchError!void {
    switch (arg) {
        Variant => {},
        else => {return MatchError.IncorrectVariant;}
    }
}
