(function () {
  'use strict';
  function init() {
    document.querySelectorAll('.h4du-page').forEach(function (root) {
      const status = root.querySelector('.action-status');
      function announce(message) { if (status) status.textContent = message; }
      root.querySelectorAll('[data-copy]').forEach(function (button) {
        button.addEventListener('click', async function () {
          try {
            await navigator.clipboard.writeText(button.dataset.copy);
            announce('Path copied.');
          } catch (_) {
            const field = document.createElement('textarea');
            field.value = button.dataset.copy;
            root.append(field); field.select();
            const copied = document.execCommand('copy'); field.remove();
            announce(copied ? 'Path copied.' : 'Unable to copy path.');
          }
        });
      });
      root.querySelectorAll('form').forEach(function (form) {
        if (!form.querySelector('input[name="refresh"]')) return;
        form.addEventListener('submit', function () {
          root.querySelectorAll('input[name="refresh"]').forEach(function (input) {
            input.form.querySelector('button[type="submit"]').disabled = true;
          });
          announce('Scan running.');
        });
      });
      root.querySelectorAll('.file-report').forEach(function (section) {
        const body = section.querySelector('tbody');
        const rows = Array.from(body.querySelectorAll('tr[data-path]'));
        const search = section.querySelector('[data-search]');
        const sort = section.querySelector('[data-sort]');
        const order = section.querySelector('[data-order]');
        const limit = section.querySelector('[data-limit]');
        const previous = section.querySelector('[data-prev]');
        const next = section.querySelector('[data-next]');
        let page = 0;
        let filtered = [];
        function render() {
          const needle = search.value.toLocaleLowerCase();
          filtered = rows.filter(function (row) { return row.dataset.path.toLocaleLowerCase().includes(needle); });
          const key = sort.value;
          filtered.sort(function (a, b) {
            let result;
            if (key === 'bytes' || key === 'files') result = Number(a.dataset[key]) - Number(b.dataset[key]);
            else result = a.dataset[key].localeCompare(b.dataset[key]);
            return (order.value === 'desc' ? -result : result) || a.dataset.path.localeCompare(b.dataset.path);
          });
          const count = Number(limit.value);
          const pages = Math.max(1, Math.ceil(filtered.length / count));
          page = Math.min(page, pages - 1);
          rows.forEach(function (row) { row.hidden = true; });
          filtered.forEach(function (row, index) { body.append(row); row.hidden = index < page * count || index >= (page + 1) * count; });
          section.querySelector('.result-count').textContent = filtered.length + ' of ' + rows.length + ' retained entries';
          section.querySelector('.no-results').hidden = filtered.length !== 0;
          section.querySelector('[data-page]').textContent = 'Page ' + (page + 1) + ' of ' + pages;
          previous.disabled = page === 0; next.disabled = page + 1 === pages;
        }
        [search, sort, order, limit].forEach(function (control) {
          control.addEventListener(control === search ? 'input' : 'change', function () { page = 0; render(); });
        });
        previous.addEventListener('click', function () { page--; render(); });
        next.addEventListener('click', function () { page++; render(); });
        section.querySelector('[data-export-visible]').addEventListener('click', function () {
          function cell(value) {
            value = String(value || '');
            if (/^\s*[=+\-@]|^[\t\r\n]/.test(value)) value = "'" + value;
            return '"' + value.replace(/"/g, '""') + '"';
          }
          const lines = [['relative_path', 'bytes', 'direct_files', 'modified_utc']];
          filtered.forEach(function (row) { lines.push(['path', 'bytes', 'files', 'mtime'].map(function (key) { return row.dataset[key] || ''; })); });
          const summary = root.querySelector('.coverage-line');
          lines.push([summary ? summary.textContent : 'Retained report entries']);
          const date = root.querySelector('.scan-date');
          if (date) lines.push(['Last scanned', date.textContent]);
          lines.push(['Built by Help4 Network - https://help4network.com/']);
          const blob = new Blob([lines.map(function (line) { return line.map(cell).join(','); }).join('\r\n')], { type: 'text/csv;charset=utf-8' });
          const url = URL.createObjectURL(blob);
          const link = document.createElement('a');
          link.href = url; link.download = 'disk-usage-' + section.dataset.report + '.csv';
          link.click(); setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
          announce('Filtered results exported.');
        });
        render();
      });
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
}());
