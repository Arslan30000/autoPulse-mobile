// Run after `flutter build web --no-web-resources-cdn`.
// Requires Playwright + Chromium; PLAYWRIGHT_MODULE may point to an existing install.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const root = path.resolve(__dirname, '../build/web');
const output = path.resolve(__dirname, '../docs/ui');
const server = http.createServer((request, response) => {
  const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
  const file = path.resolve(root, '.' + (pathname === '/' ? '/index.html' : pathname));
  if (!file.startsWith(root + path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
    response.writeHead(404).end();
    return;
  }
  const type = {'.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm',
    '.png': 'image/png', '.json': 'application/json'}[path.extname(file)];
  response.setHeader('Content-Type', type || 'application/octet-stream');
  response.end(fs.readFileSync(file));
});

(async () => {
  let browser;
  try {
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    browser = await chromium.launch({headless: true});
    const page = await browser.newPage({viewport: {width: 390, height: 844}, deviceScaleFactor: 2});
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    const origin = `http://127.0.0.1:${server.address().port}`;
    // All rendering assets must work offline, including the model-viewer module.
    await page.route('**/*', route => route.request().url().startsWith(origin)
      || route.request().url().startsWith('data:') ? route.continue() : route.abort());
    await page.goto(`${origin}/#/main`);
    const model = page.locator('model-viewer').first();
    await model.waitFor({timeout: 30000});
    await model.evaluate(viewer => new Promise((resolve, reject) => {
      if (viewer.loaded) return resolve();
      viewer.addEventListener('load', resolve, {once: true});
      viewer.addEventListener('error', () => reject(new Error('Car did not render')), {once: true});
    }));
    const accessibility = page.locator('flt-semantics-placeholder');
    if (await accessibility.count()) await accessibility.evaluate(element => element.click());
    await page.getByRole('button', {name: 'Explore 3D', exact: true}).waitFor();
    assert(await model.evaluate(v => v.loaded && v.modelIsVisible && v.src.startsWith('data:model/gltf-binary')));
    assert(await model.locator('.vehicle-status').isHidden());
    fs.mkdirSync(output, {recursive: true});
    await page.waitForTimeout(800); // Let the viewer's progress bar fade out.
    await page.screenshot({path: path.join(output, 'home-browser-390.png')});

    // Dragging over the embedded Home car must scroll the Flutter page.
    await page.mouse.move(195, 390);
    await page.mouse.wheel(0, 300);
    await page.getByRole('button', {name: 'Drive report Review your journey'}).waitFor();
    await page.mouse.wheel(0, -800);
    await page.getByRole('button', {name: 'Explore 3D', exact: true}).click();
    const interactive = page.locator('model-viewer[camera-controls]');
    await interactive.waitFor();
    await interactive.evaluate(v => new Promise(resolve => {
      if (v.loaded) return resolve();
      v.addEventListener('load', resolve, {once: true});
    }));
    await page.waitForTimeout(500);
    assert(await interactive.evaluate(v => v.loaded && v.modelIsVisible));
    const theta = await interactive.evaluate(v => {v.autoRotate = false; return v.getCameraOrbit().theta;});
    const bounds = await interactive.boundingBox();
    await page.mouse.move(bounds.x + bounds.width * .35, bounds.y + bounds.height * .5);
    await page.mouse.down();
    await page.mouse.move(bounds.x + bounds.width * .7, bounds.y + bounds.height * .5, {steps: 15});
    await page.mouse.up();
    await page.waitForTimeout(500);
    assert(Math.abs((await interactive.evaluate(v => v.getCameraOrbit().theta)) - theta) > .1,
      'Dragging should rotate the car');
    await page.screenshot({path: path.join(output, 'vehicle-3d-browser-390.png')});

    // Exercise renderer failure and recovery without needing a faulty GPU.
    await interactive.evaluate(v => v.dispatchEvent(new CustomEvent('error', {detail: {type: 'webglcontextlost'}})));
    assert(await interactive.locator('.vehicle-status').isVisible());
    await interactive.getByRole('button', {name: 'Retry', exact: true}).click();
    await interactive.locator('.vehicle-status').waitFor({state: 'hidden'});
    assert(await interactive.evaluate(v => v.loaded));
    await page.getByRole('button', {name: 'Back', exact: true}).click();
    await page.getByRole('tab', {name: 'Live', exact: true}).click();
    await page.mouse.move(380, 60);
    await page.getByText('OFFLINE', {exact: true}).waitFor();
    assert.equal(await page.getByText('Connect adapter', {exact: true}).count(), 0);
    await page.waitForTimeout(800);
    await page.screenshot({path: path.join(output, 'live-browser-390.png')});
    await page.getByRole('button', {name: 'Back', exact: true}).click();
    await page.getByRole('button', {name: 'Explore 3D', exact: true}).waitFor();
    assert(await model.evaluate(v => v.loaded && v.modelIsVisible));
    assert.deepEqual(errors, []);
    console.log('PASS: offline 3D load, scroll, rotation, error/retry, Live, and Back.');
  } finally {
    if (browser) await browser.close();
    server.close();
  }
})().catch(error => {console.error(error); process.exitCode = 1;});
