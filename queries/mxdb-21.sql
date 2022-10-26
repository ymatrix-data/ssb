:EXPLAIN_ANALYZE

select sum(lo_revenue)
     , date_part('year', lo_orderdate) as year
     , p_brand
  from :tname
 where p_category = 'MFGR#12'
   and s_region = 'AMERICA'
 group by year
        , p_brand
 order by year
        , p_brand
;