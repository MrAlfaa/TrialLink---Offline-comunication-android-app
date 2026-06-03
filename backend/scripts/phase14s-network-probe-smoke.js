const app = require('../src/app');

async function main() {
  const server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  const { port } = server.address();
  const baseUrl = `http://127.0.0.1:${port}/api/network/probe`;

  try {
    const ping = await fetch(`${baseUrl}/ping`);
    if (!ping.ok) throw new Error(`Ping failed with ${ping.status}`);

    const download = await fetch(`${baseUrl}/download?bytes=8192`);
    if (!download.ok) {
      throw new Error(`Download failed with ${download.status}`);
    }
    const bytes = await download.arrayBuffer();
    if (bytes.byteLength !== 8192) {
      throw new Error(`Expected 8192 bytes, received ${bytes.byteLength}`);
    }

    const upload = await fetch(`${baseUrl}/upload`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ payload: 'probe' }),
    });
    if (!upload.ok) throw new Error(`Upload failed with ${upload.status}`);

    console.log('Phase 14S network probe smoke PASS');
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

main().catch((error) => {
  console.error('Phase 14S network probe smoke FAIL');
  console.error(error);
  process.exit(1);
});
