# wisecow-tls.sh
#!/usr/bin/env bash

SRVPORT=4499
RSPFILE=response
TLSCERT="/app/tls/wisecow.crt"
TLSKEY="/app/tls/wisecow.key"

# Check if TLS files exist, otherwise run without TLS
if [[ -f "$TLSCERT" && -f "$TLSKEY" ]]; then
    echo "Starting Wisecow with TLS..."
    TLS_OPTS="--ssl --ssl-cert $TLSCERT --ssl-key $TLSKEY"
else
    echo "Starting Wisecow without TLS (certificates not found)"
    TLS_OPTS=""
fi

rm -f $RSPFILE
mkfifo $RSPFILE

get_api() {
	read line
	echo $line
}

handleRequest() {
    # 1) Process the request
	get_api
	mod=`fortune`

cat <<EOF > $RSPFILE
HTTP/1.1 200 OK
Content-Type: text/html

<pre>`cowsay $mod`</pre>
EOF
}

prerequisites() {
	command -v cowsay >/dev/null 2>&1 &&
	command -v fortune >/dev/null 2>&1 || 
		{ 
			echo "Install prerequisites."
			exit 1
		}
}

main() {
	prerequisites
	echo "Wisdom served on port=$SRVPORT..."

	while [ 1 ]; do
		cat $RSPFILE | nc $TLS_OPTS -lN $SRVPORT | handleRequest
		sleep 0.01
	done
}

main
