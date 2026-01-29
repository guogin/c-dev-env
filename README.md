# 操作指南

我们假设你在宿主机上有C/C++的源代码，也有VSCode。你的宿主机不是Linux系统。你希望有一个Linux环境让你编译、调试这份项目源代码，又不希望在宿主机上装太多软件。

## 项目初始化设置（只需做一次）

### 1.1 安装VSCode扩展

```bash
# 安装必需的扩展
code --install-extension ms-vscode-remote.remote-containers
code --install-extension ms-vscode.cpptools
code --install-extension ms-vscode.cmake-tools
```

### 1.2 克隆此仓库

```bash
git clone https://github.com/guogin/c-dev-env.git ~/c-dev-template
```

### 1.3 新项目设置流程

假设你有一个 C 项目：

```bash
# 你的项目目录结构
your-project/
├── include/
│   └── utils.h
├── src/
│   ├── main.c
│   └── utils.c
└── CMakeLists.txt
```

**步骤 1：复制模板文件到项目根目录**

```bash
cd ~/c-dev-template

# 复制模板文件
cp Dockerfile /path/to/your-project
cp docker-compose.yml /path/to/your-project
cp c-dev-env.sh /path/to/your-project

# 进入你的项目目录
cd /path/to/your-project

# 添加执行权限
chmod +x c-dev-env.sh
```

现在目录结构应该是：

```bash
your-project/
├── Dockerfile
├── docker-compose.yml
├── c-dev-env.sh
├── include/
│   └── utils.h
├── src/
│   ├── main.c
│   └── utils.c
└── CMakeLists.txt
```

**步骤 2：构建 Docker 镜像**

```bash
# 在项目根目录下执行
./c-dev-env.sh build

# 输出示例：
# [INFO] Building C development environment...
# Step 1/11 : FROM ubuntu:24.04
# ...
# [SUCCESS] Build completed!
# [INFO] Image can be used by both CLI and VSCode containers
```

**步骤 3：创建 VSCode 配置**

```bash
# 在项目根目录下执行
./c-dev-env.sh setup-vscode

# 输出示例：
# [INFO] Setting up VSCode Dev Container configuration...
# [SUCCESS] VSCode Dev Container configuration created!
#
# Configuration files created:
#   - /path/to/your-project/.devcontainer/devcontainer.json
#   - /path/to/your-project/.vscode/launch.json
#   - /path/to/your-project/.vscode/tasks.json
#   - /path/to/your-project/.vscode/c_cpp_properties.json
#   - /path/to/your-project/.gitignore
```

现在完整的目录结构：

```bash
your-project/
├── Dockerfile
├── docker-compose.yml
├── c-dev-env.sh
├── .gitignore                    # 新创建
├── .devcontainer/                # 新创建
│   └── devcontainer.json
├── .vscode/                      # 新创建
│   ├── launch.json
│   ├── tasks.json
│   └── c_cpp_properties.json
├── include/
│   └── utils.h
├── src/
│   ├── main.c
│   └── utils.c
└── CMakeLists.txt
```

**步骤 4：验证设置**

```bash
# 检查容器状态
./c-dev-env.sh status

# 输出示例：
# [INFO] Container status:
#
# === CLI Container (c-dev-env) ===
# [WARN] CLI container is not running
# [INFO] Container does not exist. Use './c-dev-env.sh build' to create it.
#
# === VSCode Dev Containers ===
# [INFO] No VSCode containers running
# [INFO] Open VSCode and select 'Reopen in Container' to start one
```

---

## 二、通过 CLI 编译和调试

### 2.1 启动 CLI 容器

```bash
# 在项目根目录下执行
./c-dev-env.sh start

# 输出：
# [INFO] Starting CLI development container...
# Waiting for container to start.
# [SUCCESS] CLI container started successfully!
# [INFO] Container name: c-dev-env
# [INFO] Project directory: /path/to/your-project -> /workspace
# [INFO] VSCode container (if running) is independent and unaffected
```

### 2.2 使用脚本命令编译

```bash
# 在项目根目录下执行
./c-dev-env.sh build-project

# 输出：
# [INFO] Building project in CLI container...
#
# ==> Detected CMake project
# ==> Configuring with Ninja...
# -- The C compiler identification is GNU 13.2.0
# -- Configuring done
# -- Generating done
# -- Build files have been written to: /workspace/build
# ==> Building with Ninja...
# [1/3] Building C object CMakeFiles/myapp.dir/src/utils.c.o
# [2/3] Building C object CMakeFiles/myapp.dir/src/main.c.o
# [3/3] Linking C executable myapp
# ==> Build output:
# -rwxr-xr-x 1 root root 16K ... myapp
#
# [SUCCESS] Build completed!
```

### 2.3 进入容器手动编译

```bash
# 在项目根目录下执行
./c-dev-env.sh shell

# 现在你在容器内：
# root@c-dev:/workspace#

# 查看文件结构
ls -la
# total 28
# drwxr-xr-x  6 root root  192 Dec 10 10:00 .
# drwxr-xr-x  1 root root   42 Dec 10 09:50 ..
# -rw-r--r--  1 root root 1234 Dec 10 10:00 Dockerfile
# -rw-r--r--  1 root root  987 Dec 10 10:00 docker-compose.yml
# -rwxr-xr-x  1 root root 5678 Dec 10 10:00 c-dev-env.sh
# drwxr-xr-x  2 root root   64 Dec 10 10:00 include
# drwxr-xr-x  2 root root   96 Dec 10 10:00 src
# -rw-r--r--  1 root root  219 Dec 10 10:00 CMakeLists.txt

# 手动编译
mkdir -p build
cd build
cmake -GNinja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ..
ninja

# 运行程序
./myapp
# 输出：
# Test Application
# argc = 1
# 10 + 32 = 42
# Array: [1, 2, 3, 4, 5]
# x = 42

# 退出容器
exit
```

### 2.4 从宿主机运行程序

```bash
# 在项目根目录下执行
./c-dev-env.sh run build/myapp

# 输出：
# [INFO] Running build/myapp in CLI container...
#
# Test Application
# argc = 1
# 10 + 32 = 42
# Array: [1, 2, 3, 4, 5]
# x = 42

# 带参数运行
./c-dev-env.sh run build/myapp arg1 arg2
```

### 2.5 使用 GDB 调试

```bash
# 进入容器
./c-dev-env.sh shell

# 进入 build 目录
cd /workspace/build

# 启动 GDB
gdb ./myapp

# GDB 会话：
(gdb) break main.c:14          # 在第 14 行设置断点
Breakpoint 1 at 0x1234: file /workspace/src/main.c, line 14.

(gdb) run                      # 运行程序
Starting program: /workspace/build/myapp
Test Application
argc = 1
10 + 32 = 42
Array: [1, 2, 3, 4, 5]

Breakpoint 1, main (argc=1, argv=0x7fffffffe1a8) at /workspace/src/main.c:14
14          int x = 42;

(gdb) print result             # 查看变量
$1 = 42

(gdb) next                     # 单步执行
15          printf("x = %d\n", x);

(gdb) print x
$2 = 42

(gdb) continue                 # 继续执行
Continuing.
x = 42
[Inferior 1 (process 123) exited normally]

(gdb) quit                     # 退出 GDB
exit                           # 退出容器
```

### 2.6 停止 CLI 容器

```bash
# 在项目根目录下执行
./c-dev-env.sh stop

# 输出：
# [INFO] Stopping CLI development container...
# [SUCCESS] CLI container stopped!
# [INFO] VSCode container (if running) is unaffected
```

---

## 三、通过 VSCode 编译和调试

### 3.1 打开项目

```bash
# 方法 1：在项目根目录下执行
cd /path/to/your-project
code .

# 方法 2：在 VSCode 中
# File -> Open Folder -> 选择项目根目录
```

### 3.2 在容器中重新打开

VSCode 打开后，会在右下角显示通知：

```
Folder contains a Dev Container configuration file.
[Reopen in Container]  [Clone Repository in Container Volume...]
```

**点击 "Reopen in Container"**

或者手动操作：
1. 按 `F1` 或 `Ctrl+Shift+P`
2. 输入：`Dev Containers: Reopen in Container`
3. 按 Enter

### 3.3 等待容器初始化

首次打开会比较慢（1-3分钟），VSCode 需要：
- 创建新容器
- 安装 VSCode Server
- 安装 C/C++ 扩展

你会看到进度提示：
```
Starting Dev Container (show log)
Creating container...
Starting container...
Configuring container...
Installing extensions...
```

初始化完成后，终端会显示：
```
=== Dev Container Ready ===
gcc (Ubuntu 13.2.0-23ubuntu4) 13.2.0
cmake version 3.28.3
GNU gdb (Ubuntu 15.0.50.20240403-0ubuntu1) 15.0.50.20240403-git
```

### 3.4 验证环境

在 VSCode 的集成终端中（`` Ctrl+` ``）：

```bash
# 检查当前位置（应该在容器内的 /workspace）
pwd
# /workspace

# 查看文件结构
ls -la
# total 28
# drwxr-xr-x  6 root root  192 Dec 10 10:00 .
# drwxr-xr-x  1 root root   42 Dec 10 09:50 ..
# -rw-r--r--  1 root root 1234 Dec 10 10:00 Dockerfile
# -rw-r--r--  1 root root  987 Dec 10 10:00 docker-compose.yml
# -rwxr-xr-x  1 root root 5678 Dec 10 10:00 c-dev-env.sh
# drwxr-xr-x  2 root root   64 Dec 10 10:00 .devcontainer
# drwxr-xr-x  2 root root   96 Dec 10 10:00 .vscode
# drwxr-xr-x  2 root root   64 Dec 10 10:00 include
# drwxr-xr-x  2 root root   96 Dec 10 10:00 src
# -rw-r--r--  1 root root  219 Dec 10 10:00 CMakeLists.txt

# 检查工具链
gcc --version
cmake --version
gdb --version
```

### 3.5 编译项目

#### 方法 A：使用 VSCode 任务（推荐）

1. 按 `Ctrl+Shift+B`（或 `Cmd+Shift+B` on Mac）
2. 选择 `build` 任务
3. 查看终端输出：

```
> Executing task: mkdir -p build && cd build && cmake -GNinja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON .. && ninja -j$(nproc) <

-- The C compiler identification is GNU 13.2.0
-- Configuring done
-- Generating done
-- Build files have been written to: /workspace/build
[1/3] Building C object CMakeFiles/myapp.dir/src/utils.c.o
[2/3] Building C object CMakeFiles/myapp.dir/src/main.c.o
[3/3] Linking C executable myapp

Terminal will be reused by tasks, press any key to close it.
```

#### 方法 B：使用集成终端

```bash
mkdir -p build
cd build
cmake -GNinja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ..
ninja
```

### 3.6 调试项目

#### 3.6.1 设置断点

1. 打开 `src/main.c`
2. 在第 14 行（`int x = 42;`）左侧点击，设置红色断点

#### 3.6.2 启动调试

1. 按 `F5` 开始调试
2. 如果提示选择配置，选择 `(gdb) Launch`

#### 3.6.3 调试界面

程序会停在断点处，你会看到：

**变量面板**（左侧）：
```
VARIABLES
  Local
    ▼ argc: 1
    ▼ argv: 0x7fffffffe1a8
    ▼ result: 42
    ▼ arr: int[5]
      [0]: 1
      [1]: 2
      [2]: 3
      [3]: 4
      [4]: 5
    ▶ x: <未初始化>
```

**调试控制**（顶部）：
- `F5`: 继续
- `F10`: 单步跳过
- `F11`: 单步进入
- `Shift+F11`: 单步跳出

#### 3.6.4 调试操作

1. 按 `F10` 执行 `int x = 42;`
2. 观察变量面板，`x` 的值变为 `42`
3. 按 `F10` 执行 `printf` 语句
4. 调试控制台输出：`x = 42`
5. 按 `F5` 继续执行到结束

### 3.7 运行程序（不调试）

在 VSCode 集成终端中：

```bash
./build/myapp

# 输出：
# Test Application
# argc = 1
# 10 + 32 = 42
# Array: [1, 2, 3, 4, 5]
# x = 42
```

### 3.8 关闭容器

关闭 VSCode 窗口，容器会自动停止。

或者手动：
1. `F1` -> `Dev Containers: Reopen Folder Locally`
2. VSCode 回到宿主机，容器停止

---

## 四、CLI 和 VSCode 混合使用

### 4.1 同时运行两个容器

```bash
# 终端：在项目根目录下启动 CLI 容器
./c-dev-env.sh start
./c-dev-env.sh shell

# VSCode：在项目根目录下打开
code .
# 点击 "Reopen in Container"

# 现在有两个容器同时运行
```

### 4.2 查看所有容器状态

```bash
# 在项目根目录下执行
./c-dev-env.sh status

# 输出：
# [INFO] Container status:
#
# === CLI Container (c-dev-env) ===
# NAMES         STATUS          PORTS
# c-dev-env     Up 5 minutes    0.0.0.0:1234->1234/tcp
#
# [SUCCESS] CLI container is running ✓
#
# === VSCode Dev Containers ===
# NAMES                              STATUS          PORTS
# vsc-your-project-abc123            Up 2 minutes    ...
#
# [SUCCESS] VSCode container(s) detected ✓
```

---

## 五、多项目管理

### 5.1 为多个项目设置环境

```bash
# 项目 A
cd ~/projects/project-a
find ~/c-dev-template -maxdepth 1 -type f -exec cp {} . \;
chmod +x c-dev-env.sh
./c-dev-env.sh build
./c-dev-env.sh setup-vscode

# 项目 B
cd ~/projects/project-b
find ~/c-dev-template -maxdepth 1 -type f -exec cp {} . \;
chmod +x c-dev-env.sh
./c-dev-env.sh build
./c-dev-env.sh setup-vscode

# 每个项目独立管理，互不干扰
```

### 5.2 项目切换

```bash
# 切换到项目 A
cd ~/projects/project-a
./c-dev-env.sh start
code .

# 切换到项目 B（项目 A 的容器继续运行）
cd ~/projects/project-b
./c-dev-env.sh start
code .
```

---

## 六、常见问题和技巧

### 6.1 更新模板文件

如果需要更新某个项目的 Docker 配置：

```bash
# 备份当前配置
cd /path/to/your-project
cp Dockerfile Dockerfile.bak
cp docker-compose.yml docker-compose.yml.bak

# 从模板复制新版本
cp ~/c-dev-template/Dockerfile .
cp ~/c-dev-template/docker-compose.yml .

# 重新构建
./c-dev-env.sh clean
./c-dev-env.sh build
```

### 6.2 清理构建产物

```bash
# 方法 1：使用脚本
./c-dev-env.sh exec "rm -rf /workspace/build"

# 方法 2：在 VSCode 中
# Ctrl+Shift+P -> Tasks: Run Task -> clean

# 方法 3：直接删除
rm -rf ./build
```

### 6.3 添加 .gitignore

生成的 `.gitignore` 已包含常见忽略项：

```gitignore
# Build directory
build/
.ccache/

# VSCode
.vscode/
.devcontainer/

# IDE
.idea/
*.swp
*.swo
*~

# Compiled files
*.o
*.a
*.so
*.exe

# Debug files
*.dSYM/
*.su
*.idb
*.pdb

# OS files
.DS_Store
Thumbs.db
```

如果需要版本控制 Docker 配置，可以选择性添加：

```gitignore
# 不忽略 Docker 配置文件
!Dockerfile
!docker-compose.yml
!c-dev-env.sh
```

---

## 七、完整工作流程示例

### 7.1 全新项目开发流程

```bash
# Day 0: 创建项目
mkdir my-awesome-project
cd my-awesome-project

# 创建源代码目录
mkdir -p include src
touch include/utils.h src/main.c src/utils.c CMakeLists.txt

# Day 1: 设置开发环境
find ~/c-dev-template -maxdepth 1 -type f -exec cp {} . \;
chmod +x c-dev-env.sh
./c-dev-env.sh build
./c-dev-env.sh setup-vscode

# Day 2: 开始开发
code .
# 点击 "Reopen in Container"
# 编写代码、编译、调试

# Day 3-N: 日常开发
# 1. 打开 VSCode：code .
# 2. 点击 "Reopen in Container"
# 3. 编写代码
# 4. Ctrl+Shift+B 编译
# 5. F5 调试
# 6. 关闭 VSCode
```

### 7.2 现有项目添加容器环境

```bash
# 已有项目
cd /path/to/existing-project

# 添加 Docker 环境
find ~/c-dev-template -maxdepth 1 -type f -exec cp {} . \;
chmod +x c-dev-env.sh

# 构建和配置
./c-dev-env.sh build
./c-dev-env.sh setup-vscode

# 继续开发
code .
```

---

## 八、总结

### 8.1 核心概念

1. **项目即环境**：每个项目目录包含完整的 Docker 配置
2. **双容器架构**：CLI 容器和 VSCode 容器独立运行
3. **共享代码**：两个容器挂载同一个项目目录
4. **便携性**：整套配置可以复制到任何项目

### 8.2 快速参考

```bash
# 初始化
find ~/c-dev-template -maxdepth 1 -type f -exec cp {} . \;
chmod +x c-dev-env.sh
./c-dev-env.sh build
./c-dev-env.sh setup-vscode

# 日常操作
./c-dev-env.sh start          # 启动 CLI 容器
./c-dev-env.sh shell          # 进入容器
./c-dev-env.sh build-project  # 编译
./c-dev-env.sh stop           # 停止容器

# VSCode
code .                        # 打开项目
# 点击 "Reopen in Container"
# F5 调试，Ctrl+Shift+B 编译
```
