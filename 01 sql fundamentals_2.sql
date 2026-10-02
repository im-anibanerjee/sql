-- 5. Find the names of every employee who earns more than the average salary across the entire company (not per department).
select
    FirstName,
    LastName,
    Salary
from Employees
-- Salary>71555.555555
where Salary>(
    select avg(Salary)
    from Employees
)
/*
FirstName    LastName    Salary
---------    -------     ------
Ravi         Kumar       95000.00
Priya        Shah        78000.00
Amit         Verma       82000.00
Neha         Singh       88000.00

(4 rows affected)
*/

-- 6. Find the names of every department that currently has at least one employee.
select
	DepartmentName
from Departments
where DepartmentID in (
	select distinct DepartmentID
	from Employees
	where DepartmentID is not NULL
)
/* 
DepartmentName
--------------
Engineering
Sales
HR

(3 rows affected)
*/
-- this will also give the same result as above, below is the explanation in detail
select DepartmentName
from Departments
where DepartmentID in (
    select DepartmentID
    from Employees
    group by DepartmentID
)
/*
select DepartmentID
from Employees
group by DepartmentID
    DepartmentID
    ------------
    NULL
    1
    2
    3

select DepartmentName
from Departments
where DepartmentID in (NULL, 1, 2, 3)
    DepartmentName
    --------------
    Engineering
    Sales
    HR

since there is no DepartmentName with DepartmentID NULL
*/

-- 7. For every employee, show their own salary next to the highest salary in their own department, using a correlated subquery (not a join — joins are next doc).
/*
the below written query is not giving the correct result:
    select 
        FirstName,
        LastName,
        Salary,
        DepartmentID,
        (select max(salary) from Employees) as HighestSalary
    from Employees

on running this we get: 
    FirstName  LastName  Salary    HighestSalary
    ---------  --------  --------  -------------
    Ravi       Kumar     95000.00  95000.00
    Priya      Shah      78000.00  95000.00
    Amit       Verma     82000.00  95000.00
    Neha       Singh     88000.00  95000.00
    Karan      Mehta     65000.00  95000.00
    Sara       Iyer      71000.00  95000.00
    Vikram     Rao       60000.00  95000.00
    Anjali     Nair      55000.00  95000.00
    Rohan      Gupta     50000.00  95000.00

the issue is:
    subquery is "(select max(salary) from Employees)" - no where clause
    linking it back to the outer row at all, so it is not actually correlated

    that means it just computes one single number - the company-wide max salary,
    95000 - and prints that exact same number next to every employee, regardless    
    of which department they're in

this next query will give error:
    select 
        FirstName,
        LastName,
        DepartmentID,
        (select 
            --DepartmentID,
            max(salary) --as MaxSalary
        from Employees
        group by DepartmentID
        ) as MaxSalary
    from Employees

on running the subquery, 
    select 
        DepartmentID,
        max(salary) as MaxSalary
    from Employees
    group by DepartmentI

we get the exact max-salary corresponding to each DepartmentID
    DepartmentID MaxSalary
    ------------ ---------
    NULL         50000.00
    1            95000.00
    2            88000.00
    3            60000.00

but however when we run the full query with the subquery, we get error:
    Msg 116, Level 16, State 1, Line 11
    Only one expression can be specified in the select list when the subquery is not introduced with EXISTS.

the reason is:
    group by DepartmentID doesn't correlate anything 
    it just collapses the employees table into one row per distinct department, same as it always does

    run it alone and you'd get 4 rows back: one max per group
    not one max tied to whichever employee is currently being looked at

    a subquery sitting in a select-list column position, like "(select ...) as highestsalary",
    has to collapse down to exactly one value
    sql server has nowhere to put 4 rows into one column slot
*/

select 
	FirstName,
	LastName,
	DepartmentID,
	Salary,
	(
	  select max(salary)
	  from Employees E1
	  where E1.DepartmentID=E.DepartmentID
	) as DeptMaxSalary
from Employees E
/*
FirstName  LastName  DepartmentID  Salary    DeptMaxSalary
---------  --------  ------------  --------  -------------
Ravi       Kumar     1             95000.00  95000.00
Priya      Shah      1             78000.00  95000.00
Amit       Verma     1             82000.00  95000.00
Neha       Singh     2             88000.00  88000.00
Karan      Mehta     2             65000.00  88000.00
Sara       Iyer      2             71000.00  88000.00
Vikram     Rao       3             60000.00  60000.00
Anjali     Nair      3             55000.00  60000.00
Rohan      Gupta     NULL          50000.00  NULL

(9 rows affected)

this version works because:
    the subquery is correlated: where E1.DepartmentID = E.DepartmentID; is what makes it correlated
    E1 is the inner query's own copy of Employees
    E is the outer row currently being looked at
    so the inner query only scans the rows that share that outer row's department, nothing else

tracing it one outer row at a time:
    Ravi   (Dept=1)    -> inner scans Dept=1: Ravi(95000), Priya(78000), Amit(82000) -> MAX = 95000
    Priya  (Dept=1)    -> inner scans Dept=1: Ravi(95000), Priya(78000), Amit(82000) -> MAX = 95000
    Amit   (Dept=1)    -> inner scans Dept=1: Ravi(95000), Priya(78000), Amit(82000) -> MAX = 95000
    Neha   (Dept=2)    -> inner scans Dept=2: Neha(88000), Karan(65000), Sara(71000) -> MAX = 88000
    Karan  (Dept=2)    -> inner scans Dept=2: Neha(88000), Karan(65000), Sara(71000) -> MAX = 88000
    Sara   (Dept=2)    -> inner scans Dept=2: Neha(88000), Karan(65000), Sara(71000) -> MAX = 88000
    Vikram (Dept=3)    -> inner scans Dept=3: Vikram(60000), Anjali(55000)           -> MAX = 60000
    Anjali (Dept=3)    -> inner scans Dept=3: Vikram(60000), Anjali(55000)           -> MAX = 60000
    Rohan  (Dept=NULL) -> E1.DepartmentID = NULL is never true (null=null isn't true),
                           so zero rows match -> MAX() over zero rows -> NULL

nine outer rows
nine separate runs of the inner query
each one scoped to a different slice of Employees depending on that row's own department 
that's the whole difference from the first broken attempt:
    which ran the inner query exactly once and reused the same answer for every row
*/