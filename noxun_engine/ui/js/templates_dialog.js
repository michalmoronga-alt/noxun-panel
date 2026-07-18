  // ===================== Sablony — sprava =====================
  // Zoznam sablon s akciami per riadok. "Pouzit na oznaceny" je aktivne len ked
  // je v modeli oznaceny korpus ROVNAKEHO typu ako sablona (dolna/horna) — typ
  // sa pri apply nemeni (builder by ho ignoroval, radsej jasne disabled + title).

  var TD_TPLS = [];
  var TD_CAB = null;
  var TD_TYPE = null;

  function el(id){ return document.getElementById(id); }
  function esc(s){ return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }

  function typeLabel(t){ return t === 'upper' ? 'horná' : 'dolná'; }

  function renderRows(){
    var box = el('tplRows');
    if (!TD_TPLS.length){
      box.innerHTML = '<div class="muted">Žiadne šablóny — označ skrinku a ulož ju tlačidlom hore.</div>';
      return;
    }
    var html = '';
    TD_TPLS.forEach(function(tp){
      var t = (tp.config && tp.config.type) ? tp.config.type : 'lower';
      var can = TD_CAB && t === TD_TYPE;
      var why = !TD_CAB ? 'Najprv označ skrinku v modeli'
              : (t !== TD_TYPE ? 'Šablóna je pre iný typ (' + typeLabel(t) + ') než označená skrinka'
                               : 'Prestavať ' + esc(TD_CAB) + ' podľa šablóny');
      html += '<div class="tplrow" data-name="'+esc(tp.name)+'">'
        + '<span class="tpln">'+esc(tp.name)+' <span class="tplt">'+typeLabel(t)+'</span></span>'
        + '<button class="ghostbtn tplbtn" onclick="tplApply(this)"'+(can?'':' disabled')
        + ' title="'+why+'">Použiť</button>'
        + '<button class="ghostbtn tplbtn tpldel" title="Vymazať šablónu" onclick="tplDelete(this)">✕</button>'
        + '</div>';
    });
    box.innerHTML = html;
  }

  window.TD = {
    init: function(data){
      TD_TPLS = data.templates || [];
      TD_CAB = data.selected_cab || null;
      TD_TYPE = data.selected_type || null;
      el('tdline').textContent = 'V' + (data.version || '') + ' · šablón: ' + TD_TPLS.length +
        (TD_CAB ? ' · označený: ' + TD_CAB + ' (' + typeLabel(TD_TYPE) + ')' : ' · nič nie je označené');
      renderRows();
    },
    setStatus: function(msg, err){ var e = el('status'); e.textContent = msg; e.className = err ? 'err' : 'ok'; }
  };

  function tplName(btn){ return btn.closest('.tplrow').dataset.name; }
  function tplApply(btn){
    if (window.sketchup && sketchup.tpl_apply)
      sketchup.tpl_apply(JSON.stringify({ template: tplName(btn) }));
  }
  function tplDelete(btn){
    if (window.sketchup && sketchup.tpl_delete)
      sketchup.tpl_delete(JSON.stringify({ template: tplName(btn) }));
  }
  function tplSave(){
    if (window.sketchup && sketchup.tpl_save) sketchup.tpl_save('');
  }

  if (window.sketchup && sketchup.ready) sketchup.ready('');
