# Duhaa — Learn sourcing & madhhab framework

_Last updated: 2026-06-15. Covers the data/metadata framework added to the Learn
section. This is **framework prep** — it organizes content and prepares fields;
it does **not** complete scholarly verification._

## Tone & direction
Duhaa is **Sunni, source-backed, and Salafi-friendly in sourcing** (Qur'an +
sahih/hasan, weak narrations omitted), but **non-argumentative and non-sectarian
in presentation**. It should feel calm, trustworthy, and beginner-friendly — never
like it is attacking other Muslims or forcing a label on the user.

## Evidence hierarchy (how sources are ranked)
1. **Primary evidence first**
   - Qur'an
   - Sahih al-Bukhari
   - Sahih Muslim
   - Sunan collections (Abu Dawud, Tirmidhi, Nasa'i, Ibn Majah) — with grade + grader when used
2. **Scholar-check layer** (the people who confirm references/grades before any
   "reviewed" claim): **Ibn Baz, Ibn Uthaymin, al-Fawzan, the Permanent Committee.**

The data model has optional `scholarSource` / `scholarSources` fields for this
layer. They are **empty today** — no scholar has signed off yet.

## Review status (`reviewStatus`)
| Value | Meaning |
|---|---|
| `source_backed` | Default. A source is cited, but not yet manually confirmed. |
| `reviewed` | A qualified reviewer has confirmed the reference/grade/wording. **Not used yet.** |
| `needs_review` | Reference, grade, grader, or wording is uncertain. |

There is **deliberately no `verified` value.** Nothing is marked `reviewed` until
`docs/scholar-review.md` is signed off by an imam. All 9 guides currently carry
`reviewStatus: source_backed` and `scholarReviewStatus: needs_review`.

## Source chips (`sourceSummary`)
Each step has a short chip for the future UI (full evidence stays expandable):
- `Quran 5:6`
- `Bukhari 159 · Sahih` / `Muslim 234a · Sahih` (the two Sahihayn are inherently sahih)
- `Abu Dawud 101 · Source-backed` (Sunan grades are a grader's judgment → conservative label)
- `Needs review` (used when the reference is unclear — never invent a chip)

## Madhhab sensitivity (`madhhabSensitivity`)
| Value | Meaning |
|---|---|
| `shared_basic` | Broadly-agreed, beginner-safe. No note needed. |
| `madhhab_sensitive` | Schools differ on a detail → show a gentle note. |
| `scholar_difference` | A known scholarly difference → show a gentle note. |
| `needs_review` | Sensitivity not yet assessed. |

Anything other than `shared_basic` warrants a calm **"scholars differ" note**
instead of asserting one ruling. Flagged steps carry a user-facing `madhhabNote`
plus an internal `scholarNotes` pointer (names the topic of difference, never the
ruling). Flagged areas in the current content:
- Bismillah before wudu (obligatory vs. recommended)
- how much of the head is wiped in wudu
- valid tayammum surfaces, and how far the arms are wiped
- raising the hands / hand placement in salah
- finger movement in tashahhud
- sujud al-sahw before or after the taslim
- handling long-term missed prayers (qada)

## "Not sure" madhhab → shared-basics mode
The user can pick a school (`MadhhabPreference`): `not_sure`, `hanafi`, `maliki`,
`shafii`, `hanbali`, or `local_imam_or_teacher`.

- **`not_sure` never silently picks a madhhab.** It means **shared-basics mode**:
  teach the broadly-agreed beginner-safe basics, and where a detail is
  madhhab-sensitive, show a gentle note rather than forcing one opinion.
- `local_imam_or_teacher` also defers (shared basics + follow your teacher).
- The four named schools resolve to themselves, but **no madhhab-specific rulings
  are implemented yet** — that is future work and must not be invented.

Shared-basics copy:
> "Duhaa teaches the shared beginner-safe basics first. Some details differ
> between scholars and madhhabs. For specifics, follow a trusted scholar, local
> imam, or the madhhab you study with."

Madhhab-sensitive note copy:
> "Scholars differ on some details here. Duhaa shows a beginner-safe summary.
> Follow the position you were taught by a trusted scholar or your madhhab."

## Navigation grouping & order
Guides are grouped into beginner-first sections (each guide appears in exactly one
group — no duplicate cards): **Start Here → Purification → Prayer Help → Foundations.**

Unique guide order (`displayOrder`):
1. Coming Back to Prayer After Time Away — *Start Here*
2. How to Make Wudu — *Start Here*
3. How to Pray — Core Structure — *Start Here*
4. Dhikr After Prayer — *Prayer Help*
5. Tawbah — Coming Back to Allah — *Foundations*
6. How to Make Ghusl — *Purification*
7. How to Make Tayammum — *Purification*
8. Mistakes in Prayer & Sujud al-Sahw — *Prayer Help*
9. Differences per Prayer — *Prayer Help*

Manual review priority order (`priorityOrder`): Wudu (1), Ghusl (2), Tayammum (3),
Dhikr After Prayer (4), Coming Back to Prayer (5).

## What still needs a human
- A qualified scholar must confirm every reference/grade/grader before anything
  moves from `source_backed` → `reviewed` (see `docs/scholar-review.md`).
- The madhhab-sensitive notes name *that* a difference exists; the actual
  positions/rulings still need scholar input before any school-specific display.
- `subtitle` is available on guides but intentionally left empty (not invented).
