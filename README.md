# qwik-with-quickjs
Make qwik server side html generation work with quickjs

## Just get it working
1) Generate server file:
```
$ npm run build.ssr
```
2) Replace node require imports with es module imports in file generate by
   'npm run build.ssr'.
3) Remove any 'module.exports = ...' if there are any es module exports in
   file generate by 'npm run build.ssr'.
4) Remove IIFE 'dedupeRequire' because it has a require(...). Not sure of its use.
4) Need to polyfill some functions for quickjs:
   URL, URLSearchParams, setInterval, clearInterval
   NOTE: Seems to be working when including just empty functions bodies for
   setInterval and clearInterval.
5) Run:
```
$ qjs --std -I <polyfill.js> --unhandled-rejection <input.js>
# Example: qjs --std -I src/quickjs-polyfill.js  --unhandled-rejection server.js
```

How to call renderToString function from quickJS (C) side?
Example renderToString():
```
renderToString(jsxRuntime.jsx(Root, {}), { manifest, ...opts });
```
Need to probably make jsx function available in quickJS. Can find jsx
function (const) in 'core.mjs'.



## QuickJS
### Create new promise
New promise with resolve (resolving_funcs[0]) and reject (resolving_funcs[1]) functions.
```zig
var resolving_funcs: [2]c.JSValue = undefined;
const result_promise = c.JS_NewPromiseCapability(ctx, &resolving_funcs);
```

### How to call promises
https://www.freelists.org/post/quickjs-devel/Resolving-promises-from-native-code-when-using-js-std-loop,1
https://www.freelists.org/post/quickjs-devel/Creating-an-async-function-in-C,3
