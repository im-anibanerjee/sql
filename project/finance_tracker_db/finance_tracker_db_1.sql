-- section 1
create database FinanceTrackerDB;
-- Commands completed successfully.

use FinanceTrackerDB;

create table Users (
    UserID     int identity(1,1) primary key,
    UserName   varchar(50) not null,
    Email      varchar(100) not null unique,
    DateJoined date not null default getdate()
);
-- Commands completed successfully.

-- section 2
insert into Users (UserName, Email) values
    ('Anirruddha Banerjee', 'anirruddha@financetracker.test'),
    ('Test User Two', 'testuser2@financetracker.test');

select * from Users;
/*
UserID    UserName               Email                             DateJoined
------    --------               -----                             ----------
1         Anirruddha Banerjee    anirruddha@financetracker.test    2026-10-11
2         Test User Two          testuser2@financetracker.test     2026-10-11

(2 rows affected)

no value for DateJoined in 'insert'; taking default value; current date
*/

-- section 3
create table Accounts (
    AccountID    int identity(1,1) primary key,
    UserID       int not null,
    AccountName  varchar(50) not null,
    AccountType  varchar(20) not null,
    Balance      decimal(10,2) not null default 0,
    DateOpened   date not null default getdate(),
    constraint FK_Accounts_Users foreign key (UserID) references Users(UserID)
);
-- Commands completed successfully.

-- section 4
insert into Accounts (UserID, AccountName, AccountType) values
    (1, 'Checking', 'Checking'),
    (1, 'Savings', 'Savings'),
    (2, 'Checking', 'Checking');

select * from Accounts;
/*
AccountID   UserID   AccountName    AccountType   Balance  DateOpened
---------   ------   -----------    -----------   -------  ----------
1           1        Checking       Checking      0.00     2026-10-11
2           1        Savings        Savings       0.00     2026-10-11
3           2        Checking       Checking      0.00     2026-10-11

(3 rows affected)

no value for Balance in 'insert'; default: 0
no value for DateOpened in 'insert'; default: current date
*/

-- section 5
create table Categories (
    CategoryID       int identity(1,1) primary key,
    CategoryName     varchar(50) not null,
    ParentCategoryID int null,
    constraint FK_Categories_Parent foreign key (ParentCategoryID) references Categories(CategoryID)
);
-- Commands completed successfully.

-- section 6
insert into Categories (CategoryName, ParentCategoryID) values
    ('Essentials', NULL),
    ('Entertainment', NULL);

select * from Categories;
/*
CategoryID  CategoryName    ParentCategoryID
----------  ------------    ----------------
1           Essentials      NULL
2           Entertainment   NULL

(2 rows affected)
*/

-- section 7
insert into Categories (CategoryName, ParentCategoryID) values
    ('Groceries', 1),
    ('Rent', 1),
    ('Movies', 2);

select * from Categories;
/*
CategoryID  CategoryName       ParentCategoryID
----------  ------------       ----------------
1           Essentials         NULL
2           Entertainment      NULL
3           Groceries          1
4           Rent               1
5           Movies             2

(5 rows affected)
*/

-- section 8
create table Transactions (
    TransactionID   int identity(1,1) primary key,
    AccountID       int not null,
    CategoryID      int not null,
    TransactionDate date not null,
    Amount          decimal(10,2) not null,
    Description     varchar(200) null,
    constraint FK_Transactions_Accounts foreign key (AccountID) references Accounts(AccountID),
    constraint FK_Transactions_Categories foreign key (CategoryID) references Categories(CategoryID)
);
-- Commands completed successfully.

-- section 9
insert into Transactions (AccountID, CategoryID, TransactionDate, Amount, Description) values
    (1, 4, '2026-09-01', -1500.00, 'September rent'),
    (1, 3, '2026-09-05', -120.50, 'Weekly groceries'),
    (1, 3, '2026-09-19', -95.10, 'Groceries top-up'),
    (2, 5, '2026-09-10', -45.00, 'Movie night'),
    (3, 3, '2026-09-12', -80.25, 'Groceries');

select * from Transactions;
/*
TransactionID  AccountID  CategoryID  TransactionDate  Amount    Description
-------------  ---------  ----------  ---------------  ------    -----------
1              1          4           2026-09-01       -1500.00  September rent
2              1          3           2026-09-05       -120.50   Weekly groceries
3              1          3           2026-09-19       -95.10    Groceries top-up
4              2          5           2026-09-10       -45.00    Movie night
5              3          3           2026-09-12       -80.25    Groceries

(5 rows affected)
*/

-- section 10
create table Budgets (
    BudgetID      int identity(1,1) primary key,
    UserID        int not null,
    CategoryID    int not null,
    MonthYear     date not null,
    BudgetAmount  decimal(10,2) not null,
    constraint FK_Budgets_Users foreign key (UserID) references Users(UserID),
    constraint FK_Budgets_Categories foreign key (CategoryID) references Categories(CategoryID)
);
-- Commands completed successfully.

-- section 11
insert into Budgets (UserID, CategoryID, MonthYear, BudgetAmount) values
    (1, 3, '2026-09-01', 400.00),
    (1, 4, '2026-09-01', 1500.00),
    (2, 5, '2026-09-01', 100.00);

select * from Budgets;
/*
BudgetID  UserID  CategoryID  MonthYear   BudgetAmount
--------  ------  ----------  ---------   ------------
1         1       3           2026-09-01  400.00
2         1       4           2026-09-01  1500.00
3         2       5           2026-09-01  100.00

(3 rows affected)
*/