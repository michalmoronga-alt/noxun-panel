  // ===================== Pravidla kovania — formular =====================
  // RULES drzi PLNE objekty pravidiel (vratane neznamych klucov buducich verzii);
  // formular edituje len zname polia (enabled/quantity/bands/series/clearance),
  // collect() ich prepise na kopii — nic sa nestrati. Normalizaciu (sort pasiem,
  // clamp poctov) robi Ruby po Ulozit.

  var RULES = [];

  function el(id){ return document.getElementById(id); }
  function esc(s){ return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
  function rlLabel(t){
    return { leg:'Nohy', hinge:'Závesy', slide:'Výsuvy', handle:'Úchytky',
             shelf_pin:'Podperky', connector:'Spojky' }[t] || t;
  }
  function roleDesc(r){
    var ap = (r.applies_to || {}); var role = ap.role || '';
    if (role === 'cabinet') return 'na skrinku s podstavcom';
    if (role === 'front_door') return 'na každé krídlo dvierok';
    if (role === 'drawer_front') return 'na každé zásuvkové čelo';
    return role;
  }

  window.RD = {
    init: function(data){
      RULES = data.rules || [];
      el('srcline').textContent = 'V' + (data.version || '') +
        ' · zdroj: ' + (data.source === 'project' ? 'tento projekt' : 'globálne predvoľby (projekt ešte nemá vlastné)') +
        ' · skriniek v modeli: ' + (data.cabinets || 0);
      renderRules();
    },
    setRules: function(rules, _source){ RULES = rules || []; renderRules(); },
    setStatus: function(msg, err){ var e = el('status'); e.textContent = msg; e.className = err ? 'err' : 'ok'; }
  };

  function renderRules(){
    var html = '';
    RULES.forEach(function(r, i){
      html += '<div class="rrule" data-i="'+i+'">';
      html += '<div class="rhead"><label><input type="checkbox" class="ren" '+(r.enabled!==false?'checked':'')+'> '
            + '<b>'+esc(rlLabel(r.output))+'</b></label> <span class="rid">'+esc(roleDesc(r))+'</span></div>';
      if (r.kind === 'fixed'){
        html += '<div class="rrow"><label>Počet</label><input class="rqty rnum" type="number" min="1" max="999" step="1" value="'+esc(r.quantity!=null?r.quantity:1)+'"><span class="unit">ks</span></div>';
      } else if (r.kind === 'bands'){
        html += '<div class="rbands">';
        (r.bands || []).forEach(function(b, bi){
          var last = (b.max === null || b.max === undefined);
          html += '<div class="rrow rband" data-bi="'+bi+'">'
                + (last ? '<label>všetko nad</label><span class="bmaxfill"></span>'
                        : '<label>do</label><input class="bmax rnum" type="number" min="1" step="1" value="'+esc(b.max)+'"><span class="unit">mm</span>')
                + '<span class="arrow">→</span><input class="bqty rnum" type="number" min="1" max="999" step="1" value="'+esc(b.quantity)+'"><span class="unit">ks</span>'
                + (last ? '<span class="bdel"></span>' : '<button class="ghostbtn bdel" title="Odstrániť pásmo" onclick="delBand(this)">✕</button>')
                + '</div>';
        });
        html += '<div class="btnrow"><button class="ghostbtn" onclick="addBand(this)">+ pásmo</button></div>';
        html += '</div>';
      } else if (r.kind === 'fit_series'){
        html += '<div class="rrow"><label>Rad dĺžok</label><input class="rseries" type="text" value="'+esc((r.series||[]).join(', '))+'"><span class="unit">mm</span></div>';
        html += '<div class="rrow"><label>Rezerva</label><input class="rclr rnum" type="number" min="0" step="1" value="'+esc(r.clearance!=null?r.clearance:10)+'"><span class="unit">mm</span></div>';
        html += '<div class="rrow"><label>Počet</label><input class="rqty rnum" type="number" min="1" max="999" step="1" value="'+esc(r.quantity!=null?r.quantity:1)+'"><span class="unit">sád</span></div>';
        html += '<div class="hint">Vyberie sa najväčšia dĺžka z radu, ktorá sa zmestí do svetlej hĺbky mínus rezerva.</div>';
      } else {
        html += '<div class="hint">Pravidlo novšej verzie („'+esc(r.kind)+'“) — tu sa needituje, zostáva zachované.</div>';
      }
      html += '</div>';
    });
    if (!html) html = '<div class="muted">Žiadne pravidlá — načítaj globálne predvoľby.</div>';
    el('rulesBox').innerHTML = html;
  }

  function ruleNode(node){ return node.closest('.rrule'); }
  function ruleOf(node){ return RULES[parseInt(ruleNode(node).dataset.i, 10)]; }

  function addBand(btn){
    var r = ruleOf(btn);
    r.bands = collectBands(ruleNode(btn)); // najprv prevezmi rozeditovane hodnoty
    // nove pasmo pred "vsetko nad": max = posledny konkretny max + 500 (orientacne)
    var maxes = r.bands.filter(function(b){ return b.max != null; }).map(function(b){ return b.max; });
    var nm = maxes.length ? Math.max.apply(null, maxes) + 500 : 900;
    r.bands.splice(Math.max(r.bands.length - 1, 0), 0, { max: nm, quantity: 1 });
    renderRules();
  }
  function delBand(btn){
    var r = ruleOf(btn);
    r.bands = collectBands(ruleNode(btn));
    r.bands.splice(parseInt(btn.closest('.rband').dataset.bi, 10), 1);
    renderRules();
  }
  function collectBands(ruleEl){
    var out = [];
    ruleEl.querySelectorAll('.rband').forEach(function(row){
      var maxInp = row.querySelector('.bmax');
      var q = parseInt(row.querySelector('.bqty').value, 10);
      out.push({ max: maxInp ? (parseFloat(maxInp.value) || null) : null,
                 quantity: (isNaN(q) || q < 1) ? 1 : q });
    });
    return out;
  }

  // Zozbiera formular do kopii povodnych pravidiel (nezname kluce ostavaju).
  function collectRules(){
    var out = [];
    document.querySelectorAll('.rrule').forEach(function(ruleEl){
      var src = RULES[parseInt(ruleEl.dataset.i, 10)];
      var r = JSON.parse(JSON.stringify(src));
      r.enabled = ruleEl.querySelector('.ren').checked;
      var qty = ruleEl.querySelector('.rqty');
      if (qty){ var q = parseInt(qty.value, 10); r.quantity = (isNaN(q) || q < 1) ? 1 : q; }
      if (r.kind === 'bands') r.bands = collectBands(ruleEl);
      if (r.kind === 'fit_series'){
        r.series = ruleEl.querySelector('.rseries').value.split(/[,;\s]+/)
          .map(function(s){ return parseFloat(s); })
          .filter(function(v){ return !isNaN(v) && v > 0; });
        var c = parseFloat(ruleEl.querySelector('.rclr').value);
        r.clearance = isNaN(c) ? 10 : Math.max(0, c);
      }
      out.push(r);
    });
    return out;
  }

  function saveRules(){
    var rules = collectRules();
    for (var i = 0; i < rules.length; i++){
      var r = rules[i];
      if (r.kind === 'bands' && r.enabled !== false){
        var hasCatchAll = (r.bands || []).some(function(b){ return b.max == null; });
        if (!(r.bands || []).length || !hasCatchAll){
          RD.setStatus('Pravidlo „' + rlLabel(r.output) + '“ potrebuje aspoň pásmo „všetko nad“.', true);
          return;
        }
      }
      if (r.kind === 'fit_series' && r.enabled !== false && !(r.series || []).length){
        RD.setStatus('Pravidlo „' + rlLabel(r.output) + '“ potrebuje aspoň jednu dĺžku v rade.', true);
        return;
      }
    }
    if (window.sketchup && sketchup.save_rules)
      sketchup.save_rules(JSON.stringify({ rules: rules, also_global: el('alsoGlobal').checked }));
  }
  function loadGlobal(){
    if (window.sketchup && sketchup.load_global) sketchup.load_global('');
  }

  if (window.sketchup && sketchup.ready) sketchup.ready('');
