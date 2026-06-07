// Test the article's claim: East London Mosque uses 15 deg (not 18 deg) for Fajr/Isha.
// Compare 18 vs 15 deg against ELM's actual published "Begins" times for June 6.

const adhan = require('adhan');

const coords = new adhan.Coordinates(51.5074, -0.1278); // London
const tz = 'Europe/London';
const DATE = new Date(2026, 5, 6); // June 6, 2026 (month is 0-indexed)

function fmt(d) {
  if (!d || isNaN(d)) return '—';
  return d.toLocaleTimeString('en-GB', { timeZone: tz, hour: '2-digit', minute: '2-digit', hour12: true });
}

function run(label, fajrAngle, ishaAngle) {
  const p = adhan.CalculationMethod.Other();
  p.fajrAngle = fajrAngle;
  p.ishaAngle = ishaAngle;
  p.madhab = adhan.Madhab.Shafi;
  p.highLatitudeRule = adhan.HighLatitudeRule.MiddleOfTheNight;
  const t = new adhan.PrayerTimes(coords, DATE, p);
  console.log(`\n${label} (Fajr ${fajrAngle}°, Isha ${ishaAngle}°)`);
  console.log(`   Fajr     ${fmt(t.fajr)}      (ELM: 02:46 AM)`);
  console.log(`   Sunrise  ${fmt(t.sunrise)}      (ELM: 04:43 AM)`);
  console.log(`   Dhuhr    ${fmt(t.dhuhr)}      (ELM: 01:04 PM)`);
  console.log(`   Asr      ${fmt(t.asr)}      (ELM: 05:21 PM)`);
  console.log(`   Maghrib  ${fmt(t.maghrib)}      (ELM: 09:16 PM)`);
  console.log(`   Isha     ${fmt(t.isha)}      (ELM: 10:34 PM)`);
}

console.log('=== London, June 6 — matching East London Mosque ===');
run('Default MWL-style', 18, 17);
run('Article claim: ELM', 15, 15);
