const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const c = @cImport({
    @cInclude("quickjs.h");
    @cInclude("quickjs-libc.h");
});
const qwik = @import("qwik_render");

pub fn main() anyerror!void {
    const rt = c.JS_NewRuntime() orelse {
        return error.FailedToCreateJSRuntime;
    };
    defer c.JS_FreeRuntime(rt);

    const ctx = c.JS_NewContext(rt) orelse {
        return error.FailedToCreateJSContext;
    };
    defer c.JS_FreeContext(ctx);

    c.js_std_add_helpers(ctx, -1, null);
    // NOTE: last arguement '1' means load_only
    c.js_std_eval_binary(ctx, &qwik.qjsc_quickjs_polyfill, qwik.qjsc_quickjs_polyfill_size, 1);
    c.js_std_eval_binary(ctx, &qwik.qjsc_core, qwik.qjsc_core_size, 1);
    c.js_std_eval_binary(ctx, &qwik.qjsc_server, qwik.qjsc_server_size, 1);
    c.js_std_eval_binary(ctx, &qwik.qwik_render, qwik.qwik_render_size, 0);
    const global_obj = c.JS_GetGlobalObject(ctx);
    defer c.JS_FreeValue(ctx, global_obj);
    printProperties(ctx, global_obj);

    const testFn = c.JS_GetPropertyStr(ctx, global_obj, "testFn");
    defer c.JS_FreeValue(ctx, testFn);

    const js_undefined = @import("std").mem.zeroInit(c.JSValue, .{ c.JSValueUnion{
        .int32 = @as(c_int, 0),
    }, c.JS_TAG_UNDEFINED });
    const val2 = c.JS_Call(ctx, testFn, js_undefined, 0, null);
    print("val2: {any}\n", .{val2});
    const str = c.JS_ToCString(ctx, val2);
    print("str: {s}\n", .{str});

    // if (c.JS_TAG_MODULE == val.tag) {
    //     print("I AM MODULE\n", .{});
    //     {
    //         // setModuleMeta(ctx, val, filename);

    //         const ret = c.JS_EvalFunction(ctx, val);
    //         print("ret: {any}\n", .{ret});

    //         const m = @ptrCast(*c.JSModuleDef, c.JS_VALUE_GET_PTR(val));
    //         const meta = c.JS_GetImportMeta(ctx, m);
    //         defer c.JS_FreeValue(ctx, meta);
    //         // printProperties(ctx, meta);

    //         const global_obj = c.JS_GetGlobalObject(ctx);
    //         defer c.JS_FreeValue(ctx, global_obj);
    //         printProperties(ctx, global_obj);
    //     }
    //     {
    //         // const ret = evalFunction
    //         // if (c.JS_TAG_EXCEPTION == ret.tag) {
    //         //     const ex = c.JS_GetException(ctx);
    //         //     const str = c.JS_ToCString(ctx, ex);
    //         //     print("ex: {s}\n", .{str});
    //         //     const stack_atom = c.JS_NewAtom("stack");
    //         //     const stack = c.JS_GetProperty(ctx, ex, stack_atom);
    //         //     const stack_str = c.JS_ToCString(ctx, ex);
    //         //     print("stack_str: {s}\n", .{stack_str});
    //         // }
    //     }
    // } else {
    //     print("NOT MODULE\n", .{});
    // }
}

// pub fn main() anyerror!void {
//     const js_runtime = c.JS_NewRuntime() orelse {
//         return error.FailedToCreateJSRuntime;
//     };
//     defer c.JS_FreeRuntime(js_runtime);

//     c.js_std_set_worker_new_context_func(c.JS_NewContext);
//     c.js_std_init_handlers(js_runtime);
//     const js_context = c.JS_NewContext(js_runtime) orelse {
//         return error.FailedToCreateJSContext;
//     };
//     defer c.JS_FreeContext(js_context);
//     const os_module = c.js_init_module_os(js_context, "os");
//     print("os_module: {any}\n", .{os_module});

//     c.JS_SetModuleLoaderFunc(js_runtime, null, c.js_module_loader, null);
//     c.js_std_add_helpers(js_context, 0, null);

//     var len: usize = 0;
//     const filename: [:0]const u8 = "tmp/quickjs_test.js";
//     // const c_buf = c.js_load_file(js_context, &len, filename);
//     // _ = c_buf;
//     // print("c_buf.len: {d}\n", .{len});
//     // const buf = c_buf[0..len];
//     const buf: [:0]const u8 = "export function fooFn() { return 987; }; export var foo = 2; globalThis.bar = 34";
//     // const buf: [:0]const u8 = "2 + 2";
//     len = buf.len;
//     print("|{s}|\n", .{buf});

//     const eval_flags = c.JS_EVAL_TYPE_MODULE | c.JS_EVAL_FLAG_COMPILE_ONLY;
//     // const eval_flags = c.JS_EVAL_TYPE_GLOBAL | c.JS_EVAL_FLAG_STRICT;
//     var val = c.JS_Eval(js_context, buf.ptr, len, filename.ptr, eval_flags);
//     defer c.JS_FreeValue(js_context, val);
//     print("val: {any}\n", .{val});

//     try setModuleMeta();

//     // const str = c.JS_ToCString(js_context, val);
//     // print("str: {s}\n", .{str});

//     // {
//     //     const rm = c.JS_ResolveModule(js_context, val);
//     //     print("rm: {any}\n", .{rm});

//     //     const meta = c.js_module_set_import_meta(js_context, val, 1, 0);
//     //     print("meta: {any}\n", .{meta});
//     //     const m = @ptrCast(*c.JSModuleDef, c.JS_VALUE_GET_PTR(val));
//     //     print("m: {any}\n", .{m});
//     //     {
//     //         const module_name_atom = c.JS_GetModuleName(js_context, m);
//     //         defer c.JS_FreeAtom(js_context, module_name_atom);
//     //         const module_name = c.JS_AtomToCString(js_context, module_name_atom);
//     //         defer c.JS_FreeCString(js_context, module_name);
//     //         print("module_name: {s}\n", .{module_name});
//     //     }
//     //     // var tmp_val = val;
//     //     // var val_tmp = @ptrCast(*anyopaque, &val);
//     //     // var func = JS_MKPTR(c.JS_TAG_OBJECT, val_tmp);
//     //     // const func = c.JS_ToObject(js_context, val);
//     //     // print("func: {any}\n", .{func});
//     //     // const obj = c.JS_NewObjectClass(js_context, 1);
//     //     // c.JS_SetObjectData(js_context, obj, c.JS_DupValue(js_context, val));

//     //     const i_meta = c.JS_GetImportMeta(js_context, m);
//     //     defer c.JS_FreeValue(js_context, i_meta);
//     //     print("i_meta: {any}\n", .{i_meta});

//     //     printProperties(js_context, i_meta);

//     //     const m_val = c.JS_GetPropertyStr(js_context, i_meta, "fooFn");
//     //     defer c.JS_FreeValue(js_context, m_val);
//     //     print("m_val: {any}\n", .{m_val});

//     //     const global_obj = c.JS_GetGlobalObject(js_context);
//     //     defer c.JS_FreeValue(js_context, global_obj);
//     //     print("global_obj: {any}\n", .{global_obj});

//     //     printProperties(js_context, global_obj);

//     //     const g = c.JS_GetPropertyStr(js_context, global_obj, "fooFn");
//     //     defer c.JS_FreeValue(js_context, g);
//     //     print("g: {any}\n", .{g});

//     //     // const atom = c.JS_NewAtom(js_context, "foo");
//     //     // defer c.JS_FreeAtom(js_context, atom);
//     //     // const ret = c.JS_GetPropertyInternal(js_context, val, atom, val, 0);
//     //     // print("ret: {any}\n", .{ret});

//     //     // const f = c.JS_EvalFunction(js_context, val);
//     //     // print("f: {any}\n", .{f});

//     //     // if (c.JS_IsException(val) == 1) {
//     //     //     c.js_std_dump_error(js_context);
//     //     // }
//     // }

//     // pub extern fn JS_Invoke(ctx: ?*JSContext, this_val: JSValue, atom: JSAtom, argc: c_int, argv: [*c]JSValue) JSValue;

//     // print("m: {any}\n", .{m});

//     // Need to get function from module

//     // {
//     //     const js_undefined = @import("std").mem.zeroInit(c.JSValue, .{ c.JSValueUnion{
//     //         .int32 = @as(c_int, 0),
//     //     }, c.JS_TAG_UNDEFINED });
//     //     const val2 = c.JS_Call(js_context, @ptrCast(*c.JSValue, @alignCast(8, m)).*, js_undefined, 0, null);
//     //     print("val2 isException: {any}\n", .{c.JS_IsException(val2) == 1});
//     //     print("val2: {any}\n", .{val2});
//     // }

//     // {
//     //     const global_obj = c.JS_GetGlobalObject(js_context);
//     //     defer c.JS_FreeValue(js_context, global_obj);
//     //     print("global_obj: {any}\n", .{global_obj});

//     //     const foo_fn = c.JS_GetPropertyStr(js_context, global_obj, "fooFn");
//     //     defer c.JS_FreeValue(js_context, foo_fn);
//     //     print("foo_fn: {any}\n", .{foo_fn});
//     //     print("foo_fn is function: {any}\n", .{c.JS_IsFunction(js_context, foo_fn) == 1});

//     //     const val2 = c.JS_Call(js_context, foo_fn, global_obj, 0, null);
//     //     print("val2: {any}\n", .{val2});

//     //     const str = c.JS_ToCString(js_context, val2);
//     //     print("str: {s}\n", .{str});

//     // }

//     // c.js_std_loop(js_context);

//     // {
//     //     const gn = c.JS_GetPropertyStr(js_context, global_obj, "getNumber");
//     //     print("gn undefined: {any}\n", .{c.JS_IsUndefined(gn) == 1});
//     //     print("gn: {any}\n", .{c.JS_VALUE_GET_INT(gn)});
//     // const ret = c.JS_Invoke(js_context, gn, 0, 0, null);
//     // print("ret: {any}\n", .{c.JS_VALUE_GET_INT(ret)});
//     // }

//     // print("isFunction: {any}\n", .{c.JS_IsFunction(js_context, val)});

//     // std.log.info("{d} | {d} | {d} | {d}", .{ qjsc_quickjs_polyfill_size, qjsc_core_size, qjsc_server_size, qjsc_test_server_v1_size });
//     // {
//     //     const js_module_def = c.js_init_module_os(js_context, "os");
//     //     _ = js_module_def;
//     // }
//     // print("{any}\n", .{@ptrCast([qjsc_quickjs_polyfill_size]u8, qjsc_quickjs_polyfill)});
//     // print("{any}\n", .{qjsc_quickjs_polyfill});
//     // print("{any}\n", .{qjsc_quickjs_polyfill[0]});
//     // const obj = c.JS_ReadObject(js_context, @ptrCast([*c]const u8, &qjsc_quickjs_polyfill), qjsc_quickjs_polyfill_size, c.JS_READ_OBJ_BYTECODE);
//     // _ = obj;
//     // print("{any}\n", .{obj});

//     // c.js_std_eval_binary(js_context, &qjsc_quickjs_polyfill, qjsc_quickjs_polyfill_size, 1);
//     // c.js_std_eval_binary(js_context, qjsc_core, qjsc_core_size, 1);
//     // c.js_std_eval_binary(js_context, qjsc_server, qjsc_server_size, 1);

//     // c.js_std_eval_binary(js_context, qjsc_test_server_v1, qjsc_test_server_v1_size, 1);

//     std.log.info("All your codebase are belong to us.", .{});
// }

fn printProperties(js_context: *c.JSContext, obj: c.JSValue) void {
    var tabs: [*c]c.JSPropertyEnum = undefined;
    var tabs_len: u32 = 0;
    const s = c.JS_GetOwnPropertyNames(js_context, &tabs, &tabs_len, obj, 1);
    _ = s;
    print("===== PROPS =====\nprops len: {d}\n", .{tabs_len});
    var count: usize = 0;
    while (count < tabs_len) : (count += 1) {
        // print("prop: {}\n", .{tabs[count]});
        const name = c.JS_AtomToCString(js_context, tabs[count].atom);
        defer c.JS_FreeCString(js_context, name);
        print("prop name: {s}\n", .{name});
    }
    print("===== PROPS END =====\n", .{});
}
