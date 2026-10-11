# Finance Tracker Build Notes — running log

Kept turn-by-turn as pieces are confirmed real (per spec's "Deliverables" section). Each entry: the real code, what it does, and the real output that confirmed it.

---

## Piece 0 — ER diagram (the blueprint)

Drawn before any `create table` statement, same as the spec's written schema table — but as the visual blueprint, which is the normal first step of designing a database: decide the shape and the relationships on paper (or in a diagram) first, write the DDL to match it second. The shape can still evolve as the build goes, but this is the agreed starting shape.

![FinanceTrackerDB ER diagram](finance_tracker_db/diagrams/er_diagram.png)

Five tables, three relationship "families":

- **Users → Accounts** and **Users → Budgets** (1-to-many, teal): one user owns many accounts and sets many budgets.
- **Accounts → Transactions** and **Categories → Transactions** (1-to-many): every transaction belongs to exactly one account and is tagged with exactly one category.
- **Categories → Budgets** (1-to-many, amber): a budget is set per category.
- **Categories self-join**: `ParentCategoryID → CategoryID` — a category can have a parent category (e.g. "Groceries" under "Essentials"), which is what makes the self-join and the recursive CTE later in the project meaningful rather than forced.

Source: `finance_tracker_db/diagrams/gen_er_diagram.py` (regenerate with `python3 gen_er_diagram.py` from that folder).

---

## Piece 1 — Database + Users table

**Why `Users` first:** every other table in this schema points *at* something — `Accounts` points at `Users`, `Transactions` points at `Accounts`/`Categories`, `Budgets` points at `Users`/`Categories`. A foreign key can't reference a table that doesn't exist yet, so the build order has to follow the dependency chain from the bottom up. `Users` has no foreign keys of its own, so it's the only table that can go first.

```sql
create database FinanceTrackerDB;
-- Commands completed successfully.

use FinanceTrackerDB;

create table Users (
    UserID     int identity(1,1) primary key,
    UserName   varchar(50) not null,
    Email      varchar(100) not null unique,
    DateJoined date not null default getdate()
);
-- Commands completed successfully.
```

Confirmed real: both statements returned "Commands completed successfully," no errors — expected and correct, per doc01's DDL-vs-DML point: `create database`/`create table` are DDL (defining structure), not DML (touching rows), so there's no "(N rows affected)" to print since no rows are involved yet.

Notes:
- `UserID` is `identity(1,1)` — SQL Server auto-assigns it, starting at 1, incrementing by 1.
- `Email` is marked `unique` on purpose — two users can share a name, but not an email, so this is a real constraint doing real work, not decoration.
- `DateJoined` defaults to `getdate()` on purpose too — so you don't have to supply it on every insert; SQL Server fills it in automatically if you leave it out.

---

## Piece 2 — Seed rows into Users

```sql
insert into Users (UserName, Email) values
    ('Anirruddha Banerjee', 'anirruddha@financetracker.test'),
    ('Test User Two', 'testuser2@financetracker.test');

select * from Users;
```

Confirmed real output:

```
UserID    UserName               Email                             DateJoined
------    --------               -----                             ----------
1         Anirruddha Banerjee    anirruddha@financetracker.test    2026-10-11
2         Test User Two          testuser2@financetracker.test     2026-10-11

(2 rows affected)
```

Notes:
- `UserID` and `DateJoined` were left out of the insert column list on purpose — `UserID` because `identity(1,1)` assigns it, `DateJoined` because the `default getdate()` fills it in.
- Real proof the defaults work: `UserID` came back 1, 2 (not specified, auto-assigned); `DateJoined` came back today's real date (2026-10-11), not something typed in.

---

## Piece 3 — Accounts table (with its foreign key)

```sql
create table Accounts (
    AccountID    int identity(1,1) primary key,
    UserID       int not null,
    AccountName  varchar(50) not null,
    AccountType  varchar(20) not null,
    Balance      decimal(10,2) not null default 0,
    DateOpened   date not null default getdate(),
    constraint FK_Accounts_Users foreign key (UserID) references Users(UserID)
);
```

Confirmed real: "Commands completed successfully."

Notes:
- This is the `Users -> Accounts` line from the ER diagram made real, and the whole point of including a `Users` table at all, per decision #2 in the spec: `constraint FK_Accounts_Users foreign key (UserID) references Users(UserID)` is what actually enforces that every account belongs to a real user — SQL Server will reject an insert that tries to use a `UserID` that doesn't exist in `Users`. So only UserID 1 or 2 (the two confirmed real users) can open an account right now.
- `FK_Accounts_Users` is just the constraint's own name (so it shows up by that name in error messages and in `sys.foreign_keys`), not a column.
- `Balance` defaults to `0` — a newly opened account starts at zero until funded, same pattern as `DateJoined`/`DateOpened` defaulting to today.

**Questions along the way:**

**Q:** "explain the meaning of this line, what is it doing and telling" — `constraint FK_Accounts_Users foreign key (UserID) references Users(UserID)`

**A:** It's a rule SQL Server enforces on every insert/update, not just a comment: every value written into `Accounts.UserID` has to already exist as a `UserID` in `Users`, or the row is rejected. Concretely, with the two real seeded users (UserID 1 and 2), an insert with `UserID = 1` succeeds, but `UserID = 99` fails outright, because there is no row in `Users` where `UserID = 99` — the table makes it structurally impossible to create an "orphan" account with no real owner, the same way a real bank never lets an account exist that isn't tied to a verified customer record. Breaking the line down: `constraint FK_Accounts_Users` just names the rule (shows up under that name in error messages and in `sys.foreign_keys` — not a column); `foreign key (UserID)` says which column in *this* table (`Accounts`) is being restricted; `references Users(UserID)` says which table+column it has to match — the primary key of `Users`. This is called *referential integrity*, and it's enforced by the engine itself, so no application bug can sneak in a bad reference. One side effect worth remembering for later: SQL Server will also refuse to delete a `Users` row while any `Accounts` row still points at it, since deleting it would break this same rule.

---

## Piece 4 — Seed rows into Accounts

Once seeded, we have real `AccountID`s to attach transactions to:

```sql
insert into Accounts (UserID, AccountName, AccountType) values
    (1, 'Checking', 'Checking'),
    (1, 'Savings', 'Savings'),
    (2, 'Checking', 'Checking');

select * from Accounts;
```

Confirmed real output:

```
AccountID   UserID   AccountName    AccountType   Balance  DateOpened
---------   ------   -----------    -----------   -------  ----------
1           1        Checking       Checking      0.00     2026-10-11
2           1        Savings        Savings       0.00     2026-10-11
3           2        Checking       Checking      0.00     2026-10-11

(3 rows affected)
```

Notes:
- `AccountID` and `Balance`/`DateOpened` were left out of the insert column list, same reasoning as before — `AccountID` is `identity(1,1)`, `Balance` and `DateOpened` fall back to their `default` values.
- Real proof: `AccountID` came back 1, 2, 3 (auto-assigned, continuing from 1); `Balance` came back `0.00` for all three (the `default 0`, not something typed in); `DateOpened` came back today's real date.
- The `UserID` column proves the foreign key from Piece 3 is actually doing something: rows 1 and 2 (`UserID = 1`) and row 3 (`UserID = 2`) all matched real rows in `Users` — this insert would have been rejected outright if any `UserID` here didn't already exist in `Users`.

---

## Piece 5 — Categories table (self-referencing)

This is the self-referencing table from the ER diagram (`ParentCategoryID -> CategoryID`), and it needs to exist before `Transactions`, since `Transactions` will have a foreign key into it:

```sql
create table Categories (
    CategoryID       int identity(1,1) primary key,
    CategoryName     varchar(50) not null,
    ParentCategoryID int null,
    constraint FK_Categories_Parent foreign key (ParentCategoryID) references Categories(CategoryID)
);
```

Confirmed real: "Commands completed successfully."

Notes:
- `ParentCategoryID` is `int null` (not `not null`) on purpose — a top-level category like "Essentials" has no parent, so that column has to be allowed to be empty.
- The foreign key references `Categories(CategoryID)` — this table's own primary key — which is what makes it self-referencing: every `ParentCategoryID`, when it's not null, has to point at a real `CategoryID` that already exists in this same table.

Questions along the way: none — understood on the first pass.

---

## Piece 6 — Seed top-level categories

This has to happen in two steps, not one: the top-level categories (no parent) need to exist and get their real, auto-assigned `CategoryID`s first, before any child category can reference a real parent ID — same reasoning as `Accounts` needing real `Users` rows to reference before it could be seeded.

```sql
insert into Categories (CategoryName, ParentCategoryID) values
    ('Essentials', NULL),
    ('Entertainment', NULL);

select * from Categories;
```

Confirmed real output:

```
CategoryID  CategoryName    ParentCategoryID
----------  ------------    ----------------
1           Essentials      NULL
2           Entertainment   NULL

(2 rows affected)
```

Notes:
- `ParentCategoryID` was passed as `NULL` explicitly — these two have no parent, by definition, since they're the top of the hierarchy.
- Real proof: `CategoryID` came back 1 and 2 (auto-assigned by `identity(1,1)`), and `ParentCategoryID` genuinely came back `NULL` for both — not rejected, because the column was defined `int null` (nullable) in Piece 5 specifically to allow this.
- These two real IDs (`Essentials` = 1, `Entertainment` = 2) are what the next piece's child categories will actually reference — not guessed numbers.

Questions along the way: none — understood on the first pass.

---

## Piece 7 — Seed child categories under their real parents

Now that `Essentials` (CategoryID 1) and `Entertainment` (CategoryID 2) are real rows, child categories can reference them for real — this is the self-referencing foreign key from Piece 5 actually getting used for the first time:

```sql
insert into Categories (CategoryName, ParentCategoryID) values
    ('Groceries', 1),
    ('Rent', 1),
    ('Movies', 2);

select * from Categories;
```

Confirmed real output:

```
CategoryID  CategoryName       ParentCategoryID
----------  ------------       ----------------
1           Essentials         NULL
2           Entertainment      NULL
3           Groceries          1
4           Rent               1
5           Movies             2

(5 rows affected)
```

Notes:
- `Groceries` and `Rent` got `ParentCategoryID = 1` (under `Essentials`), `Movies` got `ParentCategoryID = 2` (under `Entertainment`) — each matched a real `CategoryID` already in the table, which is exactly what `FK_Categories_Parent` enforces; any of these would have been rejected if it pointed at a `CategoryID` that didn't exist.
- `Categories` now holds the real two-level hierarchy (`Essentials`/`Entertainment` as parents, `Groceries`/`Rent`/`Movies` as children) that the self-join and the recursive CTE later in the project will actually walk — not placeholder data invented just to fill a box.

Questions along the way: none — understood on the first pass.

---

## Piece 8 — Transactions table (two foreign keys at once)

With `Accounts` (Piece 3/4) and `Categories` (Piece 5/6/7) both holding real rows now, `Transactions` can finally be built — it's the table with two foreign keys at once, one into each:

```sql
create table Transactions (
    TransactionID   int identity(1,1) primary key,
    AccountID       int not null,
    CategoryID      int not null,
    TransactionDate date not null,
    Amount          decimal(10,2) not null,
    Description     varchar(200) null,
    constraint FK_Transactions_Accounts foreign key (AccountID) references Accounts(AccountID),
    constraint FK_Transactions_Categories foreign key (CategoryID) references Categories(CategoryID)
);
```

Confirmed real: "Commands completed successfully."

Notes:
- `AccountID` and `CategoryID` are both `not null` here — unlike `Categories.ParentCategoryID`, a transaction is never allowed to exist without a real account it happened in and a real category it belongs to, so there's no nullable escape hatch on either one.
- Two separate `constraint ... foreign key` clauses are used (not one combined line) because these are two independent rules checked against two different tables — `AccountID` against `Accounts`, `CategoryID` against `Categories` — and SQL Server needs each one named and declared on its own.

Questions along the way: none — understood on the first pass.

---

## Piece 9 — Seed real transactions

With both foreign keys enforced, every transaction inserted now has to point at a real account and a real category — this is the first piece that actually puts money through the schema, spread across accounts and categories so later pieces (running balance over time, month-over-month spending per category) have something real to work with:

```sql
insert into Transactions (AccountID, CategoryID, TransactionDate, Amount, Description) values
    (1, 4, '2026-09-01', -1500.00, 'September rent'),
    (1, 3, '2026-09-05', -120.50, 'Weekly groceries'),
    (1, 3, '2026-09-19', -95.10, 'Groceries top-up'),
    (2, 5, '2026-09-10', -45.00, 'Movie night'),
    (3, 3, '2026-09-12', -80.25, 'Groceries');

select * from Transactions;
```

Confirmed real output:

```
TransactionID  AccountID  CategoryID  TransactionDate  Amount    Description
-------------  ---------  ----------  ---------------  ------    -----------
1              1          4           2026-09-01       -1500.00  September rent
2              1          3           2026-09-05       -120.50   Weekly groceries
3              1          3           2026-09-19       -95.10    Groceries top-up
4              2          5           2026-09-10       -45.00    Movie night
5              3          3           2026-09-12       -80.25    Groceries

(5 rows affected)
```

Notes:
- `Amount` is negative for all of these on purpose — these are money leaving the account (spending), so a negative number is the honest representation; a future deposit/income transaction would be the positive case.
- `AccountID`/`CategoryID` values were picked to match real rows already confirmed in Pieces 4 and 6/7, not arbitrary numbers — real proof: all 5 rows inserted clean, which they wouldn't have if any `AccountID` or `CategoryID` pointed at something that didn't exist in `Accounts`/`Categories`.
- Caught and fixed one mistake before this ran: the September rent row was first drafted with `CategoryID = 3` (`Groceries`) instead of `4` (`Rent`) — fixed in chat before you typed it, so the real data came out correct on the first real run.

Questions along the way: none — understood on the first pass.

---

## Piece 10 — Budgets table (last of the five)

The last of the five tables from the ER diagram — `Budgets` has two foreign keys, both into tables that already hold real rows (`Users` and `Categories`):

```sql
create table Budgets (
    BudgetID      int identity(1,1) primary key,
    UserID        int not null,
    CategoryID    int not null,
    MonthYear     date not null,
    BudgetAmount  decimal(10,2) not null,
    constraint FK_Budgets_Users foreign key (UserID) references Users(UserID),
    constraint FK_Budgets_Categories foreign key (CategoryID) references Categories(CategoryID)
);
```

Confirmed real: "Commands completed successfully."

Notes:
- `MonthYear` is a `date` column even though a budget is really set per *month*, not per specific day — the convention (used consistently once real rows go in) will be to always store the 1st of the month, e.g. `2026-09-01` for the September budget, so `month(MonthYear)`/`year(MonthYear)` style queries later have something clean to group on.
- With this table created, all five tables from the ER diagram now exist for real: `Users`, `Accounts`, `Categories`, `Transactions`, `Budgets`.

Questions along the way: none — understood on the first pass.

---

## Piece 11 — Seed real budgets (last seed piece)

This is the last seed piece — once this runs, every table in the schema has real rows, and the full populated-schema diagram (showing every table's real data with foreign keys traced row-to-row) can be built:

```sql
insert into Budgets (UserID, CategoryID, MonthYear, BudgetAmount) values
    (1, 3, '2026-09-01', 400.00),
    (1, 4, '2026-09-01', 1500.00),
    (2, 5, '2026-09-01', 100.00);

select * from Budgets;
```

Confirmed real output:

```
BudgetID  UserID  CategoryID  MonthYear   BudgetAmount
--------  ------  ----------  ---------   ------------
1         1       3           2026-09-01  400.00
2         1       4           2026-09-01  1500.00
3         2       5           2026-09-01  100.00

(3 rows affected)
```

Notes:
- These set a September 2026 budget for user 1 (Anirruddha) on `Groceries` (CategoryID 3) and `Rent` (CategoryID 4), and for user 2 (Test User Two) on `Movies` (CategoryID 5) — real `UserID`/`CategoryID` values matching rows already confirmed, and the same September month the real `Transactions` rows from Piece 9 fall in, so a budget-vs-actual-spend comparison later has real matching data on both sides.
- Real proof: all 3 rows inserted clean, `BudgetID` auto-assigned 1-3 — which wouldn't have happened if any `UserID`/`CategoryID` here didn't already exist in `Users`/`Categories`.
- With this, every table in the schema now holds real seeded data: `Users` (2 rows), `Accounts` (3 rows), `Categories` (5 rows), `Transactions` (5 rows), `Budgets` (3 rows).

Questions along the way: none — understood on the first pass.

---

## Populated Schema — every table's real data, every foreign key traced to its exact row

All five tables now hold real data from Pieces 1-11. This section lays out every real row, table by table, and for every foreign key column, resolves it to the exact row it points at (not just "Accounts.UserID -> Users.UserID" in the abstract, but which specific user). A matching companion diagram (`finance_tracker_db/diagrams/populated_schema.png`) gives the same thing as a picture, using a colored badge per table instead of drawn lines between ~22 individual rows (which would be unreadable at this scale) — color + number on an FK value tells you exactly which row it resolves to.

![Populated schema diagram](finance_tracker_db/diagrams/populated_schema.png)

### Users (2 rows) — referenced by Accounts.UserID, Budgets.UserID

| UserID (PK) | UserName | Email | DateJoined |
|---|---|---|---|
| 1 | Anirruddha Banerjee | anirruddha@financetracker.test | 2026-10-11 |
| 2 | Test User Two | testuser2@financetracker.test | 2026-10-11 |

### Accounts (3 rows) — UserID -> Users.UserID; referenced by Transactions.AccountID

| AccountID (PK) | UserID (FK) | AccountName | AccountType | Balance | DateOpened | UserID resolves to |
|---|---|---|---|---|---|---|
| 1 | 1 | Checking | Checking | 0.00 | 2026-10-11 | Users #1 - Anirruddha Banerjee |
| 2 | 1 | Savings | Savings | 0.00 | 2026-10-11 | Users #1 - Anirruddha Banerjee |
| 3 | 2 | Checking | Checking | 0.00 | 2026-10-11 | Users #2 - Test User Two |

### Categories (5 rows) — ParentCategoryID -> Categories.CategoryID (self); referenced by Transactions.CategoryID, Budgets.CategoryID

| CategoryID (PK) | CategoryName | ParentCategoryID (FK) | ParentCategoryID resolves to |
|---|---|---|---|
| 1 | Essentials | NULL | (top-level, no parent) |
| 2 | Entertainment | NULL | (top-level, no parent) |
| 3 | Groceries | 1 | Categories #1 - Essentials |
| 4 | Rent | 1 | Categories #1 - Essentials |
| 5 | Movies | 2 | Categories #2 - Entertainment |

### Transactions (5 rows) — AccountID -> Accounts.AccountID; CategoryID -> Categories.CategoryID

| TransactionID (PK) | AccountID (FK) | CategoryID (FK) | TransactionDate | Amount | Description | AccountID resolves to | CategoryID resolves to |
|---|---|---|---|---|---|---|---|
| 1 | 1 | 4 | 2026-09-01 | -1500.00 | September rent | Accounts #1 - Checking (User 1) | Categories #4 - Rent |
| 2 | 1 | 3 | 2026-09-05 | -120.50 | Weekly groceries | Accounts #1 - Checking (User 1) | Categories #3 - Groceries |
| 3 | 1 | 3 | 2026-09-19 | -95.10 | Groceries top-up | Accounts #1 - Checking (User 1) | Categories #3 - Groceries |
| 4 | 2 | 5 | 2026-09-10 | -45.00 | Movie night | Accounts #2 - Savings (User 1) | Categories #5 - Movies |
| 5 | 3 | 3 | 2026-09-12 | -80.25 | Groceries | Accounts #3 - Checking (User 2) | Categories #3 - Groceries |

### Budgets (3 rows) — UserID -> Users.UserID; CategoryID -> Categories.CategoryID

| BudgetID (PK) | UserID (FK) | CategoryID (FK) | MonthYear | BudgetAmount | UserID resolves to | CategoryID resolves to |
|---|---|---|---|---|---|---|
| 1 | 1 | 3 | 2026-09-01 | 400.00 | Users #1 - Anirruddha Banerjee | Categories #3 - Groceries |
| 2 | 1 | 4 | 2026-09-01 | 1500.00 | Users #1 - Anirruddha Banerjee | Categories #4 - Rent |
| 3 | 2 | 5 | 2026-09-01 | 100.00 | Users #2 - Test User Two | Categories #5 - Movies |

**Reading it end to end, one real chain:** Transaction #1 (-1500.00, "September rent") belongs to Account #1 ("Checking"), which belongs to User #1 (Anirruddha Banerjee), and is tagged with Category #4 ("Rent"), which is a child of Category #1 ("Essentials"). Budget #2 sets a 1500.00 September budget for that same User #1 on that same Category #4 — so this transaction is exactly the kind of real spending that budget was meant to track, traceable purely through the foreign keys above, not by assumption.

---

Schema and seed data are both done now — every table in the spec's five has real rows (Piece 11 finished the last of them, Budgets). The spec's "Required coverage" checklist is what's next, and the first item on it is joins: inner, left, right, full outer, and a self-join on Categories. Starting with inner join because every other join type is really "inner join, plus a rule for what to do with the rows that don't match" — so inner join is the baseline the rest build on.

## Piece 12 — inner join (Transactions + Accounts + Users + Categories)

```sql
select
    t.TransactionID,
    u.UserName,
    a.AccountName,
    c.CategoryName,
    t.TransactionDate,
    t.Amount,
    t.Description
from Transactions t
inner join Accounts a on t.AccountID = a.AccountID
inner join Users u on a.UserID = u.UserID
inner join Categories c on t.CategoryID = c.CategoryID
order by t.TransactionID;
```

Confirmed real output:

```
TransactionID  UserName             AccountName  CategoryName  TransactionDate  Amount    Description
-------------  --------             -----------  ------------  ---------------  ------    -----------
1              Anirruddha Banerjee  Checking     Rent          2026-09-01       -1500.00  September rent
2              Anirruddha Banerjee  Checking     Groceries     2026-09-05       -120.50   Weekly groceries
3              Anirruddha Banerjee  Checking     Groceries     2026-09-19       -95.10    Groceries top-up
4              Anirruddha Banerjee  Savings      Movies        2026-09-10       -45.00    Movie night
5              Test User Two        Checking     Groceries     2026-09-12       -80.25    Groceries

(5 rows affected)
```

Notes:
- This query turns the raw IDs sitting in `Transactions` into something a person could actually read — the real user's name, the real account name, the real category name — by inner-joining across all four tables that a transaction touches. Real proof: TransactionID 1 came back as "Anirruddha Banerjee / Checking / Rent," not as AccountID 1 / CategoryID 4.
- `inner join` only keeps a row when both sides have a match. That match was guaranteed in advance here — every `Transactions.AccountID` and `Transactions.CategoryID` was already forced to point at a real row when the foreign keys were created (Piece 8), and every `Accounts.UserID` was forced to point at a real `Users` row (Piece 3) — so this query couldn't drop any of the 5 real `Transactions` rows, and real proof it didn't: all 5 came back.
- That's the point worth noticing: inner join's "drop what doesn't match" behavior is invisible here because the schema's own foreign keys already prevented orphans from existing. The difference between inner and outer joins will show up for real in the next few pieces, once the join starts *from* a table that has rows nothing points at yet — `Categories` already has two of those (CategoryID 1 "Essentials" and 2 "Entertainment" are parent categories that no `Transactions` row is tagged with directly, only their children are).
- Three joins chained (`Transactions -> Accounts -> Users`, and `Transactions -> Categories`) is normal — each `inner join` only needs to know the two tables immediately on either side of it, not the whole chain at once.
- **What this is really answering (interview-style scenario):** the shape of question this query answers is "given Transactions, Accounts, Users, and Categories, show every transaction in human-readable form — who made it, which account, which category." That's a classic "join the raw IDs back into readable info" interview prompt, and in a real finance app it's literally the query that would power a transaction-history screen.
- **Visual representation:** since this is the first query in the project chaining more than two tables, a companion diagram below walks through how the chain actually works — the two lookup paths off `Transactions` (one hopping twice through `Accounts` to `Users`, one straight to `Categories`), a worked trace of the real TransactionID 1 row through all three hops, and the final 5-row result with every column's source table color-coded.

![Piece 12 join chain diagram](finance_tracker_db/diagrams/piece12_join_chain.png)

**Questions along the way:**

Q: Why did we do an inner join here? What's the necessity of it in this project? What are we trying to show/do with this join? Will it be used later? Why not the other join types, only inner join?

A: Necessity first: the spec's "Required coverage" checklist (the pass/fail bar for the whole project) literally lists "every join type - inner, left, right, full outer, and a self-join" as one line item, so some inner join query was always going to exist here regardless of which one came first. Inner join specifically comes first because it's the baseline every other join type is built from - `left join` is "inner join, plus also keep the unmatched rows from the left table, NULL-filled"; `right join` and `full outer join` are the same idea from the other side(s). You can't really understand what those *add* until you've seen the plain match-only version they're extending.

What this particular query is showing: the whole reason this project's schema is split into five separate tables (Piece 0's ER diagram, Pieces 1-11 building each one) is normalization - `Transactions` doesn't repeat the user's name or the account's name on every row, it just stores `AccountID` and `CategoryID` numbers and trusts the foreign keys to keep those numbers honest. That's great for storage and integrity, but nobody wants to read a transaction list that says "AccountID 1, CategoryID 4, -1500.00" - a human (or a report, or an app screen) wants "Checking, Rent, -1500.00". A join is the mechanism SQL gives you to reassemble that normalized data back into something readable, on demand, without ever storing a duplicate copy of "Checking" or "Rent" anywhere. That's literally what Piece 12 demonstrates.

Will it be used later: yes, constantly - this is not a one-off demo. Almost every query from here on that needs to show readable output instead of raw IDs will lean on the same inner-join pattern, including the budget-vs-actual-spend comparison already flagged at the end of the Populated Schema section (Budget #2 vs Transaction #1), the running-balance window-function piece, and the views/stored-procedure pieces later in the spec. Piece 12 is the join pattern most of the rest of the project reuses, not an isolated exercise.

Why only inner join here, not the others yet: left/right/full outer joins only prove something *different* from inner join when a row on one side has no match on the other side - otherwise they return the exact same rows inner join does, which wouldn't demonstrate anything new. Right now, in this real seeded data, `Accounts` and `Users` don't have that case - every account belongs to a real user, every account has at least one transaction (Piece 12's own Notes already point this out). The one place that case genuinely exists right now is `Categories` - CategoryID 1 ("Essentials") and 2 ("Entertainment") are parent categories with no `Transactions` row tagged to them directly, only their children are. So inner join went first because it's the type that has something clean to show on this exact data as-is; left/right/full outer are next specifically because they'll deliberately join from `Categories`, where there's finally an unmatched row for them to prove their point with.

---

Piece 12 proved inner join's blind spot: it can only show rows that match on both sides, and every row in this project's current data already had a guaranteed match, so nothing ever got dropped to prove the point. Left join fixes that by keeping a left-side row even when nothing on the right matches it, filling the right side's columns with NULL instead of dropping the row - and this project already has a real place to see that happen: `Categories` has two rows (CategoryID 1 "Essentials" and 2 "Entertainment") that no `Transactions` row is tagged to directly, only their children are. Joining from `Categories` this time, instead of from `Transactions`, is what makes left join's extra behavior show up in real output instead of staying theoretical.

## Piece 13 — left join (Categories + Transactions)

```sql
select
    c.CategoryID,
    c.CategoryName,
    t.TransactionID,
    t.Amount,
    t.Description
from Categories c
left join Transactions t on c.CategoryID = t.CategoryID
order by c.CategoryID, t.TransactionID;
```

Confirmed real output:

```
CategoryID  CategoryName   TransactionID  Amount    Description
----------  ------------   -------------  ------    -----------
1           Essentials     NULL           NULL      NULL
2           Entertainment  NULL           NULL      NULL
3           Groceries      2              -120.50   Weekly groceries
3           Groceries      3              -95.10    Groceries top-up
3           Groceries      5              -80.25    Groceries
4           Rent           1              -1500.00  September rent
5           Movies         4              -45.00    Movie night

(7 rows affected)
```

Notes:
- **What we did and what it shows:** every `Categories` row is kept this time, even the two with nothing matching on the right. Real proof: 7 rows came back, not 5 — `Categories` only has 5 rows total, so the extra 2 are CategoryID 1 ("Essentials") and 2 ("Entertainment") showing up with `TransactionID`, `Amount`, and `Description` all printed as `NULL`, exactly the two rows Piece 12's own notes predicted would be the first place an outer join could show something real.
- **Why it's `NULL` and not blank or an error:** SQL Server has no `Transactions` row to pull those three columns from for CategoryID 1 or 2, so it fills the gap with `NULL` rather than dropping the row (what `inner join` would have done) or refusing to run. `NULL` here means "no matching row existed," not "the data is missing or wrong."
- **Direct comparison to Piece 12:** same two tables' worth of information, two different join types, two different row counts on the exact same real data — inner join (joining from `Transactions`) returned 5; left join (joining from `Categories`) returns 7. That 2-row difference *is* the entire concept of outer joins, made concrete instead of abstract.
- **What this is really answering (interview-style scenario):** given `Categories` and `Transactions`, "find every category that has never been used in a transaction" or "list every category along with its spending, including categories with zero spending so far" is a classic interview question shape — the "find the ones with none" pattern (same shape as "find customers who never placed an order"). Left join is the standard tool for it, specifically *because* inner join would silently hide the very rows the question is asking about.

Questions along the way: none — understood on the first pass.

---

Piece 13 showed left join by keeping every `Categories` row and padding the missing `Transactions` side with `NULL`. Right join does the exact same thing, just with which side gets kept flipped — it's not a separate concept to learn, it's the same mechanism written from the other direction. The cleanest way to prove that isn't with new data, it's by writing the *same real result* from Piece 13 a different way: start the query from `Transactions` instead of `Categories`, and use `right join` to say "but still keep every row from `Categories`, even unmatched ones."

## Piece 14 — right join (Transactions + Categories)

```sql
select
    c.CategoryID,
    c.CategoryName,
    t.TransactionID,
    t.Amount,
    t.Description
from Transactions t
right join Categories c on t.CategoryID = c.CategoryID
order by c.CategoryID, t.TransactionID;
```

Confirmed real output:

```
CategoryID  CategoryName   TransactionID  Amount    Description
----------  ------------   -------------  ------    -----------
1           Essentials     NULL           NULL      NULL
2           Entertainment  NULL           NULL      NULL
3           Groceries      2              -120.50   Weekly groceries
3           Groceries      3              -95.10    Groceries top-up
3           Groceries      5              -80.25    Groceries
4           Rent           1              -1500.00  September rent
5           Movies         4              -45.00    Movie night

(7 rows affected)
```

Notes:
- **What we did and what it shows:** real proof the prediction held — this came back byte-for-byte the same 7 rows as Piece 13's left join, same two NULL-padded rows for Essentials and Entertainment. The only thing that changed between the two queries is which table is named in `from` versus which is named in the join, and which join keyword is used; the result is identical because both queries are asking the same underlying question, just naming the tables in the opposite order.
- **Why they're the same:** `right join` keeps every row from the table on the *right* of the join keyword, padding the left side with `NULL` where nothing matches — here that's `Categories c`, same table Piece 13 kept by naming it first and using `left join`. `A left join B` and `B right join A` always produce the same rows for that reason; right join isn't a different operation, it's left join with the roles of the two tables swapped in the sentence.
- **Real-world note:** a lot of style guides and working SQL developers avoid `right join` entirely and just rewrite everything as `left join` (reordering the `from`/`join` tables if needed), purely for consistency — one join direction to read instead of two. That convention is *why* interviewers like asking you to convert between them: it checks whether you understand the equivalence, not just whether you can type the keyword.
- **What this is really answering (interview-style scenario):** a very common interview ask is "rewrite this left join as a right join" or "what's the difference between left and right join" — and the honest technical answer, provable right here with real output, is "nothing, if you also swap which table is named where." This piece exists specifically to make that provable rather than just stated.

Questions along the way: none — understood on the first pass.

---

Piece 13 and 14 both showed a one-sided unmatched row - `Categories` had parents with no transactions, but the "many" side (`Transactions`, `Accounts`) can never be unmatched, because its foreign keys force every row to point at something real. Full outer join only earns its keep when *both* sides can genuinely have unmatched rows, and nowhere in this schema's declared foreign keys does that happen - so this piece deliberately joins two tables that have no foreign key between them at all: `Budgets` and `Transactions`, matched by `(UserID, CategoryID)` instead of a declared FK (bridging `Transactions` to a `UserID` through `Accounts` first, since `Transactions` only stores `AccountID` directly). This is also the exact comparison the Populated Schema section flagged back at the end of Piece 11 - "Budget #2 vs Transaction #1" - done properly this time: every budget alongside its real spending, any budget with zero spending yet, and any spending that has no budget set for it, all in one real result.

## Piece 15 — full outer join (Budgets + Transactions, matched by UserID + CategoryID)

```sql
select
    b.BudgetID,
    b.UserID,
    b.CategoryID,
    b.BudgetAmount,
    t.TransactionID,
    t.Amount,
    t.Description
from Budgets b
full outer join (
    select tr.TransactionID, a.UserID, tr.CategoryID, tr.Amount, tr.Description
    from Transactions tr
    inner join Accounts a on tr.AccountID = a.AccountID
) t
    on b.UserID = t.UserID and b.CategoryID = t.CategoryID
order by b.BudgetID, t.TransactionID;
```

Confirmed real output:

```
-- intermediate check: the derived table alone (UserID bridged in via Accounts)
TransactionID  UserID  CategoryID  Amount    Description
-------------  ------  ----------  ------    -----------
1              1       4           -1500.00  September rent
2              1       3           -120.50   Weekly groceries
3              1       3           -95.10    Groceries top-up
4              1       5           -45.00    Movie night
5              2       3           -80.25    Groceries

(5 rows affected)

-- final result: full outer join against Budgets
BudgetID  UserID  CategoryID  BudgetAmount  TransactionID  Amount    Description
--------  ------  ----------  ------------  -------------  ------    -----------
NULL      NULL    NULL        NULL          4              -45.00    Movie night
NULL      NULL    NULL        NULL          5              -80.25    Groceries
1         1       3           400.00        2              -120.50   Weekly groceries
1         1       3           400.00        3              -95.10    Groceries top-up
2         1       4           1500.00       1              -1500.00  September rent
3         2       5           100.00        NULL           NULL      NULL

(6 rows affected)
```

Notes:
- **What the query is doing, step by step:** the inner part — `select tr.TransactionID, a.UserID, tr.CategoryID, tr.Amount, tr.Description from Transactions tr inner join Accounts a on tr.AccountID = a.AccountID` — runs first, entirely on its own, and doesn't touch `Budgets` at all. It reuses the same "hop through `Accounts` to find `UserID`" move from Piece 12 to build a temporary result set: every transaction, now carrying its owner's `UserID` alongside it. That bridge is necessary because `Budgets` stores `UserID` directly but `Transactions` never does — there's no shared column to join on until this exists. The "intermediate check" block above confirms that bridge in isolation: the same 5 transactions as always, now with a real `UserID` column added. The outer part then treats that whole result as a stand-in table, aliased `t`, and does `Budgets b full outer join (...) t on b.UserID = t.UserID and b.CategoryID = t.CategoryID` — matching on *both* columns together, since a budget belongs to one specific user and one specific category, so a transaction only "counts against" it when both line up.
- **What kind of subquery this is, and how it relates to `01 sql fundamentals.md`:** that doc's §5 "Subqueries" covers three shapes — a *scalar* subquery (returns one value, used in a comparison like `where Amount > (select avg(Amount)...)`), an *IN* subquery (returns a list, used in `where X in (subquery)`), and a *correlated* subquery (re-runs once per outer row, referencing an outer column). This piece uses a fourth shape that doc didn't name: a **derived table** (also called an inline view) — a subquery that returns full rows and columns and gets used in the `FROM` clause as if it were its own temporary table. `full outer join` needs two real row-sets with columns to match against, not a single value or a list, which is why this shape was the one that fit here.
- **Honest note on a cleaner alternative:** `05 sql ctes.md` is still ahead of us on the Required Coverage checklist, and a CTE (`with t as (...)`) would have been the more-readable way to write this exact same subquery — the logic is identical, only the syntax changes. The derived-table form was used here on purpose, so `full outer join` stayed the one new concept in this piece instead of two at once. This query is a strong candidate to revisit and rewrite as a CTE once that piece comes up, to show the same logic both ways side by side.
- **Real proof the join worked both directions:** 6 rows came back, more than either table alone (`Budgets` has 3, the derived transaction set has 5) — because 2 transactions (Movie night, Groceries for User 2) matched nothing in `Budgets` and show up with the budget columns `NULL`, while 1 budget (BudgetID 3, User 2's Movies budget) matched no transaction and shows up with the transaction columns `NULL`. The other 3 rows matched cleanly on both sides.
- **What this is really answering (interview-style scenario):** "show me every budget alongside actual spending against it, including budgets with no spending yet and spending with no budget set" is a realistic reporting question for any finance app, and it's exactly why full outer join exists — inner join would have silently dropped both edge cases, left/right join would only have caught one of the two.

Questions along the way: none — understood on the first pass.

---

This is the last item on the "every join type" checklist - inner (12), left (13), right (14), full outer (15), and now self-join. `02 sql joins.md` §5 already covers what a self join actually is: not a separate keyword or a different kind of join at all, just an ordinary join (here, `left join`) where both "tables" happen to be the same table, referenced twice under two different aliases so a row can be compared against another row in that same table - that doc's own worked example was `Accounts.ParentAccountID` self-joined to `Accounts.AccountID`, the exact same shape as `Categories.ParentCategoryID` self-joined to `Categories.CategoryID` here, which is precisely why Piece 0's ER diagram called the Categories self-join out by name from the very start.

That doc also has a worked example worth being deliberate about here: Q4/Q5's "wrong vs right" self-join bug, where comparing `E1.ManagerID = E2.ManagerID` finds *coworkers* who share a boss (and even matches employees to themselves), while `E1.ManagerID = E2.EmployeeID` correctly finds the one row that *is* the manager. The query below uses `child.ParentCategoryID = parent.CategoryID` - a child's own foreign-key column compared against the parent's primary key, the "RIGHT" pattern from that worked example, not `ParentCategoryID = ParentCategoryID` (which would be the "WRONG" one, matching sibling categories to each other instead of parents to children).

`left join` is deliberate here too, same reasoning as that doc's Accounts example: `Categories` already has two rows with `ParentCategoryID = NULL` (Essentials, Entertainment) - an `inner join` would drop both of them from the result entirely, exactly like it would have dropped three of the four accounts in doc 02's version.

## Piece 16 — self-join (Categories parent/child hierarchy)

```sql
select
    child.CategoryID,
    child.CategoryName,
    child.ParentCategoryID,
    parent.CategoryName as ParentCategoryName
from Categories child
left join Categories parent on child.ParentCategoryID = parent.CategoryID
order by child.CategoryID;
```

Confirmed real output:

```
CategoryID  CategoryName   ParentCategoryID  ParentCategoryName
----------  ------------   ----------------  ------------------
1           Essentials     NULL              NULL
2           Entertainment  NULL              NULL
3           Groceries      1                 Essentials
4           Rent           1                 Essentials
5           Movies         2                 Entertainment
```

Notes:
- **What we did and what it shows:** all 5 real categories came back, each paired with its real parent category's name instead of the raw `ParentCategoryID` number — `Groceries`/`Rent` correctly resolve to `Essentials`, `Movies` correctly resolves to `Entertainment`.
- **Real proof `left join` was the right call:** `Essentials` and `Entertainment` show `NULL` for `ParentCategoryName` rather than vanishing from the result — if this had used `inner join` instead, both rows would have been dropped entirely, leaving only 3 of the 5 real categories, same as 3 of the 4 accounts would've vanished in `02 sql joins.md`'s own Accounts self-join example.
- **Connects back to Piece 0, and to what's still ahead:** Piece 0's ER diagram flagged this self-join by name from the very start as "what makes the self-join and the recursive CTE later in the project meaningful rather than forced." This piece is the flat, one-level version — each child shows only its immediate parent. The recursive CTE still ahead (`05 sql ctes.md`, Required Coverage checklist) will walk the *full* chain instead of just one hop, which matters the moment a category sits more than one level deep (this schema's current hierarchy is only 2 levels, so this flat version already fully resolves it — but the recursive version is what wouldn't break if a third level got added later).
- **What this is really answering (interview-style scenario):** `02 sql joins.md`'s own interview question #7 fits this exactly — "why does `Checking` show `NULL` as its parent instead of being dropped?" The `Categories` version of the same question is "why do `Essentials` and `Entertainment` show `NULL` instead of disappearing?", and the real output above proves the same answer both times: `left join` keeps every row regardless of whether a match exists.

Questions along the way: none — understood on the first pass.

---

All five join types are done — inner (12), left (13), right (14), full outer (15), self-join (16). Next on the Required Coverage checklist is set operators: `union`/`union all`, `intersect`, `except`, each one meant to be "actually useful for this domain, not forced in just to check a box." Rather than start a new domain thread, this reuses the exact same real comparison Piece 15 already set up — budgeted `(UserID, CategoryID)` pairs vs. actually-spent-against `(UserID, CategoryID)` pairs, bridging `Transactions` to `UserID` through `Accounts` the same way — because set operators are a genuinely different *tool* for answering the same real question Piece 15 answered with a join, and seeing both tools land on the same real facts is more convincing than two unrelated toy examples.

`union` first: "every `(UserID, CategoryID)` combination that has *any* financial activity at all — either a budget set for it, or real spending against it." A real use for this: a budget-setup screen deciding which user/category combinations to show as "has history" versus entirely new. `03 sql set operators.md` §1 is explicit that `union` only visibly removes something when the two source queries genuinely overlap on real rows, not just on paper — and here they do for real: `(1, 3)` (User 1, Groceries) is a true duplicate, produced once by `Budgets` and *twice* by `Transactions` (Weekly groceries and Groceries top-up both land on the same pair), and `(1, 4)` (User 1, Rent) is produced by both tables too. That's 8 raw rows going in before any deduplication.

## Piece 17 — union (Budgets + Transactions, every budgeted-or-spent UserID/CategoryID pair)

```sql
select UserID, CategoryID from Budgets
union
select a.UserID, tr.CategoryID
from Transactions tr
inner join Accounts a on tr.AccountID = a.AccountID
order by UserID, CategoryID;
```

Confirmed real output:

```
-- Budgets alone (3 raw rows)
UserID  CategoryID
------  ----------
1       3
1       4
2       5

(3 rows affected)

-- Transactions-derived alone (5 raw rows, (1,3) genuinely appears twice)
UserID  CategoryID
------  ----------
1       3
1       3
1       4
1       5
2       3

(5 rows affected)

-- final result: union of both (5 distinct rows, deduplicated from 8 raw)
UserID  CategoryID
------  ----------
1       3
1       4
1       5
2       3
2       5

(5 rows affected)
```

Notes:
- **What we did and what it shows:** real, provable deduplication — 3 raw rows from `Budgets` plus 5 raw rows from the transaction side is 8 total going in, but the final `union` result is only 5 distinct rows. `(1, 3)` (User 1, Groceries) alone accounts for 3 of those 8 raw rows (1 from `Budgets`, 2 from `Transactions` — Weekly groceries and Groceries top-up both land on the same pair) collapsing down to 1; `(1, 4)` (User 1, Rent) goes from 2 raw rows to 1. That's `03 sql set operators.md` §1's "real duplicate-removal effect" happening on this project's own real data, not a constructed example.
- **Why the intermediate checks matter here:** running `Budgets` alone and the transaction-derived subquery alone first, before the full `union`, is exactly how that doc frames tracing a set operator — confirm what each side independently produces, so the combined result's row count (5, not 8) is provably a dedup effect rather than something taken on faith.
- **What this is really answering (interview-style scenario):** "give me every user/category combination that has any financial history at all, budgeted or spent, with no duplicates" is a real question a budget-setup screen would ask before showing a user a list of categories to configure — and it's also the exact Venn-diagram "either list" picture `union` is built to answer, not a filter forced onto a single table.

Questions along the way: none — understood on the first pass.

---

`union` combined everything from Piece 17's two real sets. `intersect` asks a narrower, genuinely different question: which `(UserID, CategoryID)` pairs show up in *both* `Budgets` and real spending at once — a user/category combination that's both budgeted for and actually being spent against. `03 sql set operators.md` §2 makes an honest point worth repeating here: a two-condition `intersect` like its own Salary/HireDate example "could have been written as one query with `where ... and ...`", and for a single table, that's genuinely the more common way to write it — `intersect` earns its keep specifically when the two conditions come from two different tables or two differently-shaped queries that aren't easy to combine with a plain `and`, which is exactly this case: `Budgets` and `Transactions` aren't the same table, so there's no single `where` clause that could ask this question directly.

The predicted result is checkable before it's even run: `intersect` can never return more rows than the smaller of its two inputs, and every row it returns has to already be one of Piece 17's 5 `union` rows — `intersect` is always a subset of `union` on the same two queries.

## Piece 18 — intersect (Budgets + Transactions, UserID/CategoryID pairs that are both budgeted AND actually spent)

```sql
select UserID, CategoryID from Budgets
intersect
select a.UserID, tr.CategoryID
from Transactions tr
inner join Accounts a on tr.AccountID = a.AccountID
order by UserID, CategoryID;
```

Confirmed real output:

```
-- Budgets alone (3 raw rows)
UserID  CategoryID
------  ----------
1       3
1       4
2       5

(3 rows affected)

-- Transactions-derived alone (5 raw rows, (1,3) genuinely appears twice)
UserID  CategoryID
------  ----------
1       3
1       3
1       4
1       5
2       3

(5 rows affected)

-- final result: intersect of both (2 rows - pairs present in BOTH sets)
UserID  CategoryID
------  ----------
1       3
1       4

(2 rows affected)
```

Notes:
- **What we did and what it shows:** real proof of the prediction — exactly 2 rows came back, `(1, 3)` and `(1, 4)`, both correctly bounded below Piece 17's 5-row `union` result and below both inputs (3 and 5), since `intersect` can never return more rows than its smaller input.
- **What this is really answering (interview-style scenario):** "which budgets are actually being tracked against real spending right now" — a dashboard question distinct from either Piece 17's "any activity at all" or a plain filter on one table, and genuinely needs two different tables' worth of data to answer, which is exactly when `03 sql set operators.md` §2 says `intersect` earns its keep over a single-table `where ... and ...`.
- **A gap worth naming out loud:** `(2, 5)` — User 2's Movies budget (BudgetID 3) — is real and confirmed (Piece 11), but it's missing from this result. That's not a bug; it means User 2 has a Movies budget with zero real spending against it so far. `intersect` only shows the overlap, so a budget with no matching activity simply doesn't appear here — which is precisely the gap the next piece, `except`, is built to surface directly instead of leaving it implicit.

Questions along the way: none — understood on the first pass.

---

`intersect` showed what's shared. `except` asks the last and most different question of the three: which `(UserID, CategoryID)` pairs are in `Budgets` but *never* show up in real spending — budgets with zero activity against them. `03 sql set operators.md` §3 is explicit about one thing that makes `except` different from both `union` and `intersect`: it's directional. `A except B` and `B except A` are genuinely different questions with different answers, not just the same result in a different row order - unlike `union`/`intersect`, which don't care which side is written first. Piece 18's own closing note already named the real row this should surface: `(2, 5)`, User 2's Movies budget (BudgetID 3), which has a real budget (Piece 11) but no real transaction anywhere in `Transactions` tagged to that same user and category (Piece 9) - exactly matching what Piece 15's full outer join already proved from the join side.

## Piece 19 — except (Budgets EXCEPT Transactions — budgeted UserID/CategoryID pairs with zero real spending)

```sql
select UserID, CategoryID from Budgets
except
select a.UserID, tr.CategoryID
from Transactions tr
inner join Accounts a on tr.AccountID = a.AccountID
order by UserID, CategoryID;
```

Confirmed real output:

```
-- Budgets alone (3 raw rows)
UserID  CategoryID
------  ----------
1       3
1       4
2       5

(3 rows affected)

-- Transactions-derived alone (5 raw rows, (1,3) genuinely appears twice)
UserID  CategoryID
------  ----------
1       3
1       3
1       4
1       5
2       3

(5 rows affected)

-- final result: except of both (1 row - budgeted pairs with zero real spending)
UserID  CategoryID
------  ----------
2       5

(1 row affected)
```

Notes:
- **What we did and what it shows:** real proof of the full prediction chain built up across Pieces 15, 17, and 18 — exactly 1 row came back, `(2, 5)`, User 2's Movies budget. That is the exact gap Piece 18's `intersect` result left unexplained, and the exact row Piece 15's full outer join already showed as "budgeted, nothing spent" (`NULL` on the transaction side). Three independent query techniques — full outer join, intersect, and except — all point at the same real row, which is a stronger kind of confirmation than any single query running cleanly: three different tools agreeing on the same fact.
- **What this is really answering (interview-style scenario):** "which budgets have I set up that I haven't touched at all this period" — genuinely different from `union`'s "any activity at all" or `intersect`'s "overlap", and the kind of question a budgeting app's dashboard would use to nudge a user (you budgeted for Movies but haven't logged any spending there yet).
- **Why direction matters here:** flip the query to `Transactions EXCEPT Budgets` (swap which side is written first) and the question becomes "which real spending happened against a user/category pair with no budget at all" — not run as part of this piece, but predictable from data already confirmed: 2 rows, `(1, 5)` — User 1 spent on Movies (TxID 4) but User 1 has no Movies budget, only User 2 does — and `(2, 3)` — User 2 spent on Groceries (TxID 5) but User 2's only budget is for Movies, not Groceries. Two completely different answers from the same two tables, just by swapping which side comes first, which is exactly the point `03 sql set operators.md` §3 makes about `except` not being commutative the way `union`/`intersect` are.

Questions along the way: none — understood on the first pass.

---

Set operators are done — `union`, `intersect`, and `except` have all now run on the same real `Budgets` vs. `Transactions` data, and Pieces 15/17/18/19 all agree with each other on the same underlying facts, proven from four different angles. The spec's "Required coverage" checklist moves next to window functions: `row_number()`, `rank()`/`dense_rank()`, `lag()`/`lead()`, and running totals with `sum() over()` — all built on `partition by`, which is the core idea the rest of this phase depends on. `04 sql window functions.md` §1 explains `partition by` as the key difference from `group by`: `group by` collapses each group down to one summary row, while a window function keeps every original row and just adds a per-row value computed over its own partition — nothing gets collapsed away.

The clearest way to show that restart-per-partition behavior on real data is to rank each user's own transactions by size, independently per user, so User 2's single transaction gets its own rank 1 instead of continuing User 1's numbering.

## Piece 20 — row_number() and rank() with partition by (ranking each user's transactions by amount)

```sql
select
    a.UserID,
    tr.TransactionID,
    tr.Amount,
    tr.TransactionDate,
    row_number() over (partition by a.UserID order by tr.Amount asc) as RowNum,
    rank() over (partition by a.UserID order by tr.Amount asc) as ExpenseRank
from Transactions tr
inner join Accounts a on tr.AccountID = a.AccountID
order by a.UserID, ExpenseRank;
```

Confirmed real output:

```
UserID  TransactionID  Amount    TransactionDate  RowNum  ExpenseRank
------  -------------  --------  ---------------  ------  -----------
1       1              -1500.00  2026-09-01       1       1
1       2              -120.50   2026-09-05       2       2
1       3              -95.10    2026-09-19       3       3
1       4              -45.00    2026-09-10       4       4
2       5              -80.25    2026-09-12       1       1

(5 rows affected)
```

Notes:
- **What we did and what it shows:** real proof of the full prediction — exactly 5 rows came back, User 1's 4 transactions ranked 1 through 4 by size (September rent, the biggest expense, landing at rank 1), and User 2's 1 transaction landing at rank 1 again instead of continuing on as rank 5. `RowNum` and `ExpenseRank` agree on every single row, exactly as predicted, because nothing in this real data ties.
- **How this connects to `04 sql window functions.md`:** §1 is exactly what `RowNum` demonstrates, and its "`group by` vs. `partition by` - the same bucket, two different outputs" sub-section is the precise reason all 5 original rows survived here instead of collapsing into 2 summary rows the way `group by a.UserID` would have — `partition by` tags every row with extra computed columns, it never removes or merges rows. `ExpenseRank` formally belongs to §2, "`rank()` and `dense_rank()` - ranking with ties," though this real data doesn't contain a tie yet to show `rank()`'s distinguishing behavior against `row_number()` — that is exactly what the next piece provides, using a real tie elsewhere in this project's data.
- **What this is really answering (interview-style scenario):** "show me each user's biggest expenses first, ranked just for them" — a personalized "top transactions" view is a realistic feature for a finance app's dashboard, and it genuinely needs `partition by` specifically because the ranking has to reset per user — a single global ranking across all users mixed together would rank User 2's only transaction against User 1's four, which isn't the question a per-user view is actually asking.
- **What this query is doing, explained simply:** picture two separate rooms, one for User 1 and one for User 2. Every transaction walks into the room that belongs to its owner. Inside each room, the transactions line up on their own, biggest expense first, smallest last. Then each one gets a number for its place in that line — 1st, 2nd, 3rd — but only counting the people in its own room. User 2's room only has one transaction in it, so that transaction is automatically "1st" in its room, even though it never stood next to anyone from User 1's room.

  A real-life version of this: think of a school handing out rank 1, rank 2, rank 3 separately in every classroom, instead of ranking the entire school together. A student who is "rank 1 in Class B" isn't being compared to Class A at all — each class restarts its own count at 1. That is what `partition by` does to the rows here: it puts them in separate classrooms first, before anything gets numbered.

  Where this shows up in real life: a finance app's "your biggest expenses" screen works exactly this way — every person sees their own list starting at number 1, and it never depends on how many transactions some other user happens to have.

  The same thing, step by step, in plain words:
  step 1 — join the two tables, so every transaction also shows which user owns it (because `Transactions` only knows the `AccountID`, not the `UserID`, so `Accounts` has to be joined in to supply it).
  step 2 — split the rows into separate groups, one group per user (`partition by a.UserID`). this is the "separate rooms" step.
  step 3 — inside each group only, sort the rows from biggest expense to smallest (`order by tr.Amount asc`).
  step 4 — number the rows in that sorted order, starting over at 1 in every group (`row_number()` and `rank()`).
  step 5 — a separate, final step decides what order the rows are shown on screen (the outer `order by a.UserID, ExpenseRank`) — this does not change the numbers from step 4, it only changes the order they're displayed in.

  Connecting it back to the technical terms: "separate rooms" is `partition by`, "line up inside the room" is the `order by` written inside `OVER()`, and "give out position numbers" is `row_number()`/`rank()`.
- **What this query is doing, technical step-by-step:** four things are happening in this query, and SQL Server applies them in this order regardless of how they're arranged on the page.

  1. **`from Transactions tr inner join Accounts a on tr.AccountID = a.AccountID`** runs first and builds the complete working set before anything else happens. This is the exact same UserID-bridging join reused from Pieces 15, 17, 18, and 19: `Transactions` never stores `UserID` directly, only `AccountID`, while `Accounts` does store `UserID` — so this join exists purely to attach each transaction to its owner before any ranking can happen. The result at this stage is all 5 real transactions, each now carrying its `UserID` alongside its own columns.

  2. **The two window functions' `OVER (partition by a.UserID order by tr.Amount asc)` clauses** each define a "window" — a slice of that 5-row working set — for their own function to operate over. `partition by a.UserID` splits the 5 rows into separate, independent groups, one per distinct `UserID`: this data has exactly 2 distinct values, so there are exactly 2 partitions — User 1's 4 transactions, and User 2's 1. `order by tr.Amount asc` then sorts the rows *within each partition only* — since every `Amount` here is a negative expense, ascending order puts the single biggest expense first in each partition. Note that this clause had to be written out twice, once for `row_number()` and once for `rank()` — a window function's `OVER` clause belongs to that one function call, it isn't shared automatically just because two functions happen to want the same window (SQL Server does have a named `WINDOW` clause that avoids the duplication, but that's a later convenience, not required here).

  3. **`row_number()` and `rank()`** then number the rows inside each partition, in the sorted order from step 2, restarting at 1 every time a new partition begins. That restart is the entire point of `partition by`: User 2's one transaction gets `RowNum`/`ExpenseRank` = 1, not 5, because its window is completely independent of User 1's.

  4. **The outer `order by a.UserID, ExpenseRank`** is a separate thing entirely from the `order by` inside the `OVER()` clauses, even though both happen to sort by amount-related logic here. The inner `order by` only controls the order used to *compute* the ranking inside each partition; the outer `order by` only controls the order the final rows are *displayed* in. They don't have to match — a query could rank rows by `Amount` internally while displaying them sorted by `TransactionDate` instead.

  Running `row_number()` and `rank()` side by side here, on real data, is deliberate rather than redundant: it's how this piece proves — rather than just asserts — that the two functions agree whenever nothing ties.
- **Visual representation:** the diagram below shows this same flow as a picture — the four-step pipeline at the top, then the real 5 rows split into their two real partitions underneath it, with the dashed line marking exactly where the numbering resets.

![Piece 20 window functions diagram](finance_tracker_db/diagrams/piece20_window_functions.png)

Questions along the way: none — understood on the first pass.

---

`row_number()` and `rank()` agreed on every row in Piece 20 because nothing in that data tied. This piece uses a real tie that already exists elsewhere in the project: three real categories have transactions tagged to them (Groceries, Rent, Movies — Piece 9's real data), and two more (Essentials, Entertainment) have none tagged directly, only through their children (Piece 16's self-join already established that hierarchy). Counting real transactions per category and ranking the categories by that count produces a genuine tie twice over — Rent and Movies both have exactly 1 transaction, and Essentials and Entertainment both have exactly 0 — which is exactly the real-data situation `04 sql window functions.md` §2 needs to show `rank()`'s defining behavior: it leaves a gap in the numbering after a tie (1, 2, 2, **4**, 4 — skipping 3 entirely, since two rows already used rank 2), while `dense_rank()` numbers the same tie without a gap (1, 2, 2, **3**, 3). `row_number()` is deliberately left out of this piece: with a tie, its tie-breaking order isn't guaranteed by this query, so it wouldn't have a single correct value to predict and confirm against the way `rank()` and `dense_rank()` do.

## Piece 21 — rank() and dense_rank() with a real tie (ranking every category by transaction count, including zero-count categories)

```sql
select
    c.CategoryID,
    c.CategoryName,
    count(tr.TransactionID) as TxnCount,
    rank() over (order by count(tr.TransactionID) desc) as CategoryRank,
    dense_rank() over (order by count(tr.TransactionID) desc) as CategoryDenseRank
from Categories c
left join Transactions tr on tr.CategoryID = c.CategoryID
group by c.CategoryID, c.CategoryName
order by CategoryRank, c.CategoryID;
```

Confirmed real output:

```
CategoryID  CategoryName   TxnCount  CategoryRank  CategoryDenseRank
----------  -------------  --------  ------------  -----------------
3           Groceries      3         1             1
4           Rent           1         2             2
5           Movies         1         2             2
1           Essentials     0         4             3
2           Entertainment  0         4             3

(5 rows affected)
```

Notes:
- **What this query is doing, explained simply:** every category gets counted up — how many real transactions does it actually have? Groceries has 3, Rent has 1, Movies has 1, and Essentials and Entertainment have 0 each, because nothing was ever tagged to them directly (only their children were). Once every category has a count, they get placed in order from most transactions to least, and `rank()`/`dense_rank()` hand out a position number for that order — like a leaderboard. The twist here is that two different pairs of categories end up with the exact same count, so two different categories can legitimately tie for the same position on the leaderboard, and this piece is about what happens to the numbering when that occurs.

  A real-life version of this: imagine a race where two runners cross the finish line at the exact same time and both get awarded "2nd place." `rank()` is strict about it: because two people are already standing on the 2nd place podium, nobody gets called "3rd place" at all — the next runner is announced as "4th place," even though only three people actually finished. `dense_rank()` is the friendlier version: it still gives both tied runners "2nd place," but the very next runner is called "3rd place" — no position number gets skipped.

  Where this shows up in real life: any leaderboard, ranking, or "top N" report that might contain ties — top sellers, highest scores, most active users — has to pick one of these two behaviors on purpose, because the two give genuinely different answers whenever two entries tie.

  The same thing, step by step, in plain words:
  step 1 — join every category to its transactions, keeping categories even when they have zero matches (`left join`, not `inner join` — an `inner join` here would have silently dropped Essentials and Entertainment entirely, since they have no direct transactions to match on).
  step 2 — count the real transactions per category (`count(tr.TransactionID)`), and shrink the result down to one row per category (`group by`).
  step 3 — order all 5 categories by that count, highest first (`order by count(tr.TransactionID) desc`, inside each window function's own `OVER()`).
  step 4 — hand out position numbers in that order, two different ways at once: `rank()` leaves a gap after a tie, `dense_rank()` does not.
- **What this query is doing, technical step-by-step:** four things are happening here, applied in this order regardless of how the query is laid out on the page.

  1. **`from Categories c left join Transactions tr on tr.CategoryID = c.CategoryID`** — a `left join` is required, not an `inner join`, specifically so that a category with zero matching transactions still produces one output row (with `tr.TransactionID` coming back `NULL` for that row) instead of disappearing from the result entirely. This is the only piece so far that deliberately needs categories with *no* transactions to survive the join.

  2. **`group by c.CategoryID, c.CategoryName`** collapses all the matching `Transactions` rows for each category down into a single summary row, and `count(tr.TransactionID)` counts how many of those matched rows have a real (non-`NULL`) `TransactionID` — which is exactly 0 for Essentials and Entertainment, since their one joined row has `tr.TransactionID = NULL`. `count()` never counts `NULL`s, which is what makes the zero show up correctly instead of counting 1 "empty" row.

  3. **`rank() over (order by count(tr.TransactionID) desc)` and `dense_rank() over (order by count(tr.TransactionID) desc)`** both run *after* the `group by` has already produced one row per category — this is allowed in SQL Server because window functions are logically evaluated after grouping, so `count(tr.TransactionID)` can be reused directly inside the `OVER()`'s `order by` even though it's an aggregate. Neither function uses `partition by` here, unlike Piece 20 — there's only one group (all 5 categories together), so the whole result is treated as a single window.

  4. **The difference in behavior:** with the real counts 3, 1, 1, 0, 0, both functions agree that Groceries is rank 1 and that Rent and Movies tie for rank 2. From there they diverge: `rank()` counts the two rows that already used "2" and jumps straight to 4 for the next distinct value, leaving "3" completely unused; `dense_rank()` only cares how many *distinct* count-values have been seen so far, so it moves straight to 3. Both are internally consistent, correct answers to two subtly different questions: "what position is this row in, counting every row ahead of it" (`rank()`) versus "how many distinct groups are ahead of this one" (`dense_rank()`).
- **How this connects to `04 sql window functions.md`:** §2, "`rank()` and `dense_rank()` - ranking with ties," is the section this piece exists to prove on real data — this project's own `Categories`/`Transactions` tables happened to already contain a genuine tie (twice over), so no artificial example was needed to show the gap-vs-no-gap difference.
- **What this is really answering (interview-style scenario):** "rank every category by how much real activity it has, and tell me honestly when two categories are tied" — a realistic reporting question, and also one of the most commonly asked SQL interview questions precisely because so many candidates don't realize `rank()` and `dense_rank()` disagree the moment a tie shows up.
- **Why `row_number()` was deliberately left out this time:** with a genuine tie in the data, `row_number()` still has to assign two different numbers to Rent and Movies (it never repeats a number), but SQL Server doesn't guarantee *which* of the two gets 2 and which gets 3 without an explicit tiebreaker column — so there's no single correct value to predict in advance and confirm against, the way there is for `rank()`/`dense_rank()`. That unpredictability is itself the reason `rank()`/`dense_rank()` exist as separate functions from `row_number()`.

Questions along the way: none — understood on the first pass.

---

`row_number()`, `rank()`, and `dense_rank()` are all done now, including a real tie to prove where they actually differ. `04 sql window functions.md` §3 covers the other pair on the Required Coverage checklist: `lag()` and `lead()`, which don't rank anything — they look sideways at a neighboring row instead, one step back (`lag()`) or one step forward (`lead()`) within the same ordered partition. The clearest real question this project can ask with them is a trend question Piece 20's per-user ranking couldn't answer on its own: for each user, going transaction by transaction in date order, was the next transaction bigger or smaller than the one before it?

## Piece 22 — lag() and lead() (comparing each transaction to the one before and after it, per user, in date order)

```sql
select
    a.UserID,
    tr.TransactionID,
    tr.TransactionDate,
    tr.Amount,
    lag(tr.Amount) over (partition by a.UserID order by tr.TransactionDate) as PrevAmount,
    lead(tr.Amount) over (partition by a.UserID order by tr.TransactionDate) as NextAmount
from Transactions tr
inner join Accounts a on tr.AccountID = a.AccountID
order by a.UserID, tr.TransactionDate;
```

Confirmed real output:

```
UserID  TransactionID  TransactionDate  Amount    PrevAmount  NextAmount
------  -------------  ---------------  --------  ----------  ----------
1       1              2026-09-01       -1500.00  NULL        -120.50
1       2              2026-09-05       -120.50   -1500.00    -45.00
1       4              2026-09-10       -45.00    -120.50     -95.10
1       3              2026-09-19       -95.10    -45.00      NULL
2       5              2026-09-12       -80.25    NULL        NULL

(5 rows affected)
```

Notes:
- **What this query is doing, explained simply:** imagine User 1's transactions laid out in a single-file line, in the order they actually happened by date — not by `TransactionID`, which is why TxnID 4 (dated 09-10) appears *between* TxnID 2 (09-05) and TxnID 3 (09-19) in this output, out of ID order but in true date order. For every transaction in that line, `PrevAmount` is "what's the amount on the transaction standing right before me," and `NextAmount` is "what's the amount on the transaction standing right after me." The very first person in line has nobody standing in front of them, so their `PrevAmount` comes back empty (`NULL`). The very last person has nobody behind them, so their `NextAmount` comes back empty too.

  A real-life version of this: picture people queued up at a checkout counter. Each person can turn around and ask "how much did the person just ahead of me spend?" (`lag`) or "how much is the person just behind me about to spend?" (`lead`). The person at the very front of the queue has nobody ahead to ask — there's simply no answer, not a zero, an actual "nothing there." Same for the person at the very back asking about who's behind them.

  Where this shows up in real life: any "what changed since last time" or "is this trending up or down" feature — a spending-trend arrow next to a transaction, a stock price's day-over-day change, a step counter comparing today to yesterday — is built on exactly this "look at my neighbor" idea.

  The same thing, step by step, in plain words:
  step 1 — join the two tables, so every transaction also shows which user owns it, same bridge as every other piece since Piece 15.
  step 2 — split the rows into separate lines, one line per user (`partition by a.UserID`) — User 2's line only has 1 person in it.
  step 3 — inside each line, put the transactions in true date order (`order by tr.TransactionDate`), not ID order.
  step 4 — for every transaction, look one step back (`lag`) and one step forward (`lead`) within its own line only, and come back empty at either end of the line.
- **What this query is doing, technical step-by-step:** four things happen here, applied in this order regardless of how the query is written on the page.

  1. **`from Transactions tr inner join Accounts a on tr.AccountID = a.AccountID`** builds the same 5-row UserID-bridged working set reused since Piece 15 — every transaction, now carrying its owner's `UserID`.

  2. **`lag(tr.Amount) over (partition by a.UserID order by tr.TransactionDate)`** and **`lead(tr.Amount) over (...)`** share the same window definition as each other (same `partition by`/`order by`, written out twice, same reason as Piece 20): split the 5 rows into 2 partitions by `UserID`, then sort each partition by `TransactionDate` rather than `Amount` this time — the ordering column is what defines "before" and "after" for `lag`/`lead`, so it had to change from Piece 20's amount-based ordering to a genuinely chronological one for "before/after" to mean something real.

  3. **`lag()` reads the `Amount` value from the row one position back** in that chronological order, within the same partition; **`lead()` reads the `Amount` value from the row one position forward**. Both default to `NULL` when there is no such row — SQL Server doesn't wrap around to the other end of the partition or borrow a value from a different partition; it genuinely returns nothing.

  4. **Why the result lands in `TransactionID` order 1, 2, 4, 3 for User 1, not 1, 2, 3, 4:** the outer `order by a.UserID, tr.TransactionDate` displays rows by date, and TxnID 4 ("Movie night," 09-10) genuinely happened chronologically between TxnID 2 (09-05) and TxnID 3 (09-19) — this is the same project data as always, just finally sorted by when things happened rather than by the order they were inserted.
- **How this connects to `04 sql window functions.md`:** §3, "`lag()` and `lead()` - looking at neighboring rows," together with its "`lag()`/`lead()` with `partition by` - multiple separate sequences, not one" sub-section, is exactly this piece: two separate per-user sequences, each with its own independent start and end, rather than one long sequence spanning both users (which would have wrongly let User 2's single transaction "borrow" a neighbor from User 1's list).
- **What this is really answering (interview-style scenario):** "for each of my transactions, how does it compare to the one right before and right after it" is the mechanism behind a "spending went up/down from last time" indicator on a transaction list — a common feature request, and `lag()`/`lead()` exist specifically so this doesn't require a self-join or a manual subquery to answer.
- **Real proof the partition boundary holds here too:** User 2 has exactly 1 transaction and both `PrevAmount` and `NextAmount` came back `NULL` for it — not borrowed from User 1's last or first transaction — confirming `partition by` keeps `lag()`/`lead()` just as contained as it kept `row_number()`/`rank()` in Piece 20.

Questions along the way: none — understood on the first pass.

---

Every window function on the Required Coverage checklist has now run except one: `04 sql window functions.md` §4, running totals with `sum() over()`. This is also the most directly useful one for a finance app specifically — a running balance that updates with every transaction, the kind of number a real account screen shows next to each line item. This project's `Accounts.Balance` column has sat at a placeholder 0.00 since Piece 4 for exactly this reason: a real running balance is something a query computes from transaction history, not a number the schema stores and hopes stays in sync.

## Piece 23 — sum() over() (running balance per account, in date order)

```sql
select
    tr.AccountID,
    tr.TransactionID,
    tr.TransactionDate,
    tr.Amount,
    sum(tr.Amount) over (partition by tr.AccountID order by tr.TransactionDate
                          rows between unbounded preceding and current row) as RunningTotal
from Transactions tr
order by tr.AccountID, tr.TransactionDate;
```

Confirmed real output:

```
AccountID  TransactionID  TransactionDate  Amount    RunningTotal
---------  -------------  ---------------  --------  ------------
1          1              2026-09-01       -1500.00  -1500.00
1          2              2026-09-05       -120.50   -1620.50
1          3              2026-09-19       -95.10    -1715.60
2          4              2026-09-10       -45.00    -45.00
3          5              2026-09-12       -80.25    -80.25

(5 rows affected)
```

Notes:
- **What this query is doing, explained simply:** think of a jar for each account, starting empty. Every time a transaction happens on that account, its amount gets dropped into the jar, and `RunningTotal` tells you the jar's total *right after* that transaction dropped in — not before, not after any later ones. Account 1 had three transactions, so its jar gets checked three times, each time showing a bigger (more negative) total than the last. Accounts 2 and 3 each only had one transaction, so their jar's running total is just that one transaction, since there was nothing dropped in before it.

  A real-life version of this: think of a checkbook register, the old paper kind, where every line has its own "balance after this transaction" column, filled in by hand, one line at a time, adding the new line to whatever the balance already was above it. `RunningTotal` is exactly that column, except SQL recalculates it instantly for every row instead of someone doing the arithmetic by hand.

  Where this shows up in real life: this is the single most common use of a window function in a finance app specifically — the number shown next to every transaction on a bank statement or account screen, saying "your balance was this much right after this transaction."

  The same thing, step by step, in plain words:
  step 1 — split the transactions into separate jars, one jar per account (`partition by tr.AccountID`) — a running total for one account should never include another account's money.
  step 2 — inside each jar, line the transactions up by date (`order by tr.TransactionDate`), oldest first, since a running total only makes sense in chronological order.
  step 3 — at each transaction, add up every amount from the very first one in that jar up through this one, and nothing after it (that's what the question specifically asks about below).
- **What this query is doing, technical step-by-step:** three things happen here, applied in this order regardless of how the query is written on the page.

  1. **`from Transactions tr`** — no join to `Accounts` was needed this time, unlike every window-function piece before it. `AccountID` already lives directly on `Transactions`, and this query only needs to group by account, not by user — so the UserID-bridging join from Pieces 15, 17-22 simply isn't necessary here.

  2. **`partition by tr.AccountID order by tr.TransactionDate`** splits the 5 rows into 3 partitions (one per real `AccountID`: 1, 2, 3) and sorts each partition chronologically — the same `partition by`/`order by` pattern as every other window function piece, just partitioned one level more granular (by account rather than by user, since two of User 1's accounts, Checking and Savings, need two separate running balances, not one combined one).

  3. **`sum(tr.Amount)`** adds up the `Amount` values of every row inside the frame the next part defines, for each row.

- **`rows between unbounded preceding and current row` — what this is doing, specifically:** this is called the **frame clause**, and it is a third, separate piece of a window function's definition, alongside `partition by` (which rows are even in play) and `order by` (what order to process them in). The frame clause answers a different question from either of those: for *this specific row*, exactly which of the other rows already selected into its partition should actually get added into the `sum()` — all of them, or only some? `unbounded preceding` means "start from the very first row in this partition, no limit on how far back" — that's the left edge of the frame. `current row` means "stop at the row being calculated right now, don't include anything after it" — that's the right edge. Put together, the frame grows by exactly one row every time the calculation moves to the next row: for TransactionID 1 (the first in Account 1's partition), the frame is just that one row, so `RunningTotal` = `Amount`. For TransactionID 2, the frame now covers rows 1 and 2, so `RunningTotal` = both amounts added together. For TransactionID 3, the frame covers all three — that is exactly why the numbers 1500.00, then 1620.50, then 1715.60 keep growing instead of resetting: each row's frame is a strict superset of the one before it, never a completely different window.

  Worth knowing for later: SQL Server actually defaults to this exact frame (`range between unbounded preceding and current row`, which behaves the same as `rows` here since no two dates tie within a partition) whenever `order by` is present inside `OVER()` and no frame is written at all — so this clause was technically optional for this specific query. It was still written out explicitly on purpose: relying on an unwritten default is a common real source of subtle bugs once the data has ties, because `range` (the default) treats *tied* `order by` values as one combined group, while `rows` (what's written here) always treats every physical row separately even when two rows tie on the ordering column. Writing the frame out by hand removes any doubt about which behavior is actually running.
- **How this connects to `04 sql window functions.md`:** §4, "`sum() over()` - running totals," is exactly this piece, and is also the doc's most directly finance-relevant example — this project's own `Accounts.Balance` column has sat at a placeholder 0.00 since Piece 4 precisely because a real balance is a running total computed from transaction history, which is what this query now proves it can do on real data.
- **What this is really answering (interview-style scenario):** "show me my balance after every transaction, per account" is one of the most common real screens a finance app has, and `sum() over()` with this exact frame clause is the standard way to answer it — the alternative (a correlated subquery re-summing everything before each row, one row at a time) does the same job far less efficiently.

Questions along the way: none — understood on the first pass.

---

Every window function on the Required Coverage checklist is done — `row_number()`, `rank()`, `dense_rank()`, `lag()`, `lead()`, and `sum() over()` with an explicit frame clause, all proven on this project's own real data. The checklist's next item is Common Table Expressions, `05 sql ctes.md` — and this project already has unfinished business with one: Piece 15's full outer join used a derived table (an inline subquery in the `FROM` clause) specifically because CTEs hadn't been covered yet, with an explicit note that it was "a strong candidate to revisit... once that piece comes up." A plain CTE (`with ... as (...)`) would just be a cleaner way to write that same derived table. A more interesting use of a CTE, though, is one a derived table structurally cannot do at all: a **recursive** CTE, which can walk a hierarchy of unknown depth — and this project already has a real hierarchy to walk, `Categories.ParentCategoryID`, the same self-referencing relationship Piece 16's self-join covered. The difference this piece will make visible: Piece 16's self-join can only ever see one level — a child and its immediate parent, in the same row — while a recursive CTE can walk every level, however many there turn out to be, starting from the top and working down.

## Piece 24 — a recursive CTE (walking the full Categories hierarchy, top to bottom)

```sql
with CategoryHierarchy as (
    select CategoryID, CategoryName, ParentCategoryID, 0 as Level
    from Categories
    where ParentCategoryID is null

    union all

    select c.CategoryID, c.CategoryName, c.ParentCategoryID, ch.Level + 1
    from Categories c
    inner join CategoryHierarchy ch on c.ParentCategoryID = ch.CategoryID
)
select CategoryID, CategoryName, ParentCategoryID, Level
from CategoryHierarchy
order by Level, CategoryID;
```

Confirmed real output:

```
CategoryID  CategoryName   ParentCategoryID  Level
----------  -------------  ----------------  -----
1           Essentials     NULL              0
2           Entertainment  NULL              0
3           Groceries      1                 1
4           Rent           1                 1
5           Movies         2                 1

(5 rows affected)
```

Notes:
- **What this query is doing, explained very simply, broken into small pieces:** this is the one thing that actually makes it feel confusing, so it gets its own plain-English name: this is not really "a query joining itself." It is one query that quietly **runs multiple times in a row**, like a loop, and each time it runs it only looks at what the *previous* run just found — never the whole growing pile of results, and never itself while it's still running.

  Think of it like passing a note around a circle of people, one person at a time:
  - **Person 1 (the anchor member)** writes down the names of the two categories that have no parent at all — Essentials and Entertainment — and passes that small note on. Person 1 only ever does this once.
  - **Person 2 (the recursive member, round 1)** receives that note (just those 2 names), and asks "does `Categories` have anyone whose parent is one of the names on this note?" It finds 3 — Groceries and Rent (children of Essentials) and Movies (child of Entertainment) — writes *those* 3 names on a brand new note, and passes that new note on.
  - **Person 2 does the exact same thing again (round 2)**, but now holding the note with only 3 names on it (Groceries, Rent, Movies). It asks "does anyone have one of THESE as a parent?" Nobody does — none of these three categories have any children in the real data — so this round's note comes back completely blank.
  - **A blank note is the stop signal.** Nobody is told in the SQL "stop after 2 rounds" — the loop simply ends itself the moment a round finds nothing new to add.
  - Every note that got written down along the way — person 1's 2 names, person 2's first 3 names, and person 2's second blank note (which adds nothing) — all get stacked together into one final pile. That stacking is literally what the `union all` in the middle of the query is doing: gluing every round's output together into the single final result, 5 rows total.

  A real-life version of this: think of finding everyone in a family tree starting from a grandparent — first you write down the grandparent, then you find their kids, then you go find THEIR kids, and you keep going down generation by generation until a generation turns up with no kids at all, which is when you naturally stop. Nobody has to tell you in advance how many generations there are.

  Where this shows up in real life: any menu, folder structure, org chart, or comment-thread-with-replies feature — anything where an item can contain more of itself, nested to an unknown depth — is built on exactly this pattern. A single category's parent (Piece 16's self-join) only ever gives you one generation; this recursive CTE can walk the whole family tree, however deep it turns out to be.

  **The specific part that was going over your head, named directly:** when the recursive member writes `inner join CategoryHierarchy ch`, that is NOT "joining itself to the whole final answer," and it's not actually recursive in a scary self-referencing way either — `CategoryHierarchy` there means "whatever note was just passed to me a moment ago," nothing more. SQL Server enforces this: you genuinely cannot see the whole accumulated table from inside the recursive member, only the previous round's rows — which is also exactly why trying to run that `select` on its own, outside the `with` block, fails with the real error on this project's own `.sql` file: `Invalid object name 'CategoryHierarchy'`. That name was never a real, independently queryable table the way Piece 15's derived table was — it only exists as this one-round-at-a-time hand-off, and only inside this query.
- **What this query is doing, technical step-by-step:** two members, glued together, running as an iterative loop rather than a single self-referencing evaluation.

  1. **The anchor member** — `select CategoryID, CategoryName, ParentCategoryID, 0 as Level from Categories where ParentCategoryID is null` — runs exactly once and seeds the recursion. It must be a query that does NOT reference `CategoryHierarchy` at all, since nothing exists to reference yet. On this real data it returns 2 rows (CategoryID 1 and 2), and the literal `0 as Level` is what starts the depth counter at the top of the tree.

  2. **`union all`** is what structurally joins the anchor member to the recursive member — not a regular join on a column, just "stack these result sets on top of each other," the same operator from Piece 17, except `union all` specifically (not plain `union`) because a recursive CTE is not allowed to deduplicate between rounds; each round's rows are kept exactly as produced.

  3. **The recursive member** — `select c.CategoryID, c.CategoryName, c.ParentCategoryID, ch.Level + 1 from Categories c inner join CategoryHierarchy ch on c.ParentCategoryID = ch.CategoryID` — is the part SQL Server re-executes, round after round, substituting in only the PREVIOUS round's output wherever `CategoryHierarchy` (aliased `ch`) appears. Round 1 sees `ch` = the anchor's 2 rows, and finds every `Categories` row whose `ParentCategoryID` matches one of those 2 `CategoryID`s — the 3 children, each one level deeper (`ch.Level + 1` turns round 0's `Level = 0` into `Level = 1`). Round 2 sees `ch` = those same 3 rows from round 1, looks for children of CategoryID 3, 4, or 5, and finds none — an empty result, which is the built-in termination condition: SQL Server stops recursing the instant a round adds zero new rows, with no explicit `stop` or loop counter written anywhere in the SQL.

  4. **The final `select ... from CategoryHierarchy`**, outside the `with` block, is the only place `CategoryHierarchy` means "everything from every round combined" — all 5 rows, from the `union all` of round 0's 2 plus round 1's 3 (round 2 contributed 0 and ended things). The closing `order by Level, CategoryID` just controls display order; it has nothing to do with the recursion itself, which already finished before this line runs.
- **How this connects to `05 sql ctes.md` and `02 sql joins.md`:** `05 sql ctes.md` covers the plain, non-recursive CTE as a cleaner way to write Piece 15's derived table — this piece goes further, into recursive CTEs specifically, which a plain derived table or subquery cannot do at all (a derived table is evaluated once, it can't re-run itself against its own prior output). This also directly extends `02 sql joins.md`'s self-join material from Piece 16: Piece 16's `child.ParentCategoryID = parent.CategoryID` self-join is structurally the same comparison used inside this recursive member — the difference is Piece 16 ran that comparison exactly once (one level), while this piece re-runs the identical comparison once per round until a round comes up empty, which is what lets it reach arbitrary depth instead of just one level.
- **Visual representation:** the diagram below shows the full trace — the anchor/recursive split at the top, the real 3-round "pass the note along" execution in the middle (including the real round 2 that comes back empty and stops everything), and the final 5-row result at the bottom, color-coded by which round actually produced each row.

![Piece 24 recursive CTE diagram](finance_tracker_db/diagrams/piece24_recursive_cte.png)

- **Real proof of the limitation this piece's own data has:** this project's `Categories` table is only 2 levels deep (a handful of parents, and their direct children — no grandchildren), so round 2 genuinely coming back with 0 rows is what naturally stopped the recursion here. The mechanism this piece demonstrates would keep going exactly the same way for a 3rd, 4th, or 10th level, if the real data had one — nothing about the query itself is limited to 2 levels, only this project's current real `Categories` rows are.

Questions along the way: none — understood on the first pass.

---

CTEs are done — a plain derived-table-style CTE was effectively already covered conceptually back in Piece 15's notes, and this piece covered the genuinely new part, recursion. The Required Coverage checklist's next item is indexes and execution plans, `06 sql indexes execution plans.md` — and this is the one piece on the whole checklist that can't honestly run on this project's current real data as-is. Indexes exist to make SQL Server avoid scanning every row; with only 5 real `Transactions` rows, a full table scan and an index seek cost basically the same, so a genuine before/after proof (one query plan scanning, the same query after an index seeking instead) needs real data at real scale — the spec itself calls for "thousands of transactions, not a handful" for exactly this reason.

Rather than skip indexing or fake the scale, the next piece bulk-seeds `Transactions` up to real volume first, so the indexing piece right after it can show a genuine, measurable before/after on this project's own real (if synthetic-content) data — same "real confirmed output only" discipline as every other piece, just applied to a bigger table.

## Next piece — Piece 25: bulk-seeding Transactions to real scale (5,000 synthetic rows)

Not yet run. This generates 5,000 new rows using a "tally table" trick (`sys.all_columns cross join sys.all_columns`, a standard way to get a large row count to count off of without a physical numbers table) and `checksum(newid())` to get a genuinely different random value per row — plain `rand()` would compute once for the whole statement and give every row the identical value, which `checksum(newid())` avoids since `newid()` itself is evaluated fresh per row. Expect the final `select count(*)` to return **5005** — the 5,000 new synthetic rows plus the 5 real rows already confirmed since Piece 9.

```sql
;with Tally as (
    select top (5000) row_number() over (order by (select null)) as n
    from sys.all_columns a cross join sys.all_columns b
)
insert into Transactions (AccountID, CategoryID, TransactionDate, Amount, Description)
select
    AccountID       = (abs(checksum(newid())) % 3) + 1,
    CategoryID      = case abs(checksum(newid())) % 3
                           when 0 then 3   -- Groceries
                           when 1 then 4   -- Rent
                           else 5          -- Movies
                       end,
    TransactionDate = dateadd(day, -(abs(checksum(newid())) % 730), '2026-10-11'),
    Amount          = cast(-1 * ((abs(checksum(newid())) % 499900) / 100.0 + 1) as decimal(10,2)),
    Description     = 'Synthetic transaction #' + cast(n as varchar(10))
from Tally;

select count(*) as TotalTransactions from Transactions;
```
