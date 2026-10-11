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
select 
    CategoryID, 
    CategoryName, 
    ParentCategoryID, 
    0 as Level
from Categories
where ParentCategoryID is null

CategoryID  CategoryName                                       ParentCategoryID Level
----------- -------------------------------------------------- ---------------- -----------
1           Essentials                                         NULL             0
2           Entertainment                                      NULL             0

(2 rows affected)

select 
    c.CategoryID, 
    c.CategoryName, 
    c.ParentCategoryID, 
    ch.Level + 1
from Categories c
inner join CategoryHierarchy ch on c.ParentCategoryID = ch.CategoryID

Msg 208, Level 16, State 1, Line 15
Invalid object name 'CategoryHierarchy'.


final result:
CategoryID  CategoryName                                       ParentCategoryID Level
----------- -------------------------------------------------- ---------------- -----------
1           Essentials                                         NULL             0
2           Entertainment                                      NULL             0
3           Groceries                                          1                1
4           Rent                                               1                1
5           Movies                                             2                1

(5 rows affected)
*/