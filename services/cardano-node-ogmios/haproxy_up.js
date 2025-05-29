const port = process.argv[2] || 1337;

const HAPROXY_URL = 'http://localhost:5000/v3/services/haproxy/configuration';
const AUTH_HEADER = 'Basic ' + Buffer.from('admin:adminpwd').toString('base64');


async function haproxyFetch(path, method = 'GET', body = null) {
  const res = await fetch(`${HAPROXY_URL}${path}`, {
    method,
    headers: {
      'Authorization': AUTH_HEADER,
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : null,
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`HTTP ${res.status}: ${errText}`);
  }

  return res.status === 204 ? {} : res.json();
}

(async () => {
  try {
    console.log('➡️  Getting current HAProxy config version...');
    let version = await haproxyFetch('/version');
    console.log(`✅ Version: ${version}`);

    // console.log('➡️  Deleting backend...');
    // await haproxyFetch(`/backends/ogmios?version=${version}`, 'DELETE', {});
    // console.log('✅ Backend deleted');


    console.log('➡️  Creating backend...');
    version = await haproxyFetch('/version');
    await haproxyFetch(`/backends?version=${version}`, 'POST', {
      name: 'ogmios',
      balance: { algorithm: 'first' },
    });
    console.log('✅ Backend created');

    console.log('➡️  Adding http-request set-path rule...');
    version = await haproxyFetch('/version');
    await haproxyFetch(`/backends/ogmios/http_request_rules/0?version=${version}`, 'POST', {
      type: 'set-path',
      path_fmt: '%[path,regsub(^/ogmios/,/)]',
      index: 0,
    });
    console.log('✅ HTTP request rule added');

    console.log('➡️  Adding health check expectation...');
    version = await haproxyFetch('/version');
    await haproxyFetch(`/backends/ogmios/http_checks/0?version=${version}`, 'POST', {
      type: 'expect',
      pattern: 'rstatus (200|202)',
      index: 0,
    });
    console.log('✅ Health check rule added');

    console.log('➡️  Adding use_backend rule to frontend "app"...');
    version = await haproxyFetch('/version');
    const condition = '{ path_beg /ogmios } || { path_beg /dashboard.js } || { path_beg /assets } || { path_beg /health } || is_wss';
    await haproxyFetch(`/frontends/app/backend_switching_rules/0?version=${version}`, 'POST', {
      cond: 'if',
      cond_test: condition,
      name: 'ogmios'
    });

    console.log('✅ use_backend rule added to frontend "app"');


  } catch (err) {
    console.error('❌ Error:', err.message);
  }
})();
