-- section 20
select
    a.UserID,
    tr.TransactionID,
    tr.Amount,
    tr.TransactionDate,
    row_number() over(
        partition by a.UserID 
        order by tr.Amount asc
        ) as RowNum,
    rank() over(
        partition by a.UserID 
        order by tr.Amount asc
        ) as ExpenseRank
from Transactions tr
inner join Accounts a on tr.AccountID = a.AccountID
order by a.UserID, 
         ExpenseRank;
/*
UserID  TransactionID  Amount    TransactionDate  RowNum  ExpenseRank
------  -------------  --------  ---------------  ------  -----------
1       1              -1500.00  2026-09-01       1       1
1       2              -120.50   2026-09-05       2       2
1       3              -95.10    2026-09-19       3       3
1       4              -45.00    2026-09-10       4       4
2       5              -80.25    2026-09-12       1       1

(5 rows affected)
*/

-- section 21
select
    c.CategoryID,
    c.CategoryName,
    count(tr.TransactionID) as TxnCount,
    rank() over(
        order by count(tr.TransactionID) desc
        ) as CategoryRank,
    dense_rank() over(
        order by count(tr.TransactionID) desc
        ) as CategoryDenseRank
from Categories c
left join Transactions tr on tr.CategoryID = c.CategoryID
group by c.CategoryID, 
         c.CategoryName
order by CategoryRank, 
         c.CategoryID;
/*
CategoryID  CategoryName   TxnCount  CategoryRank  CategoryDenseRank
----------  -------------  --------  ------------  -----------------
3           Groceries      3         1             1
4           Rent           1         2             2
5           Movies         1         2             2
1           Essentials     0         4             3
2           Entertainment  0         4             3

(5 rows affected)
*/

-- section 22
select
    a.UserID,
    tr.TransactionID,
    tr.TransactionDate,
    tr.Amount,
    lag(tr.Amount) over(
        partition by a.UserID 
        order by tr.TransactionDate
        ) as PrevAmount,
    lead(tr.Amount) over(
        partition by a.UserID 
        order by tr.TransactionDate
        ) as NextAmount
from Transactions tr
inner join Accounts a on tr.AccountID = a.AccountID
order by a.UserID, 
         tr.TransactionDate;
/*
UserID  TransactionID  TransactionDate  Amount    PrevAmount  NextAmount
------  -------------  ---------------  --------  ----------  ----------
1       1              2026-09-01       -1500.00  NULL        -120.50
1       2              2026-09-05       -120.50   -1500.00    -45.00
1       4              2026-09-10       -45.00    -120.50     -95.10
1       3              2026-09-19       -95.10    -45.00      NULL
2       5              2026-09-12       -80.25    NULL        NULL

(5 rows affected)
*/

-- section 23
select
    tr.AccountID,
    tr.TransactionID,
    tr.TransactionDate,
    tr.Amount,
    sum(tr.Amount) over(
        partition by tr.AccountID 
        order by tr.TransactionDate
        rows between unbounded preceding and current row
        ) as RunningTotal
from Transactions tr
order by tr.AccountID, tr.TransactionDate;
/*
AccountID  TransactionID  TransactionDate  Amount    RunningTotal
---------  -------------  ---------------  --------  ------------
1          1              2026-09-01       -1500.00  -1500.00
1          2              2026-09-05       -120.50   -1620.50
1          3              2026-09-19       -95.10    -1715.60
2          4              2026-09-10       -45.00    -45.00
3          5              2026-09-12       -80.25    -80.25

(5 rows affected)
*/