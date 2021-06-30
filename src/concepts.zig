const std = @import("std");

/// Syntactic sugar to refer to the Self/@This() type in the hasFn Signature argument
pub const Self = struct{};

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
pub fn hasFn(comptime name :[]const u8, comptime Signature : type) std.meta.trait.TraitFn {
    

    const Closure = struct {

        pub fn trait(comptime T:type) bool {
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

/// TODO document, helper function
/// replace occurrences of the This type with the type T
fn replaceSelfType(comptime ArgType : type, comptime ReplacementType : type) type {
    if (ArgType == Self) {
        return ReplacementType;
    }
    
    switch (@typeInfo(ArgType)) {
        .Type => return ArgType,
        .Void => return ArgType,
        .Bool => return ArgType,
        .NoReturn => return ArgType,
        .Int => return ArgType,
        .Float => return ArgType,
        .Pointer => |pointer| {
                return @Type(std.builtin.TypeInfo{.Pointer = structUpdate(pointer,.{.child= replaceSelfType(pointer.child,ReplacementType)})});
            },
        .Array => return ReplacementType, //TODO
        .Struct => return ReplacementType, //TODO
        .ComptimeFloat => return ArgType, 
        .ComptimeInt => return ArgType,
        .Undefined => return ArgType,
        .Null => return ArgType,
        .Optional => |optional| {
            return @Type(std.builtin.TypeInfo{.Optional = structUpdate(optional, .{.child= replaceSelfType(optional.child,ReplacementType)})});
            },
        .ErrorUnion => return ReplacementType, //TODO
        .ErrorSet => return ArgType,
        .Enum => return ReplacementType, //TODO
        .Union => return ReplacementType, //TODO
        .Fn => return ReplacementType, //TODO
        .BoundFn => return ReplacementType, //TODO
        .Opaque => return ArgType,
        .Frame => return ArgType,
        .AnyFrame => return ArgType,
        .Vector => return ReplacementType, // TODO
        .EnumLiteral => return ArgType,
    }
}

test "replaceSelfType" {
    const Base = struct{};
    //TODO also test that nothing else gets altered!

    try std.testing.expectEqual(replaceSelfType(Self,Base),Base);
    try std.testing.expectEqual(replaceSelfType(*Self,Base),*Base);
    try std.testing.expectEqual(replaceSelfType([]Self,Base),[]Base);
    try std.testing.expectEqual(replaceSelfType(?Self,Base),?Base);
    try std.testing.expectEqual(replaceSelfType([4]Self,Base),[4]Base);

    // // and so on
    // // etc etc
    // try std.testing.expectEqual(replaceSelfType(fn()Self,Base),fn()Base);
    // try std.testing.expectEqual(replaceSelfType(fn(*Self)?i32,Base),fn(*Base)i32);

    // etc etc

}


/// TODO DOCUMENT, this is like a rust style struct update syntax
fn structUpdate(instance : anytype, update : anytype) @TypeOf(instance) {
    const InstanceType = @TypeOf(instance);

    if(@typeInfo(InstanceType) != .Struct) {
        @compileError("This function can only be applied to struct types");
    }

    const update_fields = switch(@typeInfo(@TypeOf(update))) {
        .Struct => |info| info,
        else => @compileError("The update argument must be a tuple or struct containing the fields to be updated"),
    }.fields;

    var updated_instance = instance;

    inline for (update_fields) |field| {
        if(@hasField(InstanceType, field.name)) {
            @field(updated_instance, field.name) = @field(update, field.name);
        } else {
            @compileError("Type " ++ @typeName(InstanceType) ++ " has no field named '" ++ field.name ++ "'");
        }
    }

    return updated_instance;
}

test "structUpdate" {
    const S = struct {
        a : i32,
        b : i32,
        c : f32,
    };

    const s = S{.a=1,.b=2,.c=3.14};

    const s_noupdate = structUpdate(s, .{});
    try std.testing.expect(std.meta.eql(s_noupdate, s));

    const s_new = structUpdate(s, .{.a = 20});
    try std.testing.expect(std.meta.eql(s_new, .{.a=20,.b=2,.c=3.14}));
}

test "concepts.hasFn always returns false when not given a container" {
    try std.testing.expect(!hasFn("func",fn(i32)i32)(i32));
    try std.testing.expect(!hasFn("f32", fn(f32)f32)(i32));
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
    try std.testing.expect(hasFn("default",fn()S)(S));
    try std.testing.expect(hasFn("new",fn(i32)S)(S));
    try std.testing.expect(hasFn("increment",fn(*S)anyerror!void)(S));
    try std.testing.expect(hasFn("withMyError",fn(i32)MyError!i32)(S));

    // // hasFn must return false for wrong names or wrong signatures
    try std.testing.expect(!hasFn("DeFAuLt",fn()S)(S));
    try std.testing.expect(!hasFn("NEW",fn(i32,i32)S)(S));
    try std.testing.expect(!hasFn("increment",fn(*S,i32)anyerror!void)(S));
    try std.testing.expect(!hasFn("withMyError",fn(i64)MyError!i32)(S));
    try std.testing.expect(!hasFn("withMyError",fn(i16)MyError!i32)(S));

    const DifferentError = error{SomethingElse}; 

    // // hasFn compares error unions strictly unless signature we ask for is anyerror
    try std.testing.expect(hasFn("withMyError",fn(i32)anyerror!i32)(S));
    try std.testing.expect(hasFn("withAnyError",fn()anyerror!i32)(S));

    try std.testing.expect(!hasFn("default",fn()anyerror!S)(S));
    try std.testing.expect(!hasFn("withAnyError",fn()MyError!i32)(S));
    try std.testing.expect(!hasFn("withAnyError",fn()DifferentError!i32)(S));
    try std.testing.expect(!hasFn("withMyError",fn(i32)DifferentError!i32)(S));

    // // this works because the inferred error union is exactly only MyError
    try std.testing.expect(!hasFn("increment",fn(*S,i32)MyError!void)(S));
}


/// An extension of std.meta.hasField, which takes an additional parameter specifying the
/// type of the field.
/// # Arguments
/// * `T` the type we want to inspect
/// * `name` the name of the field we are looking for
/// * `FieldType` the type of the field we are looking for
/// # Returns
/// True iff T has a field with name `name` and type `FieldType`.
pub fn hasField(comptime name :[]const u8, comptime FieldType : type) std.meta.trait.TraitFn {
    
    const Closure = struct {
        pub fn trait (comptime T: type) bool{
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
    };
    return Closure.trait;
}


test "concepts.hasField" {

    const S = struct {
        foo : i32,
        bar : f32,
    };

    try std.testing.expect(hasField("foo", i32)(S));
    try std.testing.expect(hasField("bar", f32)(S));

    try std.testing.expect(!hasField("foo", u32)(S));
    try std.testing.expect(!hasField("bar", f64)(S));

    try std.testing.expect(!hasField("fooo", i32)(S));
    try std.testing.expect(!hasField("az", f32)(S));
    try std.testing.expect(!hasField("ba", f32)(S));
    try std.testing.expect(!hasField("baz", f32)(S));

    try std.testing.expect(!hasField("baz", i32)(i32));

}