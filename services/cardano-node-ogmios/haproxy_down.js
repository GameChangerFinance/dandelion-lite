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

  console.log("Status: ", res.status === 204 ? {} : res.json())


  return res.status === 204 ? {} : res.json();
}

(async () => {
  try {
    console.log('➡️  Getting current HAProxy config version...');
    let version = await haproxyFetch('/version');
    console.log(`✅ Version: ${version}`);

    console.log('➡️  Deleting use_backend rule to frontend "app"...');
    await haproxyFetch(`/frontends/app/backend_switching_rules/0?version=${version}`, 'DELETE', {});

    console.log('➡️  Deleting backend...');
    version = await haproxyFetch('/version');
    await haproxyFetch(`/backends/ogmios?version=${version}`, 'DELETE', {});
    console.log('✅ Backend deleted');



  } catch (err) {
    console.error('❌ Error:', err.message);
  }
})();
