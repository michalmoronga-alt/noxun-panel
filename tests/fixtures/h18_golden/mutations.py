"""H18 T8: rucny reprodukovatelny beh M1-M29, vzdy obnovi presne povodne bajty.

Spustenie z repa: python tests/fixtures/h18_golden/mutations.py
Vysledky su iba v gitignored _dev/h18_takeover/mutations.json.
Goldeny PRED ani PO sa nemenia. Vsetky mutacie bezia postupne.
"""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
CORE = 'noxun_engine/core/hardware_sets.rb'
PAY = 'noxun_engine/ui/panel/payloads.rb'
JS = 'noxun_engine/ui/js/hardware.js'
ACT = 'noxun_engine/ui/panel/actions_hardware.rb'
RUBY = os.environ.get('H18_RUBY') or shutil.which('ruby') or r'C:\Ruby32-x64\bin\ruby.exe'
NODE = os.environ.get('H18_NODE') or shutil.which('node') or r'C:\Program Files\nodejs\node.exe'

CLASS = """            v = ov[ck]
            return [v, 'cab_class', ck] if present_mapping_value?(v)

            v = ov[generic_type]
            return [v, 'cab', generic_type] if present_mapping_value?(v)"""
OWNER = """            opk = it['owner_part_key'].to_s
            unless opk.empty?
              v = ov["#{generic_type}@#{opk}"]
              return [v, 'owner', "#{generic_type}@#{opk}"] if present_mapping_value?(v)
            end
            v = ov[ck]
            return [v, 'cab_class', ck] if present_mapping_value?(v)"""
MUTATIONS = [
    ('M1', CORE, CLASS, """            v = ov[generic_type]
            return [v, 'cab', generic_type] if present_mapping_value?(v)

            v = ov[ck]
            return [v, 'cab_class', ck] if present_mapping_value?(v)""", 'resolver, nakup'),
    ('M2', CORE, "return [v, 'cab', generic_type] if present_mapping_value?(v)", "return [v, 'project', generic_type] if present_mapping_value?(v)", 'zdroj aj hodnota'),
    ('M3', CORE, 'MAPPING_OWN_LEVELS = %w[owner owner_class cab_class cab].freeze', 'MAPPING_OWN_LEVELS = MAPPING_SOURCE_LEVELS', 'own_count'),
    ('M4', PAY, 'end.uniq.length\n        end\n\n        # Prva volba selectu setu', 'end.uniq.length + overrides.length\n        end\n\n        # Prva volba selectu setu', 'own_count'),
    ('M5', PAY, 'reduced = overrides.reject { |k, _| k == class_key }', 'reduced = overrides', 'js-fresh-payload'),
    # Ponechany vlastnik vrati nepovoleny zdroj `owner`: T0 zlyha uz pri stavbe
    # payloadu (KeyError slovnika), preto sa nespolieha na hotovu JS fixturu.
    ('M6', PAY, "probe = probe.merge('owner_part_key' => '')", 'probe = probe.dup', 'resolver, nakup'),
    ('M7', PAY, "%w[owner owner_class].include?(level) ? raw : nil", 'overrides["#{class_key}@#{owner}"]', 'js-fresh-payload'),
    ('M8', CORE, 'return [nil, nil, nil] if mapping_skipped?(it, class_key_for(it, gt))', 'return [nil, nil, nil] if false', 'zdroj aj hodnota'),
    ('M9', CORE, 'return [nil, nil, nil] unless expandable_hardware_item?(item)', "return [nil, nil, nil] unless item.is_a?(Hash) && !item['generic_type'].to_s.empty?", 'zdroj aj hodnota'),
    ('M10', JS, 'return n + ((typeof count ===', 'return n + ((typeof count ===', 'js-old-meta'),
    ('M11', PAY, "'project_class' => 'projektu', 'project' => 'projektu'", "'project_class' => 'skrinky', 'project' => 'projektu'", 'resolver, nakup'),
    ('M12', CORE, 'explain_problem(out, class_problem)', "explain_problem(out, class_problem.merge('reason' => 'set_incompatible'))", 'OBOCH nesuladoch'),
    ('M13', CORE, 'resolve_mapping_source(generic_type, it, cabinet_overrides, mapping).first', "value = resolve_mapping_source(generic_type, it, cabinet_overrides, mapping).first\n        mapping_none?(value) ? mapping[generic_type] : value", 'zdroj aj hodnota'),
    ('M14', PAY, 'cur = HardwareSets.mapping_option_id(value)', "cur = HardwareSets.mapping_option_id(value.is_a?(Hash) && value['bands'].is_a?(Array) ? value['bands'].first['set_id'] : value)", 'js-fresh-payload'),
    ('M15', JS, "(sc.none_label || 'predvoľba projektu')", "'predvoľba projektu'", 'js'),
    ('M16', ACT, ': výber zrušený.', ': platí predvoľba projektu.', 'zrusenie vyberu'),
    ('M17', JS, '(ov && ov.invalid) ? (ov.label || \'neplatný výber\') :', 'false ? (ov.label || \'neplatný výber\') :', 'js'),
    ('M18', PAY, '"#{HardwareSets.mapping_value_text(ov_val, {})} (uložený výber)"', "HardwareSets.param_by(ov_val['param'])", 'js-fresh-payload'),
    ('M19', PAY, 'effective = hw_purchase_overrides(cfg, status, overrides)', 'effective = overrides', 'own_count'),
    ('M20', PAY, 'overrides = hw_purchase_overrides(cfg, status)', 'overrides = blocked ? {} : cabinet_set_overrides(cfg)', 'zdieľaju pravidlo'),
    ('M21', CORE, 'explain_problem(out, type_problem)', "explain_problem(out, type_problem.merge('reason' => 'set_type_mismatch'))", 'OBOCH nesuladoch'),
    ('M22', CORE, OWNER, """            v = ov[ck]
            return [v, 'cab_class', ck] if present_mapping_value?(v)
            opk = it['owner_part_key'].to_s
            unless opk.empty?
              v = ov["#{generic_type}@#{opk}"]
              return [v, 'owner', "#{generic_type}@#{opk}"] if present_mapping_value?(v)
            end""", 'zdroj aj hodnota'),
    ('M23', CORE, OWNER, """            v = ov[ck]
            return [v, 'cab_class', ck] if present_mapping_value?(v)
            v = ov[generic_type]
            return [v, 'cab', generic_type] if present_mapping_value?(v)
            opk = it['owner_part_key'].to_s
            unless opk.empty?
              v = ov["#{generic_type}@#{opk}"]
              return [v, 'owner', "#{generic_type}@#{opk}"] if present_mapping_value?(v)
            end""", 'klasifikovane zavesy expand'),
    ('M24', PAY, "%w[cab_class cab].include?(level) ? raw : nil", 'overrides[class_key]', 'js-fresh-payload'),
    ('M25', JS, "if (entry && entry.blocked){\n      return hwSetOptionList(entry, '', entry.project_label", "if (false){\n      return hwSetOptionList(entry, '', entry.project_label", 'js'),
    ('M26', PAY, 'owner_default_label(effective[gt], proj_val, opts, proj_name)', 'owner_default_label(ov_val, proj_val, opts, proj_name)', 'js-fresh-payload'),
    ('M27', JS, "if (entry && entry.blocked){\n      return hwSetOptionList(entry, '', entry.owner_default_label", "if (false){\n      return hwSetOptionList(entry, '', entry.owner_default_label", 'js'),
    ('M28', PAY, 'effective = hw_purchase_overrides(cfg, status, overrides)\n          blocked = hw_purchase_blocked?(status)', 'effective = hw_purchase_overrides(cfg, status, overrides)\n          blocked = status != :ok', 'js-fresh-payload'),
    ('M29', PAY, "out[owner]['value_text'] = HardwareSets.mapping_value_text(val, defs) if blocked", "out[owner]['value_text'] = HardwareSets.mapping_value_text(val, defs) if false", 'js-fresh-payload'),
]

def write_verified(path, data):
    # Windows antivirus/editor moze kratko blokovat otvorenie suboru (EINVAL).
    # Retry nemení ciel ani bajty; trvala chyba zastaví beh so zalohou na disku.
    for attempt in range(20):
        try:
            path.write_bytes(data)
            assert path.read_bytes() == data
            return
        except OSError:
            if attempt == 19:
                raise
            time.sleep(0.05)

def main():
    selected = set(sys.argv[1:])
    results = []
    backups = ROOT / '_dev/h18_takeover/mutation_backups'
    backups.mkdir(parents=True, exist_ok=True)
    originals = {rel: (ROOT / rel).read_bytes() for _, rel, *_ in MUTATIONS}
    for rel, data in originals.items():
        write_verified(backups / rel.replace('/', '__'), data)
    for name, rel, old, new, target in MUTATIONS:
        if selected and name not in selected:
            continue
        path = ROOT / rel
        original = originals[rel]
        assert path.read_bytes() == original, f'{name}: subor nie je obnoveny z predoslej mutacie'
        text = original.decode('utf-8').replace('\r\n', '\n')
        if target == 'js-old-meta':
            start = text.index('  function hwSetsMetaText(')
            end = text.index('\n  function ', start + 1)
            old = text[start:end]
            new = """  function hwSetsMetaText(setOptions){
    var list = (setOptions || []).filter(function(o){ return !!o; });
    var own = list.reduce(function(n,o){ return n + (o.override_set_id || o.override_selector ? 1 : 0) + Object.keys(o.owner_overrides || {}).length; }, 0);
    return !list.length ? '' : own === 0 ? 'podľa projektu' : own + ' ' + (own === 1 ? 'vlastný' : own < 5 ? 'vlastné' : 'vlastných');
  }"""
            target = 'js'
        if old not in text:
            raise RuntimeError(f'{name}: kotva mutacie sa zmenila, nic sa neaplikovalo')
        mutated = text.replace(old, new, 1 if name not in {'M15', 'M16'} else -1)
        if b'\r\n' in original:
            mutated = mutated.replace('\n', '\r\n')
        try:
            write_verified(path, mutated.encode('utf-8'))
            if target == 'js-fresh-payload':
                payload = ROOT / '_dev/h18_takeover/mutated_payload.json'
                code = "File.write(ARGV.first, NxH18.matrix_json((NxH18.cases + NxH18Blocked.cases).to_h { |c| [c['id'], NxH18.payload(c)] }))"
                generated = subprocess.run([RUBY, '-r', './tests/fixtures/h18_golden/blocked_cases', '-e', code, str(payload)],
                                           cwd=ROOT, capture_output=True, encoding='utf-8', timeout=90)
                if generated.returncode != 0:
                    raise RuntimeError(f'{name}: generator zlyhal: {generated.stderr}')
                command = [NODE, 'tests/js/test_h18_sety_pravda.js', str(payload)]
            elif target == 'js':
                command = [NODE, 'tests/js/test_h18_sety_pravda.js']
            else:
                code = "NxTest.tests.select! { |n,_| n.include?(ARGV.first) }; abort 'ziadny test' if NxTest.tests.empty?; exit(NxTest.run! ? 0 : 1)"
                command = [RUBY, '-r', './tests/pure/test_h18_sety_pravda', '-e', code, target]
            run = subprocess.run(command, cwd=ROOT, capture_output=True, encoding='utf-8', timeout=90)
            output = run.stdout + run.stderr
            failures = None
            if not target.startswith('js'):
                try:
                    failures = json.loads(run.stdout)['failed']
                except (ValueError, KeyError):
                    pass
            killed = run.returncode == 1 and (failures is not None and failures > 0 or target.startswith('js') and 'AssertionError' in output)
            result = {'mutation': name, 'test': target, 'exit': run.returncode, 'killed': killed}
            results.append(result)
            print(json.dumps(result, ensure_ascii=False), flush=True)
            if not killed:
                print(output[:3000], flush=True)
        finally:
            write_verified(path, original)
            assert path.read_bytes() == original
    out = ROOT / '_dev/h18_takeover/mutations.json'
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(results, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    return 0 if results and all(r['killed'] for r in results) else 1

if __name__ == '__main__':
    sys.exit(main())
