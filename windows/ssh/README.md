# Windows OpenSSH

## 将默认 shell 设置为 PowerShell 7

目标：通过 `ssh windows-11` 登录 Windows 11 时，默认进入 PowerShell 7，而不是 `cmd.exe` 或 Windows PowerShell 5.1。

前提：

- Windows 11 已启用 OpenSSH Server。
- 当前 SSH 登录用户具备管理员权限，因为需要写入 `HKLM:\SOFTWARE\OpenSSH`。
- PowerShell 7 已安装。本次确认路径为：

```text
C:\Program Files\PowerShell\7\pwsh.exe
```

### 配置步骤

在本机执行：

```sh
ssh windows-11 where pwsh
```

确认输出包含：

```text
C:\Program Files\PowerShell\7\pwsh.exe
```

写入 OpenSSH 默认 shell 配置：

```sh
ssh windows-11 'reg add "HKLM\SOFTWARE\OpenSSH" /v DefaultShell /t REG_SZ /d "C:\Program Files\PowerShell\7\pwsh.exe" /f'
```

该命令会设置如下注册表值：

```text
HKLM\SOFTWARE\OpenSSH\DefaultShell = C:\Program Files\PowerShell\7\pwsh.exe
```

### 验证

开启一个新的 SSH 会话，直接执行 PowerShell 表达式：

```sh
ssh windows-11 '$PSVersionTable.PSVersion.ToString(); $PSVersionTable.PSEdition; $PSHOME; (Get-ItemProperty -Path HKLM:\SOFTWARE\OpenSSH -Name DefaultShell).DefaultShell'
```

本次验证结果：

```text
7.6.2
Core
c:\program files\powershell\7
C:\Program Files\PowerShell\7\pwsh.exe
```

也可以用布尔检查确认主版本号大于等于 7：

```sh
ssh windows-11 '$PSVersionTable.PSVersion.Major -ge 7'
```

本次验证结果：

```text
True
```

### 回滚

如果需要恢复 OpenSSH 默认行为，可以删除该注册表值：

```sh
ssh windows-11 'reg delete "HKLM\SOFTWARE\OpenSSH" /v DefaultShell /f'
```

如需显式改回 Windows PowerShell 5.1：

```sh
ssh windows-11 'reg add "HKLM\SOFTWARE\OpenSSH" /v DefaultShell /t REG_SZ /d "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" /f'
```

## 已知问题

配置完成后，新 SSH 会话已经默认进入 PowerShell 7。本次验证时发现 PowerShell profile 中的 `starship init powershell` 在 SSH 非交互命令下会报错：

```text
Invoke-Expression: ... Microsoft.PowerShell_profile.ps1:149
Cannot bind argument to parameter 'Command' because it is null.
```

这不影响默认 shell 切换结果，但会污染非交互 SSH 命令输出。后续可以在 PowerShell profile 中为 SSH 非交互场景增加保护条件，避免初始化 starship。
