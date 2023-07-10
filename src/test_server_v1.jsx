import { renderToString } from '@builder.io/qwik/server';
// import {renderToString} from "../node_modules/@builder.io/qwik/server.mjs";

// import { manifest } from '@qwik-client-manifest';
import manifest_json from '../dist/q-manifest.json';
// Built with esbuild command: esbuild src/root.tsx --loader:.js=jsx
import { Root } from './root';

console.log(renderToString);

/**
 * npx vite build --ssr src/test_server_v1.js
 */

// const manifest = manifest_json;

/**
 * Server-Side Render method to be called by a server.
 */
// export function render(opts) {
//   // Render the Root component to a string
//   // Pass in the manifest that was generated from the client build
//   return renderToString(<Root />, {
//     manifest,
//     ...opts,
//   });
// }

console.log("START");
// console.log(render({url: "http://localhost:8080/"}));
