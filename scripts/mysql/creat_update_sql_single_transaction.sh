#!/bin/bash

echo "begin;" > update_single_transaction.sql
for i in {1..1000}
do
    echo "update t1 set c2 = $((RANDOM%1000+1)) where c1 = $i;" >> update_in_single_transaction.sql
done
echo "commit;" >> update_single_transaction.sql
