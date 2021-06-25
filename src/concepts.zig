const std = @import("std");

pub fn hasFn(comptime T : type, comptime name :[]const u8, comptime Signature : type) bool {
    
    const decls   = switch (@typeInfo(T)) {
        .Union => |u| u,
        .Struct => |s| s,
        .Enum => |e| e,
        else => return false,
    }.decls;

    // this *might* help save some compile time if the decl is not present in the container at all
    if(!@hasDecl(T, name)) {
        return false;
    }

    comptime {
        inline for (decls) |decl| {
            if (std.mem.eql(u8, name, decl.name)) {
                switch (decl.data) {
                    .Fn => |fndecl| { 
                        return functionMatchesSignature(fndecl.fn_type,Signature);
                    },
                    else => {}
                }
            }
        }
    }
    return false;
}

fn functionMatchesSignature(comptime MemberFunction:type, comptime Signature:type) bool {
    const function_info = @typeInfo(MemberFunction).Fn;
    const signature_info = @typeInfo(Signature).Fn;
    
    // compare the argument list, but make sure that the argument lists are of the same length!
    if (function_info.args.len != signature_info.args.len) {
        return false;
    }
    //I have to loop unroll here, because I cannot just compare slices with std.meta.eql
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

test "concepts.hasFn always returns false when not given a container" {
    try std.testing.expect(!hasFn(i32, "func", fn(i32)i32));
    try std.testing.expect(!hasFn(f32, "f32", fn(f32)f32));
}   

test "concepts.hasFn correctly matches function name and signatures for container types" {
    const MyError = error{Something};
    
    const S = struct {
        value : i32,

        fn default() @This() {
            return .{.value=0};
        }

        fn new(val : i32) @This() {
            return .{.value=val};
        }

        fn increment(self : *@This()) !void {
            if (self.value < 0) {
                self.value += 1;
            } else {
                return MyError.Something;
            }
        }

        fn withMyError(_ : i32) MyError!i32 {
            return MyError.Something;
        }

        fn withAnyError() anyerror!i32 {
            return MyError.Something;
        }

    };
    // hasFn should find everything that is there
    try std.testing.expect(hasFn(S,"default",fn()S));
    try std.testing.expect(hasFn(S,"new",fn(i32)S));
    try std.testing.expect(hasFn(S,"increment",fn(*S)anyerror!void));
    try std.testing.expect(hasFn(S,"withMyError",fn(i32)MyError!i32));

    // hasFn must return false for wrong names or wrong signatures
    try std.testing.expect(!hasFn(S,"DeFAuLt",fn()S));
    try std.testing.expect(!hasFn(S,"NEW",fn(i32,i32)S));
    try std.testing.expect(!hasFn(S,"increment",fn(*S,i32)anyerror!void));
    try std.testing.expect(!hasFn(S,"withMyError",fn(i64)MyError!i32));
    try std.testing.expect(!hasFn(S,"withMyError",fn(i16)MyError!i32));

    const DifferentError = error{SomethingElse}; 

    // hasFn compares error unions strictly unless signature we ask for is anyerror
    try std.testing.expect(hasFn(S,"withMyError",fn(i32)anyerror!i32));
    try std.testing.expect(hasFn(S,"withAnyError",fn()anyerror!i32));

    try std.testing.expect(!hasFn(S,"withAnyError",fn()MyError!i32));
    try std.testing.expect(!hasFn(S,"withAnyError",fn()DifferentError!i32));
    try std.testing.expect(!hasFn(S,"withMyError",fn(i32)DifferentError!i32));

    // this works because the inferred error union is exactly only MyError
    try std.testing.expect(!hasFn(S,"increment",fn(*S,i32)MyError!void));
}

fn hasField(comptime T: type, comptime name :[]const u8, comptime FieldType : type) bool {
    const fields   = switch (@typeInfo(T)) {
        .Union => |u| u,
        .Struct => |s| s,
        .Enum => |e| e,
        else => return false,
    }.fields;

    // this *might* help save some compile time if the decl is not present in the container at all
    if(!@hasField(T, name)) {
        return false;
    }

    inline for (fields) |field| {
        if (std.mem.eql(u8, field.name, name) and field.field_type == FieldType) {
            return true;
        }
    }

    return false;
}

test "concepts.hasField" {

    const S = struct {
        foo : i32,
        bar : f32,
    };

    try std.testing.expect(hasField(S, "foo", i32));
    try std.testing.expect(hasField(S, "bar", f32));

    try std.testing.expect(!hasField(S, "foo", u32));
    try std.testing.expect(!hasField(S, "bar", f64));

    try std.testing.expect(!hasField(S, "fooo", i32));
    try std.testing.expect(!hasField(S, "az", f32));
    try std.testing.expect(!hasField(S, "ba", f32));
    try std.testing.expect(!hasField(S, "baz", f32));
}