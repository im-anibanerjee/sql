# 02 · SQL Joins (SQL Server / T-SQL)

## The schema we're using

Same three tables as `01 sql fundamentals.md` - `Accounts`, `Categories`, `Transactions` - in `InterviewPrepSQL`. Nothing new was created for this doc; joins work *across* tables that already exist, so the same schema and the same two deliberate gaps from doc 01 do all the work here too:

- **Account 4 (Investment) has zero transactions.** This is what makes a left/right/full join actually show something different from an inner join - an account with nothing to match against.
- **Transaction 105 has `AccountID = NULL`.** This is the other side of the same coin - a transaction with nothing to match against.
- **`Accounts.ParentAccountID`** is self-referencing (`Sub-Savings (Kids)` → `ParentAccountID = 2`, pointing back at `Savings`). This is what makes a self join demonstrable - a table joined to itself through its own foreign key.

Here's the actual data every join below runs against, straight from doc 01's real SSMS output:

| AccountID | AccountName | AccountType | ParentAccountID |
|---|---|---|---|
| 1 | Checking | Checking | NULL |
| 2 | Savings | Savings | NULL |
| 3 | Sub-Savings (Kids) | Savings | 2 |
| 4 | Investment | Investment | NULL |

| TransactionID | AccountID | CategoryID | TransactionDate | Amount |
|---|---|---|---|---|
| 101 | 1 | 1 | 2026-01-05 | -50.00 |
| 102 | 1 | 2 | 2026-01-10 | -20.00 |
| 103 | 2 | 1 | 2026-01-12 | 500.00 |
| 104 | 3 | 1 | 2026-01-15 | -10.00 |
| 105 | NULL | 2 | 2026-01-20 | -15.00 |

Every join below is run against this same five-transaction, four-account dataset, so the same two gaps keep showing up in a new shape each time.

---

## 1. `inner join` - only the rows that match on both sides

Find every transaction together with the name of the account it belongs to.

so this question is asking us to find every transaction paired with its account's name - but only for transactions that actually have a matching account.

```sql
select
    a.AccountName,
    t.TransactionID,
    t.Amount
from Accounts a
inner join Transactions t on t.AccountID = a.AccountID
```

Real output:

| AccountName | TransactionID | Amount |
|---|---|---|
| Checking | 101 | -50.00 |
| Checking | 102 | -20.00 |
| Savings | 103 | 500.00 |
| Sub-Savings (Kids) | 104 | -10.00 |

*(4 rows affected)*

Tracing every possible `Accounts`×`Transactions` pairing against the `on` condition - `inner join` keeps a pairing only when it's `TRUE`:

```
Checking(1)            ↔ 101(AccountID=1) → match → kept
Checking(1)            ↔ 102(AccountID=1) → match → kept
Savings(2)              ↔ 103(AccountID=2) → match → kept
Sub-Savings (Kids)(3)  ↔ 104(AccountID=3) → match → kept
Investment(4)           ↔ nothing has AccountID=4         → no match → dropped entirely
(no account)             ↔ 105(AccountID=NULL)            → NULL never equals 4, or anything → dropped entirely
```

Two different kinds of row vanished here, for two different reasons that happen to produce the same result: **Investment never appears** because nothing in `Transactions` points at it, and **transaction 105 never appears** because its `AccountID` is `NULL`, and `NULL = 4` (or `NULL` = any account ID) is never `TRUE` - this is the exact same three-valued-logic rule from doc 01's `where`/`group by` sections, just now deciding whether a *join* match happens instead of whether a row survives a filter. `inner join` only ever shows you the overlap - both gaps built into this schema are invisible here, on purpose.

---

## 2. `left join` - every row from the left table, matched or not

Find every account together with its transactions, including accounts that don't have any.

so this question is asking us to find every account, whether or not it has a matching transaction - account information should never disappear just because there's nothing to join it to.

```sql
select
    a.AccountName,
    t.TransactionID,
    t.Amount
from Accounts a
left join Transactions t on t.AccountID = a.AccountID
```

Real output:

| AccountName | TransactionID | Amount |
|---|---|---|
| Checking | 101 | -50.00 |
| Checking | 102 | -20.00 |
| Savings | 103 | 500.00 |
| Sub-Savings (Kids) | 104 | -10.00 |
| Investment | NULL | NULL |

*(5 rows affected)*

Same four matched rows as the inner join, plus one more: **Investment now appears**, with `NULL` standing in for every column that would have come from `Transactions`. `left join` means "keep every row from the table on the left (`Accounts`) no matter what - if nothing on the right matches, fill the right side's columns with `NULL` instead of dropping the row." Investment is the left table's only unmatched row, so it's the only one that gets this treatment.

**Transaction 105 is still missing here** - and that's correct, not a bug. `left join` only guarantees every row from the *left* table survives; it says nothing about the right table. Transaction 105 is a row in `Transactions` (the right table) with no match, so it's dropped exactly like it was in the inner join. Left and right are not interchangeable - which table you put on which side decides which gap this query is capable of showing you.

---

## 3. `right join` - every row from the right table, matched or not

Find every transaction together with its account, including transactions that don't have one.

so this question is asking us to find every transaction, whether or not it has a matching account - transaction information should never disappear just because the account link is missing.

```sql
select
    a.AccountName,
    t.TransactionID,
    t.Amount
from Accounts a
right join Transactions t on t.AccountID = a.AccountID
```

Real output:

| AccountName | TransactionID | Amount |
|---|---|---|
| Checking | 101 | -50.00 |
| Checking | 102 | -20.00 |
| Savings | 103 | 500.00 |
| Sub-Savings (Kids) | 104 | -10.00 |
| NULL | 105 | -15.00 |

*(5 rows affected)*

This is the mirror image of the left join: the same four matched rows, plus **transaction 105**, now kept with `AccountName = NULL` because nothing in `Accounts` has `AccountID = NULL` to match it against. `right join` keeps every row from the table on the right (`Transactions`) no matter what, and fills in `NULL` on the left (`Accounts`) side when there's no match.

**Investment is missing here**, for the same reason transaction 105 was missing from the left join - `right join` makes no promise about the left table, and Investment is an unmatched row in the left table. `Accounts a right join Transactions t` is written the exact same syntactic shape as the left join above, just with the guarantee pointed at the other table - which is exactly why `a left join b` and `b right join a` give you the same result: they're the same join, described from opposite ends.

---

## 4. `full outer join` - every row from both sides, matched or not

Find every account and every transaction together, matched up wherever possible, with nothing dropped from either side.

so this question is asking us to find the complete picture - every account (even with no transactions) and every transaction (even with no account) in one result, not just the rows that happen to line up.

```sql
select
    a.AccountName,
    t.TransactionID,
    t.Amount
from Accounts a
full outer join Transactions t on t.AccountID = a.AccountID
```

Real output:

| AccountName | TransactionID | Amount |
|---|---|---|
| Checking | 101 | -50.00 |
| Checking | 102 | -20.00 |
| Savings | 103 | 500.00 |
| Sub-Savings (Kids) | 104 | -10.00 |
| Investment | NULL | NULL |
| NULL | 105 | -15.00 |

*(6 rows affected)*

This is the one join that shows **both gaps at once**: the 4 matched rows, plus Investment (unmatched on the left, same as the left join surfaced), plus transaction 105 (unmatched on the right, same as the right join surfaced). `full outer join` is literally "do a left join's job and a right join's job at the same time, then combine the results" - nothing from either table is ever silently dropped just because the other side has nothing to offer it. 6 rows is the largest result of any join type here, because it's the only one not willing to lose a row from either table.

---

## 5. Self join - a table joined to its own rows

For every account, show its own name next to the name of its parent account, if it has one.

so this question is asking us to find each account's parent account by name, not just the raw `ParentAccountID` number - and accounts with no parent should still show up, just with a blank parent.

```sql
select
    child.AccountName as ChildAccount,
    parent.AccountName as ParentAccount
from Accounts child
left join Accounts parent on child.ParentAccountID = parent.AccountID
```

Real output:

| ChildAccount | ParentAccount |
|---|---|
| Checking | NULL |
| Savings | NULL |
| Sub-Savings (Kids) | Savings |
| Investment | NULL |

*(4 rows affected)*

There's only one table here - `Accounts` - but the query treats it as if it were two separate tables by giving it two different aliases, `child` and `parent`. SQL Server doesn't know or care that they're "the same table" - as far as the join logic is concerned, `child` and `parent` are just two row-sources to match up, exactly like `Accounts` and `Transactions` were above. That's all a self join is: an ordinary join where both sides happen to come from the same table.

Tracing it one child row at a time:

```
Checking(ParentAccountID=NULL)             ↔ parent.AccountID=NULL → no match (null=null isn't true) → kept, ParentAccount=NULL
Savings(ParentAccountID=NULL)              ↔ parent.AccountID=NULL → no match                          → kept, ParentAccount=NULL
Sub-Savings (Kids)(ParentAccountID=2)      ↔ parent.AccountID=2    → matches Savings                   → kept, ParentAccount=Savings
Investment(ParentAccountID=NULL)           ↔ parent.AccountID=NULL → no match                          → kept, ParentAccount=NULL
```

`left join` was used deliberately here, not `inner join` - three of the four accounts have no parent at all (`ParentAccountID = NULL`), and an `inner join` would have thrown all three of them away, leaving only `Sub-Savings (Kids)` in the result. `left join` keeps every child account regardless of whether a parent match exists, which is almost always what you actually want from a self join over a hierarchy (employees and their managers, categories and their parent categories, accounts and their parent accounts) - most rows at the top of a hierarchy have no parent, and losing them from the result would be wrong, not just incomplete.

---

## Quick reference: what each join keeps

| Join type | Guarantees every row from... | Unmatched side filled with |
|---|---|---|
| `inner join` | neither table | nothing - unmatched rows from either side are dropped entirely |
| `left join` | the left table | `NULL` on every column from the right table |
| `right join` | the right table | `NULL` on every column from the left table |
| `full outer join` | both tables | `NULL` on whichever side didn't have a match |
| self join | depends on `inner`/`left`/etc. used | a self join isn't its own join type - it's any of the above, run with both sides pointing at the same table |

---

## Interview questions

1. What's the difference between an inner join and a left join, in terms of what can get dropped from the result?
2. Why did the Investment account disappear from the inner join's result, but reappear in the left join's result?
3. Why did transaction 105 disappear from both the inner join and the left join, but reappear in the right join and the full outer join?
4. If `a left join b` and `b right join a` (same `on` condition) always produce the same result, why does SQL even have a `right join` keyword?
5. What does a full outer join actually combine - what are the two things being unioned together?
6. What is a self join, mechanically? Is there a dedicated SQL keyword for it, or is it just a regular join with a twist?
7. In the self-join example, why does `Checking` show `NULL` as its parent account instead of being dropped from the result entirely?
8. If the self-join query used `inner join` instead of `left join`, which accounts would disappear from the result, and why?
9. What's the actual difference between putting a condition in the `on` clause versus the `where` clause of a join - does it matter for every join type, or only some?
10. Can a single query join more than two tables? What does the second join's `on` clause actually refer to?
11. What's a cross join, and how is it fundamentally different from every join type covered above?
12. If two tables have no matching rows at all, what does an inner join between them return? What about a full outer join?

---

## Practice database

Same `InterviewPrepSQLPractice` database from doc 01 - `Departments` and `Employees`, with real foreign key constraints this time, including the self-referencing `ManagerID`. No new setup needed; it already exists from the fundamentals doc, and it's a better fit for practicing joins than `InterviewPrepSQL` since `Employees.ManagerID` gives a second, independent self-join to practice on top of the `Departments`/`Employees` relationship.

## Practice questions

Write each of these yourself in SSMS against `InterviewPrepSQLPractice` - type it, run it, and paste back both your query and the real output.

1. List every employee's first name, last name, and department name, using an inner join. (Think about who this leaves out before you run it.)
2. Repeat question 1, but make sure every employee shows up even if they have no department at all.
3. List every department's name together with the first and last names of its employees, making sure every department shows up even if it has no employees at all.
4. For every employee, show their own name next to their manager's name, using a self join on `Employees`. Employees with no manager should still appear, with a blank manager name.
5. List every employee's first name, department name, and manager's name, all in one query, using two joins at once.

Once you've run all five and have real output, paste it back and I'll grade it against a hand-verified answer key.
