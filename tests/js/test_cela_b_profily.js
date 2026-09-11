'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const dir = path.join(__dirname, '../../noxun_engine/ui/js');
const core = require(path.join(dir, 'core.js'));
const plain = value => JSON.parse(JSON.stringify(value));
const mixed = [{type:'door',profile:'ukw7',profile_edge:'free'},
  {type:'lift',profile:'none',profile_edge:'left'}];
assert.deepEqual(core.frontProfileScopeEdges(mixed,'all'), ['top','bottom']);
assert.deepEqual(core.frontProfileScopeEdges(mixed,'door'), ['top','bottom','free']);
assert.deepEqual(core.frontProfileScopeEdges(mixed,'lift'), ['top','bottom','left','right']);
assert.equal(core.frontProfileCommon(mixed,'all','profile_edge'),null);
assert.equal(core.frontProfileEdge({profile_edge:null}),null);
assert.equal(core.frontProfileEdge({}),'top');
assert.equal(core.frontCardFocusSelector(core.frontCardFocusKey({pc:'edge'})), '[data-pc="edge"]');

function setup(){
  const sent=[], applied=[], status=[], timers=new Map(); let tick=0;
  const message={textContent:'',hidden:true};
  const c={...core, selectedCabId:'CAB-A', cabEditsInFlight:false, applyTimer:null, applyPendingGuid:null,
    guid:'DOC-A', document:{activeElement:null}, window:{},
    el:id=>id==='frontRows'?{querySelectorAll:()=>[]}:id==='frontDraftMessage'?message:null,
    DEFAULTS:{lower:{width:600,height:720,floor_height:0}}, getType:()=> 'lower', getInsertKind:()=> 'cabinet',
    NXInsert:{state:{lastMode:'insert'},lockedFields:()=>[]},
    NX:{setStatus:(m,b)=>status.push([m,b])}, isExprInput:()=>false, isExprStr:()=>false,
    setTimeout:(fn,delay)=>{const id=++tick;timers.set(id,{fn,delay});return id;},
    clearTimeout:id=>timers.delete(id), console};
  c.nxDocGuid=()=>c.guid;
  c.nxDocPayload=(p,g)=>JSON.stringify({...p,model_guid:g==null?c.guid:g});
  c.sketchup=c.window.sketchup={front_preflight:p=>sent.push(JSON.parse(p)),apply_all:p=>applied.push(JSON.parse(p))};
  vm.createContext(c);vm.runInContext(fs.readFileSync(path.join(dir,'form.js'),'utf8'),c);
  c.construction={width:600,height:720,floor_height:0};
  c.cfg={gap:3,gap_top:2,gap_bottom:2,gap_left:-18,gap_right:2,
    items:[{id:'F1',type:'door',mode:'auto',wings:'1',profile:'ukw7',profile_edge:'free'}]};
  c.collectConstruction=()=>plain(c.construction);c.collectFronts=()=>plain(c.cfg);
  c.collectAll=()=>({...c.construction,fronts:plain(c.cfg)});
  ['invalidateFrontPlaceholders','refreshMaterialFilters','schedulePreview','updateAvailable',
    'refreshFrontCards','renderPreview','updateFrontDirBadges','updateFrontPlaceholders'].forEach(k=>c[k]=()=>{});
  function answer(request,valid=true){c.nxFrontPreflightResult({...request,valid,
    items:[{...request.fronts.items[0],wings_n:1,profile_edges:valid?['right']:[]}],
    slots:{F1:{wings_n:1,slots:[{wing:'single',state:valid?'left':null}]}},
    errors:valid?[]:[{front_id:'F1',message:'Urči smer pántov.'}]});}
  function fire(){const id=[...timers].find(([,v])=>v.delay===400)?.[0];if(id){const t=timers.get(id);timers.delete(id);t.fn();}}
  function ack(payload,ok=true){c.nxFrontApplyResult({...payload,ok});}
  return {c,sent,applied,status,message,answer,fire,ack};
}

// Cakajuci a neplatny preflight blokuje zapis, export aj native-copy flush.
{
  const t=setup(), c=t.c; c.onField();assert.equal(t.sent.length,1);
  t.fire();assert.equal(t.applied.length,0);
  let actions=0, failures=0;
  assert.equal(c.nxCabinetAction(()=>actions++,()=>failures++),false);
  assert.equal(actions,0);assert.equal(failures,1);
  const done=[];c.nxNativeFlushDone=(token,state)=>done.push(state);
  c.nxFlushForNative('copy',{});assert.deepEqual(done,['invalid']);
  t.answer(t.sent[0],false);assert.equal(c.validateFields(),false);
  assert.match(t.message.textContent,/smer/);assert.equal(t.applied.length,0);
  c.flushCabinetEditsNow();assert.match(t.status.at(-1)[0],/smer/);
  // Oprava: nic sa nezapise pred novou odpovedou, potom jediny apply.
  c.cfg.items[0].direction='left';c.onField();t.fire();assert.equal(t.applied.length,0);
  t.answer(t.sent[1]);t.fire();assert.equal(t.applied.length,1);
  assert.equal(t.applied[0].fronts.items[0].profile_edge,'free');
  assert.equal(c.nxCabinetAction(()=>actions++,()=>failures++),false);
  assert.equal(actions,0);t.ack(t.applied[0]);assert.equal(actions,1);
  assert.equal(c.cabDraftDirty,false);
}
// Stare odpovede a stary apply nesmu potvrdit novsi navrh ani cudzi dokument.
{
  const t=setup(),c=t.c;c.onField();const old=t.sent[0];
  c.cfg.items[0].wings='3';c.onField();t.answer(old);
  assert.equal(c.frontDraft.pending,true);
  t.answer(t.sent[1]);t.fire();const first=t.applied[0];
  c.construction.width=700;c.onField();t.answer(t.sent[2]);
  t.ack(first);assert.equal(c.cabDraftDirty,true);t.fire();assert.equal(t.applied.length,2);
  const last=t.applied[1];c.guid='DOC-B';c.nxFrontDraftReset();c.selectedCabId='CAB-B';
  t.ack(last);t.answer(t.sent[2]);assert.equal(c.frontDraft,null);assert.equal(c.cabDraftDirty,false);
}
// Zlyhany apply nepusti naviazanu akciu a neoznaci hodnoty ako ulozene.
{
  const t=setup(),c=t.c;c.onField();t.answer(t.sent[0]);
  let ran=0,failed=0;c.nxCabinetAction(()=>ran++,()=>failed++);
  assert.equal(t.applied.length,1);t.ack(t.applied[0],false);
  assert.equal(ran,0);assert.equal(failed,1);assert.equal(c.cabDraftDirty,true);
}
// Odmietnutie so serverovym resyncom obnovi hodnoty; stare echo nezhodi novsi edit.
{
  const t=setup(),c=t.c, restored=[];
  c.NX.loadSelected=p=>restored.push(p);
  c.onField();t.answer(t.sent[0]);t.fire();const pending=t.applied[0];
  const saved={model_guid:'DOC-A',cabinet_id:'CAB-A',width:600,fronts:plain(c.cfg)};
  c.nxRememberCabinetEcho({...saved,cabinet_id:'CAB-B'});assert.equal(c.cabApplyRequest.echo,undefined);
  c.nxRememberCabinetEcho(saved);t.ack(pending,false);
  assert.deepEqual(restored,[saved]);assert.equal(c.cabDraftDirty,false);assert.equal(c.frontDraft,null);
  c.onField();t.answer(t.sent[1]);t.fire();const second=t.applied[1];c.nxRememberCabinetEcho(saved);
  c.construction.width=750;c.onField();t.ack(second,false);
  assert.equal(restored.length,1);assert.equal(c.cabDraftDirty,true);assert.equal(c.construction.width,750);
  assert.match(fs.readFileSync(path.join(dir,'bridge.js'),'utf8'),/nxRememberCabinetEcho\(c\)/);
}
// Nova vkladacia relacia (typ/sablona) zneplatni povodne smerove sloty.
{
  const t=setup(),c=t.c;c.selectedCabId=null;c.nxFrontDraftReset();c.nxFrontDraftAsk();
  const old=t.sent[0];c.nxFrontDraftReset();c.cfg.items[0].type='blind';c.nxFrontDraftAsk();
  t.answer(old);assert.equal(c.frontDraft.pending,true);assert.equal(c.frontSlots,null);
  t.answer(t.sent[1]);assert.equal(c.frontDraft.valid,true);assert.equal(t.applied.length,0);
}
// UI projekcia pouziva fyzicke hrany; neznamy free bez odpovede nic nehada.
for (const [relay, method] of [['studioRelay','studio_do_select'],['studioRelayExport','studio_do_export'],['studioRelayHwCsv','studio_do_hw_csv'],
  ['studioRelayBudget','studio_do_budget_xlsx'],['studioRelayCp','studio_do_cp_xlsx']]){
  const t=setup(),c=t.c, exports=[];
  c.document.querySelector=()=>null;c.sketchup[method]=p=>exports.push(JSON.parse(p));
  vm.runInContext(fs.readFileSync(path.join(dir,'bridge.js'),'utf8'),c);
  c.NX=c.window.NX;
  c.NX.setStatus=()=>{};
  c.onField();c.NX[relay]({gen:7});
  assert.equal(exports[0].flush_blocked,true,relay+' blokuje pending');exports.length=0;
  t.answer(t.sent[0]);c.NX[relay]({gen:8});
  assert.equal(exports.length,0,relay+' caka na apply');t.ack(t.applied[0]);
  assert.equal(exports.length,1);assert.ok(!exports[0].flush_blocked);
  c.construction.width=700;c.onField();t.answer(t.sent[1]);c.NX[relay]({gen:9});
  t.ack(t.applied[1],false);assert.equal(exports[1].flush_blocked,true,relay+' odmietne zlyhany apply');
  c.construction.width=800;c.onField();t.answer(t.sent[2]);c.NX[relay]({gen:10});
  const pending=t.applied[2];c.guid='DOC-B';c.selectedCabId='CAB-B';c.nxFrontDraftReset();
  assert.equal(exports[2].flush_blocked,true,relay+' odpovie aj pri zmene identity');
  t.ack(pending);c.nxFrontDraftReset();assert.equal(exports.length,3,relay+' zrusenie odpovie len raz');
}

// Skutocny relay aplikacie sablony: invalid/pending stoji, po apply ide raz.
{
  const t=setup(),c=t.c, applied=[];
  c.document.querySelector=()=>null;c.sketchup.studio_do_template=p=>applied.push(JSON.parse(p));
  vm.runInContext(fs.readFileSync(path.join(dir,'bridge.js'),'utf8'),c);c.NX=c.window.NX;c.NX.setStatus=()=>{};
  const p={model_guid:'DOC-A',cabinet_id:'CAB-A',payload:{template:'Test'}};
  c.onField();c.NX.studioRelayTemplate(p);assert.equal(applied[0].flush_blocked,true);applied.length=0;
  t.answer(t.sent[0]);c.NX.studioRelayTemplate(p);assert.equal(applied.length,0);
  t.ack(t.applied[0]);assert.deepEqual(applied,[p]);
  c.guid='DOC-B';c.NX.studioRelayTemplate(p);assert.equal(applied[1].flush_blocked,true);
  c.guid='DOC-A';c.construction.width=800;c.onField();t.answer(t.sent[1]);c.NX.studioRelayTemplate(p);
  const pending=t.applied[1];c.selectedCabId='CAB-B';c.nxFrontDraftReset();
  assert.equal(applied[2].flush_blocked,true);t.ack(pending);assert.equal(applied.length,3);
}

// UI projekcia pouziva fyzicke hrany; neznamy free bez odpovede nic nehada.
{
  const c={...core,FRONT_PROFILES:[{id:'ukw7',reduction:36}],
    frontProfileReduction:()=>36};vm.createContext(c);
  vm.runInContext(fs.readFileSync(path.join(dir,'preview.js'),'utf8'),c);
  const it={profile:'ukw7',profile_edge:'free',profile_edges:['right','left']};
  const a=c.nxProfilePanel(it,0,-18,2,306.5,716),b=c.nxProfilePanel(it,1,291.5,2,306.5,716);
  assert.equal(a.w,270.5);assert.equal(b.x,327.5);assert.equal(b.h,716);
  assert.equal(c.nxProfilePanel({profile:'ukw7',profile_edge:'free'},0,0,0,600,720).band,null);
  const bottom=c.nxProfilePanel({profile:'ukw7',profile_edge:'bottom'},0,0,2,600,716);
  assert.equal(bottom.z,38);assert.equal(bottom.h,680);assert.equal(bottom.band.z,2);
}
console.log('CELA-B: hrany, mixed, preflight, stara odpoved, apply ack, export/native bariera a insert relacia OK');
