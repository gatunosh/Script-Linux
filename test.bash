lshw -c network|egrep -w 'product|serial|description'|sed 's/description: //'|sed 's/product: //'|sed 's/serial: //' | \
while read i
do
    echo "$i"
done