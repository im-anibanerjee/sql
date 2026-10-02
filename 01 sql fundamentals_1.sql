-- create table Departments (
--     DepartmentID int primary key,
--     DepartmentName varchar(50) not null
-- );

-- create table Employees (
--     EmployeeID int primary key,
--     FirstName varchar(50) not null,
--     LastName varchar(50) not null,
--     DepartmentID int null references Departments(DepartmentID),
--     ManagerID int null references Employees(EmployeeID),
--     Salary decimal(10,2) not null,
--     HireDate date not null
-- );

-- (4 rows affected)
-- (9 rows affected)

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

-- 1. List every employee's first name, last name, and salary, ordered by salary from highest to lowest.
select 
    FirstName,
    LastName,
    Salary
from Employees
order by Salary desc
/*
FirstName   LastName     Salary
---------   --------     ------ 
Ravi        Kumar        95000.00
Neha        Singh        88000.00
Amit        Verma        82000.00
Priya       Shah         78000.00
Sara        Iyer         71000.00
Karan       Mehta        65000.00
Vikram      Rao          60000.00
Anjali      Nair         55000.00
Rohan       Gupta        50000.00

(9 rows affected)
*/

-- 2. Find every employee who was hired after 2021-01-01 and earns more than 60000.
select
    FirstName,
    LastName,
    Salary,
    HireDate
from Employees 
where HireDate>'2021-01-01' and
      Salary>60000
/*
FirstName   LastName   Salary      HireDate
---------   --------   ------      --------
Amit        Verma      82000.00    2021-01-10
Karan       Mehta      65000.00    2022-05-05
Sara        Iyer       71000.00    2023-09-12

(3 rows affected)
*/

-- 3. Count how many employees are in each department — including any employees with no department at all.
select 
	count(*) as EmpCount,
	DepartmentID
from Employees
group by DepartmentID
/*
EmpCount    DepartmentID
--------    ------------
1           NULL
3           1
3           2
2           3

(4 rows affected)
*/

-- 4. Find the average salary per department, but only show departments where that average is above 70000.
-- select 
-- 	 count(*) as EmpCount, 
-- 	 DepartmentID,
-- 	 avg(Salary)
-- from Employees
-- group by DepartmentID
-- having Salary>70000

-- Msg 8121, Level 16, State 1, Line 7
-- Column 'Employees.Salary' is invalid in the HAVING clause because it is not contained in either an aggregate function or the GROUP BY clause.


-- group by departmentid collapses many rows into one row per department
-- each group is backed by several different salary values, not one
-- e.g. engineering alone has 95000, 78000, and 82000 - three salaries in one group
-- having salary > 70000 asks "is the group's salary above 70000"
-- but a group has no single salary - only an aggregate over it does
-- salary isn't wrapped in an aggregate and isn't a group by column
-- so sql server has nothing single left to compare, hence the error
-- fix: apply the condition to the aggregate itself - having avg(salary) > 70000

select 
	count(*) as EmpCount, 
	DepartmentID,
	avg(Salary) as AvgSalary
from Employees
group by DepartmentID
having avg(Salary)>70000
/*
EmpCount    DepartmentID    AvgSalary
--------    ------------    ---------
3           1               85000.000000
3           2               74666.666666

(2 rows affected)
*/

