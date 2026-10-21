// Tiny local web server for OpenDX. Web Serial only works on secure origins,
// and http://localhost counts as one. Binds to 127.0.0.1 so nothing is exposed on the network.
const http = require("http");
const fs = require("fs");
const path = require("path");

const root = __dirname;
const port = 8642;
const types = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".ico": "image/x-icon",
};

http
  .createServer((req, res) => {
    let p = decodeURIComponent(new URL(req.url, "http://localhost").pathname);
    if (p === "/") p = "/index.html";
    const file = path.join(root, path.normalize(p));
    if (!file.startsWith(root)) {
      res.writeHead(403);
      return res.end();
    }
    fs.readFile(file, (err, data) => {
      if (err) {
        res.writeHead(404);
        return res.end("not found");
      }
      res.writeHead(200, { "Content-Type": types[path.extname(file)] || "application/octet-stream" });
      res.end(data);
    });
  })
  .listen(port, "127.0.0.1", () => console.log(`OpenDX running at http://localhost:${port}  (close this window to stop)`));
