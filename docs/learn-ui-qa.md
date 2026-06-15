# Duhaa — Learn UI manual QA checklist

_Last updated: 2026-06-15. Run after changes to the Learn views. The redesign keeps
the data/framework from `docs/learn-sourcing-and-madhhab.md`; this covers the UI._

## Navigation & home
- [ ] Open **More → Learn** (Learn lives in More, not the main tab bar).
- [ ] Learn home is grouped: **Start Here → Purification → Prayer Help → Foundations**.
- [ ] Home feels light and scannable — no Arabic, no evidence, no long paragraphs on cards.
- [ ] Each guide card shows: soft group icon, title, one-line summary, a wrapping chip
      row (category · **Source-backed** · optional **Scholars differ**), and "N steps · ~M min".
- [ ] No guide appears in more than one group (no duplicate cards).
- [ ] Search filters guides by title and keeps the grouping.

## Guide detail
- [ ] Open **Coming Back to Prayer** — clean header (group, title, summary, chips,
      "Sources provided · pending scholar review.").
- [ ] Open **How to Make Wudu**.
- [ ] Each step shows "Step X of 8", title, then the instruction.

## Arabic / meaning
- [ ] Step 1 (Bismillah): Arabic is **visible by default**, large, RTL, with breathing room.
- [ ] Tap **Meaning & pronunciation** → transliteration + translation expand smoothly.
- [ ] Tap again → they collapse.
- [ ] Step 2 (Wash both hands) has **no Arabic** and **no meaning button** — just a source chip.

## Sources / evidence
- [ ] Each step shows a compact source chip (e.g. **Quran 5:6**, **Bukhari 159 · Sahih**).
- [ ] Tap the source chip → evidence expands: reference, grade badge, grading line,
      and the supporting note. Multiple references all show.
- [ ] No step shows the word **Verified** anywhere.

## Madhhab note
- [ ] On a flagged step (Wudu step 1, or step 6 "Wipe the head") a gold **Scholars differ**
      chip is present.
- [ ] Tap it → expands the gentle note + the specific "pending scholar review" pointer +
      the shared-basics reminder.
- [ ] The word **Salafi** never appears; no single school is asserted as "the" ruling.

## Accessibility & robustness
- [ ] Settings → larger Dynamic Type: text scales, Arabic stays readable, chips **wrap**
      instead of clipping.
- [ ] Reduce Motion on: expand/collapse still works, without the slide animation.
- [ ] VoiceOver: cards read as "title, summary, N steps, ~M min, Source-backed";
      chips announce expanded/collapsed.
- [ ] Small iPhone (e.g. iPhone SE/13 mini) — cards and chip rows still lay out cleanly.

## Content integrity
- [ ] No Arabic, transliteration, translation, evidence, grade, grader, source summary,
      or madhhab note was deleted.
- [ ] Nothing is labeled "Verified"; status reads **Source-backed** / **Needs review**.
