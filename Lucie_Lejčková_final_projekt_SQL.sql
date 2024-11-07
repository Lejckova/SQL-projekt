USE financial5_80;

SELECT *
FROM INFORMATION_SCHEMA.TABLES;

SELECT *
FROM INFORMATION_SCHEMA.COLUMNS;

-- Primární klíče
SELECT *
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE CONSTRAINT_SCHEMA = 'financial5_80'
  AND CONSTRAINT_NAME = 'PRIMARY';
-- -------------------------
-- typ vztahu
SELECT *
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'financial5_80';
-- -------------------------

SELECT *
FROM account
WHERE district_id = 58;
-- primární klíč account_id

SELECT district_id,
       count(account_id) as amount
FROM account
group by district_id
order by 2 DESC;
-- tabulka account:client - 1:n
-- -------------------------
SELECT *
FROM card
WHERE disp_id = 9;
-- primární klíč card_id

SELECT disp_id,
       count(card_id) as amount
FROM card
group by disp_id
order by 2 DESC;
-- tabulka card:disp - 1:1

-- -------------------------
SELECT *
FROM client
WHERE district_id = 68;
-- primární klíč client_id

SELECT district_id,
       count(client_id) as amount
FROM client
group by district_id
order by 2 DESC;
-- tabulka client:district -  1:n
-- -------------------------

SELECT *
FROM disp
WHERE account_id = 1095;
-- primární klíč disp_id

SELECT account_id,
       count(disp_id) as amount
FROM disp
group by account_id
order by 2 DESC;
-- tabulka account:disp - 1:n
-- -------------------------

SELECT *
FROM disp
WHERE client_id = 1;

SELECT client_id,
       count(disp_id) as amount
FROM disp
group by client_id
order by 2 DESC;
-- tabulka disp:client - 1:1
-- -------------------------

SELECT *
FROM loan
WHERE account_id = 2;
-- primární klíč loan_id

SELECT account_id,
       count(loan_id) as amount
FROM loan
group by account_id
order by 2 DESC;
-- tabulka loan:account - 1:1

-- -------------------------
SELECT *
FROM financial5_80.order
WHERE account_id = 2035;
-- primární klíč order_id

SELECT account_id,
       count(order_id) as amount
FROM financial5_80.order
group by account_id
order by 2 DESC;
-- tabulka account:order - 1:n
-- -------------------------

SELECT *
FROM trans;
-- primární klíč trans_id

SELECT account_id,
       count(trans_id) as amount
FROM trans
group by account_id
order by 2 DESC;
-- tabulka account:trans 1:n

-- -------------------------

-- Historie poskytnutých úvěrů
SELECT extract(YEAR FROM date)    as loan_year,
       extract(QUARTER FROM date) as loan_quarter,
       extract(MONTH FROM date)   as loan_month,
       sum(payments)              as loans_total,
       avg(payments)              as loans_avg,
       count(payments)            as loans_count
FROM loan
group by 1, 2, 3
WITH ROLLUP;

-- -------------------------

-- Stav půjčky
SELECT status,
       count(status)                as počet,
       sum(amount)                  as půjčka,
       sum((duration) * (payments)) AS splátka
FROM loan
group by status
order by status;


WITH CTE AS (SELECT status,
                    count(status)                as počet,
                    sum(amount)                  as půjčka,
                    sum((duration) * (payments)) AS splátka
             FROM loan
             group by status)
select 'A + C splacene'                                                                                  as status,
       (select SUM(počet) from CTE WHERE status = 'A') + (select SUM(počet) from CTE WHERE status = 'C') as TOTAl
UNION
select 'B + D nesplacene',
       (select SUM(počet) from CTE WHERE status = 'B') + (select SUM(počet) from CTE WHERE status = 'D');

-- -------------------------

-- Analýza účtů
WITH cte as (SELECT account_id,
                    count(amount) as COUNT_amount,
                    SUM(amount)   as SUM_amount,
                    AVG(amount)   as AVG_amount
             FROM loan
             WHERE STATUS IN ('A', 'C')
             group by account_id)
SELECt *
     --  , ROW_NUMBER() over (ORDER BY COUNT_amount DESC) AS rank_COUNT
     , ROW_NUMBER() over (ORDER BY SUM_amount DESC) AS rank_SUM
--  , ROW_NUMBER() over (ORDER BY AVG_amount DESC)   AS rank_AVG
FROM cte;

-- řadit dle počtu nemá význam, mají všichni pouze 1
-- řadit dle AVG je stejné jako dle SUM

-- -------------------------

-- Plně splacené půjčky
SELECT * FROM disp
WHERE account_id = 2;

DROP TABLE IF EXISTS results;

CREATE TEMPORARY TABLE results AS
SELECT gender,
       sum(amount) as Total
FROM loan as l
         JOIN disp as d ON d.account_id = l.account_id
         JOIN client as c ON c.client_id = d.client_id
WHERE status IN ('A', 'C')
  and d.type = 'OWNER'    -- pozor pouze OWNER, jinak se duplikují data díky DISPONENT
group by c.gender;

SELECT * FROM results; -- výsledek zůstatek splacených úvěrů rozdělený podle pohlaví klienta

WITH cte as (SELECT sum(amount) as amount
             FROM loan
             WHERE status IN ('A', 'C'))
SELECT (SELECT SUM(Total) FROM results) - (SELECT amount FROM cte) as control;

-- -------------------------

-- Analýza klienta - 1. část
SELECT *
FROM disp;

SELECT gender,
       count(amount)                  as number_of_loans,
       avg(2024 - YEAR(c.birth_date)) as AVG_age
FROM loan as l
         JOIN disp as d ON d.account_id = l.account_id
         JOIN client as c ON c.client_id = d.client_id
WHERE status IN ('A', 'C')
  and type = 'OWNER'
group by c.gender
ORDER BY 2 DESC ;

-- Více splacených půjček mají ženy

-- -------------------------


-- Analýza klienta - část 2
SELECT dis.district_id,
       A2,
       count(distinct c.client_id) as number_customers_region,
       count(amount)               as number_of_loans,
       sum(amount)                 AS sum_loans
FROM loan as l
         JOIN disp as d ON d.account_id = l.account_id
         JOIN client as c ON c.client_id = d.client_id
         JOIN district as dis ON c.district_id = dis.district_id
WHERE status IN ('A', 'C')
  and type = 'OWNER'
group by dis.district_id
order by sum_loans DESC;

-- Praha

-- -------------------------

-- Analýza klienta - část 3
WITH cte AS (SELECT dis.district_id,
                    A2,
                    count(distinct c.client_id) as number_customers_region,
                    count(amount)               as number_of_loans,
                    sum(amount)                 AS sum_loans
             FROM loan as l
                      JOIN disp as d ON d.account_id = l.account_id
                      JOIN client as c ON c.client_id = d.client_id
                      JOIN district as dis ON c.district_id = dis.district_id
             WHERE status IN ('A', 'C')
               and type = 'OWNER'
             group by dis.district_id
             order by sum_loans DESC)
SELECT *,
       (sum_loans / sum(sum_loans) over ()) * 100 as percent
from cte
order by percent desc;

-- -------------------------

-- Výběr klienta část 1 a 2
SELECT c.client_id,
       year(birth_date)           as year_birth,
       sum(l.amount - l.payments) as account_balance,
       count(l.account_id)        as number_of_loans
FROM loan as l
         JOIN disp as d ON d.account_id = l.account_id
         JOIN client as c ON c.client_id = d.client_id
         JOIN district as dis ON c.district_id = dis.district_id
WHERE status IN ('A', 'C')
  and type = 'OWNER'
-- AND extract(YEAR FROM birth_date) > 1990
group by c.client_id
HAVING
-- count(loan_id) > 5 and
sum(l.amount - l.payments) > 1000
ORDER by year_birth desc, account_balance desc;

-- po roce 1990 není žádný klient
-- zákazníci mají max 1 půjčku

 -- -------------------------

-- Končící karty napsat proceduru
WITH cte AS (select c.client_id,
                    c2.card_id,
                    date_add(issued, interval 3 year) AS expiration_date,
                    a3                                AS address
             from disp as d
                      JOIN client as c ON d.client_id = c.client_id
                      JOIN district as d2 ON c.district_id = d2.district_id
                      JOIN card as c2 ON d.disp_id = c2.disp_id)
SELECT *,
       date_add(expiration_date, interval -7 day) as send_new_card
FROM cte
WHERE '2001-01-01' BETWEEN date_add(expiration_date, interval -7 day) AND expiration_date
order by send_new_card desc;


-- drop table if exists cards_at_expiration;
CREATE TABLE IF NOT EXISTS cards_at_expiration
(
    client_id          int,
    card_id            int default 0,
    expiration_date    date,
    A3                 varchar(20),
    generated_for_date date
);

DROP PROCEDURE IF EXISTS generate_cards_at_expiration_report;
DELIMITER $$
CREATE PROCEDURE generate_cards_at_expiration_report(generated_date DATE)
BEGIN
    TRUNCATE TABLE cards_at_expiration;
    -- SELECT 'Promazání tabulky';
    INSERT INTO cards_at_expiration
    WITH cte AS (select c.client_id,
                        c2.card_id,
                        date_add(issued, interval 3 year) AS expiration_date,
                        a3                                AS address
                 from disp as d
                          JOIN client as c ON d.client_id = c.client_id
                          JOIN district as d2 ON c.district_id = d2.district_id
                          JOIN card as c2 ON d.disp_id = c2.disp_id)
    SELECT *,
           generated_date
    FROM cte
    WHERE generated_date BETWEEN date_add(expiration_date, interval -7 day) AND expiration_date;
    SELECT * FROM cards_at_expiration;
end $$
DELIMITER ;




CALL generate_cards_at_expiration_report('2000-01-01');






SELECT *
from cards_at_expiration;



