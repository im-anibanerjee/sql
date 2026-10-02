# 01 · SQL Fundamentals (SQL Server / T-SQL)

## The schema we're using

Three tables, deliberately shaped so real edge cases show up in the output instead of being hand-waved:

**Accounts**

| Column | Type |
|---|---|
| AccountID | int (PK) |
| AccountName | varchar(50) |
| AccountType | varchar(20) |
| ParentAccountID | int (NULL-able) |

**Categories**

| Column | Type |
|---|---|
| CategoryID | int (PK) |
| CategoryName | varchar(30) |

**Transactions**

| Column | Type |
|---|---|
| TransactionID | int (PK) |
| AccountID | int (NULL-able) |
| CategoryID | int (NULL-able) |
| TransactionDate | date |
| Amount | decimal(10,2) |

`Transactions.AccountID` → `Accounts.AccountID`, `Transactions.CategoryID` → `Categories.CategoryID`, `Accounts.ParentAccountID` → `Accounts.AccountID` (self-referencing, used later for the self-join demo). No FK constraints actually enforce these relationships in this schema — see section 2 for why that's deliberate.

Data:

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
| 103 | 2 | 3 | 2026-01-12 | 500.00 |
| 104 | 3 | 1 | 2026-01-15 | -10.00 |
| 105 | NULL | 2 | 2026-01-20 | -15.00 |

Account 4 (Investment) has zero transactions on purpose. Transaction 105 has no `AccountID` on purpose. Both show up as real gaps later in this doc instead of being described abstractly.

---

## 1. SQL command categories: DDL, DML, DCL, TCL

Every SQL statement falls into one of four buckets, by what it actually does to the database:

- **DDL (Data Definition Language)** — defines or changes the *structure* itself: `create`, `alter`, `drop`, `truncate`. Creating a database, creating a table, adding a column, dropping a table — none of these touch the rows inside a table, they touch the table (or database) itself.
- **DML (Data Manipulation Language)** — works with the *data inside* structures that already exist: `insert`, `update`, `delete`. (`select` reads data rather than manipulating it, so some material calls it out separately as **DQL**, Data Query Language — SQL Server's own documentation and most textbooks still fold it into DML since it's the fourth of the classic "CRUD" verbs; both groupings are common, so don't be thrown if a source you read draws that line differently.)
- **DCL (Data Control Language)** — permissions: `grant`, `revoke`, `deny`. Not used anywhere in this series yet — nobody's managing multi-user access on a personal practice database — but it's the real answer to "who's allowed to do what" in a production system.
- **TCL (Transaction Control Language)** — `begin transaction`, `commit`, `rollback`, `savepoint`. This is where **ACID** lives — Atomicity, Consistency, Isolation, Durability, the four guarantees a transaction gives you (either all its changes happen or none do; the database never ends up in a half-updated state; concurrent transactions don't corrupt each other; once committed, a change survives a crash). Not just the acronym here — full, hands-on treatment (including what can go wrong without it) is `07 sql acid concurrency.md`'s entire job, so it isn't repeated in miniature in this doc.

### The database and tables you actually created — as real DDL

These are the exact statements you ran to set up `InterviewPrepSQL` (and, earlier, to drop `MyDatabase`/`SalesDB`) — both DDL, both verified against your real SSMS session, not reproduced from memory:

Write the DDL to create the Accounts, Categories, and Transactions tables, including their primary keys and nullable columns.

so this script is asking us to create the database itself, then the three tables (`Accounts`, `Categories`, `Transactions`) with their columns, types, and primary keys. nothing here reads or returns any data — it only builds the structure that every later query in this doc runs against.

```sql
create database InterviewPrepSQL;
go
use InterviewPrepSQL;
go

create table Accounts (
    AccountID int primary key,
    AccountName varchar(50) not null,
    AccountType varchar(20) not null,
    ParentAccountID int null
);

create table Categories (
    CategoryID int primary key,
    CategoryName varchar(30) not null
);

create table Transactions (
    TransactionID int primary key,
    AccountID int null,
    CategoryID int null,
    TransactionDate date not null,
    Amount decimal(10,2) not null
);
go
```

What each piece is actually saying:

- **`create database InterviewPrepSQL;`** — creates the database itself, a fresh, empty container with nothing in it yet. `use InterviewPrepSQL;` right after switches the session's active database, so every statement after it runs against this new database rather than whichever one SSMS had open before (`master`, by default) — leave that out and the `create table`s below would either fail or land in the wrong database.
- **`AccountID int primary key`** — the data type (`int`, a whole number) and the constraint (`primary key`) declared together, right on the column. This is the same primary key you queried for real out of `sys.key_constraints` in section 2 below — this line is *why* that query found one.
- **`varchar(50) not null`** — a variable-length string, up to 50 characters, that can never be `null`. `varchar(n)` only uses as much storage as the actual string needs (up to the `n` cap), unlike `char(n)`, which always pads out to exactly `n` characters — worth knowing which one you reached for and why the next time you design a table.
- **`AccountID int null`** (on `Transactions`) — explicitly allowed to be `null`. This is the column that holds transaction 105's missing account link from earlier in this doc; without `null` being explicitly permitted here (or if it were declared `not null`), that row could never have been inserted the way it was.
- **`decimal(10,2)`** — a fixed-point number with 10 total digits, 2 of them after the decimal point. This is deliberately *not* `float`: money should never be stored as a floating-point type, because floating-point can't represent every decimal value exactly (the classic `0.1 + 0.2 ≠ 0.3` problem) — `decimal` stores the exact value you put in, which is why `Amount` is defined this way here.

### DDL vs. DML — visible in your own SSMS output, not just in theory

Here's something you can point at directly: when you ran the setup script, the only lines SSMS printed back were these three:

```
(4 rows affected)
(4 rows affected)
(5 rows affected)
```

Three lines, for three statements — but the script had *seven* statements in it (1 `create database`, 3 `create table`, 3 `insert`). The `create database` and all three `create table` statements printed **nothing at all** when they succeeded. The three `insert` statements each printed `(N rows affected)`, matching exactly how many rows each one added (4 into `Accounts`, 4 into `Categories`, 5 into `Transactions`).

That's DDL vs. DML showing up as an actual, observable difference, not just a category to memorize: DDL changes structure and either succeeds silently or throws an error — there's no "how many rows" to report, because it's not operating on rows. DML changes rows, so SQL Server tells you how many it touched, every time, whether that's an `insert`, `update`, or `delete`.

## 2. The relational model & keys

### What a relational database actually is

Data lives in **tables** (rows × columns). A **primary key (PK)** is the column (or columns) that uniquely identifies a row in that table — no two rows can share one, and it can't be NULL. A **foreign key (FK)** is a column in one table whose values are expected to match a primary key in another table — that's what turns two separate tables into a *relationship* (a transaction *belongs to* an account) instead of two unrelated piles of data.

That's the theory. Here's what it actually looks like in a database you didn't design yourself, straight from SQL Server's own metadata:

Write a query that lists every table's primary key column, using SQL Server's own system catalog views instead of a diagram.

so this question is asking us to find every table's primary key column — pulled straight from SQL Server's own metadata, not from a diagram or from memory.

```sql
select
    t.name as TableName,
    c.name as ColumnName,
    kc.name as PrimaryKeyConstraintName
from sys.tables t
join sys.key_constraints kc on kc.parent_object_id = t.object_id and kc.type = 'PK'
join sys.index_columns ic on ic.object_id = t.object_id and ic.index_id = kc.unique_index_id
join sys.columns c on c.object_id = t.object_id and c.column_id = ic.column_id
order by t.name;
```

Real output:

| TableName | ColumnName | PrimaryKeyConstraintName |
|---|---|---|
| Accounts | AccountID | PK__Accounts__349DA586AF692E3A |
| Categories | CategoryID | PK__Categori__19093A2B1DE6C945 |
| Transactions | TransactionID | PK__Transact__55433A4B84B8B682 |

*(3 rows affected)*

Two things worth noticing that you can't get from a textbook definition:

- **This query doesn't touch `Accounts`/`Categories`/`Transactions` at all** — it queries `sys.tables`, `sys.key_constraints`, `sys.index_columns`, `sys.columns`. Every SQL Server database ships with these system catalog views, and they're how SSMS itself, and every tool that inspects a database, actually knows what's in it. Worth remembering: "what are the keys on this table" is itself just a SQL query against metadata, not something you have to go find in a diagram.
- **`PK__Accounts__349DA586AF692E3A`** is a name nobody typed. Since the `create table` statement just said `AccountID int primary key` without naming the constraint, SQL Server auto-generated one: `PK__` + a truncated table name + a hex hash. In a real production schema you'd usually name these explicitly (`PK_Accounts`) so they're readable in error messages later — an auto-generated name like this in a constraint-violation error is a real, mildly annoying thing you'll hit and now know the shape of.

### A closer look at `sys.tables`, `sys.key_constraints`, `sys.index_columns`, `sys.columns` — so this actually sticks

**In plain language:** SQL Server keeps its own private notes about every database you create — which tables exist, which columns each one has, which constraints are on them. You never fill these notes in yourself; SQL Server writes them automatically the instant you run `create table`, `alter table`, and so on. Reading them back is nothing special — it's an ordinary `select`, the same syntax as querying your own data. The only thing different is *what* they contain: information about your database's structure, not your actual account/transaction data.

**Real-life example:** think of a library. The books on the shelves are your real tables (`Accounts`, `Categories`, `Transactions`) holding your real data. But the library *also* keeps a catalog system — "which books exist, which shelf, which section" — so nobody has to walk every aisle to know what the library owns; they check the catalog instead. `sys.tables` is exactly that catalog for your database: one row per table that exists, whether or not anyone ever looks inside it.

**Real-world use case:** every time you expand a database in SSMS's Object Explorer (the tree on the left) and see the list of tables, columns, and keys, SSMS isn't reading some separately-maintained diagram — it's running queries against these exact `sys.*` views, live, to build that tree on the fly. The same thing happens when a Python or C# ORM (SQLAlchemy, Entity Framework) "auto-discovers" your schema, or when a migration tool checks "does this column already exist before I try to add it." All of that is `sys.*` queries under the hood, not magic.

**Technical deep dive — what each view actually is, and the one column of it this query cares about:**

| View | One row per... | Columns this query uses | Real-life analogy |
|---|---|---|---|
| `sys.tables` | every table in the database | `object_id` (an internal ID number SQL Server assigns the table), `name` | The library's master shelf list |
| `sys.key_constraints` | every `primary key`/`unique` constraint | `parent_object_id` (which table it belongs to), `type` (`'PK'` or `'UQ'`), `name`, `unique_index_id` | A label on one shelf: "sorted by ISBN" |
| `sys.index_columns` | every column that's part of an index (a PK is always backed by one) | `object_id`, `index_id`, `column_id` | The fine print on that label: "specifically, position #1" |
| `sys.columns` | every column of every table | `object_id`, `column_id`, `name` | The master list translating "position #1" back into an actual name |

Now walk it through concretely for `Accounts`, one hop at a time:

1. `sys.tables` has a row that says, in effect: *"there's a table called `Accounts`; internally I'm tracking it as object `#101`."* (SQL Server's real `object_id` is a bigger, uglier number than `101` — that's a placeholder here purely to show the *shape* of the linking, not a value pulled from your database. The query at the bottom of this section shows you your own real numbers if you want them.)
2. `sys.key_constraints` has a row that says: *"object `#101` has a `PK`-type constraint named `PK__Accounts__349DA586AF692E3A`, backed by index `#1` on that table."*
3. `sys.index_columns` has a row that says: *"on object `#101`, index `#1`, column position `#1` is part of it."* This is the layer that lets a *composite* key (a PK spanning two or more columns) show up as multiple rows here, one per column — even though `Accounts`' own PK happens to be just the one column.
4. `sys.columns` has a row that says: *"on object `#101`, column position `#1` is named `AccountID`."*

The query's four `join`s are just walking that chain forward — matching `object_id` to `object_id`, and `unique_index_id`/`index_id`/`column_id` to each other — until it lands on an actual name (`AccountID`) instead of a bare internal number (`#101`, `#1`, `#1`) that means nothing on its own. That's genuinely all a `join` is doing here: the exact same "match rows by a shared ID" logic as `Transactions.AccountID → Accounts.AccountID` elsewhere in this doc, just walking across SQL Server's own bookkeeping tables instead of yours. Same three tables (`Categories`, `Transactions`) go through the identical four-hop chain — only the names and the (real, different) internal numbers change.

Want your database's *real* internal numbers instead of the `#101`/`#1` placeholders above? Run this — it's the same query, with the raw ID columns added back in so you can see them instead of just the friendly names they resolve to:

Extend the primary-key lookup query above to also return the raw internal `object_id`/`index_id`/`column_id` values behind each result.

so this question is asking us to find the exact same primary-key-to-column mapping as the query above, except this time showing the raw `object_id`/`index_id`/`column_id` numbers alongside the friendly names, so the walkthrough's `#101`/`#1` placeholders can be swapped for your database's real numbers.

```sql
select
    t.object_id as TableObjectID,
    t.name as TableName,
    kc.name as PrimaryKeyConstraintName,
    kc.unique_index_id as IndexID,
    ic.column_id as ColumnID,
    c.name as ColumnName
from sys.tables t
join sys.key_constraints kc on kc.parent_object_id = t.object_id and kc.type = 'PK'
join sys.index_columns ic on ic.object_id = t.object_id and ic.index_id = kc.unique_index_id
join sys.columns c on c.object_id = t.object_id and c.column_id = ic.column_id
order by t.name;
```

Paste the real output back and the walkthrough above gets redone with your actual numbers in place of the `#101`/`#1` stand-ins.

### Foreign keys — and a genuine gap worth explaining

Same idea, for foreign keys:

Write a query that lists every foreign key constraint in the database, showing which child column references which parent column.

so this question is asking us to find every foreign key constraint actually enforced on these tables — which child column points at which parent column — using the same metadata-walk as the primary-key query above, just against `sys.foreign_keys`/`sys.foreign_key_columns` instead.

```sql
select
    fk.name as ForeignKeyName,
    tp.name as ChildTable,
    cp.name as ChildColumn,
    tr.name as ParentTable,
    cr.name as ParentColumn
from sys.foreign_keys fk
join sys.foreign_key_columns fkc on fkc.constraint_object_id = fk.object_id
join sys.tables tp on tp.object_id = fkc.parent_object_id
join sys.columns cp on cp.object_id = fkc.parent_object_id and cp.column_id = fkc.parent_column_id
join sys.tables tr on tr.object_id = fkc.referenced_object_id
join sys.columns cr on cr.object_id = fkc.referenced_object_id and cr.column_id = fkc.referenced_column_id;
```

Real output:

| ForeignKeyName | ChildTable | ChildColumn | ParentTable | ParentColumn |
|---|---|---|---|---|

*(0 rows affected — the query ran cleanly against the shape above, it just found nothing to return)*

**Zero rows. That's real, and it's deliberate — not a mistake in the setup.** `Transactions.AccountID` and `Transactions.CategoryID` were created as plain `int null` columns, with no `foreign key references Accounts(AccountID)` constraint. That was on purpose: transaction 105 has `AccountID = null`, standing in for a real-world case (an uncategorized bank fee, a transaction not yet linked to an account) — and later, in the joins doc, that unmatched row is exactly what makes `right join`/`full outer join` demonstrate something real instead of a query that happens to return the same rows as `inner join`.

This is worth sitting with, because it's a genuine, defensible design trade-off, not just "we forgot":

- **With no FK constraint** (what we have): `AccountID` can be `null`, or in principle any integer at all, even one that doesn't exist in `Accounts`. Nothing stops a typo from silently creating an orphan row.
- **With a real FK constraint** (`foreign key (AccountID) references Accounts(AccountID)`): SQL Server would still allow `AccountID = null` (a FK constraint doesn't forbid NULL unless the column is also declared `not null` — NULL means "no relationship," which is different from "an invalid relationship"), but it would **reject** an `insert` or `update` that tried to set `AccountID` to a value not present in `Accounts.AccountID`. That's referential integrity: the database itself refusing to let your data contradict itself, rather than relying on application code to get it right every time.

In a real schema you're building for production, you'd almost always want that FK constraint. Here, it was left off specifically so the "orphan row" scenario could be demonstrated for real in later docs instead of being simulated with a workaround.

### A closer look at `sys.foreign_keys` and `sys.foreign_key_columns`

**In plain language:** these two work exactly like the pair from the primary-key query above (`sys.key_constraints` + `sys.index_columns`), just for foreign keys instead. `sys.foreign_keys` is "which FK constraints exist," and `sys.foreign_key_columns` is "which specific columns each one actually links."

**Real-life example:** back to the library — imagine one shelf holds a sticky note: *"these items are on loan from Section B."* That note itself is `sys.foreign_keys` — it tells you a relationship exists and names it. The fine print underneath, *"specifically, item #7 here corresponds to item #7 in Section B,"* is `sys.foreign_key_columns` — it says exactly which slot links to exactly which slot. In `InterviewPrepSQL`, this sticky note doesn't exist at all yet (zero rows, for real, see below) — there's no note on `Transactions` saying it's linked to `Accounts`, even though the columns are named as if there should be one.

**Real-world use case:** this is exactly what a tool like SSMS's "Database Diagrams" feature, or an ER-diagram generator, reads to draw the lines between boxes on a schema diagram — if `sys.foreign_keys` has no rows for your database, a diagram tool draws your tables as disconnected boxes, because as far as SQL Server is concerned, they genuinely aren't linked. That's not a diagram-tool limitation; it's an accurate reflection of `InterviewPrepSQL`'s real, deliberate state right now.

**Technical deep dive:**

| View | One row per... | Columns this query uses | Real-life analogy |
|---|---|---|---|
| `sys.foreign_keys` | every FOREIGN KEY constraint that exists | `object_id` (its own internal ID), `name` | The sticky note itself: "linked to Section B" |
| `sys.foreign_key_columns` | every (child column, parent column) pair inside each FK | `constraint_object_id` (which FK it belongs to), `parent_object_id`/`parent_column_id` (the *child* table+column — the one holding the FK), `referenced_object_id`/`referenced_column_id` (the *parent* table+column — the one being pointed at) | The fine print: "item #7 here ↔ item #7 in Section B" |

If `Transactions.AccountID` *did* have `foreign key references Accounts(AccountID)` on it, this query would come back with exactly one row: `ForeignKeyName` = some name (auto-generated, same `FK__` pattern as the PK names above, unless you'd named it yourself), `ChildTable` = `Transactions`, `ChildColumn` = `AccountID`, `ParentTable` = `Accounts`, `ParentColumn` = `AccountID`. The **zero rows** you actually got back is that exact scenario's absence, confirmed for real rather than assumed — the honest, verified answer to "does this relationship exist as an enforced constraint," which happens to be "no."

If you want to see this same query return real, populated rows instead of imagining what they'd look like, `AdventureWorksDW2022` is still on your machine (it wasn't part of the reset) and almost certainly has real foreign keys in it — say the word and this query can be pointed at that database instead, so you see actual linked rows rather than a hypothetical.

### Quick-reference: the six system views used above, in one place

Everything from the two walkthroughs above, condensed to one table for review — this is the one worth re-reading cold before an interview, since "how would you find out a table's keys without a diagram" is a real question these answer:

| View | Plain-English meaning | One-line memory hook |
|---|---|---|
| `sys.tables` | every table that exists | "the shelf list" |
| `sys.columns` | every column of every table | "the label on each item" |
| `sys.key_constraints` | every `primary key`/`unique` constraint | "which shelf is sorted, and by what" |
| `sys.index_columns` | which column(s) back a given index/key | "which specific item(s) the sort label points at" |
| `sys.foreign_keys` | every `foreign key` constraint that exists | "the sticky note: this shelf borrows from that one" |
| `sys.foreign_key_columns` | which child column links to which parent column, per FK | "the fine print under the sticky note" |

The pattern that repeats across both walkthroughs: a "what exists" view (`sys.tables`, `sys.key_constraints`, `sys.foreign_keys`) always has to be joined to a "which column, specifically" view (`sys.columns`, `sys.index_columns`, `sys.foreign_key_columns`) before you get an actual, readable name back — SQL Server's internal bookkeeping talks in ID numbers, and every query above exists purely to translate those numbers into names you recognize.

---

## 3. `select`, `where`, `order by`

### `select` with an explicit column list

List every transaction with its ID, account, category, date, and amount.

so this question is asking us to find every transaction, showing only the columns we actually want to see — no filtering, no sorting, just a clean read of the whole table.

```sql
select TransactionID, AccountID, CategoryID, TransactionDate, Amount
from Transactions;
```

Real output:

| TransactionID | AccountID | CategoryID | TransactionDate | Amount |
|---|---|---|---|---|
| 101 | 1 | 1 | 2026-01-05 | -50.00 |
| 102 | 1 | 2 | 2026-01-10 | -20.00 |
| 103 | 2 | 3 | 2026-01-12 | 500.00 |
| 104 | 3 | 1 | 2026-01-15 | -10.00 |
| 105 | NULL | 2 | 2026-01-20 | -15.00 |

*(5 rows affected)*

`select` decides which *columns* come back (projection); `from` decides which *table* they come from. Naming the columns explicitly instead of `select *` matters for reasons that don't show up in a 3-table demo but bite hard in a real one: `select *` breaks the moment someone adds a column to the table (your application code gets a column it didn't ask for and didn't expect), it's slower over the wire on a wide table (you're pulling data you'll never use), and it silently changes behavior if column order ever changes. Naming columns is the habit that survives contact with a real schema.

### `where` — filtering rows

Find every transaction that's an outflow and dated on or after January 10, 2026.

so this question is asking us to find transactions that are both outflows (`Amount` negative) and dated on or after `2026-01-10` — a row only survives if both conditions are true at once.

```sql
select TransactionID, Amount, TransactionDate
from Transactions
where Amount < 0 and TransactionDate >= '2026-01-10';
```

Real output:

| TransactionID | Amount | TransactionDate |
|---|---|---|
| 102 | -20.00 | 2026-01-10 |
| 104 | -10.00 | 2026-01-15 |
| 105 | -15.00 | 2026-01-20 |

*(3 rows affected)*

Tracing this against all 5 source rows — `where` is evaluated once per row, independently, and only keeps the row if the whole condition is `TRUE`:

```
row 101: Amount=-50.00 (< 0 ✓)   Date=2026-01-05 (>= 01-10? ✗)  → AND is FALSE → dropped
row 102: Amount=-20.00 (< 0 ✓)   Date=2026-01-10 (>= 01-10? ✓)  → AND is TRUE  → kept
row 103: Amount=500.00 (< 0 ✗)   ...                            → AND is FALSE → dropped
row 104: Amount=-10.00 (< 0 ✓)   Date=2026-01-15 (>= 01-10? ✓)  → AND is TRUE  → kept
row 105: Amount=-15.00 (< 0 ✓)   Date=2026-01-20 (>= 01-10? ✓)  → AND is TRUE  → kept
```

Matches the real output exactly: 102, 104, 105.

### `order by` — and a real NULL-ordering gotcha

List every transaction sorted by account, and within each account, by amount from largest to smallest.

so this question is asking us to find every transaction, sorted by account first and, within each account, by amount largest-to-smallest — mainly to see for real where SQL Server places a `NULL` account in an ascending sort.

```sql
select AccountID, TransactionID, Amount
from Transactions
order by AccountID asc, Amount desc;
```

Real output:

| AccountID | TransactionID | Amount |
|---|---|---|
| NULL | 105 | -15.00 |
| 1 | 102 | -20.00 |
| 1 | 101 | -50.00 |
| 2 | 103 | 500.00 |
| 3 | 104 | -10.00 |

*(5 rows affected)*

Two sort keys, applied in order: first by `AccountID` ascending, and *within* each `AccountID`, by `Amount` descending (that's why, for `AccountID = 1`, `-20.00` comes before `-50.00` — descending means largest first, and `-20.00 > -50.00`).

The real gotcha is the very first row: **`AccountID = null` sorted first**, ahead of `1`, `2`, `3`. That's not a guess — it's what SQL Server actually did, right there in the output. SQL Server's default is to treat NULL as the *lowest* possible value in an ascending sort, so it comes first. (This is genuinely engine-specific behavior worth knowing cold: some other databases sort NULLs last by default. If you ever need it the other way around in SQL Server, that's what `order by AccountID asc` combined with a `case when AccountID is null then 1 else 0 end` trick, or `is null`-based ordering, is for — not needed here, but worth knowing it's not automatic.)

---

## 4. `group by`, `having`, aggregate functions

### `group by` with aggregates

For each account, find the number of transactions, the total amount, the average amount, and the smallest and largest amount.

so this question is asking us to find per-account summary numbers — how many transactions each account has, plus its total, average, smallest, and largest amount — collapsing the 5 individual rows down to one row per account.

```sql
select AccountID, count(*) as NumTransactions, sum(Amount) as NetAmount, avg(Amount) as AvgAmount, min(Amount) as SmallestAmount, max(Amount) as LargestAmount
from Transactions
group by AccountID;
```

Real output:

| AccountID | NumTransactions | NetAmount | AvgAmount | SmallestAmount | LargestAmount |
|---|---|---|---|---|---|
| NULL | 1 | -15.00 | -15.000000 | -15.00 | -15.00 |
| 1 | 2 | -70.00 | -35.000000 | -50.00 | -20.00 |
| 2 | 1 | 500.00 | 500.000000 | 500.00 | 500.00 |
| 3 | 1 | -10.00 | -10.000000 | -10.00 | -10.00 |

*(4 rows affected)*

`group by AccountID` collapses the 5 rows into 4 groups — one per distinct `AccountID` value, **including NULL as its own group**. That's a genuinely different rule from `where`/`=`: comparing `null = null` is never `TRUE` in SQL (it's `UNKNOWN`), but `group by` still buckets every `null` row together as one group, because grouping asks "are these the same value" in a different sense than equality comparison does.

Verified by hand against the raw data (account 1 has transactions -50.00 and -20.00 → count 2, sum -70.00, avg -35.00, min -50.00, max -20.00 — matches exactly):

```
AccountID=1:    [-50.00, -20.00]  → count=2  sum=-70.00  avg=-35.00  min=-50.00  max=-20.00
AccountID=2:    [500.00]          → count=1  sum=500.00  avg=500.00  min=500.00  max=500.00
AccountID=3:    [-10.00]          → count=1  sum=-10.00  avg=-10.00  min=-10.00  max=-10.00
AccountID=NULL: [-15.00]          → count=1  sum=-15.00  avg=-15.00  min=-15.00  max=-15.00
```

One more real detail visible in the output, not something to gloss over: `sum`/`min`/`max` printed 2 decimal places (matching the column's `decimal(10,2)` definition), but `avg` printed 6 (`-35.000000`). SQL Server widens the scale (decimal places) specifically for `avg` on a `decimal` column, because division can produce a result the original 2-decimal precision can't represent exactly, and SQL Server would rather show you more precision than silently round it away.

### `group by` on more than one column

`group by` takes a comma-separated list, and SQL Server groups on the *combination* of every column listed — one row per unique combination, not one row per column. `Transactions` doesn't actually show this well (every `AccountID`+`CategoryID` pair in it happens to be unique already, so grouping by both would just return the same 5 rows back), so this one's demonstrated against `InterviewPrepSQLPractice.Employees` instead, where repeated combinations actually exist:

Find how many employees fall under each department-and-manager combination.

so this question is asking us to find how many employees fall under each (department, manager) combination — not just each department on its own, but each department *split further* by who manages them.

```sql
select
    DepartmentID,
    ManagerID,
    count(*) as EmpCount
from Employees
group by DepartmentID, ManagerID;
```

Expected output, worked out by hand against the seeded `Employees` data (run this for real and paste the output back to confirm it):

| DepartmentID | ManagerID | EmpCount |
|---|---|---|
| NULL | NULL | 1 |
| 1 | NULL | 1 |
| 1 | 1 | 2 |
| 2 | NULL | 1 |
| 2 | 4 | 2 |
| 3 | NULL | 1 |
| 3 | 7 | 1 |

Tracing every one of the 9 employees into the group its own `(DepartmentID, ManagerID)` pair puts it in — this is the same hand-verification step the single-column `group by AccountID` example above did, just with a two-part key instead of a one-part key:

```
Ravi    (Dept=1,    Mgr=NULL) → group (1, NULL)
Priya   (Dept=1,    Mgr=1)    → group (1, 1)
Amit    (Dept=1,    Mgr=1)    → group (1, 1)      — same group as Priya
Neha    (Dept=2,    Mgr=NULL) → group (2, NULL)
Karan   (Dept=2,    Mgr=4)    → group (2, 4)
Sara    (Dept=2,    Mgr=4)    → group (2, 4)      — same group as Karan
Vikram  (Dept=3,    Mgr=NULL) → group (3, NULL)
Anjali  (Dept=3,    Mgr=7)    → group (3, 7)
Rohan   (Dept=NULL, Mgr=NULL) → group (NULL, NULL)
```

Seven distinct `(DepartmentID, ManagerID)` pairs come out of that, matching the 7 rows in the table above — and only two of them have more than one employee in them (`(1, 1)` with Priya+Amit, `(2, 4)` with Karan+Sara, both `EmpCount = 2`), the rest are groups of exactly one.

Seven groups, not three (one per department, if only `DepartmentID` mattered) and not nine (one per employee, if grouping did nothing). Engineering (`DepartmentID = 1`) splits into two of those seven rows because it contains two distinct `ManagerID` values: Ravi himself (`ManagerID = null`, since nobody manages him) and everyone who reports to Ravi (`ManagerID = 1` — Priya and Amit together, hence `EmpCount = 2`). The general rule this demonstrates: adding a second `group by` column never merges existing groups, it only ever splits them further — two rows only count as "the same group" once they match on *every* listed column, not just the first one.

### `having` — filtering *after* aggregation

Find which accounts have more than one transaction.

so this question is asking us to find which accounts have *more than one* transaction — a filter applied on the group's own `count(*)`, after grouping has already happened, not on any raw column.

```sql
select AccountID, count(*) as NumTransactions
from Transactions
group by AccountID
having count(*) > 1;
```

Real output:

| AccountID | NumTransactions |
|---|---|
| 1 | 2 |

*(1 row affected)*

The distinction that actually matters: **`where` filters rows before grouping happens; `having` filters groups after grouping happens.** You cannot write `where count(*) > 1` — at the point `where` runs, there's no `count(*)` yet, because grouping hasn't happened. Tracing it: `group by` first produces the same 4 groups as above (counts 1, 2, 1, 1 for NULL/1/2/3), then `having count(*) > 1` throws away every group except the one where the count is 2 — account 1. That's the only row in the real output.

---

## 5. Subqueries

### Scalar subquery — a subquery that returns exactly one value

Find every transaction that's larger than the average transaction amount.

so this question is asking us to find any transaction bigger than the average transaction amount across the whole table — using the average itself, computed inline by the subquery, as the comparison value instead of a hard-coded number.

```sql
select TransactionID, Amount
from Transactions
where Amount > (select avg(Amount) from Transactions);
```

Real output:

| TransactionID | Amount |
|---|---|
| 103 | 500.00 |

*(1 row affected)*

The inner query `select avg(Amount) from Transactions` runs first, on its own, over all 5 rows: `(-50 + -20 + 500 + -10 + -15) / 5 = 405 / 5 = 81.00`. That single number then substitutes into the outer query as if you'd typed `where Amount > 81.00` — and only one transaction (500.00) is bigger than that. This only works because the subquery is guaranteed to return a single value; a subquery that could return more than one row would make `> (...)` ambiguous, and SQL Server would raise a real error (`Subquery returned more than 1 value`) rather than guess which one you meant.

### Subquery with `in`

Find every account that has at least one transaction.

so this question is asking us to find every account that actually has at least one transaction — Investment, which has zero, should correctly disappear from the result instead of showing up with empty values.

```sql
select AccountName
from Accounts
where AccountID in (select distinct AccountID from Transactions where AccountID is not null);
```

Real output:

| AccountName |
|---|
| Checking |
| Savings |
| Sub-Savings (Kids) |

*(3 rows affected)*

The inner query produces the set `{1, 2, 3}` (distinct, non-NULL `AccountID`s that actually appear in `Transactions`), and the outer query keeps any account whose `AccountID` is in that set. **Investment (AccountID 4) is correctly missing** — it has zero transactions, so it was never in the inner set. That's the account-with-no-transactions edge case from the schema showing up exactly where it should.

The `where AccountID is not null` inside the subquery isn't decorative — it's guarding against a real, sharp-edged trap. If you write `not in (subquery)` and that subquery's result set contains even one `null`, SQL Server's three-valued logic makes the *entire* `not in` comparison `UNKNOWN` for every row, and the outer query silently returns **zero rows** — no error, just an empty, wrong answer. This query uses `in`, not `not in`, so it wasn't at risk here, but filtering NULLs out of the subquery is the habit that keeps you safe the moment you do reach for `not in`.

### Correlated subquery — re-evaluated once per outer row

For every account, find its own largest transaction.

so this question is asking us to find each account's own single largest transaction, computed separately for every account — including an account, like Investment, that has none at all.

```sql
select a.AccountName,
    (select max(t.Amount) from Transactions t where t.AccountID = a.AccountID) as LargestTransaction
from Accounts a;
```

Real output:

| AccountName | LargestTransaction |
|---|---|
| Checking | -20.00 |
| Savings | 500.00 |
| Sub-Savings (Kids) | -10.00 |
| Investment | NULL |

*(4 rows affected)*

This is a different shape from the previous two: the inner query references `a.AccountID`, a column from the *outer* query. That reference is what makes it "correlated" — the inner query can't run once on its own the way the scalar/IN subqueries above did; it has to run once **per row** of the outer query, each time plugging in that row's `AccountID`:

```
outer row a='Checking'(1)           → inner: MAX(Amount) WHERE AccountID=1  → MAX(-50.00,-20.00) = -20.00
outer row a='Savings'(2)            → inner: MAX(Amount) WHERE AccountID=2  → MAX(500.00)         = 500.00
outer row a='Sub-Savings (Kids)'(3) → inner: MAX(Amount) WHERE AccountID=3  → MAX(-10.00)          = -10.00
outer row a='Investment'(4)         → inner: MAX(Amount) WHERE AccountID=4  → no rows match         = NULL
```

**Investment correctly shows `null`**, not `0` or an error — `max()` over zero rows has nothing to take a maximum of, so it returns NULL rather than pretending there was a value. That's the same "account with no transactions" edge case, now showing up a third time, in a third different way (missing from `in`'s result, `null` here) — which is exactly the point of designing the schema with that gap in it deliberately, rather than only ever seeing queries succeed cleanly on data with no edge cases in it.

---

## Interview questions

These are the kind of questions this topic actually draws in an interview — conceptual, meant to be answered out loud without looking anything up. Every one of them is answerable straight from what's above; work through them from memory first, then check back against the doc for anything shaky. No answers are given here on purpose — say them out loud or write them out, and share them if you want them checked.

1. What's the difference between DDL and DML? Give two real examples of each.
2. Why does `select` sometimes get called DQL instead of DML? Does it actually matter which bucket it's filed under?
3. What's the difference between a primary key and a foreign key?
4. Can a foreign key column hold `null`? What does that `null` actually mean if so?
5. What actually happens, mechanically, if you try to `insert` a row whose foreign key value doesn't exist in the parent table — with a real FK constraint in place, versus without one?
6. What's the difference between `where` and `having`? Why can't you write `where count(*) > 1`?
7. Does `group by` treat `null` as a value it groups on, or does it throw those rows out? How is that different from what `null = null` evaluates to in a `where` clause?
8. In SQL Server, does `null` sort first or last by default in an ascending `order by`? Is that guaranteed to be true in every database engine?
9. What's the actual risk of using `not in` with a subquery, and how do you protect against it?
10. What's the difference between a scalar subquery and a correlated subquery — in terms of *when* and *how many times* each one actually runs?
11. Why would you generally avoid `select *` in real application code?
12. Why is `decimal` the right choice for money instead of `float`, specifically?
13. What are ACID and TCL, and how do they relate to each other?

---

## Practice database — `InterviewPrepSQLPractice`

Everything above used `InterviewPrepSQL` — the schema this whole doc was built around, and the one every real result and trace in it came from. Practice questions use a **separate** database instead, on purpose: mixing "the database the concept doc explains" with "the database you're graded against" makes it too easy to half-remember an answer from reading rather than actually working it out yourself. This second database also isn't a one-off — it gets reused and extended as the SQL series goes on (joins, window functions, and so on will keep adding to it), the same way the Python capstone built on itself over several topics.

One more deliberate difference from `InterviewPrepSQL`: this schema **does** enforce real foreign key constraints. `InterviewPrepSQL` left them off on purpose so an orphan row could exist without anything stopping it (see section 2 above). Here, referential integrity is actually turned on — so you get to see the *other* side of that trade-off for real: SQL Server enforcing a relationship instead of just having one described in a diagram.

Run this once in SSMS to set it up. As with everything else in this series, this is your setup script to run and paste the real confirmation output back from — not something to just read past:

Write the DDL to create the Departments and Employees tables, this time with real foreign key constraints enforced, and seed them with sample data.

so this script is asking us to create the practice database and its two tables (`Departments`, `Employees`) — this time with real foreign key constraints enforced — and seed them with the 4 departments and 9 employees every practice question below is based on.

```sql
create database InterviewPrepSQLPractice;
go
use InterviewPrepSQLPractice;
go

create table Departments (
    DepartmentID int primary key,
    DepartmentName varchar(50) not null
);

create table Employees (
    EmployeeID int primary key,
    FirstName varchar(50) not null,
    LastName varchar(50) not null,
    DepartmentID int null references Departments(DepartmentID),
    ManagerID int null references Employees(EmployeeID),
    Salary decimal(10,2) not null,
    HireDate date not null
);
go

insert into Departments (DepartmentID, DepartmentName) values
(1, 'Engineering'),
(2, 'Sales'),
(3, 'HR'),
(4, 'Finance');

insert into Employees (EmployeeID, FirstName, LastName, DepartmentID, ManagerID, Salary, HireDate) values
(1, 'Ravi', 'Kumar', 1, null, 95000.00, '2019-03-01'),
(2, 'Priya', 'Shah', 1, 1, 78000.00, '2020-07-15'),
(3, 'Amit', 'Verma', 1, 1, 82000.00, '2021-01-10'),
(4, 'Neha', 'Singh', 2, null, 88000.00, '2018-11-20'),
(5, 'Karan', 'Mehta', 2, 4, 65000.00, '2022-05-05'),
(6, 'Sara', 'Iyer', 2, 4, 71000.00, '2023-09-12'),
(7, 'Vikram', 'Rao', 3, null, 60000.00, '2017-02-14'),
(8, 'Anjali', 'Nair', 3, 7, 55000.00, '2023-12-01'),
(9, 'Rohan', 'Gupta', null, null, 50000.00, '2024-03-18');
go
```

Worth noticing before you even run it: `DepartmentID int null references Departments(DepartmentID)` is a real, enforced FK — try changing Rohan's `DepartmentID` to something like `99` after this runs and SQL Server will reject it. `ManagerID int null references Employees(EmployeeID)` is a **self-referencing** FK, same idea as `Accounts.ParentAccountID` earlier, except this time it's actually enforced. Department 4 (Finance) deliberately has zero employees, same shape as Investment having zero transactions in the first schema — a real gap for a later question to run into, not a coincidence.

Once it's run, paste back the real SSMS output (should be two silent `create table`s, four `(N rows affected)` lines for the inserts) so it's on record the same way the first setup script's output was.

## Practice questions

Write each of these yourself in SSMS against `InterviewPrepSQLPractice` — don't ask for the query. Type it, run it, and paste back both your query and the real output. Just reading through the concept sections above won't make any of this stick; writing the query yourself, getting it wrong, and fixing it is the part that actually does.

1. List every employee's first name, last name, and salary, ordered by salary from highest to lowest.
2. Find every employee who was hired after `2021-01-01` **and** earns more than `60000`.
3. Count how many employees are in each department — including any employees with no department at all.
4. Find the average salary per department, but only show departments where that average is above `70000`.
5. Find the names of every employee who earns more than the average salary across the *entire* company (not per department).
6. Find the names of every department that currently has at least one employee.
7. For every employee, show their own salary next to the highest salary in their own department, using a correlated subquery (not a join — joins are next doc).

Once you've run all seven and have real output, paste it back and I'll grade it against a hand-verified answer key the same way the asyncio/GIL/pytest practice questions were graded.
