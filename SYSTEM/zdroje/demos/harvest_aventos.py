import json, re, sys, html, urllib.request, urllib.parse, time

TRACKER = '39755-295781'
UA = {'User-Agent': 'Mozilla/5.0'}

def lbx(q):
    url = ('https://live.luigisbox.tech/autocomplete/v2?tracker_id=%s&type=item:20&q=%s&hostname=www.demos-trade.sk'
           % (TRACKER, urllib.parse.quote(q)))
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30) as r:
        return json.load(r).get('hits', [])

def attr(a, k):
    v = a.get(k)
    if isinstance(v, list):
        return v[0] if v else None
    return v

def page(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30) as r:
        t = r.read().decode('utf-8', 'replace')
    t = re.sub(r'<script.*?</script>', '', t, flags=re.S)
    t = re.sub(r'<style.*?</style>', '', t, flags=re.S)
    txt = html.unescape(re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', ' ', t)))
    lf = re.search(r'LF \(([^)]*)\)\s*-?\s*(\d+)\s*-\s*(\d+)', txt)
    lf2 = re.search(r'(?:rozmedz|rozsah)[^.]{0,80}?(\d{3,4})\s*[-–]\s*(\d{3,5})', txt)
    need = re.search(r'Nutn[ée] doplni[ťt][^.]{0,160}', txt)
    kh = re.search(r'(?:výšk[aeu] korpusu|KH)[^.]{0,60}?(\d{3,4})\s*[-–]\s*(\d{3,4})', txt)
    return {
        'lf': (lf.group(2) + '-' + lf.group(3)) if lf else ((lf2.group(1) + '-' + lf2.group(2)) if lf2 else None),
        'lf_note': lf.group(1)[:80] if lf else None,
        'need': need.group(0)[:160] if need else None,
        'kh': (kh.group(1) + '-' + kh.group(2)) if kh else None,
    }

queries = sys.argv[1:] or ['Aventos HK top', '22K2', 'Aventos HL top', '20L', 'krytky HK top', 'TIP-ON Aventos', 'Aventos HK-S', 'Aventos HK-XS']
seen = {}
for q in queries:
    for h in lbx(q):
        a = h.get('attributes', {})
        code = attr(a, 'product_code')
        if not code or code in seen:
            continue
        seen[code] = {'q': q, 'title': attr(a, 'title'), 'price': attr(a, 'price') or attr(a, 'price_amount'),
                      'unit': attr(a, 'unit'), 'price_vat': attr(a, 'price_with_vat'), 'acc': a.get('accessories'), 'alt': a.get('alternatives'), 'url': attr(a, 'web_url')}

out = []
for code, rec in seen.items():
    info = {}
    if rec['url']:
        try:
            info = page(rec['url'])
        except Exception as e:  # noqa
            info = {'err': str(e)[:60]}
        time.sleep(0.3)
    out.append({'code': code, **rec, **info})

for o in out:
    print('%s | %s | %s / %s %s | LF %s (%s) | KH %s | %s | acc=%s alt=%s' % (o['code'], (o.get('title') or '').replace('<em>','').replace('</em>','')[:70], o.get('price'), o.get('price_vat'), o.get('unit'), o.get('lf'), (o.get('lf_note') or '')[:50], o.get('kh'), (o.get('need') or '')[:80], str(o.get('acc'))[:60], str(o.get('alt'))[:60]))
json.dump(out, open(sys.argv[0].replace('.py', '_out.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
