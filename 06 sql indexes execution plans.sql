-- 1. OrderStatus only has 4 distinct values, so each one matches roughly 12,500 of the 50,000 rows (25% - much less selective than AccountID's 0.2%). 
-- Create a non-clustered index on OrderStatus, then query where OrderStatus = 'Cancelled'. 
-- Do you expect SQL Server to use your new index, or scan past it? Why?

use InterviewPrepSQLPractice
go

create nonclustered index IX_Orders_OrderStatus 
    on Orders(OrderStatus)
-- Completion time: 2026-10-06T22:58:54.3665437+05:30

set statistics io on
select * from Orders where OrderStatus='Cancelled'
set statistics io off
/*
OrderID  AccountID  OrderStatus  OrderDate   Amount
-------  ---------  -----------  ----------  -------
3        4          Cancelled    2026-09-30  4.00
503      4          Cancelled    2025-05-18  504.00
1003     4          Cancelled    2026-09-30  1004.00
1503     4          Cancelled    2025-05-18  1504.00
2003     4          Cancelled    2026-09-30  4.00
2503     4          Cancelled    2025-05-18  504.00
3003     4          Cancelled    2026-09-30  1004.00
3503     4          Cancelled    2025-05-18  1504.00
4003     4          Cancelled    2026-09-30  4.00
4503     4          Cancelled    2025-05-18  504.00
....
49499    500        Cancelled    2025-05-22  1500.00
49999    500        Cancelled    2024-01-08  2000.00

(12500 rows affected)

Table 'Orders'. Scan count 1, logical reads 238, physical reads 0, page server reads 0, read-ahead reads 0, 
page server read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob page server reads 0, 
lob read-ahead reads 0, lob page server read-ahead reads 0.

(1 row affected)

SQL Server should scan past the new index and ignore it
    same story as AccountID in section 3 of the doc; just much more dramatic here. 
    
    OrderStatus only has 4 values, so 'Cancelled' matches 12,500 of the 50,000 rows (25% selective) 
    a lot more rows than AccountID's 100-row, 0.2% match
    
    the new index only has OrderStatus in its own pages, not the other columns
    so every one of those 12,500 matching rows would need its own separate Key Lookup trip back into the clustered index to fetch the rest of the row
    12,500 separate lookups costs a lot more than scanning the whole 256-page table once
    so the optimizer should decline the index and just scan.
*/
set statistics io on

select * 
from Orders 
    with (index(IX_Orders_OrderStatus)) 
where OrderStatus='Cancelled'

set statistics io off
/*
OrderID  AccountID  OrderStatus  OrderDate   Amount
-------  ---------  -----------  ----------  -------
3        4          Cancelled    2026-09-30  4.00
503      4          Cancelled    2025-05-18  504.00
1003     4          Cancelled    2026-09-30  1004.00
1503     4          Cancelled    2025-05-18  1504.00
2003     4          Cancelled    2026-09-30  4.00
2503     4          Cancelled    2025-05-18  504.00
3003     4          Cancelled    2026-09-30  1004.00
3503     4          Cancelled    2025-05-18  1504.00
4003     4          Cancelled    2026-09-30  4.00
4503     4          Cancelled    2025-05-18  504.00
....
49499    500        Cancelled    2025-05-22  1500.00
49999    500        Cancelled    2024-01-08  2000.00

(12500 rows affected)

Table 'Orders'. Scan count 1, logical reads 25828, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, 
lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.

(1 row affected)
*/

-- 2. Build a covering index for this exact query: select OrderID, Amount from Orders where OrderStatus = 'Pending'. 
-- What columns does the index need, and what plan/logical-reads number do you get once it exists?
use InterviewPrepSQLPractice
go

create nonclustered index IX_Orders_OrderStatus_Covering
    on Orders(OrderStatus)
    include (AccountID, OrderDate, Amount)

set statistics io on

select * 
from Orders 
where OrderStatus='Pending'

set statistics io off

set statistics io on
-- both queries gives the same execution plan ans same io-statistics; pasted below
select 
    OrderID, 
    Amount 
from Orders 
where OrderStatus = 'Pending' 

set statistics io off
/*
OrderID  AccountID  OrderStatus  OrderDate   Amount
-------  ---------  -----------  ----------  -------
4        5          Pending      2026-09-29  5.00
8        9          Pending      2026-09-25  9.00
12       13         Pending      2026-09-21  13.00
16       17         Pending      2026-09-17  17.00
20       21         Pending      2026-09-13  21.00
24       25         Pending      2026-09-09  25.00
28       29         Pending      2026-09-05  29.00
32       33         Pending      2026-09-01  33.00
....
49996    497        Pending      2024-01-11  1997.00
50000    1          Pending      2026-10-03  1.00

(12500 rows affected)

Table 'Orders'. Scan count 1, logical reads 61, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, 
lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.

(1 row affected)

OrderID already comes along free with every non-clustered index since it's the clustering key
so the minimal covering index for that specific select only needs Amount
*/

-- 3. Pick any single OrderID and query where OrderID = <your number>, same as section 4 
-- confirm for yourself that it's still a cheap Clustered Index Seek no matter which non-clustered indexes also exist on the table.
set statistics io on

select * from Orders where OrderID = 32145

set statistics io off
/*
OrderID  AccountID  OrderStatus  OrderDate   Amount
-------  ---------  -----------  ----------  ------
32145    146        Shipped      2026-05-11  146.00

(1 row affected)

Table 'Orders'. Scan count 0, logical reads 2, physical reads 0, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, 
lob logical reads 0, lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.

(1 row affected)

same execution plan as in doc
*/

-- 4. Using an index hint like section 3's, force IX_Orders_AccountID (the non-covering one) on a query that also needs OrderDate and Amount
-- the exact same Key Lookup pattern as section 3, just so you can see it happen a second time on your own, unguided.
set statistics io on

select 
	AccountID, 
	OrderDate, 
	Amount
from Orders 
	with (index(IX_Orders_AccountID))
where AccountID=123

set statistics io off
/*
AccountID  OrderDate   Amount
---------  ----------  -------
123        2026-06-03  123.00
123        2025-01-19  623.00
....
123        2025-01-19  623.00
123        2026-06-03  1123.00
123        2025-01-19  1623.00

(100 rows affected)

Table 'Orders'. Scan count 1, logical reads 217, physical reads 2, page server reads 0, read-ahead reads 0, page server read-ahead reads 0, lob logical reads 0, 
lob physical reads 0, lob page server reads 0, lob read-ahead reads 0, lob page server read-ahead reads 0.

(1 row affected)

same execution plan as in doc
*/