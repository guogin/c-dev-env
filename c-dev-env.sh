#!/usr/bin/env bash
# c-dev-env.sh - C语言开发环境容器管理脚本
# 可以在任意 C 项目目录中使用

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="c-dev-env"
PROJECT_DIR="${SCRIPT_DIR}"  # 项目目录就是脚本所在目录

# 颜色定义（使用 ANSI 转义序列）
if [ -t 1 ]; then
    RED=$(printf '\033[0;31m')
    GREEN=$(printf '\033[0;32m')
    YELLOW=$(printf '\033[1;33m')
    BLUE=$(printf '\033[0;34m')
    CYAN=$(printf '\033[0;36m')
    MAGENTA=$(printf '\033[0;35m')
    NC=$(printf '\033[0m')
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    MAGENTA=''
    NC=''
fi

# 打印带颜色的消息
info() {
    printf '%s[INFO]%s %s\n' "$BLUE" "$NC" "$1"
}

success() {
    printf '%s[SUCCESS]%s %s\n' "$GREEN" "$NC" "$1"
}

warn() {
    printf '%s[WARN]%s %s\n' "$YELLOW" "$NC" "$1"
}

error() {
    printf '%s[ERROR]%s %s\n' "$RED" "$NC" "$1" >&2
}

# 检查podman是否安装
check_podman() {
    if ! command -v podman &> /dev/null; then
        error "podman is not installed"
        exit 1
    fi
    
    if ! command -v podman-compose &> /dev/null; then
        warn "podman-compose not found. Attempting to install..."
        if command -v pip3 &> /dev/null; then
            pip3 install --user podman-compose
        elif command -v pip &> /dev/null; then
            pip install --user podman-compose
        else
            error "Cannot install podman-compose. Please install pip3 or pip first."
            exit 1
        fi
    fi
}

# 检查必需文件是否存在
check_required_files() {
    local missing_files=()
    
    if [ ! -f "$SCRIPT_DIR/Dockerfile" ]; then
        missing_files+=("Dockerfile")
    fi
    
    if [ ! -f "$SCRIPT_DIR/docker-compose.yml" ]; then
        missing_files+=("docker-compose.yml")
    fi
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        error "Missing required files in project directory:"
        for file in "${missing_files[@]}"; do
            printf "  - %s\n" "$file"
        done
        printf "\n"
        info "Please ensure Dockerfile and docker-compose.yml are in the project directory."
        exit 1
    fi
}

# 构建镜像
build() {
    info "Building C development environment..."
    check_required_files
    cd "$SCRIPT_DIR"
    
    podman-compose build
    local result=$?
    
    if [ $result -eq 0 ]; then
        success "Build completed!"
        info "Image can be used by both CLI and VSCode containers"
        return 0
    else
        error "Build failed"
        return 1
    fi
}

# 启动容器
start() {
    info "Starting CLI development container..."
    check_required_files
    cd "$SCRIPT_DIR"
    
    # 检查容器是否已经在运行
    if podman ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        warn "CLI container is already running"
        return 0
    fi
    
    podman-compose up -d
    local result=$?
    
    if [ $result -ne 0 ]; then
        error "Failed to start container"
        return 1
    fi
    
    # 等待容器启动
    printf "Waiting for container to start"
    for i in {1..10}; do
        if podman ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            printf "\n"
            success "CLI container started successfully!"
            info "Container name: $CONTAINER_NAME"
            info "Project directory: $PROJECT_DIR -> /workspace"
            info "VSCode container (if running) is independent and unaffected"
            return 0
        fi
        printf "."
        sleep 1
    done
    
    printf "\n"
    error "Container failed to start in time"
    return 1
}

# 停止容器
stop() {
    info "Stopping CLI development container..."
    cd "$SCRIPT_DIR"
    
    if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        warn "CLI container is not running"
        return 0
    fi
    
    podman-compose down
    local result=$?
    
    if [ $result -eq 0 ]; then
        success "CLI container stopped!"
        info "VSCode container (if running) is unaffected"
        return 0
    else
        error "Failed to stop container"
        return 1
    fi
}

# 重启容器
restart() {
    info "Restarting CLI container..."
    stop
    sleep 2
    start
}

# 进入容器shell
shell() {
    if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        error "CLI container is not running. Starting..."
        start
        local result=$?
        if [ $result -ne 0 ]; then
            return 1
        fi
    fi
    
    info "Entering CLI container shell..."
    info "Type 'exit' to return to host"
    printf "\n"
    
    podman exec -it "$CONTAINER_NAME" /bin/bash
}

# 在容器中执行命令
exec_cmd() {
    if [ $# -eq 0 ]; then
        error "Usage: $0 exec <command>"
        printf "\nExample:\n"
        printf "  %s exec 'gcc --version'\n" "$0"
        printf "  %s exec 'ls -la /workspace'\n" "$0"
        return 1
    fi
    
    if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        error "CLI container is not running"
        return 1
    fi
    
    podman exec -it "$CONTAINER_NAME" bash -c "$*"
}

# 查看容器状态
status() {
    info "Container status:"
    printf "\n"
    
    # CLI 容器状态
    printf "${CYAN}=== CLI Container (c-dev-env) ===${NC}\n"
    if podman ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        podman ps --filter "name=${CONTAINER_NAME}" \
            --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        printf "\n"
        success "CLI container is running ✓"
        
        printf "\n"
        info "Resource usage:"
        podman stats --no-stream "$CONTAINER_NAME" 2>/dev/null || warn "Could not retrieve resource usage"
    else
        warn "CLI container is not running"
        if podman ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            info "Container exists but is stopped. Use '$0 start' to start it."
        else
            info "Container does not exist. Use '$0 build' to create it."
        fi
    fi
    
    printf "\n"
    
    # VSCode 容器状态
    printf "${CYAN}=== VSCode Dev Containers ===${NC}\n"
    local vscode_containers=$(podman ps --format '{{.Names}}' | grep -i 'vsc\|devcontainer' || true)
    if [ -n "$vscode_containers" ]; then
        podman ps --filter "name=vsc" --filter "name=devcontainer" \
            --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || true
        printf "\n"
        success "VSCode container(s) detected ✓"
    else
        info "No VSCode containers running"
        info "Open VSCode and select 'Reopen in Container' to start one"
    fi
}

# 查看日志
logs() {
    if ! podman ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        error "CLI container does not exist"
        return 1
    fi
    
    info "CLI container logs:"
    printf "\n"
    
    shift  # 移除 'logs' 参数
    if [ $# -eq 0 ]; then
        podman logs --tail 50 "$CONTAINER_NAME"
    else
        podman logs "$@" "$CONTAINER_NAME"
    fi
}

# 清理（删除容器和卷）
clean() {
    printf "\n"
    warn "╔════════════════════════════════════════════════════════╗"
    warn "║  WARNING: This will remove:                           ║"
    warn "║  - CLI container (c-dev-env)                          ║"
    warn "║  - Build caches (ccache, cmake cache)                 ║"
    warn "║                                                        ║"
    warn "║  Your source code will NOT be affected.               ║"
    warn "║  VSCode containers are managed separately.            ║"
    warn "╚════════════════════════════════════════════════════════╝"
    printf "\n"
    
    printf "Are you sure you want to continue? (yes/no): "
    read -r confirm
    
    if [ "$confirm" = "yes" ] || [ "$confirm" = "y" ]; then
        info "Cleaning up..."
        cd "$SCRIPT_DIR"
        
        podman-compose down -v
        local result=$?
        
        if [ $result -eq 0 ]; then
            success "Cleanup completed!"
            info "You can rebuild with: $0 build"
            return 0
        else
            error "Cleanup failed"
            return 1
        fi
    else
        info "Cleanup cancelled"
    fi
}

# 快速编译项目
build_project() {
    info "Building project in CLI container..."
    printf "\n"
    
    if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        error "CLI container is not running. Starting..."
        start
        local result=$?
        if [ $result -ne 0 ]; then
            return 1
        fi
    fi
    
    BUILD_CMD='
cd /workspace || exit 1

if [ -f CMakeLists.txt ]; then
    echo "==> Detected CMake project"
    mkdir -p build
    cd build
    
    if command -v ninja >/dev/null 2>&1; then
        echo "==> Configuring with Ninja..."
        cmake -GNinja \
              -DCMAKE_BUILD_TYPE=Debug \
              -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
              -DCMAKE_C_COMPILER_LAUNCHER=ccache \
              -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
              .. || exit 1
        
        echo "==> Building with Ninja..."
        ninja -j$(nproc) || exit 1
    else
        echo "==> Configuring with Make..."
        cmake -DCMAKE_BUILD_TYPE=Debug \
              -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
              .. || exit 1
        
        echo "==> Building with Make..."
        make -j$(nproc) || exit 1
    fi
    
    echo "==> Build output:"
    ls -lh | grep -E "^-.*x.*"
    
elif [ -f Makefile ] || [ -f makefile ]; then
    echo "==> Detected Makefile project"
    make -j$(nproc) || exit 1
    
elif [ -f configure ]; then
    echo "==> Detected autotools project"
    if [ ! -f Makefile ]; then
        echo "==> Running configure..."
        ./configure --enable-debug || exit 1
    fi
    make -j$(nproc) || exit 1
    
else
    echo "ERROR: No build system detected (CMakeLists.txt, Makefile, or configure)"
    echo "Please create a build configuration file first."
    exit 1
fi
'
    
    exec_cmd "$BUILD_CMD"
    local result=$?
    
    if [ $result -eq 0 ]; then
        printf "\n"
        success "Build completed!"
        
        info "ccache statistics:"
        exec_cmd "ccache -s 2>/dev/null || echo 'ccache not available'"
        return 0
    else
        printf "\n"
        error "Build failed"
        return 1
    fi
}

# 运行项目
run() {
    if [ $# -eq 0 ]; then
        error "Usage: $0 run <executable> [args...]"
        printf "\nExample:\n"
        printf "  %s run build/myapp arg1 arg2\n" "$0"
        return 1
    fi
    
    info "Running $1 in CLI container..."
    printf "\n"
    
    exec_cmd "$@"
}

# VSCode配置向导
setup_vscode() {
    info "Setting up VSCode Dev Container configuration..."
    printf "\n"
    
    # 检查必需文件
    check_required_files
    
    DEVCONTAINER_DIR="$PROJECT_DIR/.devcontainer"
    VSCODE_DIR="$PROJECT_DIR/.vscode"
    
    # 创建目录
    mkdir -p "$DEVCONTAINER_DIR"
    mkdir -p "$VSCODE_DIR"

    # 创建 devcontainer.json
    cat > "$DEVCONTAINER_DIR/devcontainer.json" << 'EOF'
{
    "name": "C Dev (VSCode)",
    
    // 直接使用 Dockerfile，让 VSCode 创建独立容器
    "dockerFile": "../Dockerfile",
    
    // 构建参数
    "build": {
        "dockerfile": "../Dockerfile",
        "context": ".."
    },
    
    // 容器内的工作目录
    "workspaceFolder": "/workspace",
    
    // 挂载配置
    "mounts": [
        // 挂载代码目录
        "source=${localWorkspaceFolder},target=/workspace,type=bind,consistency=cached",
        // 挂载 .gitconfig
        "source=${env:HOME}${env:USERPROFILE}/.gitconfig,target=/root/.gitconfig,type=bind,consistency=cached",
        // 挂载 SSH 密钥
        "source=${env:HOME}${env:USERPROFILE}/.ssh,target=/root/.ssh,type=bind,consistency=cached"
    ],
    
    // 运行参数（对应 docker run 的参数）
    "runArgs": [
        "--cap-add=SYS_PTRACE",
        "--security-opt=seccomp:unconfined",
        "--hostname=c-dev-vscode"
    ],
    
    // 端口转发
    "forwardPorts": [1234, 2345],
    
    // 容器启动后要安装的 VSCode 扩展
    "customizations": {
        "vscode": {
            "extensions": [
                "ms-vscode.cpptools",
                "ms-vscode.cpptools-extension-pack",
                "ms-vscode.cmake-tools",
                "twxs.cmake",
                "ms-vscode.makefile-tools",
                "eamodio.gitlens"
            ],
            "settings": {
                "C_Cpp.default.compilerPath": "/usr/bin/gcc",
                "C_Cpp.default.cStandard": "c17",
                "C_Cpp.default.cppStandard": "c++17",
                "C_Cpp.default.intelliSenseMode": "linux-gcc-x64",
                "C_Cpp.default.compileCommands": "${workspaceFolder}/build/compile_commands.json",
                "C_Cpp.errorSquiggles": "enabled",
                "files.watcherExclude": {
                    "**/build/**": true,
                    "**/.ccache/**": true
                },
                "files.associations": {
                    "*.h": "c",
                    "*.c": "c"
                },
                "editor.formatOnSave": false,
                "cmake.configureOnOpen": false,
                "terminal.integrated.defaultProfile.linux": "bash"
            }
        }
    },
    
    // 容器启动后执行的命令
    "postCreateCommand": "echo '=== Dev Container Ready ===' && gcc --version && cmake --version && gdb --version",
    
    // 用户设置
    "remoteUser": "root",
    
    // 容器关闭行为
    "shutdownAction": "stopContainer",
    
    // 容器环境变量
    "containerEnv": {
        "TERM": "xterm-256color",
        "COLORTERM": "truecolor"
    }
}
EOF

    # 创建 launch.json
    cat > "$VSCODE_DIR/launch.json" << 'EOF'
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "(gdb) Launch",
            "type": "cppdbg",
            "request": "launch",
            "program": "${workspaceFolder}/build/${fileBasenameNoExtension}",
            "args": [],
            "stopAtEntry": false,
            "cwd": "${workspaceFolder}",
            "environment": [],
            "externalConsole": false,
            "MIMode": "gdb",
            "setupCommands": [
                {
                    "description": "Enable pretty-printing for gdb",
                    "text": "-enable-pretty-printing",
                    "ignoreFailures": true
                },
                {
                    "description": "Set Disassembly Flavor to Intel",
                    "text": "-gdb-set disassembly-flavor intel",
                    "ignoreFailures": true
                }
            ],
            "preLaunchTask": "build",
            "miDebuggerPath": "/usr/bin/gdb"
        },
        {
            "name": "(gdb) CMake Debug",
            "type": "cppdbg",
            "request": "launch",
            "program": "${command:cmake.launchTargetPath}",
            "args": [],
            "stopAtEntry": false,
            "cwd": "${workspaceFolder}",
            "environment": [],
            "externalConsole": false,
            "MIMode": "gdb",
            "setupCommands": [
                {
                    "description": "Enable pretty-printing for gdb",
                    "text": "-enable-pretty-printing",
                    "ignoreFailures": true
                }
            ]
        },
        {
            "name": "(gdb) Attach",
            "type": "cppdbg",
            "request": "attach",
            "program": "${workspaceFolder}/build/myapp",
            "processId": "${command:pickProcess}",
            "MIMode": "gdb"
        }
    ]
}
EOF

    # 创建 tasks.json
    cat > "$VSCODE_DIR/tasks.json" << 'EOF'
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "build",
            "type": "shell",
            "command": "mkdir -p build && cd build && cmake -GNinja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON .. && ninja -j$(nproc)",
            "group": {
                "kind": "build",
                "isDefault": true
            },
            "presentation": {
                "reveal": "always",
                "panel": "shared"
            },
            "problemMatcher": ["$gcc"]
        },
        {
            "label": "build-release",
            "type": "shell",
            "command": "mkdir -p build && cd build && cmake -GNinja -DCMAKE_BUILD_TYPE=Release .. && ninja -j$(nproc)",
            "group": "build",
            "presentation": {
                "reveal": "always",
                "panel": "shared"
            },
            "problemMatcher": ["$gcc"]
        },
        {
            "label": "clean",
            "type": "shell",
            "command": "rm -rf build",
            "presentation": {
                "reveal": "always",
                "panel": "shared"
            }
        },
        {
            "label": "rebuild",
            "dependsOn": ["clean", "build"],
            "dependsOrder": "sequence"
        },
        {
            "label": "make",
            "type": "shell",
            "command": "make -j$(nproc)",
            "group": "build",
            "presentation": {
                "reveal": "always",
                "panel": "shared"
            },
            "problemMatcher": ["$gcc"]
        },
        {
            "label": "run",
            "type": "shell",
            "command": "${workspaceFolder}/build/myapp",
            "dependsOn": ["build"],
            "presentation": {
                "reveal": "always",
                "panel": "shared"
            }
        }
    ]
}
EOF

    # 创建 c_cpp_properties.json
    cat > "$VSCODE_DIR/c_cpp_properties.json" << 'EOF'
{
    "configurations": [
        {
            "name": "Linux",
            "includePath": [
                "${workspaceFolder}/**",
                "${workspaceFolder}/include",
                "/usr/include",
                "/usr/local/include"
            ],
            "defines": [
                "DEBUG",
                "_DEBUG"
            ],
            "compilerPath": "/usr/bin/gcc",
            "cStandard": "c17",
            "cppStandard": "c++17",
            "intelliSenseMode": "linux-gcc-x64",
            "compileCommands": "${workspaceFolder}/build/compile_commands.json",
            "configurationProvider": "ms-vscode.cmake-tools"
        }
    ],
    "version": 4
}
EOF

    # 创建 .gitignore（如果不存在）
    if [ ! -f "$PROJECT_DIR/.gitignore" ]; then
        cat > "$PROJECT_DIR/.gitignore" << 'EOF'
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
EOF
        info "Created .gitignore"
    fi
    
    printf "\n"
    success "VSCode Dev Container configuration created!"
    printf "\n"
    info "Configuration files created:"
    printf "  - %s\n" "$DEVCONTAINER_DIR/devcontainer.json"
    printf "  - %s\n" "$VSCODE_DIR/launch.json"
    printf "  - %s\n" "$VSCODE_DIR/tasks.json"
    printf "  - %s\n" "$VSCODE_DIR/c_cpp_properties.json"
    if [ -f "$PROJECT_DIR/.gitignore" ]; then
        printf "  - %s\n" "$PROJECT_DIR/.gitignore"
    fi
    printf "\n"
    
    printf "${CYAN}╔════════════════════════════════════════════════════════╗${NC}\n"
    printf "${CYAN}║           TWO INDEPENDENT CONTAINERS                   ║${NC}\n"
    printf "${CYAN}╚════════════════════════════════════════════════════════╝${NC}\n"
    printf "\n"
    
    printf "${MAGENTA}Container 1: CLI Container (c-dev-env)${NC}\n"
    printf "  Purpose: Command-line operations\n"
    printf "  Managed by: ./c-dev-env.sh\n"
    printf "  Usage:\n"
    printf "    ${GREEN}./c-dev-env.sh start${NC}          # Start\n"
    printf "    ${GREEN}./c-dev-env.sh shell${NC}          # Enter shell\n"
    printf "    ${GREEN}./c-dev-env.sh build-project${NC}  # Build\n"
    printf "    ${GREEN}./c-dev-env.sh stop${NC}           # Stop\n"
    printf "\n"
    
    printf "${MAGENTA}Container 2: VSCode Container (auto-named)${NC}\n"
    printf "  Purpose: VSCode development & debugging\n"
    printf "  Managed by: VSCode Dev Containers\n"
    printf "  Usage:\n"
    printf "    ${GREEN}code %s${NC}\n" "$PROJECT_DIR"
    printf "    ${GREEN}Click 'Reopen in Container'${NC}\n"
    printf "    ${GREEN}Press F5 to debug${NC}\n"
    printf "    ${GREEN}Press Ctrl+Shift+B to build${NC}\n"
    printf "\n"
    
    printf "${YELLOW}Key Points:${NC}\n"
    printf "  ✓ Both containers mount the same code directory\n"
    printf "  ✓ They can run simultaneously\n"
    printf "  ✓ Changes in one are visible in the other\n"
    printf "  ✓ Each has its own isolated environment\n"
    printf "\n"
    
    success "Setup complete! Choose your workflow:"
    printf "  - Use CLI for quick operations\n"
    printf "  - Use VSCode for debugging and development\n"
    printf "  - Use both simultaneously if needed\n"
}

# 显示ccache统计
ccache_stats() {
    info "ccache statistics (CLI container):"
    printf "\n"
    
    if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        error "CLI container is not running"
        return 1
    fi
    
    exec_cmd "ccache -s"
}

# 清理ccache
ccache_clean() {
    warn "Clearing ccache (CLI container)..."
    
    if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        error "CLI container is not running"
        return 1
    fi
    
    exec_cmd "ccache -C"
    local result=$?
    
    if [ $result -eq 0 ]; then
        success "ccache cleared"
        return 0
    else
        error "Failed to clear ccache"
        return 1
    fi
}

# 显示帮助
usage() {
    cat << EOF

${GREEN}═══════════════════════════════════════════════════════════${NC}
${GREEN}  C Development Environment Manager${NC}
${GREEN}  Dual-Container Architecture${NC}
${GREEN}═══════════════════════════════════════════════════════════${NC}

${YELLOW}ARCHITECTURE:${NC}
    ${MAGENTA}Container 1${NC}: CLI Container (${CYAN}c-dev-env${NC})
      - Managed by this script
      - For command-line operations
      - Always named: c-dev-env
    
    ${MAGENTA}Container 2${NC}: VSCode Container (${CYAN}auto-named${NC})
      - Managed by VSCode Dev Containers
      - For graphical debugging
      - Auto-named by VSCode
    
    Both containers:
      ✓ Mount the same code directory
      ✓ Can run simultaneously
      ✓ Share the same codebase

${YELLOW}USAGE:${NC}
    $0 [command] [options]

${YELLOW}COMMANDS:${NC}
    ${BLUE}setup-vscode${NC}        Setup VSCode Dev Container (do this first!)
    ${BLUE}build${NC}               Build the Docker image
    ${BLUE}start${NC}               Start CLI container
    ${BLUE}stop${NC}                Stop CLI container
    ${BLUE}restart${NC}             Restart CLI container
    ${BLUE}shell${NC}               Open bash in CLI container
    ${BLUE}exec${NC} <cmd>          Execute command in CLI container
    ${BLUE}status${NC}              Show all containers status
    ${BLUE}logs${NC} [opts]         Show CLI container logs
    ${BLUE}build-project${NC}       Build project in CLI container
    ${BLUE}run${NC} <exe> [args]    Run executable in CLI container
    ${BLUE}ccache-stats${NC}        Show ccache statistics
    ${BLUE}ccache-clean${NC}        Clear ccache
    ${BLUE}clean${NC}               Remove CLI container and volumes
    ${BLUE}help${NC}                Show this help

${YELLOW}PROJECT DIRECTORY:${NC}
    Current project: ${GREEN}$PROJECT_DIR${NC}

${YELLOW}WORKFLOW 1: VSCode Development (Recommended)${NC}
    ${GREEN}# One-time setup${NC}
    1. $0 build
    2. $0 setup-vscode
    3. code .
    4. Click "Reopen in Container"
    
    ${GREEN}# Daily work${NC}
    - VSCode automatically manages its container
    - Press F5 to debug
    - Press Ctrl+Shift+B to build
    - Close VSCode to stop container

${YELLOW}WORKFLOW 2: CLI Operations${NC}
    ${GREEN}# Start CLI container${NC}
    $0 start
    
    ${GREEN}# Quick operations${NC}
    $0 shell                    # Enter shell
    $0 exec "gcc --version"     # Run command
    $0 build-project            # Compile
    $0 run build/myapp          # Execute
    
    ${GREEN}# Stop when done${NC}
    $0 stop

${YELLOW}WORKFLOW 3: Hybrid (Both Containers)${NC}
    ${GREEN}# Use both simultaneously${NC}
    Terminal: $0 start && $0 shell
    VSCode:   code . -> Reopen in Container
    
    ${GREEN}# Benefits${NC}
    - CLI for quick tests
    - VSCode for debugging
    - Both see same code changes

${YELLOW}EXAMPLES:${NC}
    ${GREEN}# Setup${NC}
    $0 build                    # Build image once
    $0 setup-vscode             # Setup VSCode once

    ${GREEN}# CLI operations${NC}
    $0 start                    # Start CLI container
    $0 shell                    # Enter container
    $0 exec "ls -la"            # Run command
    $0 build-project            # Build project
    $0 stop                     # Stop container

    ${GREEN}# VSCode operations${NC}
    code .                      # Open in VSCode
    # Click "Reopen in Container"
    # F5 to debug, Ctrl+Shift+B to build

    ${GREEN}# Status and monitoring${NC}
    $0 status                   # Check all containers
    $0 logs -f                  # Follow CLI logs
    $0 ccache-stats             # Cache stats

${YELLOW}CONTAINER INFO:${NC}
    CLI Container:   $CONTAINER_NAME
    Project Dir:     $PROJECT_DIR
    Mount Point:     /workspace
    VSCode Container: Auto-named by VSCode

${GREEN}═══════════════════════════════════════════════════════════${NC}

EOF
}

# 主函数
main() {
    check_podman
    
    case "${1:-help}" in
        build)
            build
            ;;
        start)
            start
            ;;
        stop)
            stop
            ;;
        restart)
            restart
            ;;
        shell|sh)
            shell
            ;;
        exec|ex)
            shift
            exec_cmd "$@"
            ;;
        status|st)
            status
            ;;
        logs)
            logs "$@"
            ;;
        build-project|bp|compile)
            build_project
            ;;
        run)
            shift
            run "$@"
            ;;
        ccache-stats|cs)
            ccache_stats
            ;;
        ccache-clean|cc)
            ccache_clean
            ;;
        clean)
            clean
            ;;
        setup-vscode|setup|init)
            setup_vscode
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            error "Unknown command: $1"
            printf "\n"
            usage
            exit 1
            ;;
    esac
}

main "$@"