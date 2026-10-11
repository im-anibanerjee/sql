-- section 24
with CategoryHierarchy as (
    select 
        CategoryID, 
        CategoryName, 
        ParentCategoryID, 
        0 as Level
    from Categories
    where ParentCategoryID is null

    union all

    select 
        c.CategoryID, 
        c.CategoryName, 
        c.ParentCategoryID, 
        ch.Level + 1
    from Categories c
    inner join CategoryHierarchy ch on c.ParentCategoryID = ch.CategoryID
)

select 
    CategoryID, 
    CategoryName, 
    ParentCategoryID, 
    Level
from CategoryHierarchy
order by Level, 
         CategoryID;
/*
select 
    CategoryID, 
    CategoryName, 
    ParentCategoryID, 
    0 as Level
from Categories
where ParentCategoryID is null

CategoryID  CategoryName   ParentCategoryID  Level
----------  -------------  ----------------  -----
1           Essentials     NULL              0
2           Entertainment  NULL              0

(2 rows affected)

exists inside the WITH block's loop; CategoryHierarchy is not a real standalone table; expected to fail
select 
    c.CategoryID, 
    c.CategoryName, 
    c.ParentCategoryID, 
    ch.Level + 1
from Categories c
inner join CategoryHierarchy ch on c.ParentCategoryID = ch.CategoryID

Msg 208, Level 16, State 1, Line 15
Invalid object name 'CategoryHierarchy'.

-- final result: 
CategoryID  CategoryName   ParentCategoryID  Level
----------  -------------  ----------------  -----
1           Essentials     NULL              0
2           Entertainment  NULL              0
3           Groceries      1                 1
4           Rent           1                 1
5           Movies         2                 1

(5 rows affected)
*/

-- section 25
;with Tally as (
    select top (5000) row_number() over(
        order by (select null)
        ) as n
    from sys.all_columns a cross join sys.all_columns b
)

insert into Transactions (AccountID, CategoryID, TransactionDate, Amount, Description)
select
    AccountID = (abs(checksum(newid())) % 3) + 1,
    CategoryID = case abs(checksum(newid())) % 3
                    when 0 then 3   -- Groceries
                    when 1 then 4   -- Rent
                    else 5          -- Movies
                    end,
    TransactionDate = dateadd(day, -(abs(checksum(newid())) % 730), '2026-10-11'),
    Amount = cast(-1 * ((abs(checksum(newid())) % 499900) / 100.0 + 1) as decimal(10,2)),
    Description = 'Synthetic transaction #' + cast(n as varchar(10))
from Tally;

select count(*) as TotalTransactions from Transactions;
/*
TotalTransactions
-----------------
5005

(1 row affected)
*/

-- section 26
set statistics io on;

select 
    TransactionID, 
    AccountID, 
    CategoryID, 
    TransactionDate, 
    Amount
from Transactions
where TransactionDate >= '2026-07-01' and 
      TransactionDate < '2026-08-01';

set statistics io off;
/*
TransactionID  AccountID  CategoryID  TransactionDate  Amount
-------------  ---------  ----------  ---------------  --------
12             2          5           2026-07-06       -3621.18
32             2          5           2026-07-26       -3006.88
43             2          5           2026-07-07       -2668.54
49             3          3           2026-07-10       -2897.22
111            3          3           2026-07-09       -542.07
...            ...        ...         ...              ...        (rows truncated in this paste - 255 real rows total)
4924           2          4           2026-07-01       -2406.98
4926           3          5           2026-07-07       -3101.33
4963           2          4           2026-07-03       -864.14
5001           2          5           2026-07-19       -2188.81

(255 rows affected)

-- Messages tab (the real before-index proof this piece needs):
Table 'Transactions'. Scan count 1, logical reads 42, physical reads 0, page server reads 0, read-ahead reads 0,
page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0,
lob read-ahead reads 0, lob page server read-ahead reads 0.
*/

-- section 27
create index IX_Transactions_TransactionDate on Transactions(TransactionDate);

set statistics io on;

select 
    TransactionID, 
    AccountID, 
    CategoryID, 
    TransactionDate, 
    Amount
from Transactions
where TransactionDate >= '2026-07-01' and 
      TransactionDate < '2026-08-01';

set statistics io off;
/*
TransactionID  AccountID  CategoryID  TransactionDate  Amount
-------------  ---------  ----------  ---------------  --------
12             2          5           2026-07-06       -3621.18
32             2          5           2026-07-26       -3006.88
43             2          5           2026-07-07       -2668.54
49             3          3           2026-07-10       -2897.22
111            3          3           2026-07-09       -542.07
...            ...        ...         ...              ...        (rows truncated in this paste - 255 real rows total)
4924           2          4           2026-07-01       -2406.98
4926           3          5           2026-07-07       -3101.33
4963           2          4           2026-07-03       -864.14
5001           2          5           2026-07-19       -2188.81

(255 rows affected)

-- Messages tab (the real after-index result - note logical reads is UNCHANGED at 42):
Table 'Transactions'. Scan count 1, logical reads 42, physical reads 1, page server reads 0, read-ahead reads 40,
page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0,
lob page server read-ahead reads 0.
*/

-- section 28
drop index IX_Transactions_TransactionDate on Transactions;

create index IX_Transactions_TransactionDate_Covering
    on Transactions(TransactionDate)
    include (AccountID, CategoryID, Amount);

set statistics io on;

select 
    TransactionID, 
    AccountID, 
    CategoryID, 
    TransactionDate, 
    Amount
from Transactions
where TransactionDate >= '2026-07-01' and 
      TransactionDate < '2026-08-01';

set statistics io off;
/*
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
*/

