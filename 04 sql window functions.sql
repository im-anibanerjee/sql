select * from Departments
select * from Employees
/*
DepartmentID    DepartmentName
------------    --------------
1               Engineering
2               Sales
3               HR
4               Finance

(4 rows affected)

EmployeeID  FirstName     LastName   DepartmentID   ManagerID   Salary    HireDate
----------- ---------     --------   ------------   ---------   ------    --------
1           Ravi          Kumar      1              NULL        95000.00  2019-03-01
2           Priya         Shah       1              1           78000.00  2020-07-15
3           Amit          Verma      1              1           82000.00  2021-01-10
4           Neha          Singh      2              NULL        88000.00  2018-11-20
5           Karan         Mehta      2              4           65000.00  2022-05-05
6           Sara          Iyer       2              4           71000.00  2023-09-12
7           Vikram        Rao        3              NULL        60000.00  2017-02-14
8           Anjali        Nair       3              7           55000.00  2023-12-01
9           Rohan         Gupta      NULL           NULL        50000.00  2024-03-18

(9 rows affected)
*/

-- 1. Using InterviewPrepSQLPractice, show every employee's first name, salary, and their rank by salary across the whole company 
-- (no partition by this time) using row_number(), highest salary first.
use InterviewPrepSQLPractice
go

select 
	FirstName,
	DepartmentID,
	Salary,
	row_number() over(
		order by Salary desc
		) as SalaryRank
from Employees
/*
FirstName  DepartmentID  Salary    SalaryRank
---------  ------------  --------  ----------
Ravi       1             95000.00  1
Neha       2             88000.00  2
Amit       1             82000.00  3
Priya      1             78000.00  4
Sara       2             71000.00  5
Karan      2             65000.00  6
Vikram     3             60000.00  7
Anjali     3             55000.00  8
Rohan      NULL          50000.00  9

(9 rows affected)

checking what comes with 'partiton by':
    select 
        FirstName,
        DepartmentID,
        Salary,
        row_number() over(
            partition by DepartmentID
            order by Salary desc
            ) as SalaryRank
    from Employees

    FirstName   DepartmentID     Salary      SalaryRank
    ---------   ------------     ------      ----------
    Rohan       NULL             50000.00     1
    Ravi        1                95000.00     1
    Amit        1                82000.00     2
    Priya       1                78000.00     3
    Neha        2                88000.00     1
    Sara        2                71000.00     2
    Karan       2                65000.00     3
    Vikram      3                60000.00     1
    Anjali      3                55000.00     2

    (9 rows affected)
*/

-- 2. Using InterviewPrepSQLPractice, show every employee's first name, hire date, and a count of how many employees were hired on or before them within their 
-- own department, using row_number() partitioned by DepartmentID and ordered by HireDate.
use InterviewPrepSQLPractice
go

select 
	FirstName,
	DepartmentID,
	HireDate,
	row_number() over(
		partition by DepartmentID
		order by HireDate
		) as HirirngRank
from Employees
/*
FirstName  DepartmentID  HireDate    HirirngRank
---------  ------------  ----------  -----------
Rohan      NULL          2024-03-18  1
Ravi       1             2019-03-01  1
Priya      1             2020-07-15  2
Amit       1             2021-01-10  3
Neha       2             2018-11-20  1
Karan      2             2022-05-05  2
Sara       2             2023-09-12  3
Vikram     3             2017-02-14  1
Anjali     3             2023-12-01  2

(9 rows affected)
*/

-- 3. Using InterviewPrepSQLPractice, show every employee's first name, salary, and both rank() and dense_rank() ordered by Salary desc across the whole company.
select 
	FirstName,
	Salary,
	rank() over(
		order by Salary desc
		) as SalaryRank,
	dense_rank() over(
		order by Salary desc
		) as SalaryDenseRank
from Employees
/*
FirstName  Salary    SalaryRank  SalaryDenseRank
---------  --------  ----------  ---------------
Ravi       95000.00  1           1
Neha       88000.00  2           2
Amit       82000.00  3           3
Priya      78000.00  4           4
Sara       71000.00  5           5
Karan      65000.00  6           6
Vikram     60000.00  7           7
Anjali     55000.00  8           8
Rohan      50000.00  9           9

(9 rows affected)
*/

-- 4. Using InterviewPrepSQL, show every transaction's ID, amount, and the amount of the transaction that came immediately before it in time 
-- (no partitioning - one continuous sequence across all accounts) using lag() ordered by TransactionDate.
use InterviewPrepSQL
go

select * from Transactions
/*
TransactionID AccountID   CategoryID  TransactionDate Amount
------------- ----------- ----------- --------------- ---------------------------------------
101           1           1           2026-01-05      -50.00
102           1           2           2026-01-10      -20.00
103           2           3           2026-01-12      500.00
104           3           1           2026-01-15      -10.00
105           NULL        2           2026-01-20      -15.00

(5 rows affected)
*/

select 
    TransactionID,
    Amount,
    lag(Amount) over(
        order by TransactionDate
        ) as EarlierTransaction
from Transactions
/*
TransactionID  Amount  EarlierTransaction
-------------  ------  ------------------
101            -50.00  NULL
102            -20.00  -50.00
103            500.00  -20.00
104            -10.00  500.00
105            -15.00  -10.00

(5 rows affected)

lag() means: 
    look at the row one position behind me, in whatever order 'order by' creates
    ascending (earliest date first) is the default
    with ascending order, one position behind = chronologically earlier = immediately before it in time
    that's exactly what this question needs, so order by transactiondate with no desc is correct

    adding desc flips the whole sequence - latest transaction first, earliest last
    lag() still grabs one position behind, but now that's a later transaction, not an earlier one
    so desc makes lag() silently behave like lead() instead, just because the order direction flipped

rule of thumb: 
    lag/lead's previous/next only make sense relative to the order by direction
    ascending - lag = before in time, lead = after in time
    descending - that relationship flips
*/

-- 5. Using InterviewPrepSQLPractice, show every employee's first name, department, salary, and a running total of salary per department, ordered by HireDate 
-- within each department, using sum() over().
use InterviewPrepSQLPractice
go

select 
	FirstName,
	Salary,
	HireDate,
	DepartmentID,
	sum(Salary) over(
		partition by DepartmentID
		order by HireDate
		) as RunningTotalSalary
from Employees
/*
FirstName  Salary    HireDate    DepartmentID  RunningTotalSalary
---------  --------  ----------  ------------  ------------------
Rohan      50000.00  2024-03-18  NULL          50000.00
Ravi       95000.00  2019-03-01  1             95000.00
Priya      78000.00  2020-07-15  1             173000.00
Amit       82000.00  2021-01-10  1             255000.00
Neha       88000.00  2018-11-20  2             88000.00
Karan      65000.00  2022-05-05  2             153000.00
Sara       71000.00  2023-09-12  2             224000.00
Vikram     60000.00  2017-02-14  3             60000.00
Anjali     55000.00  2023-12-01  3             115000.00

(9 rows affected)
*/