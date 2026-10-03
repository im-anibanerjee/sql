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

-- 1. Using union, combine employees earning over 80000 with employees hired before 2020-01-01 into one deduplicated list of first names. 
select 
    FirstName,
    Salary,
    HireDate
from Employees
where Salary>80000
union
select 
    FirstName,
    Salary,
    HireDate
from Employees
where HireDate<'2020-01-01'
/*
FirstName  Salary    HireDate
---------  --------  ----------
Amit       82000.00  2021-01-10
Neha       88000.00  2018-11-20
Ravi       95000.00  2019-03-01
Vikram     60000.00  2017-02-14

(4 rows affected)

the following rows land in both halves:
    FirstName  Salary    HireDate
    ---------  --------  ----------
    Neha       88000.00  2018-11-20
    Ravi       95000.00  2019-03-01
*/

-- 2. Run the exact same two queries from Q1 with union all instead, and compare the row count against Q1's result.
select 
    FirstName,
    Salary,
    HireDate
from Employees
where Salary>80000
union all
select 
    FirstName,
    Salary,
    HireDate
from Employees
where HireDate<'2020-01-01'
/*
FirstName  Salary    HireDate
---------  --------  ----------
Ravi       95000.00  2019-03-01
Amit       82000.00  2021-01-10
Neha       88000.00  2018-11-20
Ravi       95000.00  2019-03-01
Neha       88000.00  2018-11-20
Vikram     60000.00  2017-02-14

(6 rows affected)

as mentioned above in previous answer that the following rows appear in both halves of the results:
    FirstName  Salary    HireDate
    ---------  --------  ----------
    Neha       88000.00  2018-11-20
    Ravi       95000.00  2019-03-01

union: keeps one copy of each instead of two. 
union all: has no opinion about any of that; it just reports exactly what each half produced, duplicates included.

hence 4 rows with 'union' and 6 with 'union all'
*/

-- 3. Using intersect, find employees who are both earning over 80000 AND were hired before 2020-01-01.
select 
    FirstName,
    Salary,
    HireDate
from Employees
where Salary>80000
intersect
select 
    FirstName,
    Salary,
    HireDate
from Employees
where HireDate<'2020-01-01'
/*
FirstName  Salary    HireDate
---------  --------  ----------
Neha       88000.00  2018-11-20
Ravi       95000.00  2019-03-01

(2 rows affected)
*/

-- 4. Using except, find every department that has zero employees.
use InterviewPrepSQLPractice
go

select 
    DepartmentID 
from Departments
except
select 
    DepartmentID 
from Employees 
where DepartmentID is not NULL
/*

DepartmentID
------------
4
(1 row affected)

if you run the following query:
    select 
        DepartmentID,
        count(*) as EmployeeCount
    from Employees
    group by DepartmentID
    except
    select 
        DepartmentID,
        count(*) as EmployeeCount
    from Employees
    group by DepartmentID
    having DepartmentID is not NULL

the output obtained is:
    DepartmentID  EmployeeCount
    ------------  -------------
    NULL          1

what query 1 does:
    select 
        DepartmentID,
        count(*) as EmployeeCount
    from Employees
    group by DepartmentID

    DepartmentID  EmployeeCount
    ------------  -------------
    NULL          1
    1             3
    2             3
    3             2

what query 2 does:
    select 
        DepartmentID,
        count(*) as EmployeeCount
    from Employees
    group by DepartmentID
    having DepartmentID is not NULL

    DepartmentID  EmployeeCount
    ------------  -------------
    1             3
    2             3
    3             2

the query above is wrong for this question; still kept for self understanding the difference; wrong because it gives:
    employees with no department (which is why it correctly surfaced Rohan, NULL | 1), and not 
    departments with no employees: Finance (DepartmentID = 4) 
    
    the real ask can never show up this way; since zero employee rows have that value
    so no group ever forms for it — structurally, no matter how the except is written

note:
    if query 2 is written as below:
        select 
            DepartmentID,
            count(*) as EmployeeCount
        from Employees
        group by DepartmentID
        having DepartmentID!=NULL

    the output obtained is: 
        DepartmentID EmployeeCount
        ------------ -------------
        (0 rows affected)
    
    this is happening because:
        null isn't a value you can compare with = or != (<>) - it means "unknown," not "empty" or "zero"
        any comparison against null using = or != (<>) evaluates to unknown, never true or false
        
        a having (or where) clause only keeps rows where the condition evaluates to true
        unknown is treated the same as false, so the row gets dropped
        
        that applies to every row, not just the ones that are actually null
        DepartmentID = 1 != null is also unknown, not true, so even the non-null groups (1, 2, 3) get filtered out too
        
        that's why the result is 0 rows affected instead of the 3 non-null groups you'd expect
        the only way to test for null is with 'is null' or 'is not null' 
*/