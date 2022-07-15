const std = @import("std");
const print = std.debug.print;
const mem = std.mem;
const c = @cImport({
    @cInclude("quickjs.h");
    @cInclude("quickjs-libc.h");
});
const qwik = @import("qwik_render");

pub fn main() anyerror!void {
    {
        var sol1 = try SolutionJsFile.init();
        defer sol1.deinit();
    }

    // {
    //     var sol1 = try Solution1.init();
    //     defer sol1.deinit();
    //     // const html = try sol1.getHtmlString();
    //     // printValue(sol1.ctx, html);
    // }
}

const SolutionJsFile = struct {
    runtime: *c.JSRuntime,
    ctx: *c.JSContext,

    const Self = @This();

    pub fn init() !Self {
        const rt = c.JS_NewRuntime() orelse {
            return error.FailedToCreateJSRuntime;
        };
        // NOTE: '0' sets stack size to unlimited
        c.JS_SetMaxStackSize(rt, 0);
        c.js_std_set_worker_new_context_func(JS_NewCustomContext);
        c.js_std_init_handlers(rt);

        const ctx = JS_NewCustomContext(rt) orelse {
            return error.FailedToCreateJSContext;
        };

        // This resolves other JS imports
        c.JS_SetModuleLoaderFunc(rt, null, c.js_module_loader, null);
        c.JS_SetHostPromiseRejectionTracker(rt, c.js_std_promise_rejection_tracker, null);
        c.js_std_add_helpers(ctx, 0, null);

        // {
        //     const std_os_str: [:0]const u8 =
        //         \\import * as std from 'std';
        //         \\import * as os from 'os';
        //         \\globalThis.std = std;
        //         \\globalThis.os = os;
        //         \\
        //     ;
        //     const name: [:0]const u8 = "<input>";
        //     try evalBuf(ctx, std_os_str, name, c.JS_EVAL_TYPE_MODULE);
        // }

        {
            var len: usize = 0;
            const filename: [:0]const u8 = "./tmp/src/test_server_v1.mjs";
            const c_buf = c.js_load_file(ctx, &len, filename);
            const buf: [:0]const u8 = c_buf[0..len :0];

            try evalBuf(ctx, buf, filename, c.JS_EVAL_TYPE_MODULE);
        }

        c.js_std_loop(ctx);
        printException(ctx);

        return Self{ .runtime = rt, .ctx = ctx };
    }

    fn evalBuf(ctx: *c.JSContext, buf: [:0]const u8, filename: [:0]const u8, eval_flags: c_int) !void {
        var val: c.JSValue = undefined;
        defer c.JS_FreeValue(ctx, val);

        if ((eval_flags & c.JS_EVAL_TYPE_MASK) == c.JS_EVAL_TYPE_MODULE) {
            // for the modules, we compile then run to be able to set
            // import.meta
            val = c.JS_Eval(ctx, buf.ptr, buf.len, filename, eval_flags | c.JS_EVAL_FLAG_COMPILE_ONLY);
            if (val.tag != c.JS_TAG_EXCEPTION) {
                _ = c.js_module_set_import_meta(ctx, val, 1, 1);
                val = c.JS_EvalFunction(ctx, val);
            }
        } else {
            val = c.JS_Eval(ctx, buf.ptr, buf.len, filename, eval_flags);
        }
        if (val.tag == c.JS_TAG_EXCEPTION) {
            c.js_std_dump_error(ctx);
            return error.EvalBufException;
        }
    }

    pub fn deinit(self: *Self) void {
        c.JS_FreeContext(self.ctx);
        c.JS_FreeRuntime(self.runtime);
    }

    fn JS_NewCustomContext(rt: ?*c.JSRuntime) callconv(.C) ?*c.JSContext {
        const ctx = c.JS_NewContext(rt) orelse return null;
        _ = c.js_init_module_std(ctx, "std");
        _ = c.js_init_module_os(ctx, "os");
        return ctx;
    }
};

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
