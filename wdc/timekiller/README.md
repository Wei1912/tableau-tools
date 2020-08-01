# Timekiller, a Tableau Web Data Connector
## How to use

### 1. Pull Docker iamge

### 2. Run Docker container
```
docker run -it --name timekiller -p 8080:8080 wdc-timekiller {rowCnt}
```

Replace {rowCnt} with a number that specifies how many rows you want the wdc to generate.
1 row 1 second. For example, if you specify 3600, the wdc will generate 3600 rows data and takes 1 hour to complish.

### 3. Connect Tableau Desktop to it
Start Tableau Desktop and select Web Data Connector, type
```
http://localhost:8080/timekiller.html
```
