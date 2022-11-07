\set collate 'collate "C"'

drop table if exists :tname;

\set default_encode_raw encoding(encodechain='''none''', compresstype='mxcustom')
\set default_encode encoding(encodechain='''lz4''', compresstype='mxcustom')
\set default_encode_mm encoding(minmax, encodechain='''lz4''', compresstype='mxcustom')
\set simple8b encoding(encodechain='''simple8b''', compresstype='mxcustom')
\set varint encoding(encodechain='''deltazigzag''', compresstype='mxcustom')
\set scalevarint encoding(minmax, encodechain='''deltazigzag''', compresstype='mxcustom')

create table :tname
 ( 
   lo_orderkey      :dynaint
 , lo_linenumber    smallint                                :simple8b
 , lo_custkey       int                                     :varint
 , lo_partkey       int                                     :varint
 , lo_suppkey       int                                     :default_encode
 , lo_orderdate     date                                    :scalevarint          
 , lo_orderpriority :e_lo_orderpriority       :collate      :default_encode
 , lo_shippriority  smallint                                :default_encode
 , lo_quantity      smallint                                :simple8b
 , lo_extendedprice int                                     :default_encode_raw
 , lo_ordtotalprice int
 , lo_discount      smallint                                :simple8b
 , lo_revenue       int                                     :default_encode_raw
 , lo_supplycost    int                                     :default_encode_raw
 , lo_tax           smallint                                :simple8b
 , lo_commitdate    date                                    :default_encode
 , lo_shipmode      :e_lo_shipmode            :collate      :default_encode
 , c_name           text                      :collate      :default_encode
 , c_address        text                      :collate      :default_encode
 , c_city           :e_c_city                 :collate      :default_encode_mm
 , c_nation         :e_c_nation                             :default_encode_mm
 , c_region         :e_c_region                             :default_encode_mm
 , c_phone          text                      :collate      :default_encode
 , c_mktsegment     :e_c_mktsegment           :collate      :default_encode
 , s_name           text                      :collate      :default_encode
 , s_address        text                      :collate      :default_encode
 , s_city           :e_s_city                 :collate      :default_encode_mm
 , s_nation         :e_s_nation                             :default_encode_mm
 , s_region         :e_s_region                             :default_encode_mm
 , s_phone          text                      :collate      :default_encode
 , p_name           text                      :collate      :default_encode
 , p_mfgr           :e_p_mfgr                               :default_encode_mm
 , p_category       :e_p_category             :collate      :default_encode_mm
 , p_brand          :e_p_brand                :collate      :default_encode_mm
 , p_color          :e_p_color                :collate      :default_encode
 , p_type           :e_p_type                 :collate      :default_encode
 , p_size           smallint                                :simple8b
 , p_container      :e_p_container            :collate      :default_encode
 )
 using mars2
 distributed by (lo_orderkey)
 partition by range (lo_orderdate)
 ( start('1992-01-01') end('1999-01-01') every(interval :par) )
;
