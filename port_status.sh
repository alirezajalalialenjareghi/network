sudo ss -tulnp | grep LISTEN

sudo ss -tunp | grep ESTABLISHED

sudo ss -tulnp | grep -E ':80 |:443 '
