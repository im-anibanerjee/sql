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

-- 1. Using InterviewPrepSQLPractice, write a CTE that computes each department's total salary cost (the sum of Salary, grouped by DepartmentID)
-- then write an outer query that returns only the departments whose total salary cost exceeds 200000.
with DeptSalary as(
    select 
        DepartmentID,
        sum(Salary) as TotalSalary
    from Employees
    group by DepartmentID
)
select
    D.DepartmentID,
    D.DepartmentName
    DS.TotalSalary
from Departments D
join DeptSalary DS on D.DepartmentID=DS.DepartmentID
where DS.TotalSalary>200000
/*
DepartmentID  DepartmentName  TotalSalary
------------  --------------  -----------
1             Engineering     255000.00
2             Sales           224000.00

(2 rows affected)
*/

-- 2. Using InterviewPrepSQLPractice, write a CTE with row_number() (partitioned by DepartmentID, ordered by Salary desc) that ranks employees within their department
-- then write an outer query that returns only the second-highest-paid employee in each department.
use InterviewPrepSQLPractice
go
with DeptSalRank as(
    select
        FirstName,
        DepartmentID,
        Salary,
        row_number() over(
            partition by DepartmentID
            order by Salary desc
            ) as SalaryRank
    from Employees
)
select 
    DSR.FirstName,
    DSR.DepartmentID,
    D.DepartmentName,
    DSR.Salary,
    DSR.SalaryRank
from Departments D
join DeptSalRank DSR on DSR.DepartmentID=D.DepartmentID
where DSR.SalaryRank=2
/*
FirstName  DepartmentID  DepartmentName  Salary    SalaryRank
---------  ------------  --------------  --------  ----------
Amit       1             Engineering     82000.00  2
Sara       2             Sales           71000.00  2
Anjali     3             HR              55000.00  2

(3 rows affected)

CTE EmpDeptSalRank:
    FirstName  DepartmentID  Salary    SalaryRank
    ---------  ------------  --------  ----------
    Rohan      NULL          50000.00  1
    Ravi       1             95000.00  1
    Amit       1             82000.00  2
    Priya      1             78000.00  3
    Neha       2             88000.00  1
    Sara       2             71000.00  2
    Karan      2             65000.00  3
    Vikram     3             60000.00  1
    Anjali     3             55000.00  2

    (9 rows affected)
*/

-- 3. Using InterviewPrepSQLPractice, write a recursive CTE that finds, for every employee, the person at the very top of their own management chain (not just their direct manager - the root of the whole chain). 
-- You'll need to carry that top-of-chain person's ID and name forward through each recursive pass, rather than a level counter.
use InterviewPrepSQLPractice
go
with OrgRoot as(
    select EmployeeID, FirstName, ManagerID,
           EmployeeID as RootEmployeeID, FirstName as RootFirstName
    from Employees
    where ManagerID is NULL

    union all

    select E.EmployeeID, E.FirstName, E.ManagerID,
           O.RootEmployeeID, O.RootFirstName
    from Employees E
    join OrgRoot O on E.ManagerID=O.EmployeeID
)
select EmployeeID, FirstName, RootEmployeeID, RootFirstName
from OrgRoot
order by RootEmployeeID, 
         EmployeeID;
/*
EmployeeID  FirstName  RootEmployeeID  RootFirstName
----------  ---------  --------------  -------------
1           Ravi       1               Ravi
2           Priya      1               Ravi
3           Amit       1               Ravi
4           Neha       4               Neha
5           Karan      4               Neha
6           Sara       4               Neha
7           Vikram     7               Vikram
8           Anjali     7               Vikram
9           Rohan      9               Rohan

(9 rows affected)
*/

-- 4. Using InterviewPrepSQLPractice, answer "what's the maximum salary in each employee's own department, shown next to every employee" using a CTE joined back 
-- onto Employees by DepartmentID - the same question doc 01's Q7 answered with a correlated subquery.
use InterviewPrepSQLPractice
go
with DeptMaxSal as(
    select
        FirstName,
        DepartmentID,
        Salary,
        max(Salary) over(
            partition by DepartmentID
            order by Salary desc
            ) as MaxDeptSalary
    from Employees
)
select 
    FirstName, 
    DepartmentID, 
    Salary, 
    MaxDeptSalary
from DeptMaxSal
/*
FirstName  DepartmentID  Salary    MaxDeptSalary
---------  ------------  --------  -------------
Rohan      NULL          50000.00  50000.00
Ravi       1             95000.00  95000.00
Amit       1             82000.00  95000.00
Priya      1             78000.00  95000.00
Neha       2             88000.00  88000.00
Sara       2             71000.00  88000.00
Karan      2             65000.00  88000.00
Vikram     3             60000.00  60000.00
Anjali     3             55000.00  60000.00

(9 rows affected)
*/