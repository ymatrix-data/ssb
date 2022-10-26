SSB Benchmark for MatrixDB
---

*NOTE. you may checkout detail help message via -h.*

# Step 1. validate environment before moving forward

```
./validate_environment.sh
```

# Step 2. generate dataset

```
./generate_data.sh -s 1
```


# Step 3. import dataset 

```
./import_data.sh -s 1
```


# Step 4. generate a flatten table

```
./generate_flat_table.sh -s 1
```

# Step 5. run SSB benchmark

```
./ssb.sh -s 1
```

