# 10-path.zsh — PATH 变量管理系统（函数定义）
#
# 只定义 add_to_path 函数和 _path_items 数组。
# 实际的 add_to_path 调用和 PATH 组装放在 30-env.zsh 之后，
# 因为那些调用引用 $GOBIN / $JAVA_HOME / $DOCKER_PLUGIN 等变量，
# 必须等 env 模块先 export。

# 定义一个具备唯一性的数组用于存放路径项
typeset -gU _path_items
_path_items=()

# 路径添加函数：支持多个参数，会自动检查目录是否存在并扩展 ~
function add_to_path() {
    for p in "$@"; do
        # 扩展 ~ 路径
        p="${p/#\~/$HOME}"
        if [[ -d "$p" ]]; then
            _path_items+=("$p")
        fi
    done
}
