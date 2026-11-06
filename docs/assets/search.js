'use strict';
const input = document.getElementById('search');
const results = document.getElementById('search-results');
let indexPromise;
let request = 0;
input.addEventListener('input', async () => {
  const current = ++request;
  const query = input.value.trim().toLocaleLowerCase();
  results.replaceChildren();
  if (!query) return;
  try {
    indexPromise ||= fetch(input.dataset.index).then(response => {
      if (!response.ok) throw new Error('search index');
      return response.json();
    });
    const index = await indexPromise;
    if (current !== request) return;
    const terms = query.split(/\s+/);
    const matches = index.filter(page => terms.every(term => (page.title + ' ' + page.text).toLocaleLowerCase().includes(term)));
    matches.sort((a, b) => Number(b.title.toLocaleLowerCase().includes(query)) - Number(a.title.toLocaleLowerCase().includes(query)));
    for (const page of matches.slice(0, 14)) {
      const a = document.createElement('a');
      a.href = new URL(page.url, new URL(input.dataset.index, document.baseURI));
      a.textContent = page.title;
      const snippet = document.createElement('small');
      const offset = Math.max(0, page.text.toLocaleLowerCase().indexOf(terms[0]) - 35);
      snippet.textContent = page.text.slice(offset, offset + 110).replace(/\s+/g, ' ');
      a.append(snippet);
      results.append(a);
    }
    if (!matches.length) results.textContent = '未找到匹配内容';
  } catch {
    if (current === request) results.textContent = '搜索索引暂不可用，请使用左侧 API 目录。';
    indexPromise = undefined;
  }
});
