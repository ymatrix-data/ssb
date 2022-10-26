copy lineorder
  from program 'zstdcat --quiet :datadir/lineorder.tbl.zst'
  with (format csv, delimiter ',', header off);

copy customer
  from program 'zstdcat --quiet :datadir/customer.tbl.zst'
  with (format csv, delimiter ',', header off);

copy part
  from program 'zstdcat --quiet :datadir/part.tbl.zst'
  with (format csv, delimiter ',', header off);

copy supplier
  from program 'zstdcat --quiet :datadir/supplier.tbl.zst'
  with (format csv, delimiter ',', header off);