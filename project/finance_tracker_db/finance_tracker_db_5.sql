-- section 29
begin transaction;

update Accounts
set Balance = Balance - 500.00
where AccountID = 1;

update Accounts
set Balance = Balance / 0
where AccountID = 2;

rollback transaction;

select AccountID, Balance from Accounts order by AccountID;
/*
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
*/

-- section 30
-- in window A
begin transaction;

update Accounts
set Balance = Balance - 777.00
where AccountID = 1;
-- (1 row affected)

-- in window B
set transaction isolation level read uncommitted;
select AccountID, Balance from Accounts where AccountID = 1;
/*
AccountID  Balance
---------  -------
1          -777.00

(1 row affected)
*/

-- in window A
rollback transaction;
-- Commands completed successfully.

-- in window B
set transaction isolation level read committed;
select AccountID, Balance from Accounts where AccountID = 1;
/*
AccountID  Balance
---------  -------
1          0.00

(1 row affected)
*/

-- section 31
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
/*
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
*/

exec GetUserTransactionsByDateRange @UserID = 2, @StartDate = '2026-07-01', @EndDate = '2026-08-01';
go
/*
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
*/

-- section 32
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
/*
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
*/

-- section 33
-- window A
begin transaction;

update Accounts
set Balance = Balance - 10.00
where AccountID = 1;
-- (1 row affected)

-- window B
begin transaction;

update Accounts
set Balance = Balance - 10.00
where AccountID = 2;
-- (1 row affected)

-- window A
update Accounts
set Balance = Balance - 10.00
where AccountID = 2;
-- shows executing query

-- window B
update Accounts
set Balance = Balance - 10.00
where AccountID = 1;
-- (1 row affected)
-- in Window A after running the above: Msg 1205, Level 13, State 51, Line 3
-- Transaction (Process ID 69) was deadlocked on lock resources with another process and has been chosen as the deadlock victim. Rerun the transaction.

-- window B
rollback transaction;
-- Commands completed successfully.
-- begin transaction in Window B already there; check above

select
    AccountID,
    Balance
from Accounts
order by AccountID;
/*
AccountID  Balance
---------  -------
1          0.00
2          0.00
3          0.00

(3 rows affected)
*/
