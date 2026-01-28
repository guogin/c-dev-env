# 说明

我们假设你在宿主机上有C/C++的源代码，也有VSCode。你的宿主机不是Linux系统。你希望有一个Linux环境让你编译、调试这份项目源代码，又不希望在宿主机上装太多软件。

## VSCode配置

### 安装VSCode扩展

```bash
# 安装必需的扩展
code --install-extension ms-vscode-remote.remote-containers
code --install-extension ms-vscode.cpptools
code --install-extension ms-vscode.cmake-tools
```

## 完整使用流程

### 初始设置

```bash
# 1. 找到项目目录
# 假设你宿主机上的项目根目录是 ~/my-project

# 2. 放置Dockerfile, docker-compose.yml, c-dev-env.sh
# （将上面的文件保存到项目根目录）

# 3. 构建镜像
./c-dev-env.sh build

# 4. 启动容器
./c-dev-env.sh start

# 5. 生成 VSCode 配置
./c-dev-env.sh setup-vscode

# 6. 用VSCode打开项目
code ~/my-project

# 7. 在 VSCode 中，会提示：
#    "Folder contains a Dev Container configuration file"
#    点击 "Reopen in Container"
#    
#    或者按 F1 -> "Dev Containers: Reopen in Container"
```

### 日常开发

```bash
# 早上启动容器
./c-dev-env.sh start

# 打开VSCode（在容器中）
code ~/my-project
# 点击 "Reopen in Container"

# 在VSCode中：
# - 编写代码
# - Ctrl+Shift+B 编译
# - F5 调试
# - F9 设置断点
# - F10/F11 单步调试
# - 终端自动在容器内

# 如果需要直接访问容器
./c-dev-env.sh shell

# 查看状态
./c-dev-env.sh status

# 晚上关闭
./c-dev-env.sh stop
```

## 验证配置

### 创建一个完整的测试项目

```bash
# 在宿主机上创建项目代码
cp -r ./sample_project ~/my-project
```

### 测试编译和调试

```bash
# 1. 启动容器
./c-dev-env.sh start

# 2. 编译项目
./c-dev-env.sh build-project

# 3. 在容器内运行
./c-dev-env.sh exec "/workspace/build/myapp arg1 arg2"

# 4. 在容器内调试
./c-dev-env.sh shell
# 然后：
cd /workspace/build
gdb ./myapp
(gdb) break main
(gdb) run
(gdb) next
(gdb) print result
(gdb) continue
(gdb) quit

# 5. 或者在VSCode中调试
code ~/my-project
# F5 开始调试
```
