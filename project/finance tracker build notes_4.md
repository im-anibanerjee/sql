## Piece 28 — indexes & execution plans, the real fix (a covering index, run for real)

```sql
drop index IX_Transactions_TransactionDate on Transactions;

create index IX_Transactions_TransactionDate_Covering
    on Transactions(TransactionDate)
    include (AccountID, CategoryID, Amount);

set statistics io on;

select TransactionID, AccountID, CategoryID, TransactionDate, Amount
from Transactions
where TransactionDate >= '2026-07-01' and TransactionDate < '2026-08-01';

set statistics io off;
```

Confirmed real output:

```
TransactionID  AccountID  CategoryID  TransactionDate  Amount
-------------  ---------  ----------  ---------------  --------
1352           1          5           2026-07-01       -3564.89
2004           1          3           2026-07-01       -3047.23
2671           2          3           2026-07-01       -3131.18
...            ...        ...         ...              ...        (rows truncated here for length - 255 real rows total)
3530           1          5           2026-07-31       -2886.25
4273           1          3           2026-07-31       -3693.82
4523           3          5           2026-07-31       -1990.18
4921           1          3           2026-07-31       -4099.75

(255 rows affected)

Table 'Transactions'. Scan count 1, logical reads 3, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0,
lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.
```

Notes:
- **What this query is doing, explained simply:** this is the fix for the surprise in Piece 27 — `logical reads` dropped from **42 all the way down to 3**. Same question, same table, same 255 matching rows, but this time the index actually contains everything the query asked for, so SQL Server never needed to go back to the real table at all.

  Going back to the library analogy from last time: imagine the library redoes that card catalog, and this time each card doesn't just say which shelf — it also lists the author, the subject, and the price, right there on the card. Now the librarian never has to walk to the shelf and pull the actual book at all; everything needed is already sitting in the catalog drawer. That's why this time it's dramatically faster — 3 quick card-flips instead of 42 pages' worth of walking back and forth.

  Where this shows up in real life: this is the standard, correct fix once you've diagnosed a non-covering index — you don't throw the index away and give up, you make it cover the query. This exact before → non-covering → covering sequence is close to a textbook demonstration a lot of interviewers would actually want to see walked through step by step.

  The same thing, step by step, in plain words:
  step 1 — the old, non-covering index got dropped (it wasn't helping, so it would just be dead weight sitting on the table slowing down writes for no read benefit).
  step 2 — a new index got created on the same column (`TransactionDate`), but this time with `include (AccountID, CategoryID, Amount)` tacked on.
  step 3 — the exact same `select` ran again, asking for the exact same 5 columns.
  step 4 — this time, every single column the query needs — `TransactionID` (the clustered key, always along for free), `TransactionDate` (the indexed column), and `AccountID`/`CategoryID`/`Amount` (the `include`d columns) — is sitting right there inside the index. SQL Server does one quick **index seek** straight to the 255 matching rows' worth of index entries, and never has to leave the index to go fetch anything else from the real table — so `logical reads` falls to 3, a small fraction of the 42 pages the full scan needed.
- **What this query is doing, technical step-by-step, and why `include` is the key difference from Piece 27:** an `include`d column is stored inside the non-clustered index's leaf level, right alongside the key column, but is **not** part of the index's sort order — SQL Server still only sorts by `TransactionDate`, but now reads `AccountID`, `CategoryID`, and `Amount` straight off the same leaf page it's already sitting on, with zero extra page accesses per row. This is exactly what makes an index **covering**: every column the query's `select`, `where`, `join`, and `order by` touch is present somewhere in the index (key columns or `include`d columns), so the optimizer can satisfy the whole query from the index alone and never needs a **key lookup** back into the clustered table. That is the structural difference from Piece 27's index, which only had `TransactionDate` in it — covering 1 of the 4 non-key columns this query needed, forcing 255 key lookups. The 3 logical reads here are essentially just the index's own b-tree pages (root + a couple of intermediate/leaf pages) for walking straight to the matching range — no table pages touched at all. If you had a chance to check the real execution plan (Ctrl+M before running), it should show a single **Index Seek** operator reading from `IX_Transactions_TransactionDate_Covering`, with no **Key Lookup** operator anywhere in the plan — unlike Piece 27's plan, which (had it chosen the index) would have shown an Index Seek *plus* a Key Lookup joined by a Nested Loops operator.
- **How this connects to `06 sql indexes execution plans.md`:** this is the doc's covering-index section proven end to end on real, measured numbers from this project's own data: Piece 26 (no index, 42 reads) → Piece 27 (non-covering index, still 42 reads, optimizer correctly rejected it) → Piece 28 (covering index, 3 reads). That three-step progression — not just "add an index and it's faster" — is what separates a surface-level understanding of indexing from one that can actually diagnose and fix a slow query in an interview or on the job.
- **What this is really answering (interview-style scenario):** "I added an index but it didn't help — what do you do next?" now has a complete, real answer built from this project's own measurements: check whether the index is covering; if not, either accept the extra key-lookup cost (fine when very few rows match) or add the missing columns via `include` so the index can answer the query by itself. This project's own data shows the "accept it" branch failing (255 rows was too many to make key lookups worth it) and the "fix it" branch succeeding (42 → 3 reads, roughly a 14x drop).

Questions along the way: none — understood on the first pass.

---

Indexes & execution plans are done — Pieces 26 through 28 took this from zero evidence to a complete, real, three-step story: no index, a non-covering index that the optimizer correctly ignored, and a covering index that actually earned its keep. The spec's "Required coverage" checklist moves next to transactions & ACID (`07 sql transactions acid.md`): wrapping multiple statements in `begin transaction` / `commit`, and proving atomicity for real with a deliberate `rollback` — showing that a transaction's changes are either all there or none are there, nothing in between, even after an error partway through.

The clearest way to prove that for real on this project's data is to run a multi-statement transaction that updates two real rows, deliberately force an error partway through, issue a `rollback`, and then re-select both rows to prove neither change survived — not just one of them.

## Piece 29 — transactions & ACID — a multi-statement transaction with a deliberate error and a real rollback

```sql
begin transaction;

update Accounts
set Balance = Balance - 500.00
where AccountID = 1;

update Accounts
set Balance = Balance / 0
where AccountID = 2;

rollback transaction;

select AccountID, Balance from Accounts order by AccountID;
```

Confirmed real output:

```
(1 row affected)

Msg 8134, Level 16, State 1, Line 9
Divide by zero error encountered.
The statement has been terminated.

AccountID  Balance
---------  -------
1          0.00
2          0.00
3          0.00

(3 rows affected)
```

Notes:
- **What this query is doing, explained simply:** this proves that a transaction really is all-or-nothing. Two updates were attempted inside one transaction: take $500 off Account 1, then (deliberately, on purpose, to force a failure) divide Account 2's balance by zero — which SQL Server always rejects. The first update actually succeeded on its own (notice `(1 row affected)` printed, proving it really ran), but the moment the second statement failed, the transaction was rolled back, and the final `select` shows all three accounts still sitting at `0.00` — meaning Account 1's $500 deduction was undone too, even though that particular statement never had anything wrong with it.

  A real-life version of this: imagine withdrawing cash from one account and depositing it into another at a bank counter, as one combined request. If the deposit step fails for any reason, a real bank doesn't leave the money missing from the first account — it reverses the withdrawal too, so you end up exactly where you started, not $500 short with nothing to show for it. `rollback` is the database doing that exact reversal.

  Where this shows up in real life: this is the entire point of wrapping related statements in a transaction — a money transfer, an order plus its payment, a seat booking plus its charge — so a failure partway through never leaves things half-done. "All or nothing" is the real-world guarantee this test just proved with real data.

  The same thing, step by step, in plain words:
  step 1 — `begin transaction` opens a transaction; nothing inside it is permanent yet.
  step 2 — the first `update` runs and succeeds — Account 1's balance is reduced by 500, at least temporarily, inside this not-yet-committed transaction.
  step 3 — the second `update` tries to divide by zero, which SQL Server always refuses — it raises error 8134 and stops that one statement (`The statement has been terminated`).
  step 4 — `rollback transaction` then explicitly undoes everything the transaction did, including step 2's successful update — not just the one that failed.
  step 5 — the final `select` proves it: all three accounts are back to their original `0.00`, with no trace that step 2 ever ran.
- **What this query is doing, technical step-by-step, and an honest note on why the numbers look unchanged:** `begin transaction` starts an explicit transaction and takes out row-level locks as each statement modifies data, but none of it is durable until a `commit`. The first `update` genuinely executes and modifies Account 1's row in the transaction's own pending state (which is why `(1 row affected)` printed — SQL Server doesn't lie about that), but that change is only visible inside this same session/transaction, not yet written permanently. The second `update`'s divide-by-zero is a **runtime error**, not a syntax error, so SQL Server raises Msg 8134 and terminates *that statement* — by default this does **not** automatically roll back the whole transaction on its own (that default error-handling behavior is itself worth knowing — it's controlled by `set xact_abort`), which is exactly why this piece includes an explicit `rollback transaction` statement afterward rather than relying on the error to undo things automatically. Once `rollback` runs, SQL Server discards every change made since `begin transaction`, including Account 1's update, restoring the exact state from before the transaction started. One honest caveat worth stating plainly: all three accounts show `0.00` both before and after this test, because `Balance` has defaulted to `0` and never actually been updated by any earlier piece in this project (confirmed back in the original Accounts insert in Piece 2) — so this result proves the rollback worked (if it hadn't, Account 1 would show `-500.00` instead of `0.00`), but it doesn't *look* dramatic only because the starting value happened to already be zero.
- **How this connects to `07 sql transactions acid.md`:** this is the doc's **Atomicity** guarantee (the "A" in ACID) demonstrated for real: a transaction's statements are treated as a single indivisible unit — either every one of them takes effect, or none of them do. The fact that step 2's update had already "succeeded" in isolation and still got undone is the clearest possible proof that atomicity applies to the whole transaction, not statement-by-statement.
- **What this is really answering (interview-style scenario):** "why wrap multiple statements in a transaction instead of just running them one after another?" — because without a transaction, a crash or error between two related statements can leave the data in a half-done, inconsistent state (money gone from one account, never arrived anywhere) with no way to automatically undo just the first one. A transaction turns that into one atomic unit that a single `rollback` can always cleanly reverse.

Questions along the way: none — understood on the first pass.

---

Atomicity is proven for real. The spec's "Required coverage" checklist moves next to isolation levels and concurrency (`07 sql transactions acid.md`'s isolation-levels section) — the question of what one transaction is allowed to *see* while another transaction is still in progress, uncommitted. That needs two separate SSMS query windows running at the same time, since it's inherently about two sessions interacting with each other, not just one script running top to bottom.

## Piece 30 — isolation levels — a live two-window dirty-read demo (READ UNCOMMITTED vs READ COMMITTED)

```sql
-- in window A
begin transaction;

update Accounts
set Balance = Balance - 777.00
where AccountID = 1;

-- in window B
set transaction isolation level read uncommitted;
select AccountID, Balance from Accounts where AccountID = 1;

-- in window A
rollback transaction;

-- in window B
set transaction isolation level read committed;
select AccountID, Balance from Accounts where AccountID = 1;
```

Confirmed real output:

```
-- Window A: update runs, transaction stays open (not committed, not rolled back yet)
-- (1 row affected)

-- Window B, under READ UNCOMMITTED, while Window A's transaction is still open:
AccountID  Balance
---------  -------
1          -777.00

(1 row affected)

-- Window A: rollback
-- Commands completed successfully.

-- Window B, under READ COMMITTED, after Window A's rollback:
AccountID  Balance
---------  -------
1          0.00

(1 row affected)
```

Notes:
- **What this query is doing, explained simply:** this proves that `read uncommitted` lets one session peek at another session's *not-yet-real* changes — changes that might still get thrown away. Window A started changing Account 1's balance to `-777.00` but never finished (never committed, never rolled back yet). While that change was still just "in progress", Window B — set to `read uncommitted` — asked for the same balance and got shown `-777.00` anyway, as if that change were already final. But it wasn't: Window A then rolled it back, meaning `-777.00` never actually happened. Window B saw a value that turned out to be a lie — that's exactly what a **dirty read** is.

  A real-life version of this: imagine a friend is editing a shared shopping list app and types "milk: $6" but hasn't hit save yet — they're still deciding whether to undo it. If you glance at their screen over their shoulder before they save (or discard), you'd see "$6" even though it might vanish the moment they hit undo. `read uncommitted` is the database equivalent of letting someone see your screen before you've saved anything.

  Where this shows up in real life: `read uncommitted` is occasionally used on purpose for rough reporting queries where a little inaccuracy is an acceptable tradeoff for not blocking other users, but it's dangerous for anything involving money or anything that must be exactly correct — exactly the kind of thing a finance app needs to avoid, which is why `read committed` is SQL Server's actual default, not `read uncommitted`.

  The same thing, step by step, in plain words:
  step 1 — Window A opens a transaction and updates Account 1's balance to `-777.00`, but doesn't commit or roll back yet — the change is real inside Window A's own transaction, but not yet permanent for anyone else.
  step 2 — Window B, explicitly set to the `read uncommitted` isolation level, runs a plain `select` on that same row while Window A's transaction is still open.
  step 3 — because `read uncommitted` ignores the usual locks that would normally make Window B wait, it reads Window A's in-progress, uncommitted value directly — `-777.00` — even though that value might never become permanent.
  step 4 — Window A then rolls back, proving that `-777.00` genuinely never became real — which means Window B's earlier read was dirty: it reported a value that turned out to be false.
  step 5 — Window B then switches to `read committed` (the real default) and re-reads the same row — this time getting `0.00`, the real, permanent, committed value, since `read committed` never allows reading another transaction's uncommitted changes.
- **What this query is doing, technical step-by-step, and what actually changed between the two reads:** normally, when one transaction modifies a row, SQL Server holds an exclusive lock on that row until the transaction commits or rolls back, and a session reading under the default `read committed` isolation level has to respect that lock — it either waits for the lock to release, or (depending on settings) reads the last-committed version instead. Setting `read uncommitted` (equivalent to the old `with (nolock)` hint on a table) tells SQL Server to skip honoring other sessions' locks entirely, reading whatever is physically in the data pages right now, committed or not — which is why Window B saw `-777.00` without waiting at all. After Window A's `rollback`, SQL Server physically reverts those data pages back to their prior state (`0.00`), so Window B's second read — this time under `read committed`, the session default used throughout every earlier piece in this project — reads the real, final value with no risk of seeing an in-progress change. One real-world detail worth noting: because Window A's `rollback` ran *before* Window B's second `select`, Window B never actually had to wait/block here — it simply found a finished transaction and read the settled value. The blocking behavior `read committed` is really known for only shows up if the second read happens *while* the first transaction is still open, at which point `read committed` would make Window B wait for Window A's lock to release rather than return early.
- **How this connects to `07 sql transactions acid.md`:** this is the isolation-levels section proven for real with two live sessions on this project's own data — `read uncommitted` genuinely produced a dirty read of a value that later got rolled back, and `read committed` genuinely did not, matching exactly what each isolation level promises (and doesn't promise) about what one transaction is allowed to see of another's unfinished work.
- **What this is really answering (interview-style scenario):** "what's the difference between read uncommitted and read committed, and why does it matter?" — now has a concrete, measured answer instead of a definition to recite: read uncommitted can show you data that later gets rolled back and never really existed (dangerous for financial data), while read committed guarantees you only ever see data that some transaction has actually finished and committed to — the real tradeoff being read uncommitted's speed/no-blocking versus read committed's correctness guarantee.

Questions along the way: none — understood on the first pass.

---

Isolation levels are proven for real, completing the spec's transactions & ACID / concurrency coverage. The spec's "Required coverage" checklist moves next to stored procedures (`09 sql stored procedures views.md`): packaging a parameterized query up as a reusable `create procedure`, so the same logic can be called repeatedly with different inputs instead of being retyped every time.

The clearest way to prove that on this project's real data is to wrap a genuinely useful, parameterized lookup — a user's transactions within a date range, something every piece so far has had to write out by hand — into a real stored procedure, then call it twice with two different real inputs to prove the same procedure genuinely adapts to whatever is passed in.

## Piece 31 — stored procedures — a parameterized procedure for a user's transactions in a date range, called twice with different real inputs

```sql
go
create procedure GetUserTransactionsByDateRange
    @UserID int,
    @StartDate date,
    @EndDate date
as
begin
    select
        tr.TransactionID,
        a.UserID,
        tr.CategoryID,
        tr.TransactionDate,
        tr.Amount
    from Transactions tr
    inner join Accounts a on tr.AccountID = a.AccountID
    where a.UserID = @UserID and
          tr.TransactionDate >= @StartDate and
          tr.TransactionDate < @EndDate
    order by tr.TransactionDate;
end;
go

exec GetUserTransactionsByDateRange @UserID = 1, @StartDate = '2026-07-01', @EndDate = '2026-08-01';
go

exec GetUserTransactionsByDateRange @UserID = 2, @StartDate = '2026-07-01', @EndDate = '2026-08-01';
go
```

Confirmed real output:

```
-- exec GetUserTransactionsByDateRange @UserID = 1, @StartDate = '2026-07-01', @EndDate = '2026-08-01';
TransactionID  UserID  CategoryID  TransactionDate  Amount
-------------  ------  ----------  ---------------  --------
1352           1       5           2026-07-01       -3564.89
2004           1       3           2026-07-01       -3047.23
2671           1       3           2026-07-01       -3131.18
...            ...     ...         ...              ...        (rows truncated here for length - 175 real rows total)
3443           1       5           2026-07-31       -240.02
3530           1       5           2026-07-31       -2886.25
4273           1       3           2026-07-31       -3693.82
4921           1       3           2026-07-31       -4099.75

(175 rows affected)

-- exec GetUserTransactionsByDateRange @UserID = 2, @StartDate = '2026-07-01', @EndDate = '2026-08-01';
TransactionID  UserID  CategoryID  TransactionDate  Amount
-------------  ------  ----------  ---------------  --------
3869           2       4           2026-07-01       -3673.03
3877           2       5           2026-07-01       -3583.07
3966           2       3           2026-07-01       -3587.44
4413           2       3           2026-07-01       -2864.95
...            ...     ...         ...              ...        (rows truncated here for length - 80 real rows total)
4907           2       3           2026-07-30       -2256.25
1587           2       3           2026-07-31       -1608.26
2565           2       4           2026-07-31       -4739.98
4523           2       5           2026-07-31       -1990.18

(80 rows affected)
```

Notes:
- **What this query is doing, explained simply:** this packages up a query — "give me this user's transactions in this date range" — as a named, reusable thing called `GetUserTransactionsByDateRange`, so instead of retyping the whole `select`/`join`/`where` every single time, it's enough to just say "run that procedure with these inputs." It was called twice with two different real inputs — User 1 and User 2, both for July — and got back two genuinely different, correct result sets: 175 rows for User 1, 80 rows for User 2. Same stored logic, different answers, because the inputs were different.

  A real-life version of this: think of a fill-in-the-blank form at a bank — "please pull up account ___'s statement from ___ to ___." The teller doesn't invent a new process every time someone asks; they fill in the blanks on the same form and get the right, different answer for each different customer. A stored procedure is that reusable form, with `@UserID`, `@StartDate`, `@EndDate` as the blanks.

  Where this shows up in real life: almost every real application doesn't send raw SQL text to the database for every request — it calls a stored procedure (or an equivalent) with parameters, both for reuse and because the database can pre-compile and optimize the procedure's plan once instead of re-analyzing similar-looking queries over and over.

  The same thing, step by step, in plain words:
  step 1 — `create procedure` defines the reusable logic once, with three named placeholders (`@UserID`, `@StartDate`, `@EndDate`) standing in for whatever real values get passed in later.
  step 2 — the first `exec` call fills those placeholders with `1`, `'2026-07-01'`, `'2026-08-01'` — and the procedure runs its stored `select` with those exact values substituted in, returning User 1's real 175 July transactions.
  step 3 — the second `exec` call fills the exact same placeholders with `2` instead of `1` (same date range) — and the same stored logic, unchanged, returns a completely different, correct result: User 2's real 80 July transactions.
  step 4 — 175 + 80 = 255, which is exactly the same total July row count already confirmed back in Pieces 26-28 (`TransactionDate between '2026-07-01' and '2026-08-01'` returned 255 rows) — a real, independent cross-check that this procedure is pulling correct, non-overlapping data for each user.
- **What this query is doing, technical step-by-step, and why the `go` batches matter:** `create procedure ... as begin ... end` compiles the enclosed `select` into a stored, named object in the database — SQL Server parses and creates an execution plan for it once, at creation (and again whenever it's first run or the plan is invalidated), rather than re-parsing the text from scratch on every call. The `go` commands are not part of T-SQL itself — they're a batch separator that only SSMS (and similar tools) understand, telling the client "send everything above this line to the server as one unit, then start a new one." `create/alter procedure` has a hard requirement that it must be the only statement in its batch, which is exactly the rule the earlier `Msg 111` error was enforcing — the fix was adding `go` immediately before it so nothing else shared its batch. Each `exec` call then substitutes its own literal parameter values into the compiled procedure's placeholders and runs it, scoped to that one call — the procedure itself never changes between calls, only the values passed into it.
- **How this connects to `09 sql stored procedures views.md`:** this is the doc's core case for stored procedures proven on two genuinely different real inputs — reusability (one definition, many calls), a measurable plan-reuse benefit (SQL Server doesn't need to re-analyze this query's shape every time), and a clean, named interface (`@UserID`, `@StartDate`, `@EndDate`) that an application can call without knowing or caring about the underlying `join`/`where` logic at all.
- **What this is really answering (interview-style scenario):** "why use a stored procedure instead of just sending raw SQL from the application?" — reuse (write the logic once, call it from anywhere), a cleaner interface for the calling code (pass three named parameters instead of building a SQL string), and a performance angle (the database can reuse a cached execution plan across calls instead of re-compiling similar ad-hoc query text every time) — all three borne out here: one definition, two very different real result sets, no duplicated logic.

Questions along the way: the real run hit `Msg 111, Level 15, State 1 — 'CREATE/ALTER PROCEDURE' must be the first statement in a query batch`, because leftover text from Piece 30 was still sitting above it in the same query window. Fixed by adding a `go` immediately before `create procedure` (and after it, and before each `exec`) to force each statement into its own clean batch — a genuinely common real-world SSMS mistake, not a bug in the procedure itself.

---

Stored procedures are proven for real, on two different real inputs that cross-check against already-confirmed totals. The spec's "Required coverage" checklist moves next to views (`09 sql stored procedures views.md`'s views section): wrapping a query up as a named, reusable virtual table with `create view`, queryable with a plain `select` the same way a real table would be — the key difference from a stored procedure being that a view can be queried directly and filtered/joined like any other table, while a procedure has to be `exec`uted.

The clearest way to prove that on this project's real data is to build a view that reuses a join already proven back in Piece 12 — Transactions joined to Accounts and Categories — then query the view directly with a plain `select` and a `where` clause, to prove it behaves exactly like querying a real table.

## Piece 32 — views — a reusable TransactionDetails view, queried directly with a plain select

```sql
go
create view TransactionDetails as
select
    tr.TransactionID,
    a.UserID,
    a.AccountName,
    c.CategoryName,
    tr.TransactionDate,
    tr.Amount
from Transactions tr
inner join Accounts a on tr.AccountID = a.AccountID
inner join Categories c on tr.CategoryID = c.CategoryID;
go

select * from TransactionDetails
where UserID = 2 and
      CategoryName = 'Movies'
order by TransactionDate;
go
```

Confirmed real output:

```
TransactionID  UserID  AccountName  CategoryName  TransactionDate  Amount
-------------  ------  -----------  ------------  ---------------  --------
506            2       Checking     Movies        2024-10-13       -3766.70
2015           2       Checking     Movies        2024-10-13       -3652.60
279            2       Checking     Movies        2024-10-14       -4898.82
567            2       Checking     Movies        2024-10-15       -4142.60
4494           2       Checking     Movies        2024-10-15       -2881.41
...            ...     ...          ...           ...              ...        (rows truncated here for length - 724 real rows total)
3835           2       Checking     Movies        2026-10-07       -2217.14
3932           2       Checking     Movies        2026-10-07       -3122.14
1621           2       Checking     Movies        2026-10-09       -911.76
1394           2       Checking     Movies        2026-10-10       -1948.08
4831           2       Checking     Movies        2026-10-11       -900.09

(724 rows affected)
```

Notes:
- **What this query is doing, explained simply:** `TransactionDetails` is a saved, named query — a **view** — that joins `Transactions`, `Accounts`, and `Categories` together so that the account's name and the category's actual name show up right next to each transaction, instead of just raw `AccountID`/`CategoryID` numbers. Once it's created, it can be queried with a plain `select` exactly like a real table — `select * from TransactionDetails where ...` — even though there's no actual table called `TransactionDetails` storing any data; SQL Server runs the real underlying join every time the view is queried.

  A real-life version of this: think of a label-maker that always prints an item's full name instead of a barcode. The warehouse's real database still stores everything by barcode/ID, but the label-maker view presents it in human-readable form on demand — nothing about the warehouse itself changed, just how the information is being looked at.

  Where this shows up in real life: views are used constantly to hide a messy or complex join behind a simple, friendly name, so every report, dashboard, or other query that needs "transactions with real account/category names" can just say `from TransactionDetails` instead of re-writing the same three-table join over and over.

  The same thing, step by step, in plain words:
  step 1 — `create view TransactionDetails as <select ...>` saves the join query itself, under a name, without actually running it or storing any rows yet.
  step 2 — the `select * from TransactionDetails where UserID = 2 and CategoryName = 'Movies' order by TransactionDate` runs against the view exactly like it would against a real table — filtering, ordering, and all.
  step 3 — behind the scenes, SQL Server substitutes the view's saved definition in and runs the real three-table join, then applies the `where`/`order by` on top of that join's result.
  step 4 — the real result came back as 724 rows — meaning User 2 has 724 real Movies transactions across the entire seeded dataset, not just the one July slice earlier pieces have been looking at.
- **What this query is doing, technical step-by-step, and a real discovery about this project's own data:** a plain view like this one is **not** materialized — it stores no rows of its own, only the query text, so every single time it's queried, SQL Server re-runs the underlying join fresh (the opposite tradeoff from a materialized/indexed view, which would store the join's result physically and need to be kept in sync on every write — not what was built here). The real dates in this result — spanning from `2024-10-13` all the way to `2026-10-11` — are a genuinely useful discovery: every earlier piece since the bulk-seed (Pieces 26 through 31) only ever filtered down to a single month, July 2026, so the fact that the 5,000 bulk-seeded rows from Piece 25 actually span roughly two full years — ending right at today's real date — was never visible until this view's query ran with no date filter at all. That's a real, honest side-effect of writing a broader query: it surfaces the true shape of the underlying data, not just the narrow slice earlier pieces happened to look at.
- **How this connects to `09 sql stored procedures views.md`:** this proves the core distinction between a stored procedure and a view from Piece 31: a procedure has to be `exec`uted and can contain multiple statements/logic, while a view is queried directly with ordinary `select`/`where`/`order by`/`join` syntax, behaving exactly like a real table to anything that queries it — exactly what just happened here.
- **What this is really answering (interview-style scenario):** "what's the difference between a view and a stored procedure, and when would you use each?" — a view is for reusing a *shape of data* that needs to be queried flexibly (filtered, sorted, joined further) like this one was; a stored procedure is for reusing a *unit of logic* that gets executed with specific inputs, like Piece 31's parameterized lookup. This project now has a real, working example of both, built the same day, on the same underlying tables.

Questions along the way: none — understood on the first pass.

---

Views are proven for real, closing out stored procedures and views together. Checking back against the project's locked spec (`finance tracker spec.md`), the "required coverage" checklist still has one item open: isolation levels **and deadlocks** — Piece 30 proved isolation levels (a real dirty read), but a deadlock specifically needs its own fresh two-window demo, not reused from the earlier `08 sql acid concurrency.md` doc, per the spec's explicit instruction.

The clearest way to prove a real deadlock on this project's own data is the classic circular-wait setup: two sessions each update one account first (taking out a lock on it), then each tries to update the *other* session's already-locked account — a real cycle that SQL Server's deadlock monitor has to detect and break by picking one session as the victim.

## Piece 33 — deadlocks — a live two-window circular-wait demo, with a real deadlock victim

```sql
-- window A
begin transaction;

update Accounts
set Balance = Balance - 10.00
where AccountID = 1;

-- window B
begin transaction;

update Accounts
set Balance = Balance - 10.00
where AccountID = 2;

-- window A (blocks here, waiting on window B's lock)
update Accounts
set Balance = Balance - 10.00
where AccountID = 2;

-- window B (this closes the cycle)
update Accounts
set Balance = Balance - 10.00
where AccountID = 1;

-- window B
rollback transaction;

select
    AccountID,
    Balance
from Accounts
order by AccountID;
```

Confirmed real output:

```
-- Window A: update succeeds, transaction stays open
-- (1 row affected)

-- Window B: update succeeds, transaction stays open
-- (1 row affected)

-- Window A: tries to update Account 2, blocks ("Executing query...")

-- Window B: tries to update Account 1, closes the cycle
-- (1 row affected)

-- Window A, immediately after: real deadlock error
Msg 1205, Level 13, State 51, Line 3
Transaction (Process ID 69) was deadlocked on lock resources with another process and has been chosen as the deadlock victim. Rerun the transaction.

-- Window B: rollback transaction;
-- Commands completed successfully.

AccountID  Balance
---------  -------
1          0.00
2          0.00
3          0.00

(3 rows affected)
```

Notes:
- **What this query is doing, explained simply:** this builds a genuine deadlock on purpose. Window A grabs Account 1 first and holds onto it; Window B grabs Account 2 first and holds onto it. Then each one tries to also grab the *other's* account — Window A reaches for Account 2 (stuck waiting, since B is holding it), and Window B reaches for Account 1 (which A is holding). Now both sessions are stuck waiting on each other forever, with no way out on their own — that's a deadlock. SQL Server has a built-in deadlock monitor that notices this exact situation and forcibly kills one of the two sessions (picked by internal cost rules, not something either session controls) so the other one can finish. Here, Window A was the one killed — its transaction got automatically rolled back, and it received the real `Msg 1205` error telling it exactly that.

  A real-life version of this: two people cooking in a kitchen, each holding one knife, and each one refuses to put their own knife down until they can also grab the other person's knife. Neither will ever get both knives this way — they're stuck forever, unless someone (a referee) steps in and makes one of them put their knife down. SQL Server is that referee, and it always intervenes rather than letting both sessions wait forever.

  Where this shows up in real life: deadlocks happen in any real multi-user system (a bank, a ticket-booking site, an inventory system) whenever two transactions update the same two rows in opposite order at roughly the same time — genuinely common under real concurrent load, not a rare edge case, which is exactly why every production database has an automatic deadlock detector rather than just letting both sides hang.

  The same thing, step by step, in plain words:
  step 1 — Window A opens a transaction and updates Account 1, holding a lock on that row.
  step 2 — Window B opens a transaction and updates Account 2, holding a lock on that row.
  step 3 — Window A then tries to update Account 2 too, but Window B is holding that row's lock — Window A has to wait.
  step 4 — Window B then tries to update Account 1 too, but Window A is holding that row's lock — now both sessions are waiting on each other, a genuine circular wait.
  step 5 — SQL Server's deadlock monitor detects the cycle almost immediately, picks Window A as the victim, and automatically rolls back Window A's entire transaction, releasing its lock on Account 1.
  step 6 — with Account 1's lock now free, Window B's blocked update finally goes through, successfully updating Account 1 too, inside Window B's own still-open transaction.
- **What this query is doing, technical step-by-step:** SQL Server's lock manager builds an internal wait-for graph as sessions request locks already held by other sessions; when that graph forms a cycle (A waits for B, B waits for A), the deadlock monitor (which runs on a periodic interval, by default every few seconds) detects it and ends the standoff by choosing a victim — generally the transaction that would be cheapest to undo — and kills it with error 1205, automatically rolling back everything that session had done. Window B's own transaction stayed open and unbroken the whole time, so when its `rollback transaction` finally ran, it correctly undid *both* of its own pending changes together — Account 2's `-10.00` and Account 1's `-10.00` — restoring both back to their real original value, `0.00`. That's exactly what a single `rollback` is supposed to do to every change made since that session's `begin transaction`: all of it, together, not one row at a time.
- **How this connects to `08 sql acid concurrency.md`/`07 sql transactions acid.md`:** this is a fresh, live, two-window deadlock proof specifically for this project's own data and its own `Accounts` table — required separately from the earlier `08 sql acid concurrency.md` doc's own deadlock demo, per this project's locked spec, so the coverage isn't just reused from an earlier doc.
- **What this is really answering (interview-style scenario):** "what's a deadlock, and what does the database actually do about it?" — a deadlock is a circular lock-wait between two transactions that can never resolve on its own, and every production database (SQL Server included) runs an automatic deadlock monitor that detects the cycle and kills one side with a specific, catchable error (1205) so the other side can proceed — the practical takeaway being that application code calling the database should expect and retry on this specific error, not treat it as a fatal bug.

Questions along the way: none — understood on the first pass.

---

Required coverage is now fully proven on real, live data: every join type, set operators, window functions, a recursive CTE over the Categories hierarchy, a real before/after indexing story (non-covering then covering), a real atomicity/rollback demo, isolation levels (a live dirty-read), a real deadlock with a genuine victim, a parameterized stored procedure, and a view — all run for real and verified against the project's own `FinanceTrackerDB`. What's left, per the locked spec, are the project's final deliverables: a decisions log and a README tying the whole build together.

The project itself is done. Next is just writing the decisions log and the README.






