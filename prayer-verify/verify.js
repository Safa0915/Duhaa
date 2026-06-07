// Duha — prayer time verification harness
// Computes times with the `adhan` library so you can diff against a trusted
// source (IslamicFinder / Aladhan / your local mosque).
//
// THE #1 RULE: match calculation method + madhab + high-latitude rule EXACTLY
// on BOTH sides before comparing. A mismatch there is NOT a bug.

const adhan = require('adhan');

// ---- Parameters (must match whatever reference you compare against) ----
const METHOD_NAME = 'MuslimWorldLeague';      // change to match your reference
const MADHAB = adhan.Madhab.Shafi;            // Shafi (standard) or Hanafi
const HIGH_LAT = adhan.HighLatitudeRule.MiddleOfTheNight;

// ---- Cities: [name, lat, lng, IANA timezone] ----
const CITIES = [
  ['Mecca',    21.4225,  39.8262, 'Asia/Riyadh'],
  ['London',   51.5074,  -0.1278, 'Europe/London'],   // high-latitude check
  ['New York', 40.7128, -74.0060, 'America/New_York'],
  ['Jakarta',  -6.2088, 106.8456, 'Asia/Jakarta'],
  ['Karachi',  24.8607,  67.0011, 'Asia/Karachi'],
];

const DATE = new Date(); // today

function fmt(date, tz) {
  if (!date || isNaN(date)) return '—';
  return date.toLocaleTimeString('en-US', {
    timeZone: tz, hour: '2-digit', minute: '2-digit', hour12: true,
  });
}

console.log(`\n=== Duha prayer-time verification ===`);
console.log(`Date:   ${DATE.toDateString()}`);
console.log(`Method: ${METHOD_NAME}   Madhab: ${MADHAB === adhan.Madhab.Hanafi ? 'Hanafi' : 'Shafi/Standard'}`);
console.log(`HighLat: MiddleOfTheNight`);
console.log(`(Match these exact params on your reference source before diffing.)\n`);

for (const [name, lat, lng, tz] of CITIES) {
  const coords = new adhan.Coordinates(lat, lng);
  const params = adhan.CalculationMethod[METHOD_NAME]();
  params.madhab = MADHAB;
  params.highLatitudeRule = HIGH_LAT;

  const t = new adhan.PrayerTimes(coords, DATE, params);

  // Sunnah times use the library's own night calc (Maghrib -> next Fajr):
  //   middleOfTheNight = Islamic midnight (= Isha end time in Duha)
  //   lastThirdOfTheNight = Tahajjud window start
  const s = new adhan.SunnahTimes(t);

  console.log(`── ${name} (${lat}, ${lng}) ${tz}`);
  console.log(`   Fajr     ${fmt(t.fajr, tz)}`);
  console.log(`   Sunrise  ${fmt(t.sunrise, tz)}`);
  console.log(`   Dhuhr    ${fmt(t.dhuhr, tz)}`);
  console.log(`   Asr      ${fmt(t.asr, tz)}`);
  console.log(`   Maghrib  ${fmt(t.maghrib, tz)}`);
  console.log(`   Isha     ${fmt(t.isha, tz)}`);
  console.log(`   · Islamic midnight (Isha ends) ${fmt(s.middleOfTheNight, tz)}`);
  console.log(`   · Tahajjud (last third begins)  ${fmt(s.lastThirdOfTheNight, tz)}`);
  console.log('');
}

console.log(`Tip: flip MADHAB to adhan.Madhab.Hanafi and watch Asr shift later.`);
console.log(`Tip: change METHOD_NAME (e.g. 'NorthAmerica', 'Karachi', 'Egyptian') to match your local mosque.\n`);
