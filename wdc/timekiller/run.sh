row_cnt=$1
echo $row_cnt
cd ./wdc
sed -i "s/{rowCnt}/${row_cnt}/" timekiller.js
http-server
