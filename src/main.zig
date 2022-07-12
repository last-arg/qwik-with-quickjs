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
}

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
