echo "Downloading Prometheus..."
wget https://github.com/prometheus/prometheus/releases/download/v2.34.0/prometheus-2.34.0.linux-amd64.tar.gz
tar zxvf prometheus-2.34.0.linux-amd64.tar.gz
mv prometheus-2.34.0.linux-amd64 prometheus

cd /opt
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz



tar -xvf node_exporter-1.6.1.linux-amd64.tar.gz
mv node_exporter-1.6.1.linux-amd64 node_exporter

