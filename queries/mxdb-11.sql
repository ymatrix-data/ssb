:EXPLAIN_ANALYZE

SELECT  SUM(lo_extendedprice * lo_discount) AS revenue
FROM :tname
WHERE lo_orderdate >= '1993-01-01'
AND lo_orderdate < '1994-01-01'
AND lo_discount BETWEEN 1 AND 3
AND lo_quantity < 25;

