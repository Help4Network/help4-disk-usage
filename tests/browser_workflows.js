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
    await section.getByRole('button', {name:'Clear path search',exact:true}).click();
    assert(await section.locator('tr[data-path]:visible').count() === 25, 'clear filter failed');
    assert(await section.locator('[data-search]').evaluate(el=>el===document.activeElement), 'clear filter lost search focus');
    assert(await page.locator('#report-large_files > h2').isVisible(), 'section link must target heading and controls');
    assert(await section.locator('[data-search]').getAttribute('aria-controls') === 'report-large_files-table', 'search controls wrong table');
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
    const submitState = await page.evaluate(() => {
      const form=document.querySelector('form[method="post"]');
      const first = form.dispatchEvent(new Event('submit',{bubbles:true,cancelable:true}));
      const busy=document.querySelector('.h4du-page').getAttribute('aria-busy');
      const label=form.querySelector('button[type="submit"]').textContent;
      const second=form.dispatchEvent(new Event('submit',{bubbles:true,cancelable:true}));
      window.dispatchEvent(new PageTransitionEvent('pageshow',{persisted:true}));
      return {first,second,busy,label,enabled:!form.querySelector('button[type="submit"]').disabled,restored:form.querySelector('button[type="submit"]').textContent};
    });
    assert(submitState.first && !submitState.second && submitState.busy==='true' && submitState.label==='Scanning...', 'double-submit guard/busy state failed');
    assert(submitState.enabled && submitState.restored==='Refresh scan', 'back/forward cached page kept scan disabled');
    await page.setViewportSize({width:390,height:844});
    assert(!(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 1)), 'mobile overflow');
    assert(errors.length === 0, 'browser JS errors');
    console.log('browser workflow tests passed: identity, search/clear/focus, section anchors, sort, paging, copy, CSV, formulas, credit, duplicate-submit/back-cache, desktop/mobile');
  } finally {await browser.close(); fs.rmSync(fixture,{recursive:true,force:true});}
})().catch(error => {console.error(error.message); process.exit(1);});
