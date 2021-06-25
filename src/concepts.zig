const std = @import("std");

/// A function similar to std.meta.hasFn, but providing an extra argument which allows
/// to specify the signature of the function. It will check if the given type (which must be
/// a struct, union, or enum) declares a function with the given name and signature.
/// # Arguments
/// * `name` The name of the function which we are looking for
/// * `Signature`: the function signature we are looking for
/// # Returns
/// A std.meta.trait.TraitFn that takes a type T and returns 
/// true iff T declares a function with the given name and signature. There
/// is one detail that allows us to query inferred error unions.
/// ## On Function Signatures and Errors
/// Usually the function signature declared in the type and the given `Signature` must match
/// exactly, which means that the error return types must match exactly. But there is one exception
/// to this rule. If we specify `fn(...)anyerror!...` as the `Signature` argument, then if and 
/// only if the return type of the function is also an error union, the error type is discarded when
/// matching the signatures. That means only the error payload and the function argument types have to
/// match and any error is accepted. This is very handy if the declaration uses an inferred error union,
/// which might be almost impossible to match, or if we don't care about the exact error return type of
/// the function. That means a `Signature` of `fn(T)anyerror!U` *will* match `fn(T)E!U` for any `E` and also
/// `fn(T)anyerror!U`. However, it will not match `fn(T)U`.
pub fn hasFn(comptime Signature : type, comptime name :[]const u8) std.meta.trait.TraitFn {
    

    const Closure = struct {

        fn trait(comptime T:type) bool {
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
    };
    return Closure.trait;
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
    try std.testing.expect(!hasFn(fn(i32)i32,"func")(i32));
    try std.testing.expect(!hasFn(fn(f32)f32,"f32")(i32));
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
    try std.testing.expect(hasFn(fn()S,"default")(S));
    try std.testing.expect(hasFn(fn(i32)S,"new")(S));
    try std.testing.expect(hasFn(fn(*S)anyerror!void,"increment")(S));
    try std.testing.expect(hasFn(fn(i32)MyError!i32,"withMyError")(S));

    // hasFn must return false for wrong names or wrong signatures
    try std.testing.expect(!hasFn(fn()S,"DeFAuLt")(S));
    try std.testing.expect(!hasFn(fn(i32,i32)S,"NEW")(S));
    try std.testing.expect(!hasFn(fn(*S,i32)anyerror!void,"increment")(S));
    try std.testing.expect(!hasFn(fn(i64)MyError!i32,"withMyError")(S));
    try std.testing.expect(!hasFn(fn(i16)MyError!i32,"withMyError")(S));

    const DifferentError = error{SomethingElse}; 

    // hasFn compares error unions strictly unless signature we ask for is anyerror
    try std.testing.expect(hasFn(fn(i32)anyerror!i32,"withMyError")(S));
    try std.testing.expect(hasFn(fn()anyerror!i32,"withAnyError")(S));

    try std.testing.expect(!hasFn(fn()anyerror!S,"default")(S));
    try std.testing.expect(!hasFn(fn()MyError!i32,"withAnyError")(S));
    try std.testing.expect(!hasFn(fn()DifferentError!i32,"withAnyError")(S));
    try std.testing.expect(!hasFn(fn(i32)DifferentError!i32,"withMyError")(S));

    // this works because the inferred error union is exactly only MyError
    try std.testing.expect(!hasFn(fn(*S,i32)MyError!void,"increment")(S));
}


/// An extension of std.meta.hasField, which takes an additional parameter specifying the
/// type of the field.
/// # Arguments
/// * `T` the type we want to inspect
/// * `name` the name of the field we are looking for
/// * `FieldType` the type of the field we are looking for
/// # Returns
/// True iff T has a field with name `name` and type `FieldType`.
pub fn hasField(comptime T: type, comptime name :[]const u8, comptime FieldType : type) bool {
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