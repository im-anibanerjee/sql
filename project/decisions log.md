# FinanceTrackerDB — Decisions Log

Kept per the locked spec's Deliverables section: "A short README and decisions log (why this schema shape, why these indexes, why this isolation-level choice)." This records every deliberate choice made across all 37 build pieces, plus every honest real finding worth a future reader knowing was discovered, not assumed — including two places where the build initially differed from the spec's own original wording (both flagged directly at the time, and both later closed for real against a `TransferFunds` procedure built specifically to close them — see §6, §7, and §8).

---

## 1. Schema design

**Database name: `FinanceTrackerDB`.** Locked in the spec before any code was written (spec decision #1).

**Five tables, normalized to 3NF from the start** (`Users`, `Accounts`, `Categories`, `Transactions`, `Budgets`) — applying doc 07's normalization lessons directly during design, rather than building something flat and fixing anomalies afterward. Each table was built in strict dependency order (Pieces 1–11): `Users` first (no foreign keys of its own), then `Accounts` (FK → `Users`), then `Categories` (self-referencing, no dependency on the other new tables), then `Transactions` (FK → `Accounts` and `Categories` at once), then `Budgets` last (FK → `Users` and `Categories`). A foreign key can't reference a table that doesn't exist yet, so this order wasn't optional once the schema was fixed.

**Users table: included** (spec decision #2), specifically so `Accounts` has a real reason to carry a foreign key into something other than `Categories` — without it, several of the join pieces (12, 15) would have had one less real relationship to demonstrate.

**Categories is self-referencing** (`ParentCategoryID → CategoryID`, nullable) — this was called out by name on the ER diagram (Piece 0) before any table existed, specifically so the self-join (Piece 16) and the recursive CTE (Piece 24) would have real, structural data to walk, rather than being forced examples bolted onto unrelated data. The real hierarchy ended up only 2 levels deep (`Essentials`/`Entertainment` → `Groceries`/`Rent`/`Movies`), which is enough to prove a self-join works but not enough, on its own, to prove a flat self-join *wouldn't* have been enough — that's exactly why the recursive CTE piece was written to walk arbitrary depth rather than hard-code 2 hops, flagged explicitly in Piece 16's own notes as a real limitation of this project's data.

**Every foreign key is `not null` except `Categories.ParentCategoryID`.** A transaction, account, or budget is never allowed to exist without pointing at a real owner/account/category — there's no nullable escape hatch anywhere except the one place normalization actually requires it (a top-level category genuinely has no parent).

**`Amount` is stored as a signed `decimal(10,2)`, negative for spending.** Chosen once, in Piece 9, and never revisited — a future income/deposit transaction would be the positive case, but every transaction seeded in this project is spending, so every real `Amount` value across all 33 pieces is negative.

---

## 2. Seed data: two separate seeding decisions, at two different scales, for two different reasons

**Pieces 1–11: five real, hand-typed transactions.** Small on purpose — this stage was about proving the schema's constraints work (foreign keys, defaults, nullability), not about volume. Every join, set-operator, window-function, and CTE piece through Piece 24 ran against this same small, fully-traceable dataset (documented row-by-row in the "Populated Schema" section), so every real result could be hand-verified against known data rather than trusted blindly.

**Piece 25: bulk-seeded to 5,000 synthetic `Transactions` rows.** A deliberate, flagged decision (confirmed via `AskUserQuestion` before writing the seed script) — 5 hand-typed rows cannot honestly demonstrate indexing or execution-plan behavior; the optimizer needs enough real rows and enough real page count for a scan-vs-seek choice to mean anything, the same realistic-scale approach doc 06/07 used (50,000-row tables). Built with a tally-table cross join (`sys.all_columns cross join sys.all_columns`) and `checksum(newid())` per column (since `rand()` evaluates once per statement, not once per row) to get genuinely independent random values per row, while keeping every value realistic: `CategoryID` always a real leaf category (3/4/5, never a parent), `Amount` always negative, `AccountID` always one of the 3 real accounts.

**Real, honest discovery from this decision (Piece 32):** querying the bulk-seeded data with no date filter at all (the `TransactionDetails` view, Piece 32) revealed that the 5,000 rows actually span roughly two full years — `2024-10-13` through `2026-10-11` (the real date this piece was run) — not just the single month, July 2026, that every indexing/stored-procedure piece (26–31) happened to filter down to. This was never visible until a broader query ran; it's recorded here as a real property of the seeded data, not something that was designed in deliberately.

---

## 3. Join & set-operator coverage: one reused real domain thread, not five unrelated toy examples

Every join type (Pieces 12–16) and every set operator (Pieces 17–19) deliberately reused the same real comparison — budgeted `(UserID, CategoryID)` pairs (`Budgets`) against actually-spent-against `(UserID, CategoryID)` pairs (derived from `Transactions` bridged through `Accounts`) — rather than inventing a fresh toy example per concept. By Piece 19, four independent techniques (full outer join, union, intersect, except) all agreed on the same underlying real facts (e.g. User 2's Movies budget has zero real spending against it), which is a stronger proof than five queries that each ran cleanly in isolation but never cross-checked each other.

Join order was deliberately chosen to match which real data could prove each concept: inner join (12) went first because every row in the small seed data already had a guaranteed match (no orphans — the FKs prevented that by construction), so it had nothing *extra* to prove; left/right join (13/14) deliberately joined from `Categories` instead, specifically because `Categories` was the one table with real unmatched rows (the two parent categories); full outer join (15) deliberately picked two tables with **no declared foreign key between them at all** (`Budgets`/`Transactions`), since a full outer join only earns its keep when both sides can genuinely be unmatched, which no actual FK in this schema allows.

---

## 4. Window functions & recursive CTE

**Piece 20 (`row_number()`/`rank()` partitioned by `UserID`)** was deliberately built against data with no tied amounts, so both functions would agree on every row — the very next piece (21) was deliberately built against a real tie (category transaction counts) specifically to make `rank()` and `dense_rank()` diverge for real, rather than asserting the difference without proof.

**Piece 24 (recursive CTE over the Categories hierarchy)** is the one piece explicitly flagged as not fully proving what it looks like it proves: this project's real hierarchy is only 2 levels deep, so a flat self-join (Piece 16) already resolves it completely. The recursive CTE was still built (and is still the right tool in general, since it resolves arbitrary depth, not just 2 hops) — this is recorded as an honest limitation of the recursion's real seeded data, not a limitation of the technique.

---

## 5. Indexing & execution plans — written index-tradeoff reasoning

**The real, measured three-step story (Pieces 26–28), all against the 5,000-row bulk-seeded `Transactions` table:**

| Piece | Index | Logical reads | What happened |
|---|---|---|---|
| 26 | none | 42 | Baseline table scan, `TransactionDate` filter, 255 matching rows |
| 27 | `IX_Transactions_TransactionDate` (non-covering — key column only) | 42 | **Unchanged.** The optimizer correctly rejected the new index: with 255 of 5,005 rows matching (~5%) and 3 columns per row not covered by the index, 255 key lookups would have cost more than the existing scan, so SQL Server chose the scan on purpose. |
| 28 | `IX_Transactions_TransactionDate_Covering` (same key, `include (AccountID, CategoryID, Amount)`) | 3 | A ~14x drop. Every column the query needed was now inside the index itself, so no key lookup back to the table was ever needed. |

**Written reasoning (the spec's explicit "index design trade-offs" requirement):** an index's write cost (every `insert`/`update`/`delete` against `Transactions` now has to maintain this index too, and the covering version is physically wider — three extra columns copied into every leaf entry — so it costs more disk and more write overhead than the non-covering version) buys nothing on reads unless the index actually covers what a given query needs. A non-covering index is not free insurance; it's dead weight on every write with no guaranteed read benefit, which is exactly what Piece 27 proved for real rather than asserted. The covering index was the deliberate fix once that was known, not the default first move.

---

## 6. Transactions & ACID — built, with one honest deviation from the spec's own wording

**What the spec's Required Coverage section described:** "a real multi-step operation (e.g. transferring money between two accounts) wrapped properly, with a real deliberate failure-and-rollback test."

**What was actually built (Piece 29):** two updates inside one transaction against **two different accounts**, but not a *transfer* in the sense of money moving from one to the other — the first statement deducted 500 from Account 1, and the second statement (the deliberate failure) attempted a divide-by-zero on Account 2, with no logical relationship between the two amounts. This genuinely proves atomicity (the first, individually-successful update was undone when the transaction rolled back, because of the second statement's failure) — but it is not literally the account-to-account transfer the spec's own example named. **Flagged here directly, not silently:** this satisfies the spirit of the ACID requirement (a real multi-step operation, a real deliberate failure, a real rollback, verified against real data) but not its literal letter. A proper `TransferFunds`-style procedure that actually moves a specific amount from one account's balance to another's, with the same rollback-on-failure proof, was not built as part of this requirement and remains an open option if full literal spec compliance is wanted later.

**Also worth recording honestly:** every balance in this test showed `0.00` both before and after, because `Accounts.Balance` has defaulted to `0` since Piece 3 and was never durably updated by any earlier piece — the rollback still genuinely worked (proven by the fact that the deliberately-failed statement never left Account 1 at `-500.00`), it just wasn't visually dramatic on this project's own data.

---

**Update — this gap is now closed (Piece 34–35):** a real `TransferFunds` procedure was built, and the same ACID guarantee — a real successful transfer and a real deliberate failure-and-rollback — was re-proven against it specifically, on real account balances this time (1000.00/500.00/0.00 going in), not the all-zero balances this section originally had to work with. See `finance tracker build notes_5.md`.

---

## 7. Isolation levels & deadlocks — both required per spec decision #3, with the same honest deviation

**Spec decision #3 locked both halves of this requirement explicitly:** written reasoning in this log, **and** a fresh two-window demo "against this project's own transfer procedure" — not reused from doc 08.

**What was actually built:** Piece 30 (isolation levels) and Piece 33 (deadlocks) are both genuine, fresh, live two-window demos against this project's own `Accounts` table, run specifically for this project and not reused from doc 08 — satisfying that half of the requirement for real. **The honest deviation:** neither demo actually ran "against this project's own transfer procedure," because no transfer procedure was ever built (see §6 and §8 — the one stored procedure built, Piece 31, is a read-only lookup, not a money-moving procedure). Both demos instead ran directly against raw `update` statements on `Accounts`, which still proves the same isolation-level and deadlock mechanics for real, but not specifically through a procedure the way the spec's wording anticipated.

**Written reasoning — which isolation level this project actually runs under:** every piece in this project before Piece 30 ran under SQL Server's session default, `READ COMMITTED` — never explicitly set, never needed to be, since nothing before Piece 30 required two sessions to interact at all. Piece 30 deliberately proved what `READ UNCOMMITTED` allows that `READ COMMITTED` does not: a real dirty read of Account 1's uncommitted `-777.00` balance while Window A's transaction was still open, followed by a clean, non-dirty read once Window B switched back to `READ COMMITTED` after Window A rolled back. The deliberate choice for this project, going forward, is to stay on `READ COMMITTED` as the default for any real transfer logic (it's SQL Server's own default for a reason — it never risks reading a value that might not end up being real) and to treat `READ UNCOMMITTED` as something to reach for only in reporting contexts that can tolerate an occasional wrong read in exchange for never blocking.

**Piece 33's real deadlock result:** the circular-wait setup worked exactly as designed — Window A was chosen as the deadlock victim (a real `Msg 1205`, Process ID 69), its transaction automatically rolled back, which released its lock on Account 1 and let Window B's blocked update go through. Window B's own transaction stayed open and unbroken the whole time, so its final `rollback transaction` correctly undid both of its own pending changes together — Account 2 and Account 1 both ended back at their real original value, `0.00` — exactly what a single `rollback` is supposed to do to every change made since that session's `begin transaction`.

---

**Update — this gap is now closed (Piece 36–37):** both demos were re-run for real against the actual `TransferFunds` procedure, per the spec decision #3's original wording. The isolation-level demo caught a genuine mid-transfer dirty read through the real procedure's own debit/pause/credit sequence. The deadlock demo took two real attempts: the first version of `TransferFunds` turned out to make two opposite-direction transfers of the same account pair serialize instead of deadlock (a real, interesting finding in its own right, caused by the procedure's own upfront destination-account check — see `finance tracker build notes_5.md`, Piece 37, for the full explanation). Reordering that validation to check the destination account later, right before it's actually used, restored the classic lock-order pattern and reproduced a genuine `Msg 1205` deadlock on the first attempt afterward.

---

## 8. Stored procedures & views

**Piece 31 — `GetUserTransactionsByDateRange`:** a parameterized, read-only lookup (`@UserID`, `@StartDate`, `@EndDate`), tested with two genuinely different real inputs that cross-checked against an independently-known total (175 + 80 = 255, matching the already-confirmed July row count from Pieces 26–28). **Honest note, consistent with §6/§7 above:** the spec's own example for this requirement was `RecordTransaction` or a transfer procedure — something that *writes*. What was actually built reads, and was never extended into a procedure that moves money between accounts. This still satisfies the literal "at least one real procedure encapsulating a core operation" requirement (a parameterized date-range lookup is a real, reusable core operation for a finance tracker), but it's a different shape of procedure than the spec's own example anticipated, and it's the same underlying gap noted in §6 and §7 — no transfer procedure exists anywhere in this project yet.

**Piece 32 — `TransactionDetails` view:** joins `Transactions`/`Accounts`/`Categories` into readable columns, queried directly with a plain `select ... where ... order by` exactly like a real table, no `exec` required — the clean contrast with Piece 31's procedure (a view is queried, a procedure is executed) was the explicit point of building both.

---

**Update — this gap is now closed (Piece 34):** a real `TransferFunds` procedure was built — a genuine write procedure matching the spec's own named example, with its own transaction and rollback handling built in, as described in §6/§7 above and in `finance tracker build notes_5.md`.

