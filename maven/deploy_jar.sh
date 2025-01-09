#!/bin/bash

REPOSITORY_ID=""
REPOSITORY_URL=""

# 清屏
clear

echo "----------------------------------------------------"
echo "     Maven JAR 包部署脚本 - 提示输入版本      "
echo "----------------------------------------------------"

# 提示用户输入 GroupId
read -p "请输入 GroupId (例如 com.example): " GROUP_ID

# 提示用户输入 ArtifactId
read -p "请输入 ArtifactId (例如 my-library): " ARTIFACT_ID

# 提示用户输入 Version
read -p "请输入 Version (例如 1.0.0): " VERSION

# 提示用户输入 JAR 文件路径
read -p "请输入 JAR 文件路径: " FILE_PATH

# 提示用户输入 Repository ID
if [ -z "$REPOSITORY_ID" ]; then
  read -p "请输入 Repository ID (settings.xml 中配置的 ID): " REPOSITORY_ID
fi

# 提示用户输入 Repository URL
if [ -z "$REPOSITORY_URL" ]; then
  read -p "请输入 Repository URL: " REPOSITORY_URL
fi

# 检查 JAR 文件是否存在
if [ ! -f "$FILE_PATH" ]; then
  echo "错误: JAR 文件不存在: $FILE_PATH"
  exit 1
fi

# 确认信息
echo "----------------------------------------------------"
echo "请确认以下信息:"
echo "GroupId: $GROUP_ID"
echo "ArtifactId: $ARTIFACT_ID"
echo "Version: $VERSION"
echo "JAR 文件路径: $FILE_PATH"
echo "Repository ID: $REPOSITORY_ID"
echo "Repository URL: $REPOSITORY_URL"
echo "----------------------------------------------------"

# 提示用户确认是否继续
read -p "确认无误并继续部署吗? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ]; then
  echo "部署已取消。"
  exit 1
fi


# 执行 Maven 部署命令
mvn -X deploy:deploy-file \
  -DgroupId="$GROUP_ID" \
  -DartifactId="$ARTIFACT_ID" \
  -Dversion="$VERSION" \
  -Dpackaging=jar \
  -Dfile="$FILE_PATH" \
  -DrepositoryId="$REPOSITORY_ID" \
  -Durl="$REPOSITORY_URL"

# 检查部署结果
if [ $? -eq 0 ]; then
  echo "----------------------------------------------------"
  echo "JAR 包部署成功!"
  echo "----------------------------------------------------"
else
  echo "----------------------------------------------------"
  echo "JAR 包部署失败!"
  echo "----------------------------------------------------"
fi
