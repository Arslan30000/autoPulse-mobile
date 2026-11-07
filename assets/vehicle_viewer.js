// Shared by the Android/iOS WebView and Flutter web. The web plugin inserts
// HTML with innerHTML, so inline relatedJs alone does not execute there.
(() => {
  customElements.whenDefined('model-viewer').then(() => {
    customElements.get('model-viewer').minimumRenderScale = 1;
  });
  function attach(viewer) {
    if (!viewer.id.startsWith('autopulse-car-') || viewer.dataset.bound) return;
    viewer.dataset.bound = 'true';
    const status = viewer.querySelector('.vehicle-status');
    const retry = viewer.querySelector('.vehicle-retry');
    let timeout;
    const fail = () => {
      clearTimeout(timeout);
      status.hidden = false;
      status.textContent = '3D preview unavailable';
      retry.hidden = retry.dataset.enabled !== 'true';
      // Keep the actual model's rendered poster visible on WebGL failure.
      viewer.showPoster?.();
    };
    const start = () => {
      clearTimeout(timeout);
      status.hidden = false;
      status.textContent = 'Loading 3D vehicle…';
      retry.hidden = true;
      timeout = setTimeout(fail, 20000);
    };
    const ready = () => {
      clearTimeout(timeout);
      status.hidden = true;
      retry.hidden = true;
      viewer.dismissPoster?.();
    };
    viewer.addEventListener('load', ready);
    viewer.addEventListener('error', fail);
    viewer.addEventListener('progress', event => {
      if (event.detail.totalProgress === 1 && viewer.loaded) ready();
    });
    retry.addEventListener('click', () => {
      const source = viewer.getAttribute('src');
      start();
      viewer.removeAttribute('src');
      requestAnimationFrame(() => viewer.setAttribute('src', source));
    });
    start();
    if (viewer.loaded) ready();
  }
  function scan(root) {
    if (root.matches?.('model-viewer')) attach(root);
    root.querySelectorAll?.('model-viewer').forEach(attach);
  }
  scan(document);
  new MutationObserver(records => {
    for (const record of records) record.addedNodes.forEach(scan);
  }).observe(document.documentElement, {childList: true, subtree: true});
})();
