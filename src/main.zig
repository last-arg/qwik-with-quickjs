const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const c = @cImport({
    @cInclude("quickjs.h");
    @cInclude("quickjs-libc.h");
});
const qwik = @import("qwik_render");

pub fn main() anyerror!void {
    var sol1 = try Solution1.init();
    defer sol1.deinit();
    const result = try sol1.getHtmlString();
    printValue(sol1.ctx, result);
}

const Solution1 = struct {
    runtime: *c.JSRuntime,
    ctx: *c.JSContext,
    var result: ?c.JSValue = null;

    const Self = @This();

    pub fn init() !Self {
        const rt = c.JS_NewRuntime() orelse {
            return error.FailedToCreateJSRuntime;
        };
        // c.JS_SetCanBlock(rt, 1);

        const ctx = c.JS_NewContext(rt) orelse {
            return error.FailedToCreateJSContext;
        };

        c.js_std_add_helpers(ctx, -1, null);
        // NOTE: last arguement '1' means load_only
        c.js_std_eval_binary(ctx, &qwik.qjsc_quickjs_polyfill, qwik.qjsc_quickjs_polyfill_size, 1);
        c.js_std_eval_binary(ctx, &qwik.qjsc_core, qwik.qjsc_core_size, 1);
        c.js_std_eval_binary(ctx, &qwik.qjsc_server, qwik.qjsc_server_size, 1);
        c.js_std_eval_binary(ctx, &qwik.qwik_render, qwik.qwik_render_size, 0);

        return Self{ .runtime = rt, .ctx = ctx };
    }

    pub fn getHtmlString(self: *Self) !c.JSValue {
        const ctx = self.ctx;
        const js_undefined = @import("std").mem.zeroInit(c.JSValue, .{ c.JSValueUnion{
            .int32 = @as(c_int, 0),
        }, c.JS_TAG_UNDEFINED });
        defer c.JS_FreeValue(ctx, js_undefined);

        const global_obj = c.JS_GetGlobalObject(ctx);
        defer c.JS_FreeValue(ctx, global_obj);

        const jsRenderToString = c.JS_GetPropertyStr(ctx, global_obj, "testFnAsync");
        defer c.JS_FreeValue(ctx, jsRenderToString);
        const render_promise = c.JS_Call(ctx, jsRenderToString, js_undefined, 0, null);
        defer c.JS_FreeValue(ctx, render_promise);
        const render_promise_then = c.JS_GetPropertyStr(ctx, render_promise, "then");
        defer c.JS_FreeValue(ctx, render_promise_then);
        const name = "thenCb";
        const promise_then_cb = c.JS_NewCFunction(ctx, thenCb, name, name.len);
        defer c.JS_FreeValue(ctx, promise_then_cb);
        const call_promise_then = c.JS_Call(ctx, render_promise_then, render_promise, 2, &[_]c.JSValue{
            promise_then_cb,
        });
        defer c.JS_FreeValue(ctx, call_promise_then);
        c.js_std_loop(ctx);
        if (result == null) return error.JSStringIsNull;
        return result.?;
        // return c.JS_NewInt32(ctx, 1);
    }

    // var js_val: ?c.JSValue = null;
    // pub const JSCFunction = fn (?*JSContext, JSValue, c_int, [*c]JSValue) callconv(.C) JSValue;
    fn thenCb(ctx: ?*c.JSContext, func: c.JSValue, arg_count: c_int, args: [*c]c.JSValue) callconv(.C) c.JSValue {
        print("func: {d}\n", .{func});
        printValue(ctx, func);
        print("arg_count: {d}\n", .{arg_count});
        var i: usize = 0;
        while (i < arg_count) : (i += 1) {
            printValue(ctx, args[i]);
        }
        result = args[0];
        return c.JS_NewInt32(ctx, 1);
    }

    pub fn deinit(self: *Self) void {
        c.JS_FreeContext(self.ctx);
        c.JS_FreeRuntime(self.runtime);
    }
};

fn printValue(ctx: ?*c.JSContext, val: c.JSValue) void {
    const str = c.JS_ToCString(ctx, val);
    defer c.JS_FreeCString(ctx, str);
    print("JS_Value: {s}\n", .{str});
}

fn printException(ctx: *c.JSContext) void {
    const ex = c.JS_GetException(ctx);
    const ex_str = c.JS_ToCString(ctx, ex);
    print("ex: {s}\n", .{ex_str});
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
