const std = @import("std");

const Error = error {
    IncorrectVariant,
    NotAnErrorType,
    IncorrectErrorType,
    UnexpectedEmptyOptional,
    UnexpectedErrorVariant,
};



/// helper function that asserts that `arg` matches the given variant
/// # Returns
/// void if the match is true, otherwise an error
pub fn expectVariant(arg: anytype, comptime Variant : anytype) Error!void {
    const variant = switch (@typeInfo(@TypeOf(arg))) {
            .Optional => 
                arg orelse {return Error.UnexpectedEmptyOptional;},
            .ErrorUnion => 
                arg catch {return Error.UnexpectedErrorVariant;},
            else =>  arg,
    };

    switch (variant) {
        Variant => {},
        else => {return Error.IncorrectVariant;}
    }
}

pub fn expectError(_arg : anytype) Error!void {
    if(_arg) {
        return Error.NotAnErrorType;
    } else |_err| {
        return;
    }
}

pub fn expectErrorVariant(_arg: anytype, comptime ErrorVariant : anytype) Error!void {
    if (_arg) {
        return Error.NotAnErrorType;
    } else |err| {
        switch (err) {
            ErrorVariant  => return,
            else => return Error.IncorrectErrorType,
        }
    }
}