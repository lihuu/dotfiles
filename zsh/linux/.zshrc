# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
#ZSH_THEME="robbyrussell"
#ZSH_THEME="half-life"
ZSH_THEME="ys"



# Set list of themes to load
# Setting this variable when ZSH_THEME=random
# cause zsh load theme from this variable instead of
# looking in ~/.oh-my-zsh/themes/
# An empty array have no effect
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git command-not-found minikube kubectl
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"



#export http_proxy="http://192.168.2.33:7891"
export http_proxy="http://localhost:10808"
export https_proxy="http://localhost:10808"
#export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin
export DOCKER_PLUGIN=$HOME/.docker/cli-plugins
export PATH=$PATH:$DOCKER_PLUGIN:$MYSQL_HOME/bin:$GOBIN:$GOROOT/bin:$HOME/.config/yarn/global/node_modules/.bin
export PERL5LIB=/home/linuxbrew/.linuxbrew/opt/perl/lib/perl5
export HOMEBREW_NO_AUTO_UPDATE=true
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
export LDFLAGS="-L/usr/local/opt/openssl/lib"
export CPPFLAGS="-I/usr/local/opt/openssl/include"
export PATH="/usr/local/opt/openssl/bin:/usr/local/go/bin:$HOME/.deno/bin:$PATH":$HOME/.local/bin
export ANDROID_NDK_HOME=$HOME/Android/Sdk/ndk/22.1.7171670
export ANDROID_HOME=$HOME/Android/Sdk
export LANG=zh_CN.UTF-8
export LC_CTYPE=zh_CN.UTF-8
export ROCKETMQ_HOME=$HOME/Applications/rocketmq-all-5.1.0-bin-release

gitlog() {
  git log --graph --color=always \
    --format="%C(auto)%h%d %s %C(black)%C(bold)%cr" "$@" |
    fzf --ansi --no-sort --reverse --tiebreak=index --bind=ctrl-s:toggle-sort \
    --bind "ctrl-m:execute:
  (grep -o '[a-f0-9]\{7\}' | head -1 |
    xargs -I % sh -c 'git show --color=always % | less -R') << 'FZF-EOF'
  {}
  FZF-EOF"
}

alias emacs='env LC_CTYPE=zh_CN.UTF-8 emacs'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
#export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
#[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$HOME/.volta/bin:$JAVA_HOME/bin:$PATH
alias virsh="sudo virsh"

#alias kubectl="minikube kubectl --"
#alias sel = "kubectl get pods"
[[ $commands[kubectl] ]] && source <(kubectl completion zsh)
export XMODIFIERS=@im=fcitx
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx

vmip() {
  local name="$1"
  sudo virsh domifaddr "$name" | awk '/ipv4/ {print $4}' | cut -d'/' -f1
}

vmssh() {
  local input="$1"
  local user host ip

  if [[ "$input" == *"@"* ]]; then
    user="${input%@*}"
    host="${input#*@}"
  else
    user="ubuntu"
    host="$input"
  fi

  # 如果 host 是 IP 地址（纯数字加点）
  if [[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    ip="$host"
  else
    ip=$(sudo virsh domifaddr "$host" | awk '/ipv4/ {print $4}' | cut -d'/' -f1)
    if [[ -z "$ip" ]]; then
      echo "❌ 无法获取虚拟机 $host 的 IP 地址" >&2
      return 1
    fi
  fi

  echo "🔗 正在连接 $user@$ip ..."
  ssh "$user@$ip"
}

# === 删除虚拟机及其磁盘的函数 ===
vmrm() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "⚠️ 请输入要删除的虚拟机名称，例如：vmrm ubuntu-01"
    return 1
  fi

  echo "⚠️ 即将删除虚拟机：$name"
  read "confirm?确认删除该虚拟机及其磁盘？[y/N]: "
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "取消删除。"
    return 0
  fi

  # 获取磁盘路径
  local disk
  disk=$(sudo virsh domblklist "$name" | awk '/^vda/ {print $2}')

  echo "🔻 销毁虚拟机..."
  sudo virsh destroy "$name" 2>/dev/null

  echo "🧹 删除虚拟机定义..."
  sudo virsh undefine "$name" --remove-all-storage 2>/dev/null

  # 若磁盘未自动删除，尝试手动删除
  if [[ -n "$disk" && -f "$disk" ]]; then
    echo "🗑️ 删除磁盘文件 $disk"
    sudo rm -f "$disk"
  fi

  echo "✅ 虚拟机 $name 删除完成。"
}


vmscp() {

  if [[ $# -lt 2 ]]; then
    echo "用法: vmscp <源> <目标>（支持虚拟机名自动转 IP）"
    return 1
  fi

  local args=("$@")
  local updated_args=()
  local ip

  for arg in "${args[@]}"; do
    if [[ "$arg" =~ ^([^@]+@)?([^:]+):(.+)$ ]]; then
      local user_part="${match[1]}"
      if [ -z "$user_part" ]; then
        user_part="ubuntu"
      fi
      local host="${match[2]}"
      local target_path="${match[3]}"

      # 如果 host 是 IP，直接使用
      if [[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        updated_args+=("$arg")
      else
        # 解析虚拟机名为 IP
        ip=$(sudo virsh domifaddr "$host" | awk '/ipv4/ {print $4}' | cut -d'/' -f1)
        if [[ -z "$ip" ]]; then
          echo "❌ 无法获取虚拟机 $host 的 IP 地址" >&2
          return 1
        fi
        updated_args+=("${user_part}@${ip}:$target_path")
      fi
    else
      updated_args+=("$arg")
    fi
  done

  echo "📤 执行: scp ${updated_args[*]}"
  scp "${updated_args[@]}"
}

alias vmall="sudo virsh list --all"


update_host_block() {
  local host="$1" user="$2" ip="$3" port="$4" config="$5" temp="$6"

  awk -v host="$host" -v user="$user" -v ip="$ip" -v port="$port" '
  BEGIN { inhost = 0 }
  $1 == "Host" && $2 == host {
    print; inhost = 1; next
  }
$1 == "Host" && inhost == 1 {
  print "  HostName " ip
  print "  User " user
  print "  Port " port
  inhost = 0
}
inhost == 1 && ($1 == "HostName" || $1 == "User" || $1 == "Port") {
  next
}
{ print }
END {
  if (inhost == 1) {
    print "  HostName " ip
    print "  User " user
    print "  Port " port
  }
}
' "$config" >"$temp.tmp" && mv "$temp.tmp" "$temp"
}


vm_add_ssh_config(){
  vmname="$1"
  user="${2:-ubuntu}"
  port="${3:-22}"

  ip=$(sudo virsh domifaddr "$vmname" | awk '/ipv4/ {print $4}' | cut -d'/' -f1)
  [[ -z "$ip" ]] && echo "❌ 无法获取 $vmname 的 IP 地址" && exit 1

  config="$HOME/.ssh/config"
  temp="$(mktemp)"
  if grep -q "^\s*Host\s\+$vmname\s*$" "$config" 2>/dev/null; then
    update_host_block "$vmname" "$user" "$ip" "$port" "$temp" "$temp"
  else
    {
      cat "$config" 2>/dev/null
      echo -e "\nHost $vmname"
      echo "  HostName $ip"
      echo "  User $user"
      echo "  Port $port"
    } >"$temp" && mv "$temp" "$config"
  fi

  echo "✅ SSH 配置已更新：$vmname -> $ip"

}


get_hostname_from_ssh_config() {
  local host="$1"
  awk -v host="$host" '
    $1 == "Host" && $2 == host { in_block = 1; next }
    in_block && $1 == "HostName" { print $2; exit }
    in_block && $1 == "Host" { in_block = 0 }
  ' ~/.ssh/config
}



if [ -f "$HOME/.zshrc.private" ];then
  source $HOME/.zshrc.private
fi
