# 基本命令

```bash
kubectl apply -f busy-pod.yaml
kubectl delete busy-pod
kubectl logs busy-pod
```

# Deployment

表示在线业务，部署的只能是无状态的业务

## 副本

## 应用伸缩

`kubectl scale --replicas=5 deploy ngx-dep`

但要注意， kubectl scale 是命令式操作，扩容和缩容只是临时的措施，如果应用需要长时间保持一个确定的 Pod 数量，最好还是编辑 Deployment 的 YAML 文件，改动“replicas”，再以声明式的 kubectl apply 修改对象的状态。



1. Pod 只能管理容器，不能管理自身，所以就出现了 Deployment，由它来管理 Pod。
2. Deployment 里有三个关键字段，其中的 template 和 Job 一样，定义了要运行的 Pod 模板。
3. replicas 字段定义了 Pod 的“期望数量”，Kubernetes 会自动维护 Pod 数量到正常水平。
4. selector 字段定义了基于 labels 筛选 Pod 的规则，它必须与 template 里 Pod 的 labels 一致。
5. 创建 Deployment 使用命令 kubectl apply，应用的扩容、缩容使用命令 kubectl scale。

> 1. ﻿﻿﻿Deployment 实际上并不是直接管理 Pod，而是用了另外一个对象 ReplicaSet，它才是维护Pod 多个副本的真正控制器。
> 2. ﻿﻿﻿Deployment 的 apiVersion 是“apps/v1”，而
>
> Job/CronJob 则是“batch/v？”，分属于不同的组，从这点也可以看出它们的领域和用法有很大区别。
>
> 3. 其实 Job/CronJob 里也是用“selector” 字段来组合
>
> Pod 对象的，但一般我们不用显式写出，Kubernetes
>
> 会自动生成一个全局唯一的label，实质上还是强绑定关系。
>
> 4.标签名由“前缀”“名称”组成。“前缀”必须符合域名规范，最多253个字符；名称允许有字母、数字、
>
> ＄_”
>
> ”，最多63个字符。
>
> 5. 要注意 Deployment 里 metadata 的 labels 与 spec
>
> 的labels 虽然通常是一样的，但它们没有任何关系，spec 的 labels 只管理 Pod。
>
> 6. 较早版本的 Kubernetes 使用 “kubectl get deploy”
>
> 会显示出“DESIRED”“CURRENT”列，现在这两个列
>
> 已经被合并成了“READY”。

# DeamonSet

DaemonSet 的目标是在集群的每个节点上运行且仅运行一个 Pod，就好像是为节点配上一只“看门狗”，忠实地“守护”着节点，这就是 DaemonSet 名字的由来。

```yaml
#DeamonSet 的yaml文件示例
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: redis-ds
  labels:
    app: redis-ds

spec:
  selector:
    matchLabels:
      name: redis-ds

  template:
    metadata:
      labels:
        name: redis-ds
    spec:
      containers:
      - image: redis:5-alpine
        name: redis
        ports:
        - containerPort: 6379
```

