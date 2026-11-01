/* Only local presentation behavior. Metadata access stays on the server. */
(() => {
  'use strict';
  document.addEventListener('click', async (event) => {
    const button = event.target.closest('.afd-copy');
    if (!button) return;
    const code = button.closest('.afd-code').querySelector('code');
    try {
      await navigator.clipboard.writeText(code.textContent);
      button.textContent = 'Copied';
      button.setAttribute('aria-live', 'polite');
      setTimeout(() => { button.textContent = 'Copy'; }, 1600);
    } catch {
      const selection = window.getSelection();
      const range = document.createRange();
      range.selectNodeContents(code);
      selection.removeAllRanges();
      selection.addRange(range);
      button.textContent = 'Select + copy';
    }
  });
})();
