:EXPLAIN_ANALYZE

select sum(lo_extendedprice * lo_discount) as revenue
  from :tname
 where lo_orderdate >= '1994-02-07'
   and lo_orderdate <  '1994-02-14'
   and lo_discount between 5 and 7
   and lo_quantity between 26 and 35
;