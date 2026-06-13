# Duhaa — Scholar Review Document

**For review by a qualified scholar or student of knowledge.**

Duhaa (ضحى) is an iOS prayer app built on *hope, not guilt* — made to gently bring
people who don't pray, or barely pray, back to the five daily prayers. Before
publishing, the developer wants every religious statement in the app checked.
This document contains all of them.

**How to review:** tick a box if the item is acceptable as written; otherwise
leave it unticked and write the correction beside it. Where madhhab differences
matter, please note whether the wording is fair to the major schools — the app
does not declare a single madhhab (the user only picks Standard/Hanafi for Asr
timing). Honest notes are welcome, including "remove this entirely."

---

## Part 1 — Fiqh rules baked into the app's behavior

These are not display text; they are how the app behaves.

- [ ] **1.1 Prayer times** are computed with standard astronomical methods
  (Muslim World League default; user-selectable ISNA, Egypt, Umm al-Qura,
  Karachi, etc.) via the widely-used open-source Adhan library. Asr offers
  Standard (Shafi'i/Maliki/Hanbali) and Hanafi shadow rules.
- [ ] **1.2 "On time" (opt-in statistics):** a prayer marked before the next
  prayer begins counts as on time, with two firm boundaries — **Fajr only until
  sunrise**, and **Isha only until Islamic midnight** (midpoint of
  Maghrib→Fajr). Later marks count as "late," shown gently. Is this defensible
  as a tracking convention?
- [ ] **1.3 Isha note:** the app displays "Isha ends at Islamic midnight" on the
  prayer row, consistent with the on-time boundary above. At extreme latitudes
  where Isha begins after Islamic midnight, the boundary falls back to Fajr so
  the prayer is never "late" the moment it begins.
- [ ] **1.4 After civil midnight, before Fajr:** marking Isha records it for the
  *previous* day (tonight's Isha hasn't begun yet); past Islamic midnight it
  counts as prayed-late, never as missed.
- [ ] **1.5 Menstruation:** days logged as menses are excused — they never break
  a prayer streak and are never counted as missed in statistics.
- [ ] **1.6 Sunrise** appears as a note inside the Fajr row ("ends at sunrise
  5:47 AM · Duhaa follows"), explicitly not a sixth tracked prayer.
- [ ] **1.7 Tasbih default:** SubhanAllah ×33, Alhamdulillah ×33, Allahu Akbar
  ×34 (= 100).
- [ ] **1.8 High latitudes (UK / N. Europe):** computed Fajr/Isha are unreliable
  there. The app warns the user and offers manual adjustment to match the local
  mosque (the caution wording is in Part 3). Is this stopgap acceptable?

---

## Part 2 — Sisters' section Q&A (highest stakes) — ⏸ PARKED, NOT IN CURRENT BUILD

> **Status (2026-06-11):** the entire Sisters section (cycle tracker + this
> Q&A) has been removed from the shipping app for now and parked in git. It is
> not in the current build. This content still needs review **before** the
> feature is restored — keeping it here so the review isn't lost. Item 1.5
> (menstruation streak-bridging) is likewise dormant until then.

The disclaimer shown alongside this content:

> This is gentle, general guidance drawn from the Qur'an and Sunnah. Schools of fiqh differ on some details — for your own situation, lean on what you've learned in your madhhab or ask a trusted local scholar. Never let uncertainty keep you from turning to Allah.


### Wudu (Ablution)

- [ ] **2.1 Q: How do I make wudu, step by step?**
  - **A:** Begin with the intention in your heart and say Bismillah. Wash your hands three times, then rinse the mouth and nose three times. Wash your face three times, then your arms up to and including the elbows (right then left) three times. Wipe over your head once, including the ears. Finally wash your feet up to and including the ankles (right then left) three times.
  - *Cited source:* Described in the Sunnah (Bukhari & Muslim); cf. Qur'an 5:6

- [ ] **2.2 Q: What breaks my wudu?**
  - **A:** Wudu is nullified by relieving yourself (urine, stool, or passing wind), by deep sleep, and by loss of consciousness. The madhhabs differ on some matters (for example flowing blood, or touching the private part), so follow what you've learned in your school.
  - *Cited source:* Qur'an 5:6; Sunnah

- [ ] **2.3 Q: Do I need fresh wudu for every prayer?**
  - **A:** No. One wudu remains valid until something nullifies it, and you may pray as many prayers as you wish with it. Renewing wudu for each prayer is encouraged when easy, but it is not required.
  - *Cited source:* Sunnah (Bukhari)

- [ ] **2.4 Q: I'm not sure my wudu is still valid — what do I do?**
  - **A:** Certainty is not removed by doubt. If you made wudu and only doubt whether it broke, treat it as still valid. Don't let waswasa (whispering doubts) burden you — Allah does not want hardship for you.
  - *Cited source:* Principle of fiqh; Qur'an 2:185


### Salah (Prayer)

- [ ] **2.5 Q: I missed a prayer. What should I do?**
  - **A:** Pray it as soon as you remember (this is called qada), then keep moving forward. Don't despair and don't drown in guilt — returning is beloved to Allah. The Prophet ﷺ said: "Whoever forgets a prayer, let him pray it when he remembers it."
  - *Cited source:* Bukhari & Muslim

- [ ] **2.6 Q: Can I pray sitting down if I'm unwell or in pain?**
  - **A:** Yes. Pray standing if you can; if not, sitting; and if not, lying down. Allah does not burden a soul beyond what it can bear, and your prayer is fully accepted.
  - *Cited source:* Bukhari; Qur'an 2:286

- [ ] **2.7 Q: What should I wear to pray?**
  - **A:** Clean clothing that covers the awrah, in a clean place, facing the qibla. For women this is generally everything except the face and hands, worn loosely enough not to define the body. Sincerity and modesty matter more than perfection.
  - *Cited source:* Qur'an 7:31; Sunnah

- [ ] **2.8 Q: I worry I'm not praying correctly. How do I learn?**
  - **A:** Learn gently and gradually — the Prophet ﷺ said: "Pray as you have seen me praying." Perfectionism is not a condition for prayer. Begin, keep going, and your prayer will grow more beautiful with time.
  - *Cited source:* Bukhari


### Menstruation & Prayer

- [ ] **2.9 Q: Do I pray during my period?**
  - **A:** No — and this is a mercy, not a shortcoming. During menstruation the five daily prayers are lifted from you entirely. You are not sinning by not praying; you are doing exactly what Allah asks. Rest, make dhikr and du'a, and let your heart stay connected.
  - *Cited source:* Aisha (RA), Bukhari & Muslim

- [ ] **2.10 Q: Do I make up the missed prayers afterward?**
  - **A:** No. Prayers missed during menstruation are not made up — this is agreed upon. (Fasts missed in Ramadan, however, are made up later.) Aisha (RA) said they were commanded to make up the fasts and not the prayers.
  - *Cited source:* Aisha (RA), Bukhari & Muslim

- [ ] **2.11 Q: When do I start praying again?**
  - **A:** When the bleeding has clearly stopped, perform ghusl (a full purifying bath), and then resume your prayers with the next prayer time. Duha will gently welcome you back.
  - *Cited source:* Sunnah

- [ ] **2.12 Q: Can I read or touch the Qur'an during my period?**
  - **A:** Scholars differ. Many allow reciting from memory, making dhikr, and reading from a phone or behind a barrier; some restrict touching the Arabic mushaf directly. Follow your madhhab, and know that du'a and dhikr remain open to you at all times.
  - *Cited source:* Difference of opinion among the schools

- [ ] **2.13 Q: My bleeding is irregular — how do I know what counts?**
  - **A:** Irregular or prolonged bleeding (istihada) has its own gentle rulings that differ from menstruation, and a woman in that state still prays. Because it depends on your specific pattern, it's best to ask a knowledgeable, trustworthy scholar so you can have peace of mind.
  - *Cited source:* Sunnah; consult a scholar


---

## Part 3 — Notification & in-app copy making religious claims

Most notification texts are general encouragement; listed here are the ones
that assert something religious.

- [ ] **3.1** "Whoever prays Fajr is under Allah's protection all day."
  *(paraphrase of the hadith in Sahih Muslim — man salla as-subh fa-huwa fi
  dhimmatillah)*
- [ ] **3.2** "Dawn has come. The hardest one, and the most beloved." *(allusion
  to the hadith that Fajr & Isha are the heaviest upon the hypocrites — is
  "most beloved" acceptable phrasing?)*
- [ ] **3.3** "Guard the middle prayer. Time for Asr." *(Qur'an 2:238, applying
  al-wusta to Asr — majority view)*
- [ ] **3.4** "The best day the sun rises upon is Friday." *(hadith, Sahih
  Muslim)*
- [ ] **3.5** Friday-morning nudge: ghusl, nice clothes, scent, Surah Al-Kahf,
  abundant salawat, du'a in the final hour. *(established Friday sunnahs)*
- [ ] **3.6** "Your Lord has not forsaken you, nor does He despise you." —
  Ad-Duhaa 93:3 *(the app's namesake; used as encouragement after marking a
  prayer)*
- [ ] **3.7** Short after-prayer lines paraphrasing the Qur'an: "Allah is with
  those who are patient" (2:153), "With hardship comes ease" (94:6), "He is
  nearer than the jugular vein" (50:16). *(used as single-line encouragements
  without surah citations — acceptable?)*
- [ ] **3.8** High-latitude caution wording shown in Settings: dawn/Isha are
  approximate at this latitude; finish suhoor a little early; give Isha a few
  minutes; re-check offsets each season; "Pray each one on time — that's the
  heart of it."
- [ ] **3.9** Isha sub-line at extreme latitudes reads "approximate at this
  latitude" instead of an authoritative end time.

---

## Part 4 — Bundled sources (for completeness)

- [ ] **4.1 Qur'an Arabic text:** Uthmani script, sourced from the Quran.com API,
  rendered in the KFGQPC HAFS Uthmanic font (King Fahd Complex, Madinah).
- [ ] **4.2 English translation:** ClearQuran by Talal Itani, the "Allah"
  edition (the translator publishes two official editions; this one renders
  the divine name as Allah). Licensed CC BY-NC-ND — free for this free app
  with attribution, no permission required.
- [ ] **4.3 Recitation:** nine reciters (Alafasy default; AbdulBaset, Sudais,
  Shatri, Rifai, Minshawi, Shuraym) streamed from the Quran Foundation's CDN
  under registered API access — sources verified per-file at build time.
- [ ] **4.4 Du'as:** the app currently ships ONLY the two hand-curated
  categories in 4.6. The bulk Hisnul Muslim set (Morning / Evening / Daily /
  Selected) was removed pending curation and will return category by category
  after review.
- [ ] **4.5 Verse of the Day:** ~25 curated short hopeful verses (e.g. 93:3-5,
  94:5-6, 2:152, 39:53) shown one per day with translation.
- [ ] **4.6 Curated adhkar categories — please verify each citation.**
  *Wudu & Purification* (4 cards): Sahih al-Bukhari 142 and companions.
  *After Prayer Adhkar* (8 cards, in app order):
  1. Istighfar ×3 & Allāhumma antas-Salām — Sahih Muslim 591
  2. Tawhid & Allāhumma lā māniʿa — Sahih al-Bukhari 844
  3. Lā ḥawla… / lā ilāha illallāh… mukhliṣīna — Sahih Muslim 594a
  4. 10× tawhid after Fajr & Maghrib — Jami' at-Tirmidhi 3474 (Fajr) and 3534
     (Maghrib)
  5. Tasbih/Tahmid/Takbir 33/33/33 + completion — Sahih Muslim 597a (plus six
     alternate Sunnah count variations shown collapsed)
  6. Ayat al-Kursi after every prayer — an-Nasa'i, al-Sunan al-Kubrā 9848
  7. The three Quls after every prayer (3× after Fajr/Maghrib per Ibn Baz /
     Permanent Committee guidance) — Sunan Abi Dawud 1523
  8. Optional: Rabbi qinī ʿadhābak / Allāhummaghfir lī mā qaddamtu / Allāhumma
     aʿinnī ʿalā dhikrik — Sahih Muslim 709; Sahih Muslim 771; Sunan Abi
     Dawud 1522

---

## Reviewer

Name: ______________________  Qualification: ______________________

Date: ______________  Signature: ______________________

General notes:

&nbsp;

&nbsp;

