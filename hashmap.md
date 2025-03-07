# JavaHashMap 实现

基于 Map 接口的实现，HashMap 实现了所有的 map 操作，并允许 key 为 null 和 value 为 null。（HashMap 大致等同于 HashTable，不同之处是 HashTable 是线程安全的，并且不允许 null）。
HashMap 的实现不能保证插入顺序，也就是，我们遍历 HashMap 的时候，返回的元素的顺序不一定是我们插入元素的效率。（如果想保证插入顺序，请使用 LinkedHashMap）。

HashMap 能保证 put 和 get 操作是常量时间的。但是遍历时间和 HashMap 的容量以及键值映射的数量成正比。因此，如果想要保证迭代的性能,不要将初始容量大小设置的太大, 还有负载因子也不能设置太小,这些都会影响迭代性能。

前面已经说过, HashMap 有两个影响性能的参数。一个是初始化容量（initial capacity），另一个是负载因子（load factor）。capacity 是哈希表中存储桶的容量（HashMap 可以想象为一个数组+链表的数据结构，数组里面存储的是链表的头。get 操作的时候相当于，代码通过 hash 映射到数组的下标，然后 get 出值，为什么是链表呢，因为 hash 算法可能会出现冲突）。load factor 是哈希表在其容量自动增加之前可以达到多满的一种尺度。当哈希表中的条目数超出了负载因子与当前容量的乘积时，哈希表将被重新哈希（即重建内部数据结构），使哈希表的容量大约加倍。

作为一般规则，默认的负载因子（0.75），在时间和空间成本之间提供了很好的折衷。较高的值会减少空间开销，但会增加查找成本（在 HashMap 中查找一个元素的时间复杂度是 O(1)）。但是，如果空间开销是重要的考虑因素，那么可以将初始容量设置为大约是预计条目数除以负载因子的结果。

HashMap 不保证线程安全，如果存在多线程同时操作 HashMap，那么需要自己保证线程安全。如果需要线程安全的 HashMap，可以使用 ConcurrentHashMap。

HashMap fail fast 机制：当多个线程同时访问 HashMap 的时候，一个线程修改了
HashMap，其他线程会立即抛出 ConcurrentModificationException 异常，这就是 HashMap 的 fail-fast 机制。

## HashMap put 操作原理
