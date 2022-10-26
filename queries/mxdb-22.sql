:EXPLAIN_ANALYZE

select sum(lo_revenue)
     , date_part('year', lo_orderdate) as year
     , p_brand
  from :tname
 where p_brand >= 'MFGR#2221'
   and p_brand <= 'MFGR#2228'
   and s_region = 'ASIA'
 group by year
        , p_brand
 order by year
        , p_brand
;