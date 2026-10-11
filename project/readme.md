# FinanceTrackerDB

A standalone, normalized SQL Server database for tracking personal finances — users, accounts, spending categories, budgets, and transactions — built from scratch to exercise every SQL concept covered in docs `01`–`08` of this repo's interview-prep series. Same finance/transactions domain as those teaching docs, for continuity, but its own fresh database and schema (not an extension of `InterviewPrepSQL`/`InterviewPrepSQLPractice`).

See `finance tracker spec.md` for the original locked spec, and `decisions log.md` for the full reasoning behind every design choice and every honest real finding along the way. This file is the short "what is this, how do I run it" entry point.

## Schema

Five tables, normalized to 3NF from the start:

| Table | Purpose | Foreign keys |
|---|---|---|
| `Users` | Who owns the data | — |
| `Accounts` | A user's bank/savings/checking accounts | `UserID` → `Users` |
| `Categories` | Spending categories, self-referencing for a real hierarchy (e.g. `Groceries`/`Rent` under `Essentials`) | `ParentCategoryID` → `Categories` (nullable) |
| `Transactions` | Every real transaction | `AccountID` → `Accounts`, `CategoryID` → `Categories` |
| `Budgets` | A user's monthly budget per category | `UserID` → `Users`, `CategoryID` → `Categories` |

Full column-level definitions are in `finance tracker spec.md`. An ER diagram and a "populated schema" diagram (every table's real data, every FK traced to its exact row) are in `finance_tracker_db/diagrams/`.

## What's been built and proven (real, not theoretical)

Every item below was run for real against this database and verified against actual SSMS output — nothing here is guessed or reasoned out. Full code, real output, and a plain-language + technical explanation for each lives in `finance tracker build notes_1.md` through `_5.md` (split across files as the log grew; each file picks up where the last one's last piece left off).

- **Schema & seed data** (Pieces 0–11) — all five tables built in dependency order, seeded with 5 real hand-typed transactions first (for traceability), then bulk-seeded to 5,000 synthetic rows later (Piece 25) once realistic scale was needed for indexing work.
- **Every join type** (Pieces 12–16) — inner, left, right, full outer, and a self-join on `Categories`' own parent/child hierarchy — all reusing one real comparison (budgeted vs. actually-spent `UserID`/`CategoryID` pairs) rather than five unrelated toy examples.
- **Set operators** (Pieces 17–19) — `union`, `intersect`, `except` on that same real comparison, cross-checking each other's results.
- **Window functions** (Pieces 20–23) — `row_number()`, `rank()`/`dense_rank()` (including a real tie), `lag()`/`lead()`, and a running total with `sum() over()`.
- **A recursive CTE** (Piece 24) — walking the full `Categories` hierarchy top to bottom.
- **Indexes & execution plans** (Pieces 26–28) — a real, measured before/after/after-again story at 5,000-row scale: no index (42 logical reads) → a non-covering index the optimizer correctly rejected (still 42) → a covering index that actually worked (3 reads, a ~14x drop). Written index-tradeoff reasoning is in the decisions log.
- **Transactions & ACID** (Piece 29) — a multi-statement transaction with a deliberate failure (divide-by-zero) and a real rollback, proving atomicity.
- **Isolation levels** (Piece 30) — a live two-window demo of a real dirty read under `READ UNCOMMITTED`, and the same read coming back clean under `READ COMMITTED`.
- **Deadlocks** (Piece 33) — a live two-window circular-wait demo producing a real `Msg 1205` deadlock victim, with the surviving session's rollback correctly undoing all of its own pending changes.
- **Stored procedures** (Piece 31) — a parameterized `GetUserTransactionsByDateRange` procedure, called with two different real inputs.
- **Views** (Piece 32) — a `TransactionDetails` view joining `Transactions`/`Accounts`/`Categories`, queried directly like a real table.
- **A real `TransferFunds` procedure** (Piece 34) — the one gap the pieces above originally left open (every example above pointed at a money-moving procedure that didn't exist yet): a real stored procedure that moves money from one account to another, with its own transaction, validation, and rollback-on-failure handling built in.
- **ACID, isolation levels, and deadlocks, re-proven against that real procedure specifically** (Pieces 35–37) — a real successful transfer and a real deliberate failure-and-rollback (Piece 35); a live two-window dirty-read demo caught genuinely mid-transfer through the procedure's own debit/pause/credit sequence (Piece 36); and a real two-window `Msg 1205` deadlock (Piece 37) — which took two genuine attempts, the first of which revealed a real finding about how a procedure's own validation order can prevent a deadlock entirely (full explanation in the build notes).

## File layout

```
project/
├── finance tracker spec.md              the locked original spec
├── finance tracker build notes_1.md     Pieces 0-11  (schema + seed data)
├── finance tracker build notes_2.md     Pieces 12-19 (joins + set operators)
├── finance tracker build notes_3.md     Pieces 20-27 (window functions, recursive CTE, bulk seed, indexing before/after)
├── finance tracker build notes_4.md     Pieces 28-33 (covering index, ACID, isolation levels, stored procs, views, deadlocks)
├── finance tracker build notes_5.md     Pieces 34-37 (TransferFunds procedure, ACID/isolation/deadlocks re-proven against it)
├── decisions log.md                     why each choice was made, and every honest real finding
├── readme.md                            this file
└── finance_tracker_db/
    ├── finance_tracker_db_1.sql         raw SSMS transcript, sections 1-11
    ├── finance_tracker_db_2.sql         raw SSMS transcript, sections 12-19
    ├── finance_tracker_db_3.sql         raw SSMS transcript, sections 20-23
    ├── finance_tracker_db_4.sql         raw SSMS transcript, sections 24-28
    ├── finance_tracker_db_5.sql         raw SSMS transcript, sections 29-33
    ├── finance_tracker_db_6.sql         raw SSMS transcript, sections 34-37
    └── diagrams/                        ER diagram, populated-schema diagram, and per-piece companion diagrams
```

## How to rebuild this database from scratch

1. Run `finance_tracker_db_1.sql` through `finance_tracker_db_6.sql`, in order, in SSMS against a fresh SQL Server instance. Each file is a straight transcript (schema, seed data, and every query in sequence) — running all six end to end recreates the full database, its 5,000-row bulk-seeded `Transactions` table, and the `TransferFunds` procedure exactly as they exist in this project.
2. Section markers (`-- section N`) inside each `.sql` file correspond 1-to-1 with the "Piece N" headings in the build-notes files, so any piece's real output can be found and re-verified by cross-referencing the section number.
3. The one piece that depends on timing rather than a single script running top-to-bottom is Piece 25 (bulk seed) — run it once; running it again adds another 5,000 rows on top rather than replacing the existing ones.
4. Pieces 30, 33, 36, and 37 (isolation levels and deadlocks, both the original raw-`update` demos and the later ones re-proven against `TransferFunds`) each need two separate SSMS query windows run in a specific order — the build notes for those pieces spell out the exact window-by-window sequence. `TransferFunds` also takes an optional `@SimulateDelay` parameter, used only to recreate that timing for Pieces 36 and 37 — real callers never need to set it.

## Engine

SQL Server (SSMS), matching the resume/work setup this entire interview-prep series targets — not PostgreSQL. Every real result in this project was run by hand in SSMS and pasted back, never simulated.
