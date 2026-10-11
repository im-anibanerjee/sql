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
-- testing the anchor member alone (valid on its own - Categories is a real table)
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

-- testing the recursive member alone (expected to fail - CategoryHierarchy only
-- exists inside the WITH block's loop, it is not a real standalone table)
select 
    c.CategoryID, 
    c.CategoryName, 
    c.ParentCategoryID, 
    ch.Level + 1
from Categories c
inner join CategoryHierarchy ch on c.ParentCategoryID = ch.CategoryID

Msg 208, Level 16, State 1, Line 15
Invalid object name 'CategoryHierarchy'.

-- final result: full query, run as written
CategoryID  CategoryName   ParentCategoryID  Level
----------  -------------  ----------------  -----
1           Essentials     NULL              0
2           Entertainment  NULL              0
3           Groceries      1                 1
4           Rent           1                 1
5           Movies         2                 1

(5 rows affected)
*/