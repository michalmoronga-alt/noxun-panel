'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const dir = path.join(__dirname, '../../noxun_engine/ui/js');
const pv = require(path.join(dir, 'preview.js'));
const items = [{id:'F1', type:'door', z:2, height:716, wings_n:2}];
assert.deepEqual(pv.nxFrontsExtent(items,600,720,-18,2),{minX:-18,maxX:600,minZ:0,maxZ:720});
assert.deepEqual(pv.nxFrontsExtent(items,600,720,2,-18),{minX:0,maxX:618,minZ:0,maxZ:720});
const fields = {fr_gap:'3',fr_gap_top:'2',fr_gap_bottom:'2',fr_gap_left:'-18',fr_gap_right:'0'};
const context = {
  el: id => id === 'frontRows' ? {querySelectorAll:()=>[]} : {value:fields[id]},
  numv: id => Number(fields[id]), setNum: (id,v)=>{fields[id]=String(v);}, onField:()=>{},
  setTimeout:()=>0, clearTimeout:()=>{}, console
};
vm.createContext(context);
vm.runInContext(fs.readFileSync(path.join(dir,'form.js'),'utf8'),context);
let got = context.collectFronts();
assert.equal(got.gap_left,-18);
assert.equal(got.gap_right,0);
assert.equal(Object.hasOwn(got,'gap_sides'),false);
assert.equal(context.frontSideGap({gap_sides:-5,gap_left:0},'gap_left'),0);
assert.equal(context.frontSideGap({gap_sides:-5,gap_left:0},'gap_right'),-5);
assert.equal(context.EDGE_LIMIT_FIELDS.fr_gap_left,1);
assert.equal(context.EDGE_LIMIT_FIELDS.fr_gap_right,1);
context.onField=()=>{};
context.resetFrontGaps();
assert.equal(fields.fr_gap_left,'2');
assert.equal(fields.fr_gap_right,'2');
// Skutocna kresba, ghost aj kota pouzivaju rovnake asymetricke hranice.
const draw = { ...context, frontProfileReduction:()=>0, esc:String, frontSlots:{}, frontDirectionOf:()=>null };
vm.createContext(draw);
vm.runInContext(fs.readFileSync(path.join(dir,'preview.js'),'utf8'),draw);
const g={W:600,H:720,fh:0,t:18,gapLeft:-18,gapRight:2,gap:3,fronts:items};
let svg=[]; draw.drawFrontsGhost(svg,x=>x,z=>z,g);
assert.match(svg.join(''),/M-18 2h616/);
svg=[]; draw.drawFrontDims(svg,x=>x,z=>z,g);
assert.match(svg.join(''),/>616<\/text>/);
assert.match(svg.join(''),/M-18 /);
console.log('CELA-A: migracia formulara, reset, asymetricky fit, ghost a koty OK');
