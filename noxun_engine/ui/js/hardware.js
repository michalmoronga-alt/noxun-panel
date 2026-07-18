  // ===================== KOVANIE (V0.4 faza 1) =====================
  // Sekcia zobrazuje vypocitane polozky (config.hardware oznacenej skrinky) a rucne
  // zasahy. Identita polozky = (owner_part_key, generic_type, rule_id) — presne tak
  // ju posiela set_hardware_override do Ruby. Bez oznacenej skrinky len hint
  // (kovanie sa pocita na realnej skrinke, nie z hodnot panela).

  function hwLabel(t){
    return { leg:'Nohy', hinge:'Závesy', slide:'Výsuv', handle:'Úchytky',
             shelf_pin:'Podperky', connector:'Spojky' }[t] || t;
  }
  function hwUnit(t){ return t === 'slide' ? 'sada' : 'ks'; }
  // Ludsky popis vlastnika: front:F2/wing:left -> "F2 · ľavé krídlo".
  function hwOwnerDesc(owner){
    if (!owner) return '';
    var m = owner.match(/^front:([^\/]+)\/wing:(left|right|single)$/);
    if (m){
      var side = m[2]==='left' ? ' · ľavé krídlo' : (m[2]==='right' ? ' · pravé krídlo' : '');
      return m[1] + side;
    }
    var p = owner.match(/^front:([^\/]+)\/panel$/);
    if (p) return p[1] + ' · zásuvka';
    return owner;
  }
  function hwParamsDesc(it){
    var ps = it.params || {};
    if (ps.nominal_length != null) return 'NL ' + Math.round(ps.nominal_length);
    if (ps.height != null) return Math.round(ps.height) + ' mm';
    return '';
  }
  function hwKey(owner, type, rule){ return (owner||'') + '||' + type + '||' + rule; }

  // items: config.hardware (pole) alebo null (nic neoznacene); overrides: hardware_overrides.
  function renderHardware(items, overrides){
    var box = el('hwRows'); if (!box) return;
    if (items === null){
      box.innerHTML = '<div class="muted">Označ skrinku v modeli — kovanie sa počíta na vloženej skrinke.</div>';
      return;
    }
    var html = '';
    var present = {};
    items.forEach(function(it){
      present[hwKey(it.owner_part_key, it.generic_type, it.rule_id)] = true;
      var name = hwLabel(it.generic_type);
      var owner = hwOwnerDesc(it.owner_part_key);
      var extra = hwParamsDesc(it);
      var manual = it.source === 'manual';
      html += '<div class="hwrow" data-owner="'+esc(it.owner_part_key||'')+'" data-type="'+esc(it.generic_type)+'" data-rule="'+esc(it.rule_id)+'">'
        + '<span class="hwname">'+esc(name)+(owner?' <span class="hwown">'+esc(owner)+'</span>':'')
        + (extra?' <span class="hwext">'+esc(extra)+'</span>':'')+'</span>'
        + '<input class="hwqty'+(manual?' manual':'')+'" type="number" min="1" max="999" step="1" value="'+esc(it.quantity)+'" onchange="onHwQty(this)">'
        + '<span class="unit">'+hwUnit(it.generic_type)+'</span>'
        + (manual
            ? '<button class="ghostbtn hwbtn" title="Vrátiť na pravidlo ('+esc(it.rule_quantity)+')" onclick="onHwReset(this)">↺</button>'
            : '<span class="hwsrc" title="Počet z pravidla"></span>')
        + '<button class="ghostbtn hwbtn" title="Vypnúť položku" onclick="onHwDisable(this)">✕</button>'
        + '</div>';
    });
    // Vypnute kategorie: disabled override bez zodpovedajucej polozky (evaluate ju vyradil).
    (overrides || []).forEach(function(ov){
      if (!ov || ov.disabled !== true) return;
      if (present[hwKey(ov.owner_part_key, ov.generic_type, ov.rule_id)]) return;
      var owner = hwOwnerDesc(ov.owner_part_key);
      html += '<div class="hwrow hwoff" data-owner="'+esc(ov.owner_part_key||'')+'" data-type="'+esc(ov.generic_type)+'" data-rule="'+esc(ov.rule_id)+'">'
        + '<span class="hwname">'+esc(hwLabel(ov.generic_type))+(owner?' <span class="hwown">'+esc(owner)+'</span>':'')
        + ' <span class="hwext">vypnuté</span></span>'
        + '<button class="ghostbtn hwbtn" title="Obnoviť (platí pravidlo)" onclick="onHwReset(this)">↺ obnoviť</button>'
        + '</div>';
    });
    if (!html) html = '<div class="muted">Skrinka nemá žiadne kovanie (bez čiel, bez podstavca).</div>';
    box.innerHTML = html;
  }

  function hwPayload(node, extra){
    var row = node.closest('.hwrow');
    var out = { owner_part_key: row.dataset.owner || null,
                generic_type: row.dataset.type, rule_id: row.dataset.rule };
    for (var k in extra) out[k] = extra[k];
    return out;
  }
  function hwSend(payload){
    if (window.sketchup && sketchup.set_hardware_override)
      sketchup.set_hardware_override(JSON.stringify(payload));
  }
  function onHwQty(inp){
    var q = parseInt(inp.value, 10);
    if (isNaN(q) || q < 1){ NX.setStatus('Počet musí byť aspoň 1 (alebo položku vypni ✕).', true); return; }
    hwSend(hwPayload(inp, { quantity: q }));
  }
  function onHwDisable(btn){ hwSend(hwPayload(btn, { disabled: true })); }
  function onHwReset(btn){ hwSend(hwPayload(btn, { reset: true })); }
  function openRulesDialog(){
    if (window.sketchup && sketchup.open_rules) sketchup.open_rules('');
  }
