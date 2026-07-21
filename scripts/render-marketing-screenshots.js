const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const root = path.resolve(__dirname, '..');
const outDir = path.join(root, 'outputs', 'screenshots');
fs.mkdirSync(outDir, { recursive: true });

const css = fs.readFileSync(path.join(root, 'src/static/help4-disk-usage-whm.css'), 'utf8');
const whmCss = css;

function cpanelShell(title, body) {
  return `<!doctype html><html><head><meta charset="utf-8"><title>${title}</title><style>
    *{box-sizing:border-box}body{margin:0;background:#f5f7fa;color:#151923;font:14px/1.45 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
    .cp-header{height:58px;background:#20252b;color:#fff;display:flex;align-items:center;justify-content:space-between;padding:0 24px}.cp-brand{font-size:21px;font-weight:700}.cp-account{color:#dfe4ea;font-size:13px}
    .cp-layout{display:grid;grid-template-columns:236px minmax(0,1fr);min-height:942px}.cp-nav{background:#fff;border-right:1px solid #dfe4ea;padding:22px 16px}.cp-nav-title{margin:0 8px 16px;color:#596577;font-size:12px;font-weight:700;text-transform:uppercase}.cp-link{display:block;padding:9px 11px;color:#2c3543;text-decoration:none}.cp-link.selected{background:#eaf2ff;border-left:3px solid #256fda;padding-left:8px;color:#174f9d;font-weight:700}.cp-content{min-width:0;padding:26px 24px;background:#f8f9fb}
    ${css}
  </style></head><body><header class="cp-header"><div class="cp-brand">cPanel</div><div class="cp-account">customer01</div></header><div class="cp-layout"><aside class="cp-nav"><div class="cp-nav-title">Tools</div><a class="cp-link">File Manager</a><a class="cp-link">Disk Usage</a><a class="cp-link selected">Help4 Disk Usage</a><a class="cp-link">Email Accounts</a><a class="cp-link">Databases</a></aside><main class="cp-content"><div class="h4du-page wrap">${body}</div></main></div></body></html>`;
}

function metric(label, value) {
  return `<div><strong>${value}</strong><span>${label}</span></div>`;
}

function whmShell(title, body) {
  return `<!doctype html><html><head><meta charset="utf-8"><title>${title}</title><style>
    *{box-sizing:border-box}body{margin:0;background:#fff;color:#151923;font:14px/1.45 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
    .whm-header{height:52px;background:#17213b;color:#fff;display:flex;align-items:center;padding:0 22px;font-size:18px;font-weight:700}
    .whm-header span{margin-left:12px;color:#bdc8de;font-size:13px;font-weight:500}
    .whm-layout{display:grid;grid-template-columns:284px minmax(0,1fr);min-height:898px}
    .whm-nav{background:#202c54;color:#e6ebf5;padding:20px 18px}.whm-nav h2{margin:0 0 18px;font-size:14px;color:#fff}
    .whm-nav-group{margin:18px 0 8px;font-weight:700}.whm-nav-link{display:block;padding:8px 12px;color:#e6ebf5;text-decoration:none}
    .whm-nav-link.selected{background:#314274;border-left:3px solid #fff;padding-left:9px;font-weight:700}
    .whm-content{min-width:0;padding:26px 24px;background:#fff}
    ${whmCss}
  </style></head><body><header class="whm-header">WHM <span>Server Manager</span></header><div class="whm-layout"><aside class="whm-nav"><h2>Main menu</h2><div class="whm-nav-group">System Health</div><a class="whm-nav-link">Show Current Disk Usage</a><div class="whm-nav-group">Plugins</div><a class="whm-nav-link selected">Help4 Disk Usage</a></aside><main class="whm-content"><div class="h4du-page wrap">${body}</div></main></div></body></html>`;
}

const whmRoot = whmShell('WHM Disk Usage Audit', `
  <header class="topbar"><div><h1>Disk Usage Audit</h1><p class="muted">Root view: all accounts. Signed in as root.</p></div><div class="actions"><a class="button">Refresh all accounts</a></div></header>
  <section class="metrics">
    ${metric('Visible accounts', '24')}
    ${metric('Indexed file bytes', '812.6 GB')}
    ${metric('Indexed inodes', '3,482,914')}
    ${metric('Bad accounts', '2')}
    ${metric('Incomplete scans', '0')}
  </section>
  <section><h2>Actionable Offenders</h2><table><thead><tr><th>Account</th><th>Owner</th><th>Status</th><th>Disk</th><th>Inodes</th><th>Last scan</th><th>Top issue</th><th></th></tr></thead><tbody>
    <tr><td><strong>customer01</strong><div class="path">/home/customer01</div></td><td>reseller01</td><td><span class="pill bad">bad</span></td><td>248.4 GB</td><td>812,440</td><td>2026-06-24T19:54:00Z</td><td>backups: 171.2 GB, 824 files<br>largest: 42.8 GB site-full-backup.tar.gz</td><td><a class="button small">Rescan</a></td></tr>
    <tr><td><strong>customer02</strong><div class="path">/home/customer02</div></td><td>reseller01</td><td><span class="pill check">check</span></td><td>91.7 GB</td><td>1,203,918</td><td>2026-06-24T19:51:12Z</td><td>mail: 63.5 GB, 789,404 files<br>inode-heavy tree detected</td><td><a class="button small">Rescan</a></td></tr>
    <tr><td><strong>customer03</strong><div class="path">/home/customer03</div></td><td>root</td><td><span class="pill check">check</span></td><td>38.2 GB</td><td>428,115</td><td>2026-06-24T19:49:33Z</td><td>cache: 18.4 GB, 96,118 files<br>generated cache cleanup candidate</td><td><a class="button small">Rescan</a></td></tr>
  </tbody></table></section>
  <p class="credit">Help4 Disk Usage by Help4 Network</p>`);

const cpanel = cpanelShell('Help4 Disk Usage', `
  <header class="topbar"><div><h1>Help4 Disk Usage</h1><p class="muted">Account view for customer01. Paths are shown relative to your home directory.</p></div><div class="actions"><a class="button">Refresh scan</a></div></header>
  <div class="notice">Scan refreshed for this account.</div>
  <section class="metrics">
    ${metric('Status', 'check')}
    ${metric('Indexed file bytes', '91.7 GB')}
    ${metric('Indexed inodes', '1,203,918')}
    ${metric('Last scanned', '2026-06-24T19:54:00Z')}
  </section>
  <section><h2>Remediation Hints</h2><ul class="hints">
    <li>Mailbox growth should be handled through mail retention, archive, or client cleanup.</li>
    <li>Backup archives and SQL dumps are frequent quota offenders; move needed copies off-account.</li>
    <li>Cache directories are cleanup candidates after confirming the application can regenerate them.</li>
    <li>Dependency trees can explode inode counts; remove unused builds and deployment leftovers.</li>
  </ul></section>
  <section><h2>Cleanup Hotspots</h2><table><thead><tr><th>Category</th><th>Bytes</th><th>Files</th><th>Hint</th></tr></thead><tbody>
    <tr><td>mail</td><td>63.5 GB</td><td>789,404</td><td>Mailbox growth should be handled through mail retention, archive, or client cleanup.</td></tr>
    <tr><td>backups</td><td>19.8 GB</td><td>824</td><td>Backup archives and SQL dumps are frequent quota offenders; move needed copies off-account.</td></tr>
    <tr><td>cache</td><td>6.4 GB</td><td>96,118</td><td>Cache directories are cleanup candidates after confirming the application can regenerate them.</td></tr>
    <tr><td>uploads</td><td>1.7 GB</td><td>14,221</td><td>Uploads need content review before deletion; start with duplicates and generated thumbnails.</td></tr>
  </tbody></table></section>
  <section><h2>Large files</h2><table><thead><tr><th>Relative path</th><th>Bytes</th><th>Mtime</th></tr></thead><tbody>
    <tr><td>backups/site-full-backup.tar.gz</td><td>42.8 GB</td><td>2026-06-21T21:59:19Z</td></tr>
    <tr><td>backups/database-export.sql.gz</td><td>8.1 GB</td><td>2026-06-20T10:44:18Z</td></tr>
    <tr><td>mail/archive/client-mailbox.mbox</td><td>4.7 GB</td><td>2026-05-18T03:12:41Z</td></tr>
    <tr><td>public_html/wp-content/uploads/video-library.zip</td><td>2.4 GB</td><td>2026-03-04T16:22:01Z</td></tr>
    <tr><td>tmp/cache-export-previous-release.tar</td><td>1.9 GB</td><td>2025-12-14T08:40:11Z</td></tr>
  </tbody></table></section>
  <section><h2>Inode-heavy directories</h2><table><thead><tr><th>Relative path</th><th>Files</th><th>Bytes</th></tr></thead><tbody>
    <tr><td>mail/cur</td><td>392,114</td><td>31.7 GB</td></tr>
    <tr><td>mail/.spam/new</td><td>211,802</td><td>9.4 GB</td></tr>
    <tr><td>public_html/cache/pages</td><td>94,442</td><td>5.8 GB</td></tr>
    <tr><td>public_html/wp-content/cache</td><td>73,118</td><td>612.5 MB</td></tr>
    <tr><td>node_modules</td><td>58,339</td><td>1.2 GB</td></tr>
  </tbody></table></section>
  <p class="credit">Help4 Disk Usage by Help4 Network</p>`);

function whmcsShell(title, body) {
  return `<!doctype html><html><head><meta charset="utf-8"><title>${title}</title><style>
    body{margin:0;background:#eef1f5;color:#151923;font:14px/1.45 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
    .adminbar{height:48px;background:#1f2937;color:#fff;display:flex;align-items:center;padding:0 22px;font-weight:700}
    .layout{display:grid;grid-template-columns:220px 1fr;min-height:720px}.side{background:#273244;color:#d7dee9;padding:18px}.side div{padding:9px 0;border-bottom:1px solid rgba(255,255,255,.08)}
    .main{padding:24px}.panel{background:#fff;border:1px solid #d9dee7;border-radius:6px;padding:18px;margin-bottom:18px}.muted{color:#687386}
    h1{margin:0 0 6px;font-size:26px}h2{font-size:18px;margin:0 0 12px}.metrics{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:18px 0}
    .metrics div{background:#fff;border:1px solid #d9dee7;border-radius:6px;padding:14px}.metrics strong{display:block;font-size:24px}.metrics span{color:#687386}
    table{width:100%;border-collapse:collapse;background:#fff;border:1px solid #d9dee7;border-radius:6px;overflow:hidden}th,td{padding:10px;border-bottom:1px solid #e8ebf0;text-align:left;vertical-align:top}
    th{background:#eef1f5;font-size:12px;text-transform:uppercase}.badge{display:inline-block;border-radius:99px;padding:3px 8px;font-weight:700;text-transform:uppercase}.check{background:#fff1c2;color:#774400}.ok{background:#dff8e8;color:#075e2a}.bad{background:#ffd9d4;color:#7a1e16}
    .btn{display:inline-block;background:#1f6feb;color:#fff;padding:7px 10px;border-radius:4px;text-decoration:none;margin-right:4px}.credit{text-align:right;color:#687386;font-size:12px;margin-top:24px}
  </style></head><body><div class="adminbar">WHMCS Admin</div><div class="layout"><aside class="side"><div>Clients</div><div>Orders</div><div>Support</div><div>Addons</div><div>Help4 Disk Usage</div></aside><main class="main">${body}<div class="credit">Help4 Disk Usage by Help4 Network</div></main></div></body></html>`;
}

const whmcsAdmin = whmcsShell('WHMCS Help4 Disk Usage', `
  <h1>Help4 Disk Usage</h1><p class="muted">WHMCS deployment and support reporting for cPanel/WHM disk and inode scans.</p>
  <div class="metrics"><div><strong>8</strong><span>Tracked servers</span></div><div><strong>1,284</strong><span>Synced accounts</span></div><div><strong>23</strong><span>Bad accounts</span></div><div><strong>118</strong><span>Needs review</span></div></div>
  <section class="panel"><h2>Servers & Deploy</h2><table><thead><tr><th>Server</th><th>Host</th><th>Status</th><th>Last Scan</th><th>Counts</th><th>Actions</th></tr></thead><tbody>
    <tr><td><strong>cPanel Node A</strong><br><span class="muted">ID 101</span></td><td>cpanel-a.example.net</td><td><span class="badge ok">synced</span></td><td>2026-06-24 19:54</td><td>412 accounts<br>8 bad / 39 check</td><td><a class="btn">Check</a><a class="btn">Deploy</a><a class="btn">Sync</a></td></tr>
    <tr><td><strong>cPanel Node B</strong><br><span class="muted">ID 102</span></td><td>cpanel-b.example.net</td><td><span class="badge check">deployable</span></td><td>not deployed</td><td>0 accounts</td><td><a class="btn">Check</a><a class="btn">Deploy</a></td></tr>
  </tbody></table></section>
  <section class="panel"><h2>Top Customer Offenders</h2><table><thead><tr><th>Account</th><th>Status</th><th>Disk</th><th>Inodes</th><th>Support Hint</th></tr></thead><tbody>
    <tr><td><strong>customer01</strong><br><span class="muted">site-one.example.com</span></td><td><span class="badge bad">bad</span></td><td>248.4 GB</td><td>812,440</td><td>Backup archives and SQL dumps are frequent quota offenders; move needed copies off-account.</td></tr>
    <tr><td><strong>customer02</strong><br><span class="muted">site-two.example.com</span></td><td><span class="badge check">check</span></td><td>91.7 GB</td><td>1,203,918</td><td>Mailbox growth should be handled through mail retention, archive, or client cleanup.</td></tr>
  </tbody></table></section>`);

const whmcsHealth = whmcsShell('WHMCS Help4 Disk Usage Server Health', `
  <h1>Help4 Disk Usage</h1><p class="muted">WHMCS deployment and support reporting for cPanel/WHM disk and inode scans.</p>
  <section class="panel"><h2>Server Health</h2><p class="muted">Operational health across WHMCS cPanel server records. Health combines plugin deployment state, last scan freshness, scan errors, and bad/check account counts.</p>
  <div class="metrics"><div><strong>5</strong><span>Healthy</span></div><div><strong>2</strong><span>Attention</span></div><div><strong>1</strong><span>Stale</span></div><div><strong>0</strong><span>Errors</span></div></div>
  <table><thead><tr><th>Server</th><th>Health</th><th>Last Scan</th><th>Coverage</th><th>Findings</th><th>Last Error</th><th>Next Step</th><th>Actions</th></tr></thead><tbody>
    <tr><td><strong>cPanel Node A</strong><br><span class="muted">node-a.example.net</span></td><td><span class="badge ok">healthy</span><br><span class="muted">synced</span></td><td>2026-06-27 06:12<br><span class="muted">15 minutes ago</span></td><td>412 scanned accounts</td><td>0 bad<br>0 check</td><td></td><td>No immediate action needed.</td><td><a class="btn">Check</a><a class="btn">Deploy</a><a class="btn">Sync</a></td></tr>
    <tr><td><strong>cPanel Node B</strong><br><span class="muted">node-b.example.net</span></td><td><span class="badge check">attention</span><br><span class="muted">synced</span></td><td>2026-06-27 05:41<br><span class="muted">46 minutes ago</span></td><td>288 scanned accounts</td><td>4 bad<br>17 check</td><td></td><td>Review Customer Reports for bad/check accounts.</td><td><a class="btn">Check</a><a class="btn">Deploy</a><a class="btn">Sync</a></td></tr>
    <tr><td><strong>cPanel Node C</strong><br><span class="muted">node-c.example.net</span></td><td><span class="badge check">stale</span><br><span class="muted">installed</span></td><td>2026-06-25 23:08<br><span class="muted">1 days ago</span></td><td>191 scanned accounts</td><td>1 bad<br>9 check</td><td></td><td>Run Sync; last scan is older than 24 hours.</td><td><a class="btn">Check</a><a class="btn">Deploy</a><a class="btn">Sync</a></td></tr>
    <tr><td><strong>cPanel Node D</strong><br><span class="muted">node-d.example.net</span></td><td><span class="badge check">not synced</span><br><span class="muted">installed</span></td><td>never<br><span class="muted">never</span></td><td>0 scanned accounts</td><td>0 bad<br>0 check</td><td></td><td>Run Sync to collect the first server scan.</td><td><a class="btn">Check</a><a class="btn">Deploy</a><a class="btn">Sync</a></td></tr>
  </tbody></table></section>`);

const whmcsHomeWidget = whmcsShell('WHMCS Admin Home Widget', `
  <h1>Admin Home</h1><p class="muted">Operational widgets and quick status for the hosting desk.</p>
  <section class="panel"><h2>Help4 Disk Usage Health</h2>
  <div class="metrics"><div><strong>5</strong><span>Healthy</span></div><div><strong>2</strong><span>Attention</span></div><div><strong>1</strong><span>Stale</span></div><div><strong>0</strong><span>Errors</span></div></div>
  <table><thead><tr><th>Server</th><th>Health</th><th>Last Scan</th><th>Next Step</th></tr></thead><tbody>
    <tr><td><strong>cPanel Node B</strong><br><span class="muted">node-b.example.net</span></td><td><span class="badge check">attention</span></td><td>2026-06-27 05:41<br><span class="muted">46 minutes ago</span></td><td>Review Customer Reports.</td></tr>
    <tr><td><strong>cPanel Node C</strong><br><span class="muted">node-c.example.net</span></td><td><span class="badge check">stale</span></td><td>2026-06-25 23:08<br><span class="muted">1 days ago</span></td><td>Run Sync; scan is older than 24 hours.</td></tr>
    <tr><td><strong>cPanel Node D</strong><br><span class="muted">node-d.example.net</span></td><td><span class="badge check">not synced</span></td><td>never<br><span class="muted">never</span></td><td>Run Sync to collect the first scan.</td></tr>
  </tbody></table>
  <p style="margin-top:12px"><a class="btn">Open Server Health</a></p></section>`);

const whmcsClient = `<!doctype html><html><head><meta charset="utf-8"><title>Client Disk Usage Reports</title><style>
body{margin:0;background:#f6f7f9;color:#151923;font:14px/1.45 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}.top{background:#fff;border-bottom:1px solid #dde2ea;padding:16px 32px;font-weight:700}.wrap{max-width:1120px;margin:0 auto;padding:28px}.muted{color:#687386}.panel{background:#fff;border:1px solid #dde2ea;border-radius:6px;padding:18px}table{width:100%;border-collapse:collapse}th,td{padding:11px;border-bottom:1px solid #e8ebf0;text-align:left;vertical-align:top}th{background:#eef1f5;font-size:12px;text-transform:uppercase}.label{border-radius:99px;background:#fff1c2;color:#774400;padding:3px 8px;text-transform:uppercase;font-weight:700}.credit{text-align:right;color:#687386;font-size:12px;margin-top:24px}
</style></head><body><div class="top">Client Area</div><main class="wrap"><h1>Help4 Disk Usage</h1><p class="muted">Latest disk and inode scan summaries for your hosting services.</p><section class="panel"><table><thead><tr><th>Service</th><th>Status</th><th>Disk</th><th>Inodes</th><th>Last Scan</th><th>Recommended Next Step</th></tr></thead><tbody><tr><td><strong>site-one.example.com</strong><br><span class="muted">customer01</span></td><td><span class="label">check</span></td><td>91.7 GB</td><td>1,203,918</td><td>2026-06-24 19:54</td><td>Mailbox growth should be handled through mail retention, archive, or client cleanup.</td></tr></tbody></table></section><p class="credit">Help4 Disk Usage by Help4 Network</p></main></body></html>`;

async function shot(page, html, file, viewport = { width: 1440, height: 950 }) {
  await page.setViewportSize(viewport);
  await page.setContent(html, { waitUntil: 'load' });
  await page.screenshot({ path: path.join(outDir, file), fullPage: true });
}

(async () => {
  const executablePath = process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH;
  const browser = await chromium.launch({
    headless: true,
    ...(executablePath ? { executablePath } : {}),
  });
  const page = await browser.newPage();
  await shot(page, whmRoot, 'whm-root-dashboard.png');
  await shot(page, cpanel, 'cpanel-account-dashboard.png', { width: 1280, height: 1000 });
  await shot(page, whmcsAdmin, 'whmcs-admin-deploy-reporting.png');
  await shot(page, whmcsHomeWidget, 'whmcs-admin-home-health-widget.png');
  await shot(page, whmcsHealth, 'whmcs-server-health.png');
  await shot(page, whmcsClient, 'whmcs-client-report.png', { width: 1280, height: 800 });
  await browser.close();
  console.log(outDir);
})();
