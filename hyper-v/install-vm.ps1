# 需要以“管理员身份”运行 PowerShell 脚本！
# 该脚本用于在 Hyper-V 上创建一个 Ubuntu 虚拟机，使用 cloud-init 进行配置
# 需要安装以下工具：
# - qemu-img.exe：用于转换 Cloud Image 为 VHDX 格式
# - mkisofs.exe：用于生成 cloud-init ISO

# 配置项
# 从参数传入虚拟机名称，如果没有传入，则使用随机生成的名称
$vmName = $args[0]  
#vmName 可以设置为从参数传入，如果没有传入，使用随机生成的名字
if (-not $vmName) {
  $vmName = "ubuntu-" + (Get-Random -Minimum 1 -Maximum 1000)
}
$memory = 2GB
$cpuCount = 2
$vhdSizeGB = 20
$vmParentPath = "C:\HyperV"  # 虚拟机父目录
$vmStoragePath = "$vmParentPath\VMs"  # 虚拟机存储路径
$vmCachePath = "$vmParentPath\Cache"  # 虚拟机缓存路径
$vmPath = "$vmStoragePath\$vmName"
$vhdPath = "$vmPath\$vmName.vhdx"
$isoPath = "$vmPath\seed.iso"
$switchName = "Default Switch"  # 可用 Get-VMSwitch 查看

# 0. 检查 Hyper-V 是否启用，对应名称的虚拟机是否存在，虚拟机目录是否创
if (-not (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -ErrorAction SilentlyContinue).State -eq "Enabled") {
  Write-Error "Hyper-V 功能未启用，请先启用 Hyper-V。"
  exit 1
}

if (Get-VM -Name $vmName -ErrorAction SilentlyContinue) {
  Write-Error "虚拟机 '$vmName' 已存在，请先删除或更改名称。"
  exit 1
}

# 检查存放虚拟机的目录是否存在，如果存在，删除目录及内部的文件，但是要提醒用户二次确认
if (Test-Path $vmPath) {
  Write-Host "目录 '$vmPath' 已存在，是否删除并重新创建？(Y/N)"
  $confirmation = Read-Host
  if ($confirmation -eq 'Y' -or $confirmation -eq 'y') {
    Remove-Item -Path $vmPath -Recurse -Force
    New-Item -Path $vmPath -ItemType Directory -Force | Out-Null
    Write-Host "目录已删除并重新创建。"
  }
  else {
    Write-Error "操作已取消，脚本将退出。"
    exit 1
  }
}

# 检查并创建虚拟机目录，通过脚本创建的虚拟机都会存放在此目录下
Write-Host "检查并创建虚拟机目录: $vmPath"
if (!(Test-Path $vmPath)) {
  New-Item -Path $vmPath -ItemType Directory -Force | Out-Null
  Write-Host "目录已创建。"
}
else {
  Write-Host "目录已存在。"
}

# 1. 准备Cloud镜像
$cloudImageUrl = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img" 
$imageFileName = Split-Path -Path $cloudImageUrl -Leaf
$cloudImagePath = Join-Path -Path $vmCachePath -ChildPath $imageFileName

Write-Host "检查 Cloud Image: $cloudImagePath"
if (Test-Path $cloudImagePath) {
  Write-Host "Cloud image '$cloudImagePath' 已存在，跳过下载。"
}
else {
  Write-Host "下载 Ubuntu Cloud Image 从 '$cloudImageUrl' 到 '$cloudImagePath'..."
  try {
    Invoke-WebRequest -Uri $cloudImageUrl -OutFile $cloudImagePath -ErrorAction Stop
    Write-Host "镜像下载完成。"
  }
  catch {
    Write-Error "下载镜像失败: $($_.Exception.Message)"
    Write-Error "请检查网络连接、URL是否有效以及目标路径 '$vmPath' 是否有写入权限。"
    exit 1 
  }
}
# 2. 转换 Cloud Image 为 VHDX 格式，使用 qemu-img 工具，需要预先下载
Write-Host "转换 IMG '$cloudImagePath' -> VHDX '$vhdPath'..."
try {
  qemu-img.exe convert -f qcow2 -O vhdx $cloudImagePath $vhdPath 
  Write-Host "VHDX 转换完成。"
}
catch {
  Write-Error "VHDX 转换失败: $($_.Exception.Message)"
  exit 1
}

Write-Host "调整 VHDX '$vhdPath' 的大小为 $($vhdSizeGB)GB (using Resize-VHD)..."
try {
  # Resize-VHD cmdlet 需要以字节为单位的大小，但它能智能处理 "20GB" 这样的字符串
  Resize-VHD -Path $vhdPath -SizeBytes "$($vhdSizeGB)GB" -ErrorAction Stop
  Write-Host "VHDX 大小调整完成 (using Resize-VHD)。"
}
catch {
  Write-Error "VHDX 大小调整失败 (using Resize-VHD): $($_.Exception.Message)"
  throw "无法继续，VHDX 大小调整失败 (Resize-VHD)。"
}


# 3. 创建 cloud-init 配置文件
$userData = @"
#cloud-config
hostname: $vmName
timezone: Asia/Shanghai
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    plain_text_passwd: "ubuntu"
ssh_pwauth: true
runcmd:
  - echo 'Hello from cloud-init!' > /home/ubuntu/hello.txt
  - sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="console=ttyS0,115200n8 console=tty0 /' /etc/default/grub
  - update-grub
  - apt-get update
  - apt-get install -y linux-tools-`$(uname -r) linux-cloud-tools-`$(uname -r)
  - systemctl enable hv-kvp-daemon.service
  - systemctl start hv-kvp-daemon.service
  - systemctl enable serial-getty@ttyS0.service
  - systemctl start serial-getty@ttyS0.service
"@

$metaData = @"
instance-id: $vmName
local-hostname: $vmName
"@

Write-Host "写入 cloud-init 配置..."
Set-Content -Path (Join-Path -Path $vmPath -ChildPath "user-data") -Value $userData -Encoding UTF8
Set-Content -Path (Join-Path -Path $vmPath -ChildPath "meta-data") -Value $metaData -Encoding UTF8

# 4. 生成 cloud-init ISO ，使用 mkisofs 工具，需要预先下载
Write-Host "生成 cloud-init ISO '$isoPath'..."
Push-Location $vmPath
try {
  Write-Host "当前工作目录: $(Get-Location)"
  Write-Host "尝试创建 ISO: $isoPath 使用文件: user-data, meta-data"
  # 运行命令之前要切换工作目录，因为 mkisofs.exe 需要在当前目录下找到 user-data 和 meta-data 文件
  # 如果不是当前目录，生成的ISO中文件会被重命名（太坑了这个），这个会导致 cloud-init 无法正确读取配置（文件名必须是 user-data 和 meta-data）
  mkisofs.exe -o $isoPath -V cidata -J -R "user-data" "meta-data"
  Write-Host "cloud-init ISO 生成完成。"
}
catch {
  Write-Error "cloud-init ISO 生成失败: $($_.Exception.Message)"
  Write-Error "请确保 mkisofs.exe 已正确安装并配置在系统 PATH 中，或者已在脚本中指定其完整路径。"
  exit 1
}
finally {
  Pop-Location
}

if (!(Test-Path $isoPath)) {
  Write-Warning "seed.iso 在预期位置 '$isoPath' 未找到。请检查 mkisofs.exe 的输出。"
  exit
}


# 5. 创建 VM
Write-Host "创建 Hyper-V 虚拟机..."
New-VM -Name $vmName -MemoryStartupBytes $memory -Generation 2 -VHDPath $vhdPath -SwitchName $switchName | Out-Null
Set-VMProcessor -VMName $vmName -Count $cpuCount

# 关闭 security boot，不然虚拟机会启动不了
Set-VMFirmware -VMName $vmName -EnableSecureBoot Off

# 添加 cloud-init ISO
Add-VMDvdDrive -VMName $vmName -Path $isoPath

# 设置启动顺序（确保从 VHD 启动）
Set-VMFirmware -VMName $vmName -FirstBootDevice (Get-VMHardDiskDrive -VMName $vmName)


Start-VM -Name $vmName

Write-Host "虚拟机已创建并启动，请使用 Hyper-V 管理器连接控制台或通过 SSH 登录。"
# 查看虚拟机的ip地址
# 第一次启动的时候，不能使用 Get-VMNetworkAdapter 获取 IP 地址，获取到地址之后，也不可以，重新启动之后，才能获取到 IP 地址
Write-Host "或者虚拟机重启后可以通过以下命令查看其 IP 地址："
Write-Host "Get-VMNetworkAdapter -VMName $vmName | Select-Object -ExpandProperty IPAddresses"
