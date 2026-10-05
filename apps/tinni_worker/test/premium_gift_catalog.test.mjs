import test from 'node:test';
import assert from 'node:assert/strict';
import {premiumGiftCatalog} from '../src/premium_gift_catalog.js';
test('premium catalog authoritative prices, categories and unique IDs',()=>{
 const gifts=Object.values(premiumGiftCatalog);
 const normal=gifts.filter(g=>g.category==='normal');
 assert.equal(normal.length,50);
 assert.equal(normal.filter(g=>g.price<=100000).length,4);
 assert.equal(normal.filter(g=>g.price>100000).length,46);
 assert.equal(Math.max(...normal.map(g=>g.price)),10000000);
 assert.equal(gifts.filter(g=>g.category==='cp').length,20);
 assert.equal(gifts.filter(g=>g.category==='country').length,249);
 for(const gift of gifts) { assert.ok(Number.isSafeInteger(gift.price)&&gift.price>0); }
 assert.equal(premiumGiftCatalog['cp-invite'].price,2222222);
});
