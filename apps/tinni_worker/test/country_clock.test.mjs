import test from 'node:test';
import assert from 'node:assert/strict';
import { countryDay,countryTimeZone,countryTimeZones } from '../src/country_clock.js';
test('India and Saudi Arabia use independent local midnight boundaries',()=>{
 const time=Date.parse('2026-10-05T18:29:59Z');
 const india=countryDay('IN',time),saudi=countryDay('SA',time);
 assert.equal(india.time_zone,'Asia/Kolkata');
 assert.equal(saudi.time_zone,'Asia/Riyadh');
 assert.equal(india.resets_at,Date.parse('2026-10-05T18:30:00Z'));
 assert.equal(saudi.resets_at,Date.parse('2026-10-05T21:00:00Z'));
 assert.equal(countryDay('IN',india.resets_at).day_key,'2026-10-06');
 assert.equal(countryDay('SA',india.resets_at).day_key,'2026-10-05');
});
test('day length respects daylight saving and half-hour zones',()=>{
 const spring=countryDay('US',Date.parse('2026-03-08T12:00:00Z'));
 const fall=countryDay('US',Date.parse('2026-11-01T12:00:00Z'));
 assert.equal(spring.resets_at-spring.starts_at,23*3600000);
 assert.equal(fall.resets_at-fall.starts_at,25*3600000);
 assert.equal(countryDay('NP',Date.parse('2026-10-05T12:00:00Z')).resets_at,Date.parse('2026-10-05T18:15:00Z'));
 assert.equal(countryDay('US',Date.parse('2026-10-05T12:00:00Z'),'Pacific/Honolulu').time_zone,'Pacific/Honolulu');
 assert.throws(()=>countryTimeZone('IN','invalid/timezone'),RangeError);
});
test('every configured country has a valid primary IANA zone',()=>{
 assert.ok(Object.keys(countryTimeZones).length>=247);
 for(const code of Object.keys(countryTimeZones)) assert.doesNotThrow(()=>countryTimeZone(code),code);
});

test('multi-zone countries default to capital-region time and allow explicit overrides',()=>{
 assert.equal(countryTimeZone('AU'),'Australia/Sydney');
 assert.equal(countryTimeZone('RU'),'Europe/Moscow');
 assert.equal(countryTimeZone('CA'),'America/Toronto');
 assert.equal(countryTimeZone('BR'),'America/Sao_Paulo');
 assert.equal(countryTimeZone('AU','Australia/Perth'),'Australia/Perth');
});
