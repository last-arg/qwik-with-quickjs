import { defineConfig } from 'vite';
import { qwikVite } from '@builder.io/qwik/optimizer';
const path = require("path");
export default defineConfig(() => {
    return {
    // build: {
    //   lib: {
    //     entry: './src/root.tsx',
    //     formats: ['es', 'cjs'],
    //     fileName: (format) => `root.${format}.qwik.js`,
    //   },
    // },
  // resolve:{
  //   alias:{
  //     '@builder.io' : path.resolve(__dirname, './node_modules/@builder.io')
  //   },
  // },
 
        // ssr: {
        //   input: './src/test_server_v1.jsx'
        //  },
        // resolve:{
        //   alias:{
        //     '@builder.io': path.resolve(__dirname, './node_modules/@builder.io'),
        //     '@qwik-client-manifest': path.resolve(__dirname, './dist/q-manifest.json')
        //   },
        // },
        plugins: [
            qwikVite(),
        ],
    };
});
