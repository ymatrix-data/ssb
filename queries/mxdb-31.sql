:EXPLAIN_ANALYZE

select c_nation
     , s_nation
     , date_part('year', lo_orderdate) as year
     , sum(lo_revenue) as revenue
  from :tname
 where c_region = 'ASIA'
   and s_region = 'ASIA'
   and lo_orderdate >= '1992-01-01'
   and lo_orderdate <  '1998-01-01'
 group by c_nation
        , s_nation
        , year
 order by year asc
        , revenue desc
;