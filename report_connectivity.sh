ping -c 5 8.8.8.8

ping -c 5 google.com

if command -v dig &> /dev/null
then
    dig github.com
else
    echo "dig command not found. Trying nslookup."
    # Fallback to nslookup if dig is not installed
    if command -v nslookup &> /dev/null
    then
        nslookup github.com
    else
        echo "Neither dig nor nslookup found. Cannot test DNS resolution."
    fi
fi