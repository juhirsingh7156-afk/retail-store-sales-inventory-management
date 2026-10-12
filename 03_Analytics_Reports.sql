USE RetailStoreDB;
GO
/* 1. KPI summary: set dates as needed */
DECLARE @StartDate DATE='2026-01-01', @EndDate DATE='2026-03-31';
EXEC dbo.usp_GetSalesSummary @StartDate=@StartDate, @EndDate=@EndDate;
GO

/* 2. Monthly sales and gross profit */
SELECT YEAR(OrderDate) AS SalesYear, MONTH(OrderDate) AS SalesMonth,
       SUM(NetSales) AS NetSales, SUM(GrossProfit) AS GrossProfit,
       COUNT(DISTINCT OrderID) AS Orders
FROM dbo.vw_SalesDetail
WHERE Status='Completed'
GROUP BY YEAR(OrderDate),MONTH(OrderDate)
ORDER BY SalesYear,SalesMonth;
GO

/* 3. Top 10 products by net sales */
SELECT TOP (10) ProductName, SUM(Quantity) AS UnitsSold,
       SUM(NetSales) AS NetSales, SUM(GrossProfit) AS GrossProfit
FROM dbo.vw_SalesDetail
WHERE Status='Completed'
GROUP BY ProductName
ORDER BY NetSales DESC;
GO

/* 4. Category performance */
SELECT CategoryName,SUM(NetSales) AS NetSales,SUM(GrossProfit) AS GrossProfit,
       SUM(Quantity) AS UnitsSold
FROM dbo.vw_SalesDetail
WHERE Status='Completed'
GROUP BY CategoryName
ORDER BY NetSales DESC;
GO

/* 5. Low stock and out-of-stock products */
SELECT * FROM dbo.vw_InventoryStatus
WHERE StockStatus IN ('REORDER','OUT OF STOCK')
ORDER BY CASE StockStatus WHEN 'OUT OF STOCK' THEN 0 ELSE 1 END, StockQty;
GO

/* 6. Payment method mix */
SELECT PaymentMethod,COUNT(DISTINCT OrderID) AS Orders,SUM(NetSales) AS NetSales
FROM dbo.vw_SalesDetail
WHERE Status='Completed'
GROUP BY PaymentMethod
ORDER BY NetSales DESC;
GO

/* 7. Customer value */
SELECT TOP (10) CustomerName,COUNT(DISTINCT OrderID) AS Orders,
       SUM(NetSales) AS NetSales,SUM(GrossProfit) AS GrossProfit
FROM dbo.vw_SalesDetail
WHERE Status='Completed'
GROUP BY CustomerName
ORDER BY NetSales DESC;
GO

/* 8. Data quality checks: expected to return zero rows */
SELECT oi.OrderItemID
FROM dbo.OrderItems oi
JOIN dbo.Orders o ON o.OrderID=oi.OrderID
WHERE oi.Quantity<=0 OR oi.UnitPrice<0 OR oi.DiscountRate<0 OR oi.DiscountRate>1;
GO

/* 9. Example safe stock receipt (optional; changes data) */
-- EXEC dbo.usp_RecordStockReceipt @ProductID=1, @Quantity=25;
