import { renderToString, RenderOptions } from '@builder.io/qwik/server';
import { manifest } from '@qwik-client-manifest';
import { Root } from './root';

/**
 * Server-Side Render method to be called by a server.
 */
export async function render(opts?: RenderOptions) {
    console.log("render start")
    console.log(manifest);
    console.log(JSON.stringify(manifest, null, 2));
    console.log("render end")
  // console.log(JSON.stringify(manifest));
  // Render the Root component to a string
  // Pass in the manifest that was generated from the client build
  const r = renderToString(<Root />, {
    manifest,
    ...opts,
  });
  return r;
}

