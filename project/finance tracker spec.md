# SQL Project Spec — FinanceTrackerDB (LOCKED)

Per the standing build-spec standard: written and agreed before any schema or query code was written. Every decision below is confirmed — this stays fixed for the build; any change from here is a deliberate, logged decision, not a quiet drift.

## What this project is

A standalone, properly-designed database for tracking personal finances — accounts, spending categories, and every transaction between them — built from scratch, judged entirely on its own, separate from the `InterviewPrepSQL`/`InterviewPrepSQLPractice` teaching databases docs 01–08 used. Same domain as those docs (finance/transactions) for continuity, and a fresh database/schema — but not a separate repo; it lives as its own `project` subfolder inside the existing `sql` repo, the same pattern the Python capstone used (`python/project/cli_tool/`).

## Decisions

1. **Database name: `FinanceTrackerDB`.**
2. **Users table: included.** Accounts belong to a user — gives a real reason for a couple of the join demos, more realistic than an owner-less set of accounts.
3. **Isolation levels / deadlocks coverage: both.** The decisions log documents which isolation level the transfer procedure runs under and why (referencing doc 08's live proof), **and** a fresh, real two-window isolation/deadlock demo runs against this project's own schema specifically — not assumed to carry over just because doc 08 already proved the mechanics once elsewhere.
4. **Location: `D:\interview prep\sql\project\`** — no separate repo. Lives inside the existing `sql` repo as its own `project` subfolder, mirroring the Python capstone's structure exactly: `finance tracker spec.md` and `finance tracker build notes.md` at the `project\` root, with the actual schema/query/procedure scripts organized under a `finance_tracker\` folder beside them (matching `python/project/cli_tool/`).

## Schema

Five tables, normalized from the start (applying doc 07's lessons directly, not fixing anomalies after the fact):

**Users**
| Column | Type |
|---|---|
| UserID | int (PK) |
| UserName | varchar(50) |
| Email | varchar(100) |
| DateJoined | date |

**Accounts**
| Column | Type |
|---|---|
| AccountID | int (PK) |
| UserID | int (FK → Users) |
| AccountName | varchar(50) |
| AccountType | varchar(20) |
| Balance | decimal(10,2) |
| DateOpened | date |

**Categories** *(self-referencing, for a real hierarchy — Groceries under Essentials, etc.)*
| Column | Type |
|---|---|
| CategoryID | int (PK) |
| CategoryName | varchar(50) |
| ParentCategoryID | int (FK → Categories, NULL-able) |

**Transactions**
| Column | Type |
|---|---|
| TransactionID | int (PK) |
| AccountID | int (FK → Accounts) |
| CategoryID | int (FK → Categories) |
| TransactionDate | date |
| Amount | decimal(10,2) |
| Description | varchar(200) |

**Budgets**
| Column | Type |
|---|---|
| BudgetID | int (PK) |
| UserID | int (FK → Users) |
| CategoryID | int (FK → Categories) |
| MonthYear | date |
| BudgetAmount | decimal(10,2) |

Seeded at a realistic scale (thousands of transactions, not a handful) so indexing and execution-plan work actually measures something — same approach as the 50,000-row tables in doc 06/07, scale to be finalized once the schema itself is agreed.

## Required coverage — every concept doc 01–08 taught, actually used

This is the pass/fail bar. Not "enough queries to get by" — every one of these needs a real, working piece in the finished project:

- **Schema design** — normalized to 3NF from the start, with written FD reasoning (doc 07 §8's approach), not retrofitted.
- **Every join type** — inner, left, right, full outer, and a self-join (Categories parent/child hierarchy).
- **Set operators** — `UNION`/`UNION ALL`, `INTERSECT`, `EXCEPT`, each in a query that's actually useful for this domain (not forced in just to check a box).
- **Window functions** — `ROW_NUMBER`, `RANK`, `LAG`/`LEAD`, `PARTITION BY` — e.g. a running account balance over time, month-over-month spending change per category.
- **CTEs** — at least one genuinely useful CTE, likely a recursive one walking the Categories hierarchy.
- **Indexes + execution plans** — at least one real before/after index demonstration on the realistically-scaled table, with real `STATISTICS IO`/plan output, same proof style as doc 06.
- **Index design trade-offs** — written reasoning for at least one index choice (what it costs on writes, what it buys on reads).
- **Transactions & ACID** — a real multi-step operation (e.g. transferring money between two accounts) wrapped properly, with a real deliberate failure-and-rollback test, same proof style as doc 08.
- **Isolation levels / deadlocks** — a real, fresh two-window demo against this project's own transfer procedure (not reused from doc 08), plus written reasoning in the decisions log for which isolation level it actually runs under.
- **Stored procedures** — at least one real procedure encapsulating a core operation (e.g. `RecordTransaction` or a transfer procedure).
- **Views** — at least one real view (e.g. a monthly spending summary or account-balances view), tested for real.

## Deliverables

- `finance tracker spec.md` — this doc, once finalized.
- Schema creation script(s).
- Seed/sample data script.
- A query library — one file (or organized set) covering every item in "Required coverage" above, each with its real executed output captured.
- Stored procedure + view scripts, with real tests.
- `finance tracker build notes.md` — the running log kept as the build happens, same pattern as the Python capstone: each piece's real code, explanation, and genuine Q&A as it's confirmed.
- A short README and decisions log (why this schema shape, why these indexes, why this isolation-level choice) — good practice to start now, since the Wknd 13–15 capstone will want the same habit later.

## What this spec deliberately does not say

How to actually write any of the SQL, the exact query wording, or the exact index definitions — that's the live-build phase, piece by piece, typed by you into your own files.

---

**Next step:** the live build starts — piece by piece, in chat, typed by you into your own files, with `finance tracker build notes.md` logging each piece as it's confirmed real.
