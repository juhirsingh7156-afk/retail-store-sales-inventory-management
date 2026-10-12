/*
Retail Store Sales & Inventory Management
SQL Server 2019+ recommended. Run this script in SSMS.
Creates database if absent, then tables, constraints, indexes, views, procedures and triggers.
*/
IF DB_ID(N'RetailStoreDB') IS NULL
    CREATE DATABASE RetailStoreDB;
GO
USE RetailStoreDB;
GO

IF OBJECT_ID('dbo.trg_OrderItems_Inventory', 'TR') IS NOT NULL DROP TRIGGER dbo.trg_OrderItems_Inventory;
IF OBJECT_ID('dbo.usp_RecordStockReceipt', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_RecordStockReceipt;
IF OBJECT_ID('dbo.usp_GetSalesSummary', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_GetSalesSummary;
IF OBJECT_ID('dbo.vw_SalesDetail', 'V') IS NOT NULL DROP VIEW dbo.vw_SalesDetail;
IF OBJECT_ID('dbo.vw_InventoryStatus', 'V') IS NOT NULL DROP VIEW dbo.vw_InventoryStatus;
GO
IF OBJECT_ID('dbo.OrderItems','U') IS NOT NULL DROP TABLE dbo.OrderItems;
IF OBJECT_ID('dbo.Orders','U') IS NOT NULL DROP TABLE dbo.Orders;
IF OBJECT_ID('dbo.ProductSuppliers','U') IS NOT NULL DROP TABLE dbo.ProductSuppliers;
IF OBJECT_ID('dbo.Products','U') IS NOT NULL DROP TABLE dbo.Products;
IF OBJECT_ID('dbo.Suppliers','U') IS NOT NULL DROP TABLE dbo.Suppliers;
IF OBJECT_ID('dbo.Customers','U') IS NOT NULL DROP TABLE dbo.Customers;
IF OBJECT_ID('dbo.Categories','U') IS NOT NULL DROP TABLE dbo.Categories;
GO

CREATE TABLE dbo.Categories(
    CategoryID INT NOT NULL CONSTRAINT PK_Categories PRIMARY KEY,
    CategoryName NVARCHAR(80) NOT NULL CONSTRAINT UQ_Categories_Name UNIQUE
);
CREATE TABLE dbo.Customers(
    CustomerID INT NOT NULL CONSTRAINT PK_Customers PRIMARY KEY,
    CustomerName NVARCHAR(120) NOT NULL,
    Email NVARCHAR(254) NULL,
    Phone NVARCHAR(30) NULL,
    CustomerType VARCHAR(20) NOT NULL CONSTRAINT CK_Customers_Type CHECK(CustomerType IN ('Retail','Wholesale'))
);
CREATE TABLE dbo.Suppliers(
    SupplierID INT NOT NULL CONSTRAINT PK_Suppliers PRIMARY KEY,
    SupplierName NVARCHAR(150) NOT NULL,
    Email NVARCHAR(254) NULL,
    Phone NVARCHAR(30) NULL
);
CREATE TABLE dbo.Products(
    ProductID INT NOT NULL CONSTRAINT PK_Products PRIMARY KEY,
    SKU VARCHAR(30) NOT NULL CONSTRAINT UQ_Products_SKU UNIQUE,
    ProductName NVARCHAR(150) NOT NULL,
    CategoryID INT NOT NULL,
    UnitPrice DECIMAL(12,2) NOT NULL CONSTRAINT CK_Products_Price CHECK(UnitPrice >= 0),
    UnitCost DECIMAL(12,2) NOT NULL CONSTRAINT CK_Products_Cost CHECK(UnitCost >= 0),
    StockQty INT NOT NULL CONSTRAINT CK_Products_Stock CHECK(StockQty >= 0),
    ReorderLevel INT NOT NULL CONSTRAINT CK_Products_Reorder CHECK(ReorderLevel >= 0),
    IsActive BIT NOT NULL CONSTRAINT DF_Products_IsActive DEFAULT(1),
    CONSTRAINT FK_Products_Categories FOREIGN KEY(CategoryID) REFERENCES dbo.Categories(CategoryID)
);
CREATE TABLE dbo.ProductSuppliers(
    ProductID INT NOT NULL,
    SupplierID INT NOT NULL,
    LeadTimeDays INT NOT NULL CONSTRAINT CK_ProductSuppliers_LeadTime CHECK(LeadTimeDays >= 0),
    CONSTRAINT PK_ProductSuppliers PRIMARY KEY(ProductID,SupplierID),
    CONSTRAINT FK_ProductSuppliers_Products FOREIGN KEY(ProductID) REFERENCES dbo.Products(ProductID),
    CONSTRAINT FK_ProductSuppliers_Suppliers FOREIGN KEY(SupplierID) REFERENCES dbo.Suppliers(SupplierID)
);
CREATE TABLE dbo.Orders(
    OrderID INT NOT NULL CONSTRAINT PK_Orders PRIMARY KEY,
    OrderNumber VARCHAR(30) NOT NULL CONSTRAINT UQ_Orders_OrderNumber UNIQUE,
    CustomerID INT NOT NULL,
    OrderDate DATE NOT NULL,
    Status VARCHAR(20) NOT NULL CONSTRAINT CK_Orders_Status CHECK(Status IN ('Completed','Cancelled','Returned','Pending')),
    PaymentMethod VARCHAR(20) NOT NULL CONSTRAINT CK_Orders_Payment CHECK(PaymentMethod IN ('UPI','Card','Cash','Wallet','Bank Transfer')),
    DiscountRate DECIMAL(5,4) NOT NULL CONSTRAINT CK_Orders_Discount CHECK(DiscountRate >= 0 AND DiscountRate <= 1),
    CONSTRAINT FK_Orders_Customers FOREIGN KEY(CustomerID) REFERENCES dbo.Customers(CustomerID)
);
CREATE TABLE dbo.OrderItems(
    OrderItemID INT NOT NULL CONSTRAINT PK_OrderItems PRIMARY KEY,
    OrderID INT NOT NULL,
    ProductID INT NOT NULL,
    Quantity INT NOT NULL CONSTRAINT CK_OrderItems_Quantity CHECK(Quantity > 0),
    UnitPrice DECIMAL(12,2) NOT NULL CONSTRAINT CK_OrderItems_UnitPrice CHECK(UnitPrice >= 0),
    DiscountRate DECIMAL(5,4) NOT NULL CONSTRAINT CK_OrderItems_Discount CHECK(DiscountRate >= 0 AND DiscountRate <= 1),
    CONSTRAINT FK_OrderItems_Orders FOREIGN KEY(OrderID) REFERENCES dbo.Orders(OrderID),
    CONSTRAINT FK_OrderItems_Products FOREIGN KEY(ProductID) REFERENCES dbo.Products(ProductID)
);
GO
CREATE INDEX IX_Orders_OrderDate_Status ON dbo.Orders(OrderDate,Status);
CREATE INDEX IX_OrderItems_ProductID ON dbo.OrderItems(ProductID);
CREATE INDEX IX_Orders_CustomerID ON dbo.Orders(CustomerID);
GO

CREATE VIEW dbo.vw_SalesDetail AS
SELECT o.OrderID,o.OrderNumber,o.OrderDate,o.Status,o.PaymentMethod,
       c.CustomerID,c.CustomerName,p.ProductID,p.SKU,p.ProductName,cat.CategoryName,
       oi.Quantity,oi.UnitPrice,oi.DiscountRate AS LineDiscountRate,o.DiscountRate AS OrderDiscountRate,
       CAST(oi.Quantity*oi.UnitPrice*(1-oi.DiscountRate)*(1-o.DiscountRate) AS DECIMAL(14,2)) AS NetSales,
       CAST(oi.Quantity*p.UnitCost AS DECIMAL(14,2)) AS CostAmount,
       CAST(oi.Quantity*oi.UnitPrice*(1-oi.DiscountRate)*(1-o.DiscountRate)-oi.Quantity*p.UnitCost AS DECIMAL(14,2)) AS GrossProfit
FROM dbo.OrderItems oi
JOIN dbo.Orders o ON o.OrderID=oi.OrderID
JOIN dbo.Customers c ON c.CustomerID=o.CustomerID
JOIN dbo.Products p ON p.ProductID=oi.ProductID
JOIN dbo.Categories cat ON cat.CategoryID=p.CategoryID;
GO

CREATE VIEW dbo.vw_InventoryStatus AS
SELECT p.ProductID,p.SKU,p.ProductName,c.CategoryName,p.UnitPrice,p.UnitCost,p.StockQty,p.ReorderLevel,
       CAST(p.StockQty*p.UnitCost AS DECIMAL(14,2)) AS StockValue,
       CASE WHEN p.StockQty=0 THEN 'OUT OF STOCK'
            WHEN p.StockQty<=p.ReorderLevel THEN 'REORDER'
            ELSE 'OK' END AS StockStatus
FROM dbo.Products p JOIN dbo.Categories c ON c.CategoryID=p.CategoryID
WHERE p.IsActive=1;
GO

CREATE PROCEDURE dbo.usp_GetSalesSummary
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    IF @StartDate IS NULL OR @EndDate IS NULL OR @StartDate>@EndDate
        THROW 50001, 'Provide a valid start and end date.', 1;
    SELECT CAST(SUM(NetSales) AS DECIMAL(14,2)) AS NetSales,
           CAST(SUM(GrossProfit) AS DECIMAL(14,2)) AS GrossProfit,
           COUNT(DISTINCT OrderID) AS CompletedOrders,
           SUM(Quantity) AS UnitsSold
    FROM dbo.vw_SalesDetail
    WHERE Status='Completed' AND OrderDate>=@StartDate AND OrderDate<=@EndDate;
END;
GO

CREATE PROCEDURE dbo.usp_RecordStockReceipt
    @ProductID INT,
    @Quantity INT
AS
BEGIN
    SET NOCOUNT ON;
    IF @Quantity<=0 THROW 50002, 'Receipt quantity must be greater than zero.', 1;
    UPDATE dbo.Products SET StockQty=StockQty+@Quantity WHERE ProductID=@ProductID;
    IF @@ROWCOUNT=0 THROW 50003, 'Product ID was not found.', 1;
    SELECT ProductID,SKU,ProductName,StockQty FROM dbo.Products WHERE ProductID=@ProductID;
END;
GO

/* Inventory decreases when an order item is inserted for a Completed order.
   If the insert would make stock negative, the whole statement fails. */
CREATE TRIGGER dbo.trg_OrderItems_Inventory
ON dbo.OrderItems
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS(
        SELECT 1 FROM inserted i
        JOIN dbo.Orders o ON o.OrderID=i.OrderID AND o.Status='Completed'
        JOIN dbo.Products p ON p.ProductID=i.ProductID
        WHERE p.StockQty < i.Quantity
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50004, 'Insufficient inventory for completed order item.', 1;
    END;
    UPDATE p
       SET p.StockQty=p.StockQty-x.Qty
    FROM dbo.Products p
    JOIN (
        SELECT i.ProductID,SUM(i.Quantity) AS Qty
        FROM inserted i JOIN dbo.Orders o ON o.OrderID=i.OrderID AND o.Status='Completed'
        GROUP BY i.ProductID
    ) x ON x.ProductID=p.ProductID;
END;
GO
