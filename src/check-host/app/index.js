const express = require('express');
const { exec } = require('child_process');
const net = require('net');

const app = express();
const PORT = 5000;

function pingHost(host) {
  return new Promise((resolve) => {
    exec(`ping -c 3 ${host}`, (error, stdout, stderr) => {
      if (error) {
        return resolve({ reachable: false, error: stderr.trim() });
      }
      resolve({ reachable: true, output: stdout.trim() });
    });
  });
}

function tcpCheck(host, port) {
  return new Promise((resolve) => {
    const socket = new net.Socket();
    const timeout = 5000;
    let result = { open: false };

    socket.setTimeout(timeout);

    socket.on('connect', () => {
      result.open = true;
      socket.destroy();
    });

    socket.on('error', (err) => {
      result.error = err.message;
    });

    socket.on('timeout', () => {
      result.error = 'Timeout';
      socket.destroy();
    });

    socket.on('close', () => resolve(result));

    socket.connect(port, host);
  });
}

app.get('/check', async (req, res) => {
  const host = req.query.host;
  const port = parseInt(req.query.port || '80', 10);

  if (!host) {
    return res.status(400).json({ error: "Missing 'host' parameter" });
  }

  const pingResult = await pingHost(host);
  const tcpResult = await tcpCheck(host, port);

  res.json({
    host,
    port,
    ping: pingResult,
    tcp: tcpResult
  });
});

app.listen(PORT, () => {
  console.log(`Ping API listening on port ${PORT}`);
});
