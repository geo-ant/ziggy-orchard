const std = @import("std");
const dice = @import("dice.zig");

const game = @import("game.zig");

fn dummy_picking_strat(g :game.Game) ?usize {
    const indices = [_]u8{0,1,2,3};
    for (indices) |idx| {
        if (g.fruit_count[idx] > 0) {
            std.log.info("Select index = {}", .{idx});
            return idx;
        }
    }
    return null;
}

fn hasFnWithSig(comptime T : type, comptime name :[]const u8, comptime Sig : anytype, comptime R : type) bool {
    
    // this is just to save some compile time in case the function name does not exist at all
    if (!@hasDecl(T, name)) {
        return false;
    }

    comptime const decls   = switch (@typeInfo(T)) {
        .Union => |u| u,
        .Struct => |s| s,
        .Enum => |e| e,
        else => return null,
    }.decls;

    comptime {
        inline for (decls) |decl| {
            if (std.mem.eql(u8, name, decl.name)) {
                switch (decl.data) {
                    .Fn => |fndecl| {
                        // @compileLog("fndecl.fn_type = ", fndecl.fn_type);
                        if( !areEqualExceptForError(fndecl.return_type,R)) {
                            return false;
                        }
                        // maybe replace by a if (unpack(Variant, val)) |var| {}
                        const func =  switch (@typeInfo(fndecl.fn_type)) {
                            .Fn => |f| f,
                            else => @compileError("This should have been a function type. Something must have changed with lib / compiler internals."),
                        };

                        const signature_types = extractFunctionArguments(Sig);

                        comptime if (signature_types.len==func.args.len) {
                            inline for (signature_types) |arg_type,idx| {
                                if (arg_type != func.args[idx].arg_type) {
                                    return false;
                                }
                            }
                        } else {
                            return false;
                        };
                        return true;
                    },
                    else => {}
                }
            }
        }
    }
    return false;
}

fn hasFnWithSig2(comptime T : type, comptime name :[]const u8, comptime Signature : type) bool {
    
    // this is just to save some compile time in case the function name does not exist at all
    if (!@hasDecl(T, name)) {
        return false;
    }


    comptime const decls   = switch (@typeInfo(T)) {
        .Union => |u| u,
        .Struct => |s| s,
        .Enum => |e| e,
        else => return null,
    }.decls;

    comptime {
        inline for (decls) |decl| {
            if (std.mem.eql(u8, name, decl.name)) {
                switch (decl.data) {
                    .Fn => |fndecl| { 
                        // this is very simple but will not enable us to
                        // use it with functions returning inferred error unions
                        // unless we are able to specify them
                        return functionMatchesSignature(fndecl.fn_type,Signature);
                    },
                    else => {}
                }
            }
        }
    }
    return false;
}

fn tryUnwrap(optional : anytype, variant : anytype) ?@TypeOf(@typeInfo(optional.?)) {
    return switch(union_val) {
        variant => |val| val,
        else => null,
    };
}

// for syntax sugar
const This = struct{};

fn functionMatchesSignature(comptime MemberFunction:type, comptime Signature:type) bool {
    const function_info = @typeInfo(MemberFunction).Fn;
    const signature_info = @typeInfo(Signature).Fn;
    
    //TODO: it seems std.meta.eql will not work for slices 
    // I expected it to iterate through the slice and recursively compare for equaliy, which was probably naive
    // if(!std.meta.eql(function_info.args, signature_info.args)) {
    //     return false;
    // }

    // compare the argument list
    inline for (function_info.args) |arg,idx| {
        if(!std.meta.eql(arg, signature_info.args[idx])) {
            return false;
        }
    } 
    // compare the signature. Here we allow anyerror to be the same as an inferred error set.function_info
    // if any other error is given in the return type, then the errors must exactly match
    // In all cases but one we test that the return types of the signatures are exactly identical
    // the one case is that the return type of the signature is anyerror!T. In this case we test only that
    // the non-error payloads of the functions are equivalent. This to give the user a chance to test for 
    // inferred signatures without exactly knowing the error set type.
    if (signature_info.return_type) |signature_return_type| {
        if (function_info.return_type) |function_return_type| {
            switch(@typeInfo(signature_return_type)) {
                .ErrorUnion => |signature_error_union| {
                    if (signature_error_union.error_set == anyerror) {
                        switch(@typeInfo(function_return_type)) {
                            .ErrorUnion => |function_return_error_union| {
                                    return std.meta.eql(function_return_error_union.payload, signature_error_union.payload);
                            },
                            else => {},
                        }
                    }
                },
                else => {}
            }
        }
    }
    
    return std.meta.eql(signature_info.return_type, function_info.return_type);
}

// fn unwrapAs(comptime union_ : anytype, variant : anytype) @TypeOf(union_.variant) {
//     return switch(union_) {
//         variant => |val| val,
//         else => @compileError("Union cannot be unwrapped as the given variant"),
//     };
// }

/// returns true if the types are the same, but it is also ok if the types have 
/// different error unions. Then the child types are compared. Eg. Err1!T and Err2!T will
/// compare equal
/// TODO: make this better so that the types only compare equal when the RHS argument error
/// union is anyerror!T
fn areEqualExceptForError(comptime T : type, comptime U: type) bool {
    const unpacked_T= switch(@typeInfo(T)) {
        .ErrorUnion => |eu| eu.payload,
        else => T,
    };
    const unpacked_U = switch(@typeInfo(U)) {
        .ErrorUnion => |eu| eu.payload,
        else => U,
    };
    return unpacked_T == unpacked_U;
}

fn extractFunctionArguments(comptime Sig : anytype) []type {
    const structure = switch (@typeInfo(@TypeOf(Sig))){
        .Struct => |s| s,
        else => @compileError("Must be a struct"),
    };
    comptime if (structure.decls.len > 0) {
        @compileError("Signature struct may have no declarations");
    };

    var signature_types = [_]type{undefined} ** (structure.fields.len);

    inline for (structure.fields) |field, idx| {
        if (field.field_type != type) {
            @compileError("The fields of the signature struct must be types");
        }
        signature_types[idx] = field.default_value orelse {@compileError("The types cannot have empty value");};
    }


    return &signature_types;
}

fn transform(comptime Ts : [] const type, comptime f : fn(type)type) [Ts.len] type {
    
    var Us = [_]type{undefined}**(Ts.len);
    
    inline for (Ts) |T,idx| {
        Us[idx] = f(T);
    } 

    return Us;
}


// fn transform2(comptime T : anytype, comptime U: anytype, comptime Ts : [] const T, comptime f : fn(T)U) ?[Ts.len] U {
    
//     var Us = [_]U{undefined}**(Ts.len);
    
//     inline for (Ts) |T,idx| {
//         Us[idx] = f(T);
//     } 

//     return Us;
// }

fn identity(comptime T: type) type {
    return T;
}



pub fn main() anyerror!void {
    std.log.info("All your codebase are belong to us.", .{});
    var trees = dice.Fruit.TREE_COUNT;

    var dr1 = dice.DiceResult.new_basket();
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
    var game_generator = game.GameGenerator(dummy_picking_strat, 12).new(seed);
    var g = (try game_generator.next()).?;
    std.debug.print("Game = {s}", .{g});

    std.log.info("Dice = {s}", .{out});

    const FakeError = error{none};

    std.log.info("Has function Dice = {}", .{hasFnWithSig(dice.DiceResult,"new_raven",.{},dice.DiceResult)});
    std.log.info("Has function Game = {}", .{hasFnWithSig(game.Game,"applySingleTurn",.{u3,u4},anyerror!void)});
    std.log.info("Has function Game = {}", .{hasFnWithSig(game.Game,"isWon",.{game.Game},bool)});
    std.log.info("Has function Game = {}", .{hasFnWithSig(game.Game,"pick_one",.{*game.Game,usize},FakeError!void)});
    std.log.info("Has function Game = {}", .{hasFnWithSig(game.Game,"pick_one",.{*game.Game,usize},anyerror!void)});
    std.log.info("***\n", .{});

    std.log.info("Has function2 Game = {}", .{hasFnWithSig2(game.Game,"isWon",fn(game.Game) bool)});
    std.log.info("Has function2 Game = {}", .{hasFnWithSig2(game.Game,"totalFruitCount",fn(game.Game)usize)});
    std.log.info("Has function2 Game = {}", .{hasFnWithSig2(game.Game,"pick_one",fn(*game.Game,usize)FakeError!void)});
    std.log.info("Has function2 Game = {}", .{hasFnWithSig2(game.Game,"pick_one",fn(*game.Game,usize)anyerror!void)});

    const Us = transform(&[_]type{i32,u32,u32}, identity);
}

const expect = std.testing.expect;

test "something" {
    //try expect(false);
}