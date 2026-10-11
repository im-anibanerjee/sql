-- section 12
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
/*
TransactionID  UserName             AccountName  CategoryName  TransactionDate  Amount    Description
-------------  --------             -----------  ------------  ---------------  ------    -----------
1              Anirruddha Banerjee  Checking     Rent          2026-09-01       -1500.00  September rent
2              Anirruddha Banerjee  Checking     Groceries     2026-09-05       -120.50   Weekly groceries
3              Anirruddha Banerjee  Checking     Groceries     2026-09-19       -95.10    Groceries top-up
4              Anirruddha Banerjee  Savings      Movies        2026-09-10       -45.00    Movie night
5              Test User Two        Checking     Groceries     2026-09-12       -80.25    Groceries

(5 rows affected)
*/

-- section 13
select
    c.CategoryID,
    c.CategoryName,
    t.TransactionID,
    t.Amount,
    t.Description
from Categories c
left join Transactions t on c.CategoryID = t.CategoryID
order by c.CategoryID, t.TransactionID;
/*
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
*/

-- section 14
select
    c.CategoryID,
    c.CategoryName,
    t.TransactionID,
    t.Amount,
    t.Description
from Transactions t
right join Categories c on t.CategoryID = c.CategoryID
order by c.CategoryID, t.TransactionID;
/*
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
*/

-- section 15
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
    select 
        tr.TransactionID, 
        a.UserID, 
        tr.CategoryID, 
        tr.Amount, 
        tr.Description
    from Transactions tr
    inner join Accounts a on tr.AccountID = a.AccountID
) t
on b.UserID = t.UserID and b.CategoryID = t.CategoryID
order by b.BudgetID, t.TransactionID;
/*
select 
    tr.TransactionID, 
    a.UserID, 
    tr.CategoryID, 
    tr.Amount, 
    tr.Description
from Transactions tr
inner join Accounts a on tr.AccountID = a.AccountID

TransactionID  UserID  CategoryID  Amount    Description
-------------  ------  ----------  ------    -----------
1              1       4           -1500.00  September rent
2              1       3           -120.50   Weekly groceries
3              1       3           -95.10    Groceries top-up
4              1       5           -45.00    Movie night
5              2       3           -80.25    Groceries

(5 rows affected)

final result:
BudgetID  UserID  CategoryID  BudgetAmount  TransactionID  Amount    Description
--------  ------  ----------  ------------  -------------  ------    -----------
NULL      NULL    NULL        NULL          4              -45.00    Movie night
NULL      NULL    NULL        NULL          5              -80.25    Groceries
1         1       3           400.00        2              -120.50   Weekly groceries
1         1       3           400.00        3              -95.10    Groceries top-up
2         1       4           1500.00       1              -1500.00  September rent
3         2       5           100.00        NULL           NULL      NULL

(6 rows affected)
*/

-- section 16
select
    child.CategoryID,
    child.CategoryName,
    child.ParentCategoryID,
    parent.CategoryName as ParentCategoryName
from Categories child
left join Categories parent on child.ParentCategoryID = parent.CategoryID
order by child.CategoryID;
/*
CategoryID  CategoryName   ParentCategoryID  ParentCategoryName
----------  ------------   ----------------  ------------------
1           Essentials     NULL              NULL
2           Entertainment  NULL              NULL
3           Groceries      1                 Essentials
4           Rent           1                 Essentials
5           Movies         2                 Entertainment

(5 rows affected)
*/ 

-- section 17
select 
    UserID, 
    CategoryID 
from Budgets

union

select 
    a.UserID, 
    tr.CategoryID
from Transactions tr
inner join Accounts a on tr.AccountID = a.AccountID
order by UserID, 
         CategoryID;
/*
Budgets: 3 raw rows
UserID  CategoryID
------  ----------
1       3
1       4
2       5

(3 rows affected)

Transactions-Account inner join: 5 rows; (1,3) genuinely appears twice
UserID  CategoryID
------  ----------
1       3
1       3
1       4
1       5
2       3

(5 rows affected)

final result: union of both; 5 distinct rows, deduplicated from 8
UserID  CategoryID
------  ----------
1       3
1       4
1       5
2       3
2       5

(5 rows affected)
*/

-- section 18
select 
    UserID, 
    CategoryID 
from Budgets

intersect

select 
    a.UserID, 
    tr.CategoryID
from Transactions tr
inner join Accounts a on tr.AccountID = a.AccountID
order by UserID, 
         CategoryID;

/*
Budgets: 3 rows
UserID  CategoryID
------  ----------
1       3
1       4
2       5

(3 rows affected)

Transactions-Account inner join: 5 rows; (1,3) genuinely appears twice
UserID  CategoryID
------  ----------
1       3
1       3
1       4
1       5
2       3

(5 rows affected)

final result: intersect of both; 2 rows - pairs present in BOTH sets
UserID  CategoryID
------  ----------
1       3
1       4

(2 rows affected)
*/

-- section 19
select 
    UserID, 
    CategoryID 
from Budgets

except

select 
    a.UserID, 
    tr.CategoryID
from Transactions tr
inner join Accounts a on tr.AccountID = a.AccountID
order by UserID, 
         CategoryID;
/*
Budgets: 3 rows
UserID  CategoryID
------  ----------
1       3
1       4
2       5

(3 rows affected)

Transactions-Account inner join: 5 rows; (1,3) genuinely appears twice
UserID  CategoryID
------  ----------
1       3
1       3
1       4
1       5
2       3

(5 rows affected)

final result: except of both; 1 row - budgeted pair with zero real spending
UserID  CategoryID
------  ----------
2       5

(1 row affected)
*/