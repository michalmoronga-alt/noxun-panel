import json, re, sys, html, urllib.request, urllib.parse, time
TRACKER = '39755-295781'
UA = {'User-Agent': 'Mozilla/5.0'}
def lbx(q):
    url = ('https://live.luigisbox.tech/autocomplete/v2?tracker_id=%s&type=item:20&q=%s&hostname=www.demos-trade.sk' % (TRACKER, urllib.parse.quote(q)))
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30) as r:
        return json.load(r).get('hits', [])
def attr(a, k):
    v = a.get(k)
    return (v[0] if v else None) if isinstance(v, list) else v
def page(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30) as r:
        t = r.read().decode('utf-8', 'replace')
    t = re.sub(r'<script.*?</script>', '', t, flags=re.S); t = re.sub(r'<style.*?</style>', '', t, flags=re.S)
    txt = html.unescape(re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', ' ', t)))
    m = re.search(r'Popis produktu(.{0,700})', txt)
    return {'desc': m.group(1).strip() if m else txt[:300]}
# 1) doplnkové kódy zo starého zberu
old = json.load(open('aventos_hk_hl_top_2026-09-08.json', encoding='utf-8'))
acc = set()
for o in old:
    for c in (o.get('acc') or []) + (o.get('alt') or []): acc.add(c)
queries = sorted(acc) + ['22K8000', '347834', 'krytky Aventos HK top', '22.8000', '507343', 'krytky Aventos HL top',
  'TIP-ON 956A1004', '250831', '497007', 'TIP-ON dvierka 76', 'Aventos HL top Tip-on', '22L2200T', '22L2500T', '22L2', '22Q1076U', '22Q080Z', 'Aventos HK top krytky čierna', 'Aventos HK top krytky sivá']
seen = {}
for q in queries:
    try: hits = lbx(q)
    except Exception as e: print('ERR', q, e); continue
    for h in hits:
        a = h.get('attributes', {}); code = attr(a, 'product_code')
        if not code or code in seen: continue
        seen[code] = {'q': q, 'title': re.sub(r'</?em>', '', attr(a, 'title') or ''), 'price': attr(a, 'price'), 'unit': attr(a, 'unit'),
                      'price_vat': attr(a, 'price_with_vat'), 'url': attr(a, 'web_url'), 'acc': a.get('accessories'), 'alt': a.get('alternatives')}
    time.sleep(0.2)
out = []
for code, rec in seen.items():
    t = rec['title'].lower()
    if not any(k in t for k in ['aventos', 'tip-on', 'tip on', 'krytk', '22k', '22l', '22q', '20s', '956a']): continue
    info = {}
    if rec['url']:
        try: info = page(rec['url'])
        except Exception as e: info = {'err': str(e)[:60]}
        time.sleep(0.3)
    out.append({'code': code, **rec, **info})
for o in sorted(out, key=lambda x: x['title']):
    print('%s | %s | %s %s | %s | q=%s' % (o['code'], o['title'][:80], o.get('price_vat'), o.get('unit'), o['url'], o['q']))
json.dump(out, open('aventos2_out.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('TOTAL', len(out), 'of', len(seen))
