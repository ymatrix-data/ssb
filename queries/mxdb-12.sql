:EXPLAIN_ANALYZE

select sum(lo_extendedprice * lo_discount) as revenue
  from :tname
 where lo_orderdate >= '1994-01-01'
   and lo_orderdate <  '1994-02-01'
   and lo_discount between 4 and 6
   and lo_quantity between 26 and 35
;