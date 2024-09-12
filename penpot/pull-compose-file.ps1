# 定义下载URL和目标文件路径
$url = "https://raw.githubusercontent.com/penpot/penpot/main/docker/images/docker-compose.yaml"
$outputFile = "docker-compose.yaml"

if (Get-Command wget -ErrorAction SilentlyContinue) {
    wget $url -OutFile $outputFile --no-check-certificate
    Write-Host "使用 wget 下载文件成功！"
} 
elseif (Get-Command curl -ErrorAction SilentlyContinue) {
    curl $url -o $outputFile
    Write-Host "使用 curl 下载文件成功！"
} 
else {
    try {
        Invoke-WebRequest -Uri $url -OutFile $outputFile
        Write-Host "使用 Invoke-WebRequest 下载文件成功！"
    } catch {
        Write-Host "下载文件失败：" $_.Exception.Message
    }
}

