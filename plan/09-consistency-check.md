# Consistency check

**Run:** 2026-11-07, step 4 of [the brief](../docs/agent-prompt.md), by the main agent after the six specialist documents were written. Rerun it after any large change.

## Result

- **327 tasks** across documents 02 to 07. All are `todo`.
- **No duplicate task IDs** and **no dependency loops**. Every task-level dependency points to a task that exists.
- **All 138 approved requirements** are covered by at least one task.
- The **25 proposed requirements** are listed in [01](01-requirements-checklist.md#proposed-awaiting-approval). Most have no task yet, because they must not be built until Sami approves them (Q-08).
- Every specialist document uses the required headings from [00 §2](00-MASTER-PLAN.md#required-sections-in-specialist-documents).
- No task depends on a task in a later phase.

## Contradictions and gaps fixed

| # | Found | Fixed in | Fix |
| --- | --- | --- | --- |
| 1 | 07 required public approvers to meet REQ-MOD-003 and REQ-MOD-007 together. This was stricter than Sami's answer, and 04 and 05 read it differently. | 07 | Going public is approved by the class teacher or principal. Widening scope is done by an admin or a chosen teacher (D-029). |
| 2 | 07 let teachers hide only posts in their own classes. REQ-MOD-002 and 05 said any class or madrasa post. | 07, 05 | Any class or madrasa post (D-031). |
| 3 | The transfer notice form (02, 05, 06) and pledges (06) had no tables in 04. | 04, 06 | Added `transfer_notices` and `recurring_pledges` (04 §8.7, §8.8), `donations.pledge_id`, and tasks P1-E3-T46 and T47 (D-030). |
| 4 | 05 stored about, facilities and daily life text in `institute_settings`. 04 had made a `site_pages` table. | 05 | Uses `site_pages`. |
| 5 | Receipt numbers had 6 digits in 04 and 5 digits in 06, which owns receipts. | 04 | 5 digits, for example `MAA-2026-00042`. |
| 6 | Four documents gave the same proposed IDs different meanings (for example, REQ-DON-015 meant three different things). | 02, 03, 04, 06 | Renumbered to unique IDs, listed once in 01. |
| 7 | Fourteen dependencies were written as descriptions, such as "04 RLS policy task". | 03, 06 | Replaced with real task IDs. |
| 8 | Dependencies on whole epics made loops between P0-E1, P0-E2, P0-E3 and P0-E4, and between the donate page and the notice form. | 02, 03, 04, 05, 06 | Narrowed to the specific tasks needed. |
| 9 | The glossary had no reversal event, transfer notice, pledge or principal. | 00 | Added to 00 §8. |
| 10 | About 77 decisions made inside the specialist documents were not in the decision log. | 08 | Numbered D-032 to D-107 as proposed, awaiting Sami (Q-09). |
| 11 | Open questions were raised inside 07, 06, 03 and 02. | 00 | Moved to 00 §6 as Q-08 to Q-21. |

## Left for Sami and Moazam

These need a person's decision, not a document fix. All are in [00 §6](00-MASTER-PLAN.md#open-questions).

- Whether the admin and finance officer may see who gave an anonymous donation (Q-10).
- A private way for students to raise a worry, with no private messages (Q-11).
- Whether student media waits for a teacher's check (Q-12).
- Who approves verified articles going public (Q-17).
- One sponsor per orphan or several (Q-18).
- The likely $5-a-month Cloudflare upgrade (Q-21).

## Requirement coverage

| Requirement | Priority | Explained in | Tasks |
| --- | --- | --- | --- |
| REQ-DON-001 | MUST | 06 §4 | P1-E1-T08, P1-E1-T21, P1-E3-T01, P1-E3-T07, P1-E3-T41 |
| REQ-DON-002 | MUST | 06 §7 | P1-E1-T08, P1-E1-T21, P1-E3-T01, P1-E3-T07, P1-E3-T41, P2-E4-T01 and 2 more |
| REQ-DON-003 | MUST | 06 §13 | P1-E3-T07, P1-E3-T10, P1-E3-T11, P1-E3-T47, P4-E5-T61, P5-E2-T02 |
| REQ-DON-004 | MUST | 06 §6 | P1-E1-T08, P1-E3-T01, P1-E3-T07, P1-E3-T41, P2-E3-T01, P2-E3-T04 and 1 more |
| REQ-DON-005 | MUST | 06 §5 | P1-E1-T05, P1-E2-T01, P1-E2-T40, P1-E2-T50 |
| REQ-DON-006 | MUST | 06 §5 | P1-E1-T06, P1-E2-T04, P1-E2-T40, P1-E2-T50, P1-E3-T41 |
| REQ-DON-007 | MUST | 06 §5 | P1-E1-T06, P1-E2-T01, P1-E2-T40, P1-E2-T50 |
| REQ-DON-008 | MUST | 06 §4 | P1-E3-T01, P1-E3-T02, P1-E3-T08, P1-E3-T12, P1-E3-T41, P1-E3-T43 |
| REQ-DON-009 | MUST | 05 §8 | P1-E1-T15, P1-E2-T02, P1-E2-T40, P1-E2-T50 |
| REQ-DON-010 | MUST | 06 §14 | P1-E3-T03, P1-E3-T41, P1-E4-T03, P2-E7-T02 |
| REQ-DON-011 | SHOULD | 06 §14 | P2-E7-T01, P2-E7-T02, P2-E7-T03, P2-E7-T05, P2-E7-T60 |
| REQ-DON-012 | MUST | 06 §15 | P1-E3-T09, P1-E3-T12, P1-E3-T45, P2-E2-T03, P5-E5-T02 |
| REQ-DON-013 | SHOULD | 05 §10 | P1-E2-T02, P1-E2-T40, P4-E4-T01, P4-E4-T02, P4-E4-T04, P4-E4-T05 and 1 more |
| REQ-DON-014 | MUST | 06 §5 | P1-E1-T04, P1-E2-T01, P1-E2-T06, P1-E2-T40 |
| REQ-TRL-001 | MUST | 06 §8 | P1-E3-T01, P1-E3-T42, P1-E3-T43, P1-E4-T01, P1-E4-T02, P2-E2-T01 and 1 more |
| REQ-TRL-002 | MUST | 04 §9 | P0-E2-T03, P0-E2-T16, P1-E3-T01, P1-E3-T42 |
| REQ-TRL-003 | MUST | 04 §9 | P1-E3-T09, P1-E3-T42, P1-E3-T45, P2-E1-T04, P2-E2-T03, P2-E2-T41 and 3 more |
| REQ-TRL-004 | MUST | 06 §8 | P2-E1-T03, P2-E2-T01, P2-E2-T02, P2-E2-T04, P2-E2-T40 |
| REQ-TRL-005 | MUST | 06 §8 | P2-E2-T01, P2-E2-T04, P2-E2-T40, P2-E4-T02 |
| REQ-TRL-006 | MUST | 06 §6 | P2-E2-T04, P2-E3-T01, P2-E3-T02, P2-E3-T03, P2-E3-T20, P2-E3-T40 |
| REQ-TRL-007 | MUST | 06 §8 | P1-E4-T01, P1-E4-T20, P1-E4-T40, P2-E2-T04, P2-E2-T05, P2-E2-T40 |
| REQ-TRL-008 | MUST | 06 §10 | P1-E4-T05, P1-E4-T20, P2-E5-T05 |
| REQ-TRL-009 | MUST | 06 §10 | P1-E4-T20, P2-E5-T05, P2-E6-T40 |
| REQ-TRL-010 | MUST | 05 §5 | P1-E1-T40, P1-E2-T05, P2-E6-T02, P2-E6-T40, P2-E6-T50, P2-E6-T51 |
| REQ-TRL-011 | MUST | 06 §9 | P2-E1-T01, P2-E1-T02, P2-E1-T03, P2-E1-T30, P2-E1-T40, P2-E1-T50 |
| REQ-TRL-012 | SHOULD | 06 §9 | P2-E1-T40, P2-E1-T50, P2-E2-T41, P2-E6-T01, P2-E6-T03, P2-E6-T50 |
| REQ-TRL-013 | MUST | 06 §9 | P1-E5-T10, P2-E1-T05, P2-E1-T50, P2-E2-T42 |
| REQ-TRL-014 | MUST | 04 §9 | P1-E3-T42 |
| REQ-DPR-001 | MUST | 06 §11 | P1-E1-T09, P1-E1-T21, P1-E3-T04, P1-E3-T07, P1-E3-T40, P1-E3-T46 |
| REQ-DPR-002 | MUST | 06 §11 | P1-E3-T04, P1-E3-T05, P1-E3-T30, P1-E3-T44, P1-E4-T01, P1-E4-T04 and 1 more |
| REQ-DPR-003 | SHOULD | 06 §11 | P2-E5-T01, P2-E5-T40 |
| REQ-DPR-004 | MUST | 03 §6 | P0-E5-T01, P0-E5-T02, P1-E1-T11, P1-E1-T12, P2-E5-T01, P2-E5-T40 |
| REQ-DPR-005 | SHOULD | 06 §10 | P2-E5-T02, P2-E5-T40, P2-E5-T51 |
| REQ-DPR-006 | MUST | 06 §10 | P1-E1-T09, P1-E1-T21, P1-E3-T06, P1-E3-T07, P2-E5-T03, P2-E5-T41 |
| REQ-DPR-007 | MUST | 06 §10 | P2-E5-T04, P2-E5-T20, P2-E5-T41, P2-E5-T50 |
| REQ-DPR-008 | MUST | 06 §10 | P2-E5-T03, P2-E5-T04, P2-E5-T20, P2-E5-T41, P2-E5-T50 |
| REQ-DPR-009 | MUST | 06 §10 | P1-E3-T06, P1-E3-T40, P1-E5-T07, P1-E5-T09, P2-E5-T04, P2-E5-T05 and 6 more |
| REQ-DPR-010 | MUST | 06 §10 | P1-E4-T03, P1-E4-T40, P2-E5-T01, P2-E5-T06, P2-E5-T20 |
| REQ-ORP-001 | MUST | 06 §12 | P4-E1-T01, P4-E1-T40 |
| REQ-ORP-002 | MUST | 06 §12 | P4-E1-T02, P4-E1-T20, P4-E1-T40, P4-E3-T50 |
| REQ-ORP-003 | MUST | 06 §12 | P4-E1-T20, P4-E2-T01, P4-E2-T02, P4-E2-T40, P4-E3-T50 |
| REQ-ORP-004 | MUST | 06 §12 | P3-E2-T02, P4-E2-T01, P4-E2-T40 |
| REQ-ORP-005 | MUST | 06 §12 | P4-E1-T02, P4-E2-T02, P4-E2-T40, P4-E3-T50 |
| REQ-ORP-006 | MUST | 06 §12 | P4-E1-T04, P4-E1-T20, P4-E2-T03, P4-E2-T40, P4-E3-T50 |
| REQ-ORP-007 | MUST | 06 §12 | P4-E1-T20, P4-E3-T01, P4-E3-T02, P4-E3-T40, P4-E3-T50 |
| REQ-ORP-008 | SHOULD | 06 §12 | P4-E1-T03, P4-E1-T40 |
| REQ-ORP-009 | MUST | 06 §12 | P2-E2-T05, P4-E1-T01, P4-E1-T40 |
| REQ-STU-001 | MUST | 07 §4 | P0-E5-T03, P1-E1-T11, P3-E1-T01, P3-E1-T41, P3-E8-T06 |
| REQ-STU-002 | MUST | 07 §4 | P3-E1-T03, P3-E1-T04, P3-E1-T09, P3-E1-T41, P3-E7-T03, P3-E7-T70 |
| REQ-STU-003 | MUST | 07 §4 | P3-E1-T02, P3-E1-T05, P3-E1-T41, P3-E7-T03 |
| REQ-STU-004 | SHOULD | 07 §5 | P3-E1-T13, P3-E2-T03, P3-E2-T04, P3-E2-T40, P3-E8-T02 |
| REQ-STU-005 | MUST | 07 §6 | P3-E3-T01, P3-E3-T04, P3-E3-T05, P3-E3-T08, P3-E3-T09, P3-E3-T10 and 2 more |
| REQ-STU-006 | MUST | 07 §6 | P3-E3-T02, P3-E3-T20, P3-E3-T40 |
| REQ-STU-007 | MUST | 07 §6 | P3-E3-T06, P3-E3-T07, P3-E3-T21, P3-E3-T41 |
| REQ-STU-008 | MUST | 07 §7 | P3-E3-T01, P3-E3-T40, P3-E5-T01, P3-E7-T05 |
| REQ-STU-009 | MUST | 07 §4 | P3-E1-T10, P3-E1-T41 |
| REQ-STU-010 | MUST | 02 §13 | P3-E1-T04, P3-E7-T01, P3-E7-T02, P3-E7-T03, P3-E7-T05, P3-E7-T06 and 2 more |
| REQ-STU-011 | MUST | 07 §8 | P3-E3-T20, P3-E5-T04, P3-E5-T41, P3-E7-T05 |
| REQ-TCH-001 | MUST | 07 §10 | P3-E1-T12, P3-E6-T02, P3-E8-T04 |
| REQ-TCH-002 | MUST | 07 §9 | P3-E6-T04, P3-E6-T06, P3-E6-T20, P3-E6-T40 |
| REQ-TCH-003 | MUST | 07 §9 | P3-E6-T05, P3-E6-T20, P3-E6-T40, P3-E8-T04, P3-E8-T71 |
| REQ-TCH-004 | MUST | 07 §10 | P3-E5-T40, P3-E5-T50, P3-E6-T03, P3-E6-T06 |
| REQ-TCH-005 | MUST | 07 §4 | P3-E1-T06, P3-E1-T07, P3-E1-T40, P3-E7-T06 |
| REQ-TCH-006 | MUST | 07 §4 | P3-E1-T08, P3-E1-T41, P3-E7-T06 |
| REQ-PUB-001 | MUST | 05 §4 | P0-E2-T10, P1-E1-T02, P1-E1-T03, P1-E1-T04, P1-E1-T05, P4-E4-T02 |
| REQ-PUB-002 | MUST | 05 §5 | P0-E4-T11, P1-E1-T07, P1-E1-T20, P1-E1-T40, P1-E2-T05 |
| REQ-PUB-003 | MUST | 05 §5 | P1-E1-T06, P1-E1-T15, P1-E1-T20, P1-E1-T40, P1-E2-T05, P2-E6-T02 and 2 more |
| REQ-PUB-004 | MUST | 05 §5 | P3-E8-T01, P3-E8-T02, P3-E8-T07, P3-E8-T40, P3-E8-T70 |
| REQ-PUB-005 | MUST | 05 §5 | P3-E8-T03, P3-E8-T04, P3-E8-T07, P3-E8-T40, P3-E8-T71 |
| REQ-PUB-006 | MUST | 05 §5 | P0-E2-T07, P0-E2-T15, P1-E1-T10, P1-E5-T03 |
| REQ-PUB-007 | MUST | 05 §5 | P0-E2-T07, P0-E2-T09, P0-E2-T15, P0-E3-T09, P0-E4-T09, P1-E1-T01 and 1 more |
| REQ-PUB-008 | MUST | 05 §5 | P0-E2-T07, P1-E1-T08, P1-E1-T21, P1-E5-T03 |
| REQ-ROL-001 | MUST | 05 §6 | P0-E2-T08, P0-E5-T04, P0-E5-T50, P0-E5-T52, P1-E5-T06 |
| REQ-ROL-002 | MUST | 05 §7 | P0-E5-T04, P0-E5-T50, P0-E5-T51, P1-E5-T01 |
| REQ-ROL-003 | MUST | 05 §6 | P0-E2-T08, P0-E5-T52, P1-E1-T11, P1-E5-T06, P3-E1-T01, P3-E2-T01 |
| REQ-ROL-004 | MUST | 05 §8 | P0-E5-T08, P1-E5-T06 |
| REQ-ROL-005 | MUST | 06 §6 | P1-E1-T06, P1-E2-T03, P1-E2-T40, P1-E2-T50, P2-E3-T02, P2-E3-T03 and 2 more |
| REQ-ROL-006 | MUST | 06 §7 | P2-E4-T01, P2-E4-T02, P2-E4-T03, P2-E4-T40 |
| REQ-ROL-007 | MUST | 06 §9 | P1-E5-T10, P2-E1-T01, P2-E1-T02, P2-E1-T40, P2-E1-T50 |
| REQ-ROL-008 | MUST | 05 §9 | P0-E2-T11, P0-E5-T10, P1-E5-T07, P1-E5-T09, P3-E1-T01, P3-E1-T08 and 6 more |
| REQ-ROL-009 | MUST | 05 §9 | P1-E5-T08, P1-E5-T40 |
| REQ-ROL-010 | MUST | 05 §8 | P0-E2-T12, P1-E5-T04, P3-E6-T01, P3-E8-T06, P3-E8-T07, P4-E4-T03 |
| REQ-PAY-001 | MUST | 06 §4 | P1-E1-T09, P1-E3-T02, P1-E3-T08, P1-E3-T12, P1-E3-T31, P1-E3-T41 and 2 more |
| REQ-PAY-002 | MUST | 03 §11 | P5-E1-T01, P5-E1-T02 |
| REQ-PAY-003 | LATER | 06 §16 | P5-E2-T01, P5-E2-T02, P5-E5-T01 |
| REQ-PAY-004 | LATER | 06 §16 | P5-E3-T01, P5-E5-T01 |
| REQ-PAY-005 | LATER | 06 §16 | P5-E4-T01, P5-E4-T30 |
| REQ-PAY-006 | LATER | 06 §15 | P1-E3-T31, P5-E2-T01, P5-E3-T01, P5-E5-T01, P5-E5-T30 |
| REQ-PAY-007 | SHOULD | 06 §13 | P1-E1-T09, P4-E4-T02, P4-E5-T01, P4-E5-T02, P4-E5-T03, P4-E5-T60 and 2 more |
| REQ-PAY-008 | LATER | 06 §14 | P1-E4-T03, P5-E6-T01 |
| REQ-SEC-001 | MUST | 04 §6 | P0-E1-T04, P0-E1-T05, P0-E2-T01, P0-E2-T05, P0-E2-T07, P0-E2-T08 and 5 more |
| REQ-SEC-002 | MUST | 04 §6 | P0-E1-T07, P0-E2-T14, P0-E2-T18, P0-E2-T32 |
| REQ-SEC-003 | SHOULD | 03 §6 | P0-E5-T06, P0-E5-T09, P1-E1-T11, P1-E5-T06 |
| REQ-SEC-004 | MUST | 04 §8 | P1-E3-T04, P1-E3-T32, P1-E3-T44, P1-E4-T04 |
| REQ-SEC-005 | MUST | 03 §12 | P0-E1-T10, P1-E3-T32, P1-E3-T44, P1-E4-T05, P3-E1-T05 |
| REQ-SEC-006 | MUST | 03 §13 | P0-E1-T12, P0-E1-T13, P0-E2-T18 |
| REQ-SEC-007 | MUST | 04 §7 | P0-E5-T51, P3-E1-T02, P3-E1-T05, P3-E1-T08, P3-E1-T41 |
| REQ-SEC-008 | MUST | 03 §13 | P0-E1-T11, P0-E2-T11, P1-E3-T06, P1-E5-T07, P1-E5-T09, P1-E5-T40 and 2 more |
| REQ-CHS-001 | MUST | 07 §12 | P0-E4-T12, P1-E1-T04, P1-E5-T05, P3-E1-T03, P3-E1-T05, P3-E1-T09 and 8 more |
| REQ-CHS-002 | MUST | 07 §12 | P3-E3-T12, P3-E3-T14, P3-E4-T72, P3-E5-T05, P3-E7-T04, P4-E1-T03 and 1 more |
| REQ-CHS-003 | MUST | 07 §12 | P3-E1-T40, P3-E3-T11, P3-E3-T13 |
| REQ-CHS-004 | MUST | 07 §8 | P3-E4-T04, P3-E4-T73, P3-E5-T06, P3-E5-T10, P3-E5-T30, P3-E5-T40 and 2 more |
| REQ-CHS-005 | MUST | 07 §5 | P3-E2-T02, P3-E2-T03, P3-E2-T04, P3-E2-T05, P3-E2-T40, P3-E5-T08 and 4 more |
| REQ-CHS-006 | MUST | 07 §5 | P3-E2-T01, P3-E2-T02, P3-E2-T40 |
| REQ-PRF-001 | SHOULD | 02 §9 | P0-E1-T14, P0-E4-T04, P0-E4-T16, P1-E1-T14 |
| REQ-PRF-002 | MUST | 03 §8 | P0-E4-T14, P1-E1-T14, P2-E1-T02, P2-E1-T31, P3-E4-T02 |
| REQ-PRF-003 | MUST | 03 §8 | P0-E2-T09, P2-E1-T30, P3-E4-T01, P3-E4-T05, P3-E4-T06, P3-E4-T07 and 2 more |
| REQ-PRF-004 | MUST | 07 §11 | P0-E4-T14, P3-E3-T09, P3-E4-T07, P3-E4-T08, P3-E4-T40, P3-E4-T70 and 1 more |
| REQ-PRF-005 | MUST | 03 §14 | P0-E1-T02, P0-E1-T05, P0-E1-T06, P0-E1-T15, P0-E2-T19, P2-E7-T05 and 2 more |
| REQ-ACC-001 | MUST | 02 §10 | P0-E4-T03, P0-E4-T11 |
| REQ-ACC-002 | SHOULD | 02 §10 | P0-E4-T08, P0-E4-T10, P0-E4-T13, P0-E4-T15, P3-E7-T07 |
| REQ-ACC-003 | SHOULD | 02 §10 | P0-E4-T15, P1-E1-T03, P1-E1-T14, P1-E5-T05 |
| REQ-ACC-004 | SHOULD | 02 §10 | P0-E4-T08, P0-E4-T15, P1-E1-T14, P1-E5-T02 |
| REQ-ACC-005 | SHOULD | 02 §10 | P0-E4-T05, P0-E4-T15, P3-E7-T07 |
| REQ-LNG-001 | MUST | 02 §8 | P0-E3-T03, P0-E4-T17, P1-E5-T01, P3-E7-T01, P3-E7-T70 |
| REQ-LNG-002 | MUST | 03 §7 | P0-E3-T03 |
| REQ-LNG-003 | MUST | 02 §8 | P0-E3-T07, P0-E4-T09, P1-E1-T01 |
| REQ-LNG-004 | MUST | 03 §7 | P0-E3-T02, P0-E3-T07, P1-E1-T12 |
| REQ-LNG-005 | MUST | 03 §7 | P0-E3-T02 |
| REQ-LNG-006 | MUST | 02 §8 | P0-E3-T04, P0-E3-T09, P0-E4-T04, P0-E4-T05, P0-E4-T06 |
| REQ-LNG-007 | MUST | 02 §8 | P0-E4-T07, P3-E3-T03 |
| REQ-LNG-008 | MUST | 03 §7 | P0-E3-T01, P0-E3-T08, P1-E1-T02, P1-E1-T13 |
| REQ-LNG-009 | MUST | 03 §7 | P0-E2-T03, P0-E2-T10, P0-E3-T06, P0-E4-T10, P1-E1-T04, P1-E2-T02 and 2 more |
| REQ-LNG-010 | MUST | 07 §6 | P0-E3-T06, P3-E3-T03, P3-E3-T20, P3-E3-T40 |
| REQ-LNG-011 | MUST | 03 §10 | P1-E3-T05, P1-E3-T30, P2-E7-T04, P2-E7-T60, P4-E5-T03 |
| REQ-LNG-012 | MUST | 02 §8 | P0-E3-T05, P0-E4-T07, P1-E1-T05, P1-E4-T01, P1-E5-T02 |
| REQ-MOD-001 | MUST | 07 §8 | P3-E3-T01, P3-E3-T40 |
| REQ-MOD-002 | MUST | 07 §8 | P3-E5-T03, P3-E5-T40 |
| REQ-MOD-003 | MUST | 07 §8 | P3-E5-T07, P3-E5-T08, P3-E5-T40, P3-E5-T50 |
| REQ-MOD-004 | MUST | 07 §8 | P3-E5-T07, P3-E5-T08, P3-E5-T09, P3-E5-T40, P3-E6-T20 |
| REQ-MOD-005 | MUST | 07 §8 | P3-E5-T04, P3-E5-T05, P3-E5-T10, P3-E5-T41, P3-E5-T50, P3-E8-T02 and 1 more |
| REQ-MOD-006 | SHOULD | 07 §8 | P3-E2-T04, P3-E4-T04, P3-E4-T73, P3-E5-T06, P3-E5-T30, P3-E8-T05 |
| REQ-MOD-007 | MUST | 07 §7 | P3-E5-T02, P3-E5-T40 |
| REQ-MIR-001 | MUST | 04 §5 | P0-E2-T04, P0-E2-T15, P0-E4-T01, P1-E1-T01, P1-E5-T03 |
| REQ-MIR-002 | MUST | 03 §4 | P0-E1-T09, P0-E1-T14, P0-E2-T06, P0-E2-T31, P0-E4-T02 |
| REQ-MIR-003 | MUST | 04 §5 | P0-E2-T02, P0-E2-T04 |
| REQ-MIR-004 | SHOULD | 04 §11 | P3-E3-T40, P3-E5-T01 |
| REQ-MIR-005 | MUST | 02 §5 | P0-E2-T07, P0-E4-T01, P0-E4-T02, P0-E4-T03, P0-E4-T12 |
| REQ-DON-015 (proposed) | MUST | 06 §4 | P1-E3-T46 |
| REQ-DON-016 (proposed) | SHOULD | 06 §4 | — |
| REQ-DON-017 (proposed) | SHOULD | 06 §4 | P1-E3-T01 |
| REQ-DON-018 (proposed) | MUST | 03 §9 | P4-E5-T01 |
| REQ-TRL-015 (proposed) | MUST | 06 §6 | — |
| REQ-TRL-016 (proposed) | MUST | 06 §8 | P2-E2-T02 |
| REQ-DPR-011 (proposed) | MUST | 05 §7 | — |
| REQ-DPR-012 (proposed) | MUST | 06 §10 | — |
| REQ-DPR-013 (proposed) | SHOULD | 04 §13 | — |
| REQ-ORP-010 (proposed) | SHOULD | 06 §12 | P4-E2-T03 |
| REQ-PUB-009 (proposed) | SHOULD | 05 §5 | — |
| REQ-ROL-011 (proposed) | MUST | 05 §9 | — |
| REQ-ROL-012 (proposed) | MUST | 05 §8 | — |
| REQ-ROL-013 (proposed) | SHOULD | 05 §6 | — |
| REQ-SEC-009 (proposed) | SHOULD | 05 §9 | — |
| REQ-SEC-010 (proposed) | SHOULD | 03 §6 | P0-E5-T07 |
| REQ-SEC-011 (proposed) | MUST | 04 §13 | — |
| REQ-CHS-007 (proposed) | MUST | 07 §11 | P2-E1-T31 |
| REQ-CHS-008 (proposed) | MUST | 07 §5 | — |
| REQ-CHS-009 (proposed) | SHOULD | 07 §12 | — |
| REQ-CHS-010 (proposed) | MUST | 07 §12 | — |
| REQ-MOD-008 (proposed) | SHOULD | 07 §8 | — |
| REQ-MOD-009 (proposed) | MUST | 07 §11 | — |
| REQ-ACC-006 (proposed) | MUST | 02 §5 | — |
| REQ-PRF-006 (proposed) | SHOULD | 02 §9 | — |
