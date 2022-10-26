:EXPLAIN_ANALYZE

select c_city
     , s_city
     , date_part('year', lo_orderdate) as year
     , sum(lo_revenue) as revenue
  from :tname
 where c_city in ('UNITED KI1', 'UNITED KI5')
   and s_city in ('UNITED KI1', 'UNITED KI5')
   and lo_orderdate >= '1997-12-01'
   and lo_orderdate <  '1998-01-01'
 group by c_city
        , s_city
        , year
 order by year asc
        , revenue desc
;