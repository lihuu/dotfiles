#!/bin/bash
echo "prepare pr1 from 'update t1 set c2=? where c1=?';" > prepare.sql
for i in {1..1000}
do
    echo "set @a=$((RANDOM%1000+1)),@b=$i;" >> prepare.sql
    echo "execute pr1 using @a,@b;" >> prepare.sql
done
echo "deallocate prepare pr1;" >> prepare.sql
