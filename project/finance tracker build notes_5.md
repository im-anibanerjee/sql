This file picks up after the decisions log and README were written. The one open item left from the decisions log — "no transfer procedure exists" — is closed here: a real `TransferFunds` stored procedure was built, and the ACID, isolation-level, and deadlock demos were re-run for real against it specifically, exactly as the spec's §3 decision had asked for.

Everything below was run for real in SSMS against this project's own `FinanceTrackerDB`, with Claude driving the mouse and keyboard directly (computer use) rather than the usual "you run it, I verify" pattern — the user explicitly authorized this for this piece of work, since the cloud environment Claude normally works from has no network path to this machine's local SQL Server instance.

## Piece 34 — a real `TransferFunds` stored procedure, closing the spec's long-standing gap

```sql
create procedure TransferFunds
    @FromAccountID int,
    @ToAccountID int,
    @Amount decimal(10,2),
    @SimulateDelay bit = 0
as
begin
    set nocount on;

    begin try
        if @FromAccountID = @ToAccountID
            throw 50000, 'Source and destination accounts must be different.', 1;

        if @Amount <= 0
            throw 50004, 'Transfer amount must be greater than zero.', 1;

        begin transaction;

        if not exists (select 1 from Accounts where AccountID = @FromAccountID)
            throw 50001, 'Source account does not exist.', 1;

        if (select Balance from Accounts where AccountID = @FromAccountID) < @Amount
            throw 50003, 'Insufficient funds in source account.', 1;

        update Accounts
        set Balance = Balance - @Amount
        where AccountID = @FromAccountID;

        if @SimulateDelay = 1
            waitfor delay '00:00:15';

        if not exists (select 1 from Accounts where AccountID = @ToAccountID)
            throw 50002, 'Destination account does not exist.', 1;

        update Accounts
        set Balance = Balance + @Amount
        where AccountID = @ToAccountID;

        commit transaction;
    end try
    begin catch
        if @@trancount > 0
            rollback transaction;

        throw;
    end catch
end
go
```

Confirmed real output:

```
Commands completed successfully.
```

Notes:
- **What this query is doing, explained simply:** this packages up "move money from one account to another" as a single, reusable, named operation — call `TransferFunds` with a from-account, a to-account, and an amount, and it either moves the money correctly and completely, or it doesn't move it at all. Nothing in between. It checks that the two accounts aren't the same, that the amount is a real positive number, that the source account actually exists and has enough money, then takes the money out of one account and puts it into the other, as one all-or-nothing unit.

  A real-life version of this: this is a bank teller's own checklist for a transfer request, laminated and taped to the counter — check the slip isn't asking to move money from an account to itself, check the amount isn't zero or negative, check the source account is real and has enough in it, then do the debit and the credit together, never just one of them. Every teller follows the same checklist every time, instead of everyone improvising their own steps.

  Where this shows up in real life: this is exactly what sits behind the "Transfer" button in any real banking app — a single server-side operation that either completes the whole transfer or none of it, with built-in validation so a typo or a bad request can't leave an account half-debited.

  The same thing, step by step, in plain words:
  step 1 — reject the call outright if the two accounts are the same, or if the amount isn't a real positive number — no point even starting a transaction for an obviously bad request.
  step 2 — open a transaction, then check the source account actually exists and has enough balance to cover the transfer; if either check fails, the procedure throws a real error and nothing has been touched yet.
  step 3 — subtract the amount from the source account's balance — this is the one risky moment, where money has technically left one account but hasn't arrived anywhere yet.
  step 4 — an optional pause (`@SimulateDelay`), used only for the timing demos further down — real callers never set this, since it defaults to off.
  step 5 — check the destination account exists, then add the amount to it — only now has the money genuinely "arrived".
  step 6 — commit the transaction, making both changes permanent together, or if anything in the `try` block threw an error, the `catch` block rolls back everything done since `begin transaction` and re-throws the real error so the caller knows exactly what went wrong.
- **What this query is doing, technical step-by-step:** this is a `try`/`catch`-wrapped procedure built around a single explicit transaction. Validation is split deliberately: the same-account and non-positive-amount checks run *before* `begin transaction` (cheap, no need for a transaction just to reject garbage input), while the source-account-exists and sufficient-funds checks run *after* `begin transaction` but *before* the debit, so a bad source account or short balance never touches a row. The destination-account-exists check, however, is deliberately placed *after* the debit and the delay, immediately before the credit — not upfront. That ordering choice matters a lot for what happens later in Piece 37, and is explained in full there; the short version is that checking the destination account too early (reading its row before the source account is even locked) accidentally prevents two opposite-direction transfers from ever deadlocking against each other, which turned out to be worth testing on its own. `@SimulateDelay` and the `waitfor delay` exist purely so this same, real, unmodified procedure could be used to reproduce the isolation-level and deadlock demos below with a predictable pause to work with — it changes no business logic and defaults to off (`0`) for every normal call.
- **How this connects to `09 sql stored procedures views.md` and the spec's decisions log:** the decisions log flagged, across three separate sections (§6 ACID, §7 isolation/deadlocks, §8 stored procedures), that no procedure genuinely moving money between two accounts had ever been built — everything required was still proven for real, just through simpler, unrelated mechanics each time. This procedure is that missing piece, built for real and about to be re-tested for real against all three of those requirements.
- **What this is really answering (interview-style scenario):** "design a stored procedure to transfer money between two accounts, safely." — the real answer isn't just the `update`/`update` pair; it's validating inputs before opening a transaction, validating business rules (existence, sufficient funds) inside the transaction but before any write, and wrapping the whole thing in `try`/`catch` so any failure anywhere rolls back everything cleanly rather than leaving a half-done transfer.

Questions along the way: none — understood on the first pass.

---

## Piece 35 — ACID, re-proven for real against `TransferFunds` — a real successful transfer and a real deliberate failure

```sql
-- resetting Accounts 1-3 to clean, known starting balances before the TransferFunds re-test
update Accounts set Balance = 1000.00 where AccountID = 1;
update Accounts set Balance = 500.00 where AccountID = 2;
update Accounts set Balance = 0.00 where AccountID = 3;

-- a real successful transfer through TransferFunds
exec TransferFunds @FromAccountID = 1, @ToAccountID = 2, @Amount = 200.00;

select
    AccountID,
    Balance
from Accounts
order by AccountID;

-- a deliberate failing transfer (insufficient funds), proving rollback
exec TransferFunds @FromAccountID = 3, @ToAccountID = 1, @Amount = 9999.00;

select
    AccountID,
    Balance
from Accounts
order by AccountID;
```

Confirmed real output:

```
-- reset
AccountID  Balance
---------  -------
1          1000.00
2          500.00
3          0.00

(3 rows affected)

-- after the successful 200.00 transfer, Account 1 -> Account 2
AccountID  Balance
---------  -------
1          800.00
2          700.00
3          0.00

(3 rows affected)

-- the deliberate failure: Account 3 has 0.00, asked to send 9999.00
Msg 50003, Level 16, State 1, Procedure TransferFunds, Line 27 [Batch Start Line 0]
Insufficient funds in source account.

-- balances re-checked after the failed call -- unchanged
AccountID  Balance
---------  -------
1          800.00
2          700.00
3          0.00

(3 rows affected)
```

Notes:
- **What this query is doing, explained simply:** this is the real proof that `TransferFunds` keeps its all-or-nothing promise. First, a normal transfer of 200.00 from Account 1 to Account 2 runs clean — Account 1 drops by exactly 200.00, Account 2 rises by exactly 200.00, nothing else changes. Then a transfer is deliberately asked for that can't possibly work — sending 9999.00 out of Account 3, which only has 0.00 — and the procedure refuses outright with a real error. The balances afterward are checked again and are completely unchanged: not even a partial debit happened.

  A real-life version of this: asking an ATM to withdraw ₹9999 from an account that only has ₹0 in it — the machine doesn't hand over whatever cash it has and call it close enough; it refuses the whole request and your balance stays exactly what it was.

  Where this shows up in real life: this is the actual guarantee every banking system advertises — a transfer either fully happens or it doesn't happen at all, there's no "half transferred" state a customer could ever see, and that guarantee is what atomicity (the "A" in ACID) means in practice, not just in theory.

  The same thing, step by step, in plain words:
  step 1 — reset all three accounts to known, clean starting balances, so the rest of the test has a predictable baseline.
  step 2 — call `TransferFunds` for a normal, valid 200.00 transfer; it succeeds, and the real balances afterward show exactly the expected before/after math (1000 − 200 = 800, 500 + 200 = 700).
  step 3 — call `TransferFunds` again, this time asking to move far more money than Account 3 actually has; the procedure's own balance check catches this before any `update` ever runs, and throws a real, specific error (`Msg 50003`) instead of silently doing nothing or doing something wrong.
  step 4 — re-check all three balances; they're identical to what they were right before the failed call — proving the failed attempt left genuinely zero trace, not even a reverted-but-still-logged partial change.
- **What this query is doing, technical step-by-step:** the successful case exercises the procedure's normal path end to end — both `update` statements run inside the open transaction and `commit transaction` makes them permanent together. The failing case exercises the `catch` block specifically: the `throw 50003` statement raises a real SQL Server error from inside the `try` block, control immediately jumps to `begin catch`, where `if @@trancount > 0 rollback transaction` undoes everything done since `begin transaction` (in this case, nothing had been written yet, since the balance check runs before the first `update`), and then `throw;` (with no arguments) re-raises the original error up to the caller with its original message, severity, and state intact, rather than the caller just seeing a generic failure. The before/after `select` statements are the actual proof here — not the error message alone, but the fact that the real stored balances are bit-for-bit identical to their pre-attempt values.
- **How this connects to `07 sql transactions acid.md`/`08 sql acid concurrency.md` and Piece 29:** Piece 29 proved atomicity with a hand-rolled multi-statement transaction and a deliberate divide-by-zero error. This re-proves the exact same guarantee — a real failure leaving zero partial effect — but now against the actual procedure the spec's §6 had originally envisioned, with the failure being a genuine business-rule violation (insufficient funds) rather than an arithmetic error, and the procedure's own `try`/`catch`/`throw` pattern doing the rollback instead of a one-off manual rollback.
- **What this is really answering (interview-style scenario):** "how do you guarantee a money transfer never leaves an account half-updated?" — wrap both the debit and credit in one transaction, validate every business rule before the first write happens where possible, and use `try`/`catch` so any failure anywhere triggers a full rollback automatically rather than relying on the caller to clean up after a partial failure.

Questions along the way: none — understood on the first pass.

---

## Piece 36 — isolation levels, re-proven for real against `TransferFunds` — a live two-window dirty-read demo through the real procedure

```sql
-- window A: starts a real transfer with a 15-second pause mid-transaction
exec TransferFunds @FromAccountID = 2, @ToAccountID = 1, @Amount = 50.00, @SimulateDelay = 1;

-- window B, while window A's transfer is still mid-flight, under READ UNCOMMITTED
set transaction isolation level read uncommitted;
select
    AccountID,
    Balance
from Accounts
where AccountID in (1, 2)
order by AccountID;

-- window B, same accounts, now under READ COMMITTED
set transaction isolation level read committed;
select
    AccountID,
    Balance
from Accounts
where AccountID in (1, 2)
order by AccountID;
```

Confirmed real output:

```
-- window A: starts the delayed transfer (700.00 / 800.00 going in, moving 50.00 from Account 2 to Account 1)

-- window B, under READ UNCOMMITTED, caught genuinely mid-transfer:
AccountID  Balance
---------  -------
1          700.00
2          750.00

(2 rows affected)

-- window B, under READ COMMITTED, read after window A's transfer committed:
AccountID  Balance
---------  -------
1          750.00
2          750.00

(2 rows affected)

-- window A, checked afterward: Commands completed successfully.
```

Notes:
- **What this query is doing, explained simply:** `TransferFunds` debits the source account first, pauses, then credits the destination account — so for a few real seconds in the middle of any transfer, the money has genuinely left one account but hasn't arrived in the other yet. That's not a bug; every real transfer briefly passes through that in-between moment. This test catches that exact moment on camera: Window B reads both account balances twice while Window A's transfer is paused mid-flight. Under `read uncommitted`, Window B sees the in-between, not-yet-real state — Account 2 already debited to 750.00, Account 1 not yet credited (still 700.00, waiting on the pending 50.00) — money that's technically in transit. Under `read committed`, Window B's read instead reflects the real, finished, settled state once Window A's transfer has gone through.

  A real-life version of this: picture a courier who has already picked up a package from the sender's house but hasn't yet dropped it off at the receiver's house. If you check the sender's porch mid-delivery, the package is gone — but it's also not at the receiver's door yet. It's genuinely "in transit." `read uncommitted` is like being allowed to peek at the sender's now-empty porch before the delivery is actually complete, not accounting for the fact that the package hasn't arrived anywhere permanent yet.

  Where this shows up in real life: this is exactly the scenario `read committed` (SQL Server's real default) exists to prevent for anything involving money — a dashboard or report that reads `read uncommitted` data during a transfer could show a temporarily wrong total (money "missing" from both accounts at once), which is a real, visible bug a customer could notice, not just a theoretical concern.

  The same thing, step by step, in plain words:
  step 1 — Window A calls `TransferFunds` with the demo-only `@SimulateDelay = 1` flag, moving 50.00 from Account 2 to Account 1; the procedure debits Account 2 immediately, then deliberately pauses for 15 real seconds before crediting Account 1.
  step 2 — while that pause is running, Window B — explicitly set to `read uncommitted` — reads both account balances and genuinely catches the mid-transfer state: Account 2 already shows the debit (800 − 50 = 750), but Account 1 doesn't show the credit yet (still 700, not yet 750).
  step 3 — Window B then switches to `read committed` and reads the same two balances again; by now Window A's transfer has finished and committed, so this second read shows the real, final, settled values — Account 1 at 750 (700 + 50, now actually credited) and Account 2 still at 750 (unchanged since its debit, now made permanent by the commit) — the point this step proves is that the second read, under `read committed`, only ever shows a fully-settled state, never an in-between one.
  step 4 — Window A's own session is checked afterward and shows a clean "Commands completed successfully" — the transfer that Window B partially glimpsed really did complete in full.
- **What this query is doing, technical step-by-step, and the exact arithmetic:** going into this test, Account 1 was at 700.00 and Account 2 was at 800.00 (the real balances left over from the earlier ACID re-test in Piece 35, plus one earlier delayed transfer used while getting this demo's timing right). `TransferFunds @FromAccountID=2, @ToAccountID=1, @Amount=50.00` first runs `update Accounts set Balance = Balance - 50.00 where AccountID = 2`, taking Account 2 to 750.00 and holding an exclusive lock on that row for the rest of the transaction. Then it hits `waitfor delay '00:00:15'`, holding the transaction open with Account 1 still untouched at 700.00. Window B's first read, under `read uncommitted`, bypasses locking entirely (equivalent to the old `with (nolock)` hint) and reads the live, uncommitted data pages directly — correctly showing `700.00 / 750.00`, a real snapshot of money genuinely in transit: Account 2's debit is visible, but Account 1 hasn't received anything yet. After the 15-second pause, `TransferFunds` runs its second update, crediting Account 1 to 750.00 (700 + 50), then commits. Window B's second read, under `read committed`, reads the final committed values — `750.00 / 750.00` — both balances now settled, with the 50.00 having fully and visibly moved from Account 2 to Account 1.
- **How this connects to `07 sql transactions acid.md` and Piece 30:** Piece 30 proved the exact same `read uncommitted` vs `read committed` contrast using two hand-written `update`/`rollback` statements. This re-proves it against the real `TransferFunds` procedure specifically, as the spec's §7 decision required — the dirty read here is a genuine mid-transfer snapshot of a real business operation, not an artificial rollback scenario.
- **What this is really answering (interview-style scenario):** "why does the default isolation level matter for a money-transfer procedure?" — a transfer that debits one account and credits another is never instantaneous from the database's point of view; `read committed` (the real default) guarantees nobody else can observe that in-between state, while `read uncommitted` trades that safety away for not blocking — a tradeoff that's fine for rough analytics but genuinely dangerous for anything touching real account balances.

Questions along the way: none — understood on the first pass, aside from double-checking the exact before/after arithmetic above against the real numbers rather than assuming them.

---

## Piece 37 — deadlocks, re-proven for real against `TransferFunds` — a live two-window circular-wait demo, plus a real finding about validation order

The first two real attempts at this did **not** produce a deadlock, and that result turned out to be worth documenting on its own rather than just discarding.

**Attempt 1 and 2 (real, not a deadlock):** with the original version of `TransferFunds` (Piece 34's version, which checked that the *destination* account existed right at the very start of the procedure, before the source account was ever locked), two opposite-direction transfers between the same two accounts never deadlocked — they consistently just serialized. Window B's own check "does the destination account exist?" (`@ToAccountID`) reads a row that Window A was already holding an exclusive lock on (as *its own* source account), so Window B blocked on that very first check, before it had even locked anything of its own. That meant Window B could never reach the point of locking its own source account while Window A was still mid-transfer — so the two transactions could never both be waiting on each other at once, which is the actual requirement for a deadlock. The real, measured proof of this: with a 15-second demo delay, Window B's total runtime was 29 seconds (not ~15); with a 40-second delay, Window B's total runtime was ~81 seconds (not ~40) — in both cases, almost exactly double the delay, meaning Window B spent one full delay's worth of time just waiting for Window A to finish before Window B could even start its own locking sequence.

**The fix, and the real deadlock:** the destination-account check was moved from the start of the procedure to immediately before the credit `update` (right after the delay) — see Piece 34's final code above. This restores the same lock-acquisition order Piece 33's original hand-written deadlock demo used: each session locks its own source account first, then only reaches for the other account afterward. With that change, the real deadlock below was reproduced on the first attempt.

```sql
-- window A: locks Account 1 first, pauses, then wants Account 2
exec TransferFunds @FromAccountID = 1, @ToAccountID = 2, @Amount = 10.00, @SimulateDelay = 1;

-- window B: locks Account 2 first, pauses, then wants Account 1 -- started right behind window A
exec TransferFunds @FromAccountID = 2, @ToAccountID = 1, @Amount = 10.00, @SimulateDelay = 1;

select
    AccountID,
    Balance
from Accounts
order by AccountID;
```

Confirmed real output:

```
-- Window A (Process ID 63), immediately after Window B's call went through:
Msg 1205, Level 13, State 51, Procedure TransferFunds, Line 37 [Batch Start Line 0]
Transaction (Process ID 63) was deadlocked on lock resources with another process and has been chosen as the deadlock victim. Rerun the transaction.

-- Window B (Process ID 52):
Commands completed successfully.

AccountID  Balance
---------  -------
1          760.00
2          740.00
3          0.00

(3 rows affected)
```

Notes:
- **What this query is doing, explained simply:** this is the same kind of deadlock as Piece 33, but now through the real procedure instead of two hand-written `update` statements. Window A calls `TransferFunds` to send 10.00 from Account 1 to Account 2, locking Account 1 first and then pausing. Window B, started right behind it, calls `TransferFunds` to send 10.00 the other way, from Account 2 to Account 1, locking Account 2 first and then pausing. When both pauses end, Window A reaches for Account 2 (held by Window B) and Window B reaches for Account 1 (held by Window A) — each one is now stuck waiting for the other to let go, forever, on their own. SQL Server's deadlock monitor steps in, picks one side to forcibly cancel, and lets the other side finish.

  A real-life version of this: the same two-cooks-one-knife-each story from Piece 33, except this time both cooks are following the exact same laminated recipe card (the procedure) instead of improvising — proving the deadlock risk isn't about sloppy one-off code, it's an inherent risk of *any* two operations that touch the same two resources in opposite order, even a carefully written, reusable one.

  Where this shows up in real life: this is precisely why real banking systems need to think carefully about lock order inside shared procedures like a transfer function — two customers transferring money between the same two accounts in opposite directions, at the same moment, is a completely ordinary, realistic scenario, not a rare edge case, and the system has to survive it gracefully rather than hanging.

  The same thing, step by step, in plain words:
  step 1 — Window A calls `TransferFunds`, which locks Account 1 (its source account) and then pauses.
  step 2 — Window B, started moments later, calls `TransferFunds` the other direction, locking Account 2 (its own source account) and then pausing.
  step 3 — Window A's pause ends first; it tries to lock Account 2 next (its destination), but Window B is still holding it — Window A blocks.
  step 4 — Window B's pause ends shortly after; it tries to lock Account 1 next (its destination), but Window A is still holding it, and is now itself blocked waiting on Window B — a genuine circular wait.
  step 5 — SQL Server's deadlock monitor detects the cycle and picks Window A (Process ID 63) as the victim, automatically rolling back its entire transaction and releasing its lock on Account 1.
  step 6 — with Account 1 now free, Window B's blocked update goes through, and Window B's own transaction — never broken, never rolled back — commits both of its changes together: Account 2 debited by 10.00, Account 1 credited by 10.00.
- **What this query is doing, technical step-by-step, including why the first two attempts didn't deadlock:** a true deadlock needs two sessions to form an actual *cycle* in SQL Server's internal wait-for graph — A waiting on a resource B holds, and B simultaneously waiting on a resource A holds. The original procedure's upfront destination-account check broke that symmetry: Window B's very first read inside its own transaction (checking that Account 1, its destination, exists) needed a shared lock on a row Window A already held exclusively — so Window B started waiting on Window A *before* Window B had locked anything of its own. That's ordinary blocking, not a deadlock, because only one side (B) was ever actually waiting; A was never waiting on anything B held, since B hadn't acquired or held any lock yet. Moving that same check to just before the credit `update` means both sessions now lock their own source account *first*, unconditionally, before ever touching the other account — restoring the symmetric lock order a real deadlock requires. With that change, Window A's attempt to lock Account 2 and Window B's attempt to lock Account 1 landed close enough together that each was genuinely waiting on the other at the same time, and SQL Server's periodic deadlock monitor (which scans for exactly this kind of cycle) detected it and killed Process ID 63 (Window A) as the victim, auto-rolling-back its transaction. Window B's own transaction was never interrupted, so its final commit applied both of its pending changes together, which the real before/after balances confirm: starting from 750.00 / 750.00, only Window B's 10.00 transfer (Account 2 → Account 1) actually took effect, landing at 760.00 / 740.00 — exactly matching a single successful 10.00 transfer and nothing from Window A's rolled-back attempt.
- **How this connects to `08 sql acid concurrency.md` and Piece 33:** this is the fresh, live, two-window deadlock demo the spec's §3 and §7 decisions required specifically against this project's own transfer procedure, not reused from Piece 33's hand-written version or from the earlier teaching doc. It also surfaces a real lesson Piece 33 couldn't have, since Piece 33 never involved a procedure with its own validation logic: *where* a procedure checks its inputs relative to where it takes its locks can be the difference between two conflicting operations deadlocking versus just safely serializing — which is a genuinely useful, non-obvious thing to know when designing any procedure that touches more than one row.
- **What this is really answering (interview-style scenario):** "can two calls to the same transfer procedure deadlock each other, and how would you reason about it?" — yes, if the procedure locks its two resources in an order that can run in either direction depending on which account is the source; the real, demonstrated fix isn't to avoid transactions or locking, it's to be deliberate about validation and lock order, and to design the caller (or the procedure itself) to expect and retry on error 1205 rather than treating a deadlock as a fatal, unrecoverable failure.

Questions along the way: none — the first two non-deadlocking attempts prompted real investigation into *why*, rather than being treated as a failed demo to just retry blindly.

