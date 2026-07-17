  // Diagnostika: chyby JS posielaj do Ruby (Engine.log). Konzolu HtmlDialogu v SketchUp konzole
  // nevidno, preto window.onerror + unhandledrejection -> sketchup.js_error. Necha sa natrvalo.
  window.onerror = function(msg, src, line, col, err){
    try {
      if (window.sketchup && sketchup.js_error)
        sketchup.js_error(JSON.stringify({ msg: String(msg), src: src ? String(src) : null,
          line: line, col: col, stack: (err && err.stack) ? String(err.stack) : null }));
    } catch(e){}
    return false;
  };
  window.addEventListener('unhandledrejection', function(ev){
    try {
      var r = ev ? ev.reason : null;
      if (window.sketchup && sketchup.js_error)
        sketchup.js_error(JSON.stringify({ msg: 'unhandledrejection: ' + (r && r.message ? r.message : String(r)),
          stack: (r && r.stack) ? String(r.stack) : null }));
    } catch(e){}
  });
