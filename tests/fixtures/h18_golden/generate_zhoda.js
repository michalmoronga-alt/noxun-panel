'use strict';
const fs = require('node:fs'), path = require('node:path');
const { disagreements } = require('./zhoda.js');
const target = path.join(__dirname, 'zhoda_pred.json');
if (fs.existsSync(target)) throw new Error('zhoda_pred uz existuje; neregenerovat');
const read = name => JSON.parse(fs.readFileSync(path.join(__dirname, name + '.json'), 'utf8'));
const result = disagreements(read('payload_pred'), read('source_pred'));
fs.writeFileSync(target, JSON.stringify(result, null, 2) + '\n');
console.log('H18 ZHODA PRED: ' + result.length + ' rozchodov');
