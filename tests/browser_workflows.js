const fs = require('fs');
const os = require('os');
const path = require('path');
const {execFileSync} = require('child_process');
const {chromium} = require('playwright');
const repo = path.resolve(__dirname, '..');
const assert = (ok, reason) => { if (!ok) throw new Error(reason); };

(async () => {
  const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'h4du-ui-'));
  const user = os.userInfo().username;
  const browser = await chromium.launch({headless: true,
    ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH ? {executablePath:process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH} : {})});
  try {
    fs.mkdirSync(fixture + '/accounts');
    const files = Array.from({length:35}, (_, i) => ({relative_path:i === 0 ? '=formula.log' : 'cache/file-' + String(i).padStart(2, '0') + '.log', bytes:1000 + i, mtime:'2026-10-07T12:20:00Z'}));
    fs.writeFileSync(fixture + '/accounts/' + user + '.json', JSON.stringify({user, scanned_at:'2026-10-07T12:20:00Z', scanned_at_epoch:Math.floor(Date.now()/1000), scan_complete:true, large_files:files, category_hotspots:[], remediation_hints:[]}));
    const response = execFileSync('perl', [repo + '/src/cpanel/index.live.pl'], {encoding:'utf8', env:{...process.env, LC_ALL:'C', LANG:'C', PERL5LIB:repo+'/tests/lib', HELP4_DU_ACCOUNT_CACHE_DIR:fixture, HELP4_DU_CONFIG:fixture+'/none', REQUEST_METHOD:'GET', QUERY_STRING:'', REMOTE_USER:user}});
    const context = await browser.newContext({viewport:{width:1440,height:1000}, acceptDownloads:true});
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.setContent(response.split('\r\n\r\n').slice(1).join('\r\n\r\n'));
    await page.addStyleTag({path:repo+'/src/static/help4-disk-usage-whm.css'});
    await page.addScriptTag({path:repo+'/src/static/help4-disk-usage.js'});
    assert(await page.getByRole('heading', {name:'Disk Usage Audit',exact:true}).isVisible(), 'page identity or blank page failure');
    const section = page.locator('[data-report="large_files"]');
    assert(await section.locator('tr[data-path]:visible').count() === 25, 'default page size');
    await section.locator('[data-next]').click();
    assert(await section.locator('tr[data-path]:visible').count() === 10, 'second page size');
    await section.locator('[data-search]').fill('file-03');
    assert(await section.locator('tr[data-path]:visible').count() === 1, 'path search failed');
    await section.locator('[data-search]').fill('missing');
    assert(await section.locator('.no-results').isVisible(), 'empty filter missing');
    await section.locator('[data-search]').fill('');
    await section.locator('[data-order]').selectOption('asc');
    assert(await section.locator('tr[data-path]:visible').first().getAttribute('data-path') === '=formula.log', 'numeric sort wrong');
    await page.evaluate(() => Object.defineProperty(navigator, 'clipboard', {value:{writeText:async value => { window.copiedPath=value; }}, configurable:true}));
    await section.locator('[data-copy]').first().click();
    assert(await page.evaluate(() => window.copiedPath) === '=formula.log', 'copy did not use exact path');
    const downloaded = page.waitForEvent('download');
    await section.locator('[data-export-visible]').click();
    const download = await downloaded;
    const csv = fs.readFileSync(await download.path(), 'utf8');
    assert(csv.includes("'=formula.log") && csv.includes('help4network.com') && csv.includes('cache/file-34'), 'filtered CSV formula/credit/full result failure');
    await page.setViewportSize({width:390,height:844});
    assert(!(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 1)), 'mobile overflow');
    assert(errors.length === 0, 'browser JS errors');
    console.log('browser workflow tests passed: identity, search, sort, paging, copy, CSV, formulas, credit, desktop/mobile');
  } finally {await browser.close(); fs.rmSync(fixture,{recursive:true,force:true});}
})().catch(error => {console.error(error.message); process.exit(1);});
