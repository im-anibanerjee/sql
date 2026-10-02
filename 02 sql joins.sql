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

-- 1. List every employee's first name, last name, and department name, using an inner join. (Think about who this leaves out before you run it.)
select
	E.FirstName,
	E.LastName,
	D.DepartmentName
from Employees E
inner join Departments D on E.DepartmentID=D.DepartmentID
/*
FirstName  LastName  DepartmentName
---------  --------  --------------
Ravi       Kumar     Engineering
Priya      Shah      Engineering
Amit       Verma     Engineering
Neha       Singh     Sales
Karan      Mehta     Sales
Sara       Iyer      Sales
Vikram     Rao       HR
Anjali     Nair      HR

(8 rows affected)

from the Department table the following record is not there in the output
    DepartmentID    DepartmentName
    ------------    --------------
    4               Finance

from Employees table the following record is not there in the output
    EmployeeID  FirstName     LastName   DepartmentID   ManagerID   Salary    HireDate
    ----------- ---------     --------   ------------   ---------   ------    --------
    9           Rohan         Gupta      NULL           NULL        50000.00  2024-03-18

department:Finance  is not there in the Employees table
Rohan (FirstName), DepartmentID:NULL; there is no DepartmentID in with NULL in Departments table
*/

-- 2. Repeat question 1, but make sure every employee shows up even if they have no department at all.
select
	E.FirstName,
	E.LastName,
	D.DepartmentName
from Employees E
left join Departments D on E.DepartmentID=D.DepartmentID
/*
FirstName  LastName  DepartmentName
---------  --------  --------------
Ravi       Kumar     Engineering
Priya      Shah      Engineering
Amit       Verma     Engineering
Neha       Singh     Sales
Karan      Mehta     Sales
Sara       Iyer      Sales
Vikram     Rao       HR
Anjali     Nair      HR
Rohan      Gupta     NULL

(9 rows affected)

this time Rohan (FirstName), DepartmentID:NULL; there is no DepartmentID in with NULL in Departments table
so result has both persons which have department's assigned or not
    EmployeeID  FirstName     LastName   DepartmentID   ManagerID   Salary    HireDate
    ----------- ---------     --------   ------------   ---------   ------    --------
    9           Rohan         Gupta      NULL           NULL        50000.00  2024-03-18

from the Department table the following record is not there in the output
    DepartmentID    DepartmentName
    ------------    --------------
    4               Finance
*/

-- 3. List every department's name together with the first and last names of its employees, making sure every department shows up even if it has no employees at all.
select
	E.FirstName,
	E.LastName,
	D.DepartmentName
from Employees E
right join Departments D on E.DepartmentID=D.DepartmentID
/*
FirstName  LastName  DepartmentName
---------  --------  --------------
Ravi       Kumar     Engineering
Priya      Shah      Engineering
Amit       Verma     Engineering
Neha       Singh     Sales
Karan      Mehta     Sales
Sara       Iyer      Sales
Vikram     Rao       HR
Anjali     Nair      HR
NULL       NULL      Finance

(9 rows affected)

notice here that:
from Employees table the following record is not there in the output
    EmployeeID  FirstName     LastName   DepartmentID   ManagerID   Salary    HireDate
    ----------- ---------     --------   ------------   ---------   ------    --------
    9           Rohan         Gupta      NULL           NULL        50000.00  2024-03-18

from the Department table the following record is there in the output although there is no employee in that department
    DepartmentID    DepartmentName
    ------------    --------------
    4               Finance

alternative to right join; doing the same with left join
    select
        E.FirstName,
        E.LastName,
        D.DepartmentName
    from Departments D
    left join Employees E on E.DepartmentID=D.DepartmentID
*/

-- 4. For every employee, show their own name next to their manager's name, using a self join on Employees.
-- Employees with no manager should still appear, with a blank manager name.
select
    E1.FirstName as EmployeeName,
    E2.FirstName as ManagerName
from Employees E1
left join Employees E2 on E1.ManagerID = E2.EmployeeID
/*
EmployeeName  ManagerName
------------  -----------
Ravi          NULL
Priya         Ravi
Amit          Ravi
Neha          NULL
Karan         Neha
Sara          Neha
Vikram        NULL
Anjali        Vikram
Rohan         NULL

(9 rows affected)
*/

-- 5. List every employee's first name, department name, and manager's name, all in one query, using two joins at once.
select
	E.FirstName,
	D.DepartmentName,
    E2.FirstName as ManagerName
from Employees E
left join Departments D on E.DepartmentID=D.DepartmentID
left join Employees E2 on E.ManagerID=E2.EmployeeID
/*
FirstName  DepartmentName  ManagerName
---------  --------------  -----------
Ravi       Engineering     NULL
Priya      Engineering     Ravi
Amit       Engineering     Ravi
Neha       Sales           NULL
Karan      Sales           Neha
Sara       Sales           Neha
Vikram     HR              NULL
Anjali     HR              Vikram
Rohan      NULL            NULL

(9 rows affected)

from the Department table the following record is not there in the output
    DepartmentID    DepartmentName
    ------------    --------------
    4               Finance
*/
