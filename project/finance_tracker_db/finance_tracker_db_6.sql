-- section 34
create procedure TransferFunds
    @FromAccountID int,
    @ToAccountID int,
    @Amount decimal(10,2),
    @SimulateDelay bit = 0
as
begin
    set nocount on;

    begin try
        if @FromAccountID = @ToAccountID
            throw 50000, 'Source and destination accounts must be different.', 1;

        if @Amount <= 0
            throw 50004, 'Transfer amount must be greater than zero.', 1;

        begin transaction;

        if not exists (select 1 from Accounts where AccountID = @FromAccountID)
            throw 50001, 'Source account does not exist.', 1;

        if (select Balance from Accounts where AccountID = @FromAccountID) < @Amount
            throw 50003, 'Insufficient funds in source account.', 1;

        update Accounts
        set Balance = Balance - @Amount
        where AccountID = @FromAccountID;

        if @SimulateDelay = 1
            waitfor delay '00:00:15';

        if not exists (select 1 from Accounts where AccountID = @ToAccountID)
            throw 50002, 'Destination account does not exist.', 1;

        update Accounts
        set Balance = Balance + @Amount
        where AccountID = @ToAccountID;

        commit transaction;
    end try
    begin catch
        if @@trancount > 0
            rollback transaction;

        throw;
    end catch
end
go
/*
Commands completed successfully.
*/

-- section 35
-- resetting Accounts 1-3 to clean, known starting balances before the TransferFunds re-test
update Accounts set Balance = 1000.00 where AccountID = 1;
update Accounts set Balance = 500.00 where AccountID = 2;
update Accounts set Balance = 0.00 where AccountID = 3;

select
    AccountID,
    Balance
from Accounts
order by AccountID;
/*
AccountID  Balance
---------  -------
1          1000.00
2          500.00
3          0.00

(3 rows affected)
*/

-- a real successful transfer through TransferFunds
exec TransferFunds @FromAccountID = 1, @ToAccountID = 2, @Amount = 200.00;

select
    AccountID,
    Balance
from Accounts
order by AccountID;
/*
AccountID  Balance
---------  -------
1          800.00
2          700.00
3          0.00

(3 rows affected)
*/

-- a deliberate failing transfer (insufficient funds), proving rollback
exec TransferFunds @FromAccountID = 3, @ToAccountID = 1, @Amount = 9999.00;
/*
Msg 50003, Level 16, State 1, Procedure TransferFunds, Line 27 [Batch Start Line 0]
Insufficient funds in source account.
*/

select
    AccountID,
    Balance
from Accounts
order by AccountID;
/*
AccountID  Balance
---------  -------
1          800.00
2          700.00
3          0.00

(3 rows affected)
*/

-- section 36
-- window A: starts a real transfer with a pause mid-transaction
exec TransferFunds @FromAccountID = 2, @ToAccountID = 1, @Amount = 50.00, @SimulateDelay = 1;

-- window B, while window A's transfer is still mid-flight, under READ UNCOMMITTED
set transaction isolation level read uncommitted;
select
    AccountID,
    Balance
from Accounts
where AccountID in (1, 2)
order by AccountID;
/*
AccountID  Balance
---------  -------
1          700.00
2          750.00

(2 rows affected)
*/

-- window B, same accounts, now under READ COMMITTED, after window A's transfer committed
set transaction isolation level read committed;
select
    AccountID,
    Balance
from Accounts
where AccountID in (1, 2)
order by AccountID;
/*
AccountID  Balance
---------  -------
1          750.00
2          750.00

(2 rows affected)
*/

-- window A, checked after the above: Commands completed successfully.

-- section 37
-- window A: locks Account 1 first, pauses, then wants Account 2
exec TransferFunds @FromAccountID = 1, @ToAccountID = 2, @Amount = 10.00, @SimulateDelay = 1;
-- in Window A: Msg 1205, Level 13, State 51, Procedure TransferFunds, Line 37 [Batch Start Line 0]
-- Transaction (Process ID 63) was deadlocked on lock resources with another process and has been chosen as the deadlock victim. Rerun the transaction.

-- window B: locks Account 2 first, pauses, then wants Account 1 -- the circular wait, started right behind window A
exec TransferFunds @FromAccountID = 2, @ToAccountID = 1, @Amount = 10.00, @SimulateDelay = 1;
-- Commands completed successfully.

select
    AccountID,
    Balance
from Accounts
order by AccountID;
/*
AccountID  Balance
---------  -------
1          760.00
2          740.00
3          0.00

(3 rows affected)
*/
