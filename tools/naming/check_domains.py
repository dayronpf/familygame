#!/usr/bin/env python3
"""Comprueba si unos nombres están registrados como dominio .com, .net, .app y .org, consultando los servicios RDAP
oficiales de cada registro (Verisign, Google Registry, PIR). RDAP responde 404 cuando el dominio NO está registrado.

Uso:  python3 tools/naming/check_domains.py candidatos.txt resultados.json

«libre» solo significa «no registrado hoy»: puede estar reservado o ser premium, y no dice nada de marcas registradas.
Antes de comprar hay que confirmarlo en el registrador. Un nombre por línea, sin acentos ni espacios.
"""
import concurrent.futures as cf
import json
import sys
import time
import urllib.error
import urllib.request

EP = {
 'com': 'https://rdap.verisign.com/com/v1/domain/{}',
 'net': 'https://rdap.verisign.com/net/v1/domain/{}',
 'app': 'https://pubapi.registry.google/rdap/domain/{}',
 'org': 'https://rdap.publicinterestregistry.org/rdap/domain/{}',
}
def status(domain, tld):
    url = EP[tld].format(f'{domain}.{tld}')
    for attempt in range(3):
        try:
            r = urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'name-check/1.0'}), timeout=15)
            return 'tomado'
        except urllib.error.HTTPError as e:
            if e.code == 404: return 'libre'
            if e.code == 429: time.sleep(2 * (attempt + 1)); continue
            return f'error{e.code}'
        except Exception as e:
            time.sleep(1)
    return 'error'
names = [l.strip() for l in open(sys.argv[1]) if l.strip() and not l.startswith('#')]
jobs = [(n, t) for n in names for t in EP]
res = {}
with cf.ThreadPoolExecutor(8) as ex:
    futs = {ex.submit(status, n, t): (n, t) for n, t in jobs}
    for f in cf.as_completed(futs):
        n, t = futs[f]; res.setdefault(n, {})[t] = f.result()
json.dump(res, open(sys.argv[2], 'w'), indent=1, ensure_ascii=False)
for n in names:
    print(f"{n:22}", ' '.join(f"{t}:{res[n][t]:7}" for t in EP))
