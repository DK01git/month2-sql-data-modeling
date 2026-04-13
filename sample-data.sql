-- ============================================================
-- SECTION 1: PUBLIC SCHEMA (OLTP source tables)
-- ============================================================

-- Suppliers (no FK dependencies — load first)
INSERT INTO public.suppliers VALUES
('SUP001','TechSource Inc','john@techsource.com','USA',14),
('SUP002','GlobalGoods Ltd','sarah@globalgoods.com','China',30),
('SUP003','EuroSupply GmbH','hans@eurosupply.com','Germany',21),
('SUP004','AsiaTrade Co','li@asiatrade.com','Japan',25),
('SUP005','LocalBest LLC','mike@localbest.com','USA',7);

-- Products (depends on suppliers)
INSERT INTO public.products VALUES
('PRD001','Wireless Headphones','Electronics','Audio','SoundMax',45.00,99.99,'SUP001'),
('PRD002','Running Shoes','Footwear','Athletic','SpeedFit',35.00,79.99,'SUP002'),
('PRD003','Coffee Maker','Appliances','Kitchen','BrewMaster',28.00,59.99,'SUP003'),
('PRD004','Yoga Mat','Sports','Fitness','FlexPro',12.00,29.99,'SUP002'),
('PRD005','Laptop Stand','Electronics','Accessories','DeskPro',18.00,49.99,'SUP001'),
('PRD006','Winter Jacket','Clothing','Outerwear','WarmWear',55.00,129.99,'SUP004'),
('PRD007','Blender','Appliances','Kitchen','BlendKing',22.00,49.99,'SUP003'),
('PRD008','Backpack','Accessories','Bags','CarryAll',25.00,59.99,'SUP004'),
('PRD009','Smart Watch','Electronics','Wearables','TechTime',85.00,199.99,'SUP001'),
('PRD010','Desk Lamp','Home','Lighting','BrightHome',15.00,34.99,'SUP005');

-- Customers (no FK dependencies)
INSERT INTO public.customers VALUES
('CUS001','Alice Johnson','alice@email.com','555-0101','123 Main St','New York','NY','10001','2021-01-15'),
('CUS002','Bob Smith','bob@email.com','555-0102','456 Oak Ave','Los Angeles','CA','90001','2021-03-22'),
('CUS003','Carol White','carol@email.com','555-0103','789 Pine Rd','Chicago','IL','60601','2021-06-10'),
('CUS004','David Brown','david@email.com','555-0104','321 Elm St','Houston','TX','77001','2022-02-28'),
('CUS005','Emma Davis','emma@email.com','555-0105','654 Maple Dr','Phoenix','AZ','85001','2022-05-14'),
('CUS006','Frank Miller','frank@email.com','555-0106','987 Cedar Ln','Philadelphia','PA','19101','2022-08-30'),
('CUS007','Grace Wilson','grace@email.com','555-0107','147 Birch Blvd','San Antonio','TX','78201','2023-01-05'),
('CUS008','Henry Moore','henry@email.com','555-0108','258 Walnut Way','San Diego','CA','92101','2023-04-18'),
('CUS009','Iris Taylor','iris@email.com','555-0109','369 Spruce St','Dallas','TX','75201','2023-07-22'),
('CUS010','Jack Anderson','jack@email.com','555-0110','741 Ash Ave','San Jose','CA','95101','2023-11-09');

-- Stores (no FK dependencies)
INSERT INTO public.stores VALUES
('STR001','NYC Flagship','New York','NY','Northeast','Flagship','James Cooper','2019-03-01'),
('STR002','LA Mall Store','Los Angeles','CA','West','Mall','Sarah Chen','2019-06-15'),
('STR003','Chicago Downtown','Chicago','IL','Midwest','Downtown','Robert Davis','2020-01-10'),
('STR004','Houston Suburb','Houston','TX','South','Suburban','Maria Garcia','2020-08-20'),
('STR005','Phoenix Online Hub','Phoenix','AZ','West','Online','Kevin Lee','2021-02-14');

-- Promotions (no FK dependencies)
INSERT INTO public.promotions VALUES
('PRM001','Summer Sale','Percentage',15.00,'2023-06-01','2023-08-31','All'),
('PRM002','Black Friday','Percentage',25.00,'2023-11-24','2023-11-24','All'),
('PRM003','Member Discount','Percentage',10.00,'2023-01-01','2023-12-31','Online'),
('PRM004','Clearance','Percentage',30.00,'2023-09-01','2023-09-30','In-Store'),
('PRM005','New Year Deal','Percentage',20.00,'2024-01-01','2024-01-07','All');

-- Orders (depends on customers — store_id assigned by region)
INSERT INTO public.orders VALUES
('ORD001','CUS001','2023-01-15','Completed',159.98,'STR001'),
('ORD002','CUS002','2023-02-20','Completed',79.99,'STR002'),
('ORD003','CUS003','2023-03-10','Completed',89.98,'STR003'),
('ORD004','CUS004','2023-04-05','Completed',229.98,'STR004'),
('ORD005','CUS005','2023-05-18','Completed',29.99,'STR005'),
('ORD006','CUS006','2023-06-22','Completed',199.99,'STR005'),
('ORD007','CUS007','2023-07-30','Completed',109.98,'STR004'),
('ORD008','CUS008','2023-08-14','Completed',49.99,'STR002'),
('ORD009','CUS009','2023-09-25','Completed',259.98,'STR004'),
('ORD010','CUS010','2023-10-31','Completed',34.99,'STR002'),
('ORD011','CUS001','2023-11-24','Completed',299.97,'STR001'),
('ORD012','CUS002','2023-12-15','Completed',149.98,'STR002'),
('ORD013','CUS003','2024-01-08','Completed',79.99,'STR003'),
('ORD014','CUS004','2024-02-14','Completed',189.98,'STR004'),
('ORD015','CUS005','2024-03-20','Completed',59.99,'STR005');

-- Order Items (depends on orders)
INSERT INTO public.order_items VALUES
('ITM001','ORD001','PRD001',1,99.99,0),
('ITM002','ORD001','PRD005',1,49.99,0),
('ITM003','ORD002','PRD002',1,79.99,0),
('ITM004','ORD003','PRD003',1,59.99,0),
('ITM005','ORD003','PRD004',1,29.99,0),
('ITM006','ORD004','PRD006',1,129.99,0),
('ITM007','ORD004','PRD009',1,199.99,15),
('ITM008','ORD005','PRD004',1,29.99,0),
('ITM009','ORD006','PRD009',1,199.99,0),
('ITM010','ORD007','PRD002',1,79.99,0),
('ITM011','ORD007','PRD008',1,59.99,0),
('ITM012','ORD008','PRD005',1,49.99,0),
('ITM013','ORD009','PRD001',1,99.99,0),
('ITM014','ORD009','PRD006',1,129.99,0),
('ITM015','ORD009','PRD009',1,199.99,25),
('ITM016','ORD010','PRD010',1,34.99,0),
('ITM017','ORD011','PRD001',1,99.99,25),
('ITM018','ORD011','PRD006',1,129.99,25),
('ITM019','ORD011','PRD009',1,199.99,25),
('ITM020','ORD012','PRD002',1,79.99,0),
('ITM021','ORD012','PRD008',1,59.99,0),
('ITM022','ORD013','PRD002',1,79.99,0),
('ITM023','ORD014','PRD003',1,59.99,0),
('ITM024','ORD014','PRD007',1,49.99,0),
('ITM025','ORD015','PRD004',2,29.99,0);

-- Inventory (depends on stores + products)
INSERT INTO public.inventory VALUES
('STR001','PRD001',150,20,'2023-12-01'),
('STR001','PRD002',200,30,'2023-12-01'),
('STR001','PRD009',75,10,'2023-12-01'),
('STR002','PRD002',180,25,'2023-12-01'),
('STR002','PRD006',90,15,'2023-12-01'),
('STR003','PRD003',120,20,'2023-12-01'),
('STR003','PRD007',100,15,'2023-12-01'),
('STR004','PRD004',250,40,'2023-12-01'),
('STR004','PRD008',130,20,'2023-12-01'),
('STR005','PRD005',95,15,'2023-12-01'),
('STR005','PRD010',160,25,'2023-12-01');


-- ============================================================
-- SECTION 2: STAGING SCHEMA (mirrors of public tables)
-- ============================================================

INSERT INTO staging.suppliers    SELECT * FROM public.suppliers;
INSERT INTO staging.products     SELECT * FROM public.products;
INSERT INTO staging.customers    SELECT * FROM public.customers;
INSERT INTO staging.stores       SELECT * FROM public.stores;
INSERT INTO staging.promotions   SELECT * FROM public.promotions;
INSERT INTO staging.orders       SELECT * FROM public.orders;
INSERT INTO staging.order_items  SELECT * FROM public.order_items;
INSERT INTO staging.inventory    SELECT * FROM public.inventory;


-- ============================================================
-- VERIFICATION
-- ============================================================

SELECT 'public.suppliers'    AS tbl, COUNT(*) FROM public.suppliers
UNION ALL
SELECT 'public.products',           COUNT(*) FROM public.products
UNION ALL
SELECT 'public.customers',          COUNT(*) FROM public.customers
UNION ALL
SELECT 'public.stores',             COUNT(*) FROM public.stores
UNION ALL
SELECT 'public.promotions',         COUNT(*) FROM public.promotions
UNION ALL
SELECT 'public.orders',             COUNT(*) FROM public.orders
UNION ALL
SELECT 'public.order_items',        COUNT(*) FROM public.order_items
UNION ALL
SELECT 'public.inventory',          COUNT(*) FROM public.inventory
UNION ALL
SELECT 'staging.customers',         COUNT(*) FROM staging.customers
UNION ALL
SELECT 'staging.orders',            COUNT(*) FROM staging.orders
ORDER BY tbl;
