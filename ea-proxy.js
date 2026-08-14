const http = require('http');

const LISTEN_PORT = 8083;
const ASPHYXIA_PORT = 8084;

const server = http.createServer((req, res) => {
  let reqBody = [];
  req.on('data', chunk => reqBody.push(chunk));
  req.on('end', () => {
    console.log(`[REQ ${new Date().toISOString()}] ${req.method} ${req.url}`);

    const options = {
      hostname: '127.0.0.1',
      port: ASPHYXIA_PORT,
      path: req.url,
      method: req.method,
      headers: { 
        ...req.headers, 
        host: `127.0.0.1:${ASPHYXIA_PORT}`,
        'x-compress': 'none',
        'accept-encoding': 'identity'
      }
    };

    const proxyReq = http.request(options, (proxyRes) => {
      let body = [];
      proxyRes.on('data', chunk => body.push(chunk));
      proxyRes.on('end', () => {
        let content = Buffer.concat(body).toString('utf8');

        // Fix 1: Rewrite all service URLs to point to proxy port 8083 WITH trailing slash!
        content = content.replace(/url="http:\/\/127\.0\.0\.1:8084\/?"/g, 'url="http://127.0.0.1:8083/"');
        content = content.replace(/url="http:\/\/127\.0\.0\.1:8083\/?"/g, 'url="http://127.0.0.1:8083/"');

        // Fix 2: Force Japan country code JP so LDJ:J:A:A accepts facility as valid in-region arcade
        content = content.replace(/<country __type="str">AX<\/country>/g, '<country __type="str">JP</country>');
        content = content.replace(/<countryjname __type="str">不明<\/countryjname>/g, '<countryjname __type="str">日本<\/countryjname>');

        const resBuf = Buffer.from(content, 'utf8');
        const headers = { ...proxyRes.headers };

        delete headers['transfer-encoding'];
        delete headers['Transfer-Encoding'];
        headers['content-length'] = resBuf.length;

        console.log(`[RESP ${proxyRes.statusCode}] ${resBuf.length} bytes`);

        res.writeHead(proxyRes.statusCode, headers);
        res.end(resBuf);
      });
    });

    proxyReq.on('error', (err) => {
      console.error(`[ERR] ${err.message}`);
      res.writeHead(502, { 'Content-Type': 'text/plain' });
      res.end('Bad Gateway: Asphyxia Core not reachable on port ' + ASPHYXIA_PORT);
    });

    proxyReq.write(Buffer.concat(reqBody));
    proxyReq.end();
  });
});

server.listen(LISTEN_PORT, '0.0.0.0', () => {
  console.log(`[+] E-Amusement XRPC Fixer Proxy active on http://0.0.0.0:${LISTEN_PORT} -> Asphyxia on :${ASPHYXIA_PORT}`);
});
