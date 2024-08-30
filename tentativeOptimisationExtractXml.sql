CREATE TABLE aOrders
(
    OrderID INT,
    OrderDetails XML
);
insert into aOrders Select 1, '<Order>
    <CustomerID>12345</CustomerID>
    <OrderDate>2024-06-25</OrderDate>
    <TotalAmount>250.75</TotalAmount>
</Order>'

SELECT
    OrderID,
    OrderDetails.value('(Order/CustomerID)[1]', 'INT') AS CustomerID,
    OrderDetails.value('(Order/OrderDate)[1]', 'DATE') AS OrderDate,
    OrderDetails.value('(Order/TotalAmount)[1]', 'DECIMAL(10, 2)') AS TotalAmount
FROM 
    aOrders;

SELECT
    O.OrderID,
    C.value('(CustomerID)[1]', 'INT') AS CustomerID,
    C.value('(OrderDate)[1]', 'DATE') AS OrderDate,
    C.value('(TotalAmount)[1]', 'DECIMAL(10, 2)') AS TotalAmount
FROM 
    aOrders O
CROSS APPLY 
    OrderDetails.nodes('/Order') AS T(C);