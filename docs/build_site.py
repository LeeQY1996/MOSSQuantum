#!/usr/bin/env python3
"""Build and validate the repository's static API reference (Python 3.11+)."""
from __future__ import annotations

import argparse
import html
import json
import posixpath
import re
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import quote, unquote, urlsplit

from markdown_it import MarkdownIt


def slug(text):
    text = re.sub(r'<[^>]*>', '', text).lower().strip()
    text = re.sub(r'[^\w\-\s]', '', text, flags=re.UNICODE)
    return re.sub(r'\s', '-', text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', default='_site')
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    config = json.loads((root / 'docs/site.json').read_text())
    output = Path(args.output).resolve()
    if output == root or root in output.parents and output.parts[len(root.parts)] in {'docs', 'src', '.git'}:
        raise SystemExit('Output must be separate from source, docs and Git metadata')
    output.mkdir(parents=True, exist_ok=True)
    repo = config['repository']
    branch = config['branch']
    origin = f'https://github.com/LeeQY1996/{repo}'
    site_url = f'https://leeqy1996.github.io/{repo}/'
    sources = {p.resolve() for pattern in config['sources'] for p in root.glob(pattern) if p.is_file()}
    sources = {p for p in sources if not any(part in {'validation', 'performance', 'results', 'build'} for part in p.relative_to(root).parts)}
    routes = {}
    for source in sorted(sources):
        relative = source.relative_to(root)
        route = relative.relative_to('docs') if relative.parts[0] == 'docs' else relative
        routes[source] = str(route.with_suffix('.html'))
    if len(set(routes.values())) != len(routes):
        raise SystemExit('Duplicate output routes')
    markdown = MarkdownIt('commonmark', {'html': True, 'typographer': False}).enable(['table', 'strikethrough'])
    parsed = {}
    for source in routes:
        text = source.read_text()
        if text.startswith('---\n'):
            text = re.sub(r'\A---\n.*?\n---\n', '', text, count=1, flags=re.S)
        tokens = markdown.parse(text)
        headings, duplicates = [], {}
        anchors = set(re.findall(r'\bid=[\"\']([^\"\']+)', text))
        for index, token in enumerate(tokens):
            if token.type == 'heading_open':
                label = tokens[index + 1].content
                base = slug(label) or 'section'
                count = duplicates.get(base, 0)
                anchor = f'{base}-{count}' if count else base
                while anchor in anchors:
                    count += 1
                    anchor = f'{base}-{count}'
                duplicates[base] = count + 1
                token.attrSet('id', anchor)
                anchors.add(anchor)
                headings.append((int(token.tag[1]), label, anchor))
        title = headings[0][1] if headings else source.stem
        parsed[source] = (tokens, headings, anchors, title)
    errors = []

    def relative_url(route, source):
        return quote(posixpath.relpath(route, posixpath.dirname(routes[source]) or '.'), safe='/._-')

    def link(url, source):
        parts = urlsplit(url)
        if parts.scheme or parts.netloc or url.startswith('/'):
            return url
        target = (source.parent / unquote(parts.path)).resolve() if parts.path else source
        fragment = unquote(parts.fragment)
        if target in routes:
            if fragment and fragment not in parsed[target][2]:
                errors.append(f'{source.relative_to(root)}: missing anchor {url}')
            result = relative_url(routes[target], source)
        elif target.exists() and target.is_relative_to(root):
            relative = target.relative_to(root).as_posix()
            if relative.startswith('docs/assets/'):
                result = relative_url('assets/' + target.relative_to(root / 'docs/assets').as_posix(), source)
            else:
                result = origin + ('/tree/' if target.is_dir() else '/blob/') + quote(branch, safe='') + '/' + quote(relative, safe='/')
        else:
            errors.append(f'{source.relative_to(root)}: missing target {url}')
            return url
        if parts.query:
            result += '?' + parts.query
        if parts.fragment:
            result += '#' + quote(fragment, safe='-._~!$&()*+,;=:@/?')
        return result

    def e(value):
        return html.escape(str(value), quote=True)


    def rewrite_html_images(content, source):
        offsets = [0] + [match.end() for match in re.finditer("\n", content)]
        replacements = []
        attribute_pattern = re.compile(
            r"""(?P<name>[^\s"'<>/=]+)(?:(?P<assignment>\s*=\s*)(?:(?P<quote>["'])(?P<quoted>.*?)(?P=quote)|(?P<bare>[^\s"'\x60=<>]+)))?""",
            re.I | re.S)

        class ImageParser(HTMLParser):
            def handle_starttag(self, tag, attrs):
                if tag != 'img':
                    return
                attributes = attribute_pattern.finditer(self.get_starttag_text(), 4)
                attribute = next((item for item in attributes
                                  if item.group('name').lower() == 'src' and item.group('assignment')), None)
                if attribute is None:
                    return
                mark = attribute.group('quote') or '"'
                url = attribute.group('quoted') if attribute.group('quote') else attribute.group('bare')
                replacement = attribute.group('name') + attribute.group('assignment') + mark + e(link(html.unescape(url), source)) + mark
                line, column = self.getpos()
                offset = offsets[line - 1] + column
                replacements.append((offset + attribute.start(), offset + attribute.end(), replacement))

            handle_startendtag = handle_starttag

        parser = ImageParser(convert_charrefs=False)
        parser.feed(content)
        parser.close()
        for start, end, replacement in reversed(replacements):
            content = content[:start] + replacement + content[end:]
        return content

    search = []
    for source, route in routes.items():
        tokens, headings, anchors, title = parsed[source]
        for token in tokens:
            if token.type == 'html_block':
                token.content = rewrite_html_images(token.content, source)
            for child in token.children or []:
                if child.type == 'link_open':
                    child.attrSet('href', link(child.attrGet('href') or '', source))
                elif child.type == 'image':
                    child.attrSet('src', link(child.attrGet('src') or '', source))
                elif child.type == 'html_inline':
                    child.content = rewrite_html_images(child.content, source)
        content = markdown.renderer.render(tokens, markdown.options, {})
        nav = []
        for label, path in config['navigation']:
            target = (root / path).resolve()
            if target not in routes:
                errors.append(f'Navigation target missing: {path}')
                continue
            nav.append(f'<a class="{"active" if target == source else ""}" href="{e(relative_url(routes[target], source))}">{e(label)}</a>')
        family = ''.join(f'<a href="https://leeqy1996.github.io/{name}/">{name}</a>' for name in config['family'])
        toc = ''.join(f'<a href="#{e(anchor)}">{e(re.sub(r"`", "", label))}</a>' for level, label, anchor in headings if level == 2)
        home = relative_url('index.html', source)
        style = relative_url('assets/style.css', source)
        brand_icon = relative_url('assets/brand/moos-qubit-grid.png', source)
        brand_label = e(config['title'])
        if config['title'].startswith('MOSS'):
            brand_label = 'MOSS<wbr>' + e(config['title'][4:])
        js = relative_url('assets/search.js', source)
        index = relative_url('search-index.json', source)
        canonical = site_url + quote(route, safe='/')
        page = f'''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{e(title)} · {e(config['title'])}</title><meta name="description" content="{e(config['description'])}">
<link rel="canonical" href="{e(canonical)}"><link rel="icon" type="image/png" href="{e(brand_icon)}"><link rel="stylesheet" href="{e(style)}"></head>
<body><a class="skip" href="#main">跳至正文</a><header><a class="brand" href="{e(home)}" aria-label="{e(config['title'])}" title="{e(config['title'])}"><img class="brand-icon" src="{e(brand_icon)}" alt="" width="56" height="56"><span class="brand-name">{brand_label}</span></a><a href="{origin}">GitHub ↗</a></header>
<div class="layout"><aside class="sidebar"><label for="search">搜索 API / 函数</label><input id="search" type="search" placeholder="输入函数名或关键词" autocomplete="off" data-index="{e(index)}"><div id="search-results" aria-live="polite"></div><nav aria-label="文档">{''.join(nav)}</nav><details><summary>MOSS 家族</summary>{family}</details></aside>
<main id="main"><article>{content}</article><footer>由仓库源码维护 · <a href="{origin}/blob/{quote(branch, safe='')}/{quote(source.relative_to(root).as_posix(), safe='/')}">查看 / 编辑本页源文件</a></footer></main><aside class="toc"><strong>本页目录</strong>{toc}</aside></div>
<script src="{e(js)}" defer></script></body></html>'''
        target = output / route
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(page)
        plain = re.sub(r'<[^>]+>', ' ', content)
        search.append({'title': title, 'url': route, 'text': html.unescape(plain)})
    if errors:
        raise SystemExit('Link validation failed:\n' + '\n'.join(sorted(set(errors))))
    for asset in sorted((root / 'docs/assets').rglob('*')):
        if asset.is_file():
            target = output / 'assets' / asset.relative_to(root / 'docs/assets')
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(asset.read_bytes())
    (output / 'search-index.json').write_text(json.dumps(search, ensure_ascii=False))
    (output / '.nojekyll').touch()
    (output / '404.html').write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>页面未找到</title><p>页面未找到。<a href="' + site_url + '">返回文档首页</a></p></html>')
    print(f'{repo}: built {len(routes)} pages; all local Markdown links and anchors validated')


if __name__ == '__main__':
    main()
