# 用法

假设有三台服务器 ubuntu-01,ubuntu-02,ubuntu-03，已经在~/.ssh/config 中配置好信息，并且hostname也分别为ubuntu-01,ubuntu-02,ubuntu-03

1. 运行 `./generate-ssl-config.sh ubuntu-01,ubuntu-02,ubuntu-03` 生成，ssl config 文件。
2. 运行 `./generate-cert.sh ubuntu-01,ubuntu-02,ubuntu-03` 生成证书。
3. 运行 `./generate-etcd-conf.sh ubuntu-01,ubuntu-02,ubuntu-03` 生成etcd配置文件。
