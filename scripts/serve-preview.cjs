'use strict';
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(process.argv[2] || 'build/web');
const port = Number(process.argv[3] || 8800);
const types = {'.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.ttf': 'font/ttf', '.otf': 'font/otf'};
http.createServer((request, response) => {
  let pathname;
  try { pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname); } catch (_) { response.writeHead(400).end(); return; }
  let filename = path.resolve(root, '.' + pathname);
  if (filename !== root && !filename.startsWith(root + path.sep)) { response.writeHead(403).end(); return; }
  if (!fs.existsSync(filename) || fs.statSync(filename).isDirectory()) filename = path.join(root, 'index.html');
  if (!fs.existsSync(filename)) { response.writeHead(404).end('Build the Flutter web app first.'); return; }
  response.writeHead(200, {'Content-Type': types[path.extname(filename)] || 'application/octet-stream', 'Cache-Control': 'no-store'});
  fs.createReadStream(filename).pipe(response);
}).listen(port, '127.0.0.1', () => console.log(`ZooStudy preview: http://127.0.0.1:${port}`));
