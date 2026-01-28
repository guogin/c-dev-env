#!/usr/bin/env bash
# c-dev-env.sh - C语言开发环境容器管理脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="c-dev-env"
PROJECT_DIR="${HOME}/my-project"

# 颜色定义（使用 ANSI 转义序列）
if [ -t 1 ]; then
    # 只在终端输出时使用颜色
    RED=$(printf '\033[0;31m')
    GREEN=$(printf '\033[0;32m')
    YELLOW=$(printf '\033[1;33m')
    BLUE=$(printf '\033[0;34m')
    NC=$(printf '\033[0m')
else
    # 非终端输出时不使用颜色
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
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

# 构建镜像
build() {
    info "Building C development environment..."
    cd "$SCRIPT_DIR"
    
    podman-compose build
    local result=$?
    
    if [ $result -eq 0 ]; then
        success "Build completed!"
        return 0
    else
        error "Build failed"
        return 1
    fi
}

# 启动容器
start() {
    info "Starting C development environment..."
    cd "$SCRIPT_DIR"
    
    # 检查项目目录是否存在
    if [ ! -d "$PROJECT_DIR" ]; then
        warn "Project directory $PROJECT_DIR does not exist. Creating..."
        mkdir -p "$PROJECT_DIR"
    fi
    
    # 检查容器是否已经在运行
    if podman ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        warn "Container is already running"
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
            success "Container started successfully!"
            info "Container name: $CONTAINER_NAME"
            info "Project directory: $PROJECT_DIR -> /workspace"
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
    info "Stopping C development environment..."
    cd "$SCRIPT_DIR"
    
    if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        warn "Container is not running"
        return 0
    fi
    
    podman-compose down
    local result=$?
    
    if [ $result -eq 0 ]; then
        success "Container stopped!"
        return 0
    else
        error "Failed to stop container"
        return 1
    fi
}

# 重启容器
restart() {
    info "Restarting container..."
    stop
    sleep 2
    start
}

# 进入容器shell
shell() {
    if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        error "Container is not running. Starting..."
        start
        local result=$?
        if [ $result -ne 0 ]; then
            return 1
        fi
    fi
    
    info "Entering container shell..."
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
        error "Container is not running"
        return 1
    fi
    
    podman exec -it "$CONTAINER_NAME" bash -c "$*"
}

# 查看容器状态
status() {
    info "Container status:"
    printf "\n"
    
    if podman ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        # 显示容器信息
        podman ps --filter "name=${CONTAINER_NAME}" \
            --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        
        printf "\n"
        success "Container is running ✓"
        
        # 显示资源使用情况
        printf "\n"
        info "Resource usage:"
        podman stats --no-stream "$CONTAINER_NAME" 2>/dev/null || warn "Could not retrieve resource usage"
    else
        warn "Container is not running"
        
        # 检查容器是否存在但已停止
        if podman ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            info "Container exists but is stopped. Use '$0 start' to start it."
        else
            info "Container does not exist. Use '$0 build' to create it."
        fi
    fi
}

# 查看日志
logs() {
    if ! podman ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        error "Container does not exist"
        return 1
    fi
    
    info "Container logs:"
    printf "\n"
    
    shift  # 移除 'logs' 参数
    if [ $# -eq 0 ]; then
        # 默认显示最后50行
        podman logs --tail 50 "$CONTAINER_NAME"
    else
        podman logs "$@" "$CONTAINER_NAME"
    fi
}

# 清理（删除容器和卷）
clean() {
    printf "\n"
    warn "╔════════════════════════════════════════════════════════╗"
    warn "║  WARNING: This will remove the container and all      ║"
    warn "║  build caches (ccache, cmake cache)!                  ║"
    warn "║  Your source code will NOT be affected.               ║"
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
    info "Building project in container..."
    printf "\n"
    
    if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        error "Container is not running. Starting..."
        start
        local result=$?
        if [ $result -ne 0 ]; then
            return 1
        fi
    fi
    
    # 检测构建系统并编译
    BUILD_CMD='
cd /workspace || exit 1

if [ -f CMakeLists.txt ]; then
    echo "==> Detected CMake project"
    mkdir -p build
    cd build
    
    # 使用 Ninja + ccache 加速编译
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
        
        # 显示 ccache 统计
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
    
    info "Running $1 in container..."
    printf "\n"
    
    exec_cmd "$@"
}

# VSCode配置向导
setup_vscode() {
    info "Setting up VSCode configuration..."
    printf "\n"
    
    VSCODE_DIR="$PROJECT_DIR/.vscode"
    
    # 创建目录
    mkdir -p "$VSCODE_DIR"

    # 创建 launch.json - 调试配置
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

    # 创建 tasks.json - 构建任务
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

    # 创建 c_cpp_properties.json - IntelliSense 配置
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

    # 创建 settings.json
    if [ ! -f "$VSCODE_DIR/settings.json" ]; then
        cat > "$VSCODE_DIR/settings.json" << 'EOF'
{
    "files.watcherExclude": {
        "**/build/**": true,
        "**/.ccache/**": true
    },
    "files.associations": {
        "*.h": "c",
        "*.c": "c"
    },
    "editor.formatOnSave": false,
    "C_Cpp.default.compilerPath": "/usr/bin/gcc",
    "C_Cpp.errorSquiggles": "enabled"
}
EOF
    fi
    
    printf "\n"
    success "VSCode configuration created!"
    printf "\n"
    info "Configuration files created:"
    printf "  - %s\n" "$VSCODE_DIR/launch.json"
    printf "  - %s\n" "$VSCODE_DIR/tasks.json"
    printf "  - %s\n" "$VSCODE_DIR/c_cpp_properties.json"
    printf "  - %s\n" "$VSCODE_DIR/settings.json"
    printf "\n"
    
    info "IMPORTANT: Container lifecycle workflow:"
    printf "  ${YELLOW}1.${NC} Start container:   ${GREEN}%s start${NC}\n" "$0"
    printf "  ${YELLOW}2.${NC} Open VSCode:       ${GREEN}%s vscode${NC}\n" "$0"
    printf "\n"
    warn "VSCode will NOT start/stop the container automatically."
    info "You must use the script to manage container lifecycle."
}

# 查找容器
find_container() {
    podman ps --format '{{.Names}}' | grep -E "^c-dev-env$" | head -1
}

# 用 VSCode 连接到容器
vscode() {
    # 确保容器运行
    CONTAINER=$(find_container)
    if [ -z "$CONTAINER" ]; then
        warn "Container not running. Starting..."
        start
        CONTAINER=$(find_container)
        if [ -z "$CONTAINER" ]; then
            error "Failed to start container"
            return 1
        fi
    fi
    
    info "Opening VSCode..."
    info "Container: $CONTAINER"
    
    # 方法1：使用命令行（需要 Remote-Containers 扩展）
    code --remote "attached-container+$CONTAINER" "$PROJECT_DIR"
    
    # 如果上面不行，提示手动操作
    local result=$?
    if [ $result -ne 0 ]; then
        warn "Automatic attach failed. Please:"
        printf "  1. Open VSCode: ${GREEN}code %s${NC}\n" "$PROJECT_DIR"
        printf "  2. Press F1\n"
        printf "  3. Select: ${GREEN}Dev Containers: Attach to Running Container...${NC}\n"
        printf "  4. Choose: ${GREEN}%s${NC}\n" "$CONTAINER"
        printf "  5. Open folder: ${GREEN}/workspace${NC}\n"
    fi
}

# 显示ccache统计
ccache_stats() {
    info "ccache statistics:"
    printf "\n"
    
    if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        error "Container is not running"
        return 1
    fi
    
    exec_cmd "ccache -s"
}

# 清理ccache
ccache_clean() {
    warn "Clearing ccache..."
    
    if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        error "Container is not running"
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
${GREEN}═══════════════════════════════════════════════════════════${NC}

${YELLOW}USAGE:${NC}
    $0 [command] [options]

${YELLOW}COMMANDS:${NC}
    ${BLUE}build${NC}               Build the container image
    ${BLUE}start${NC}               Start the development container
    ${BLUE}stop${NC}                Stop the development container
    ${BLUE}restart${NC}             Restart the container
    ${BLUE}shell${NC}               Open a bash shell in the container
    ${BLUE}exec${NC} <cmd>          Execute a command in the container
    ${BLUE}status${NC}              Show container status and resource usage
    ${BLUE}logs${NC} [opts]         Show container logs
    ${BLUE}build-project${NC}       Build the project inside container
    ${BLUE}run${NC} <exe> [args]    Run an executable in the container
    ${BLUE}ccache-stats${NC}        Show ccache statistics
    ${BLUE}ccache-clean${NC}        Clear ccache
    ${BLUE}clean${NC}               Remove container and volumes
    ${BLUE}setup-vscode${NC}        Setup VSCode Dev Container configuration
    ${BLUE}vscode${NC}              Open VSCode connected to the container
    ${BLUE}help${NC}                Show this help message

${YELLOW}EXAMPLES:${NC}
    ${GREEN}# Initial setup${NC}
    $0 build                    # Build the Docker image
    $0 start                    # Start the container
    $0 setup-vscode             # Setup VSCode integration

    ${GREEN}# Daily development${NC}
    $0 shell                    # Enter container shell
    $0 exec "gcc --version"     # Run command in container
    $0 build-project            # Compile your project
    $0 run build/myapp arg1     # Run your program

    ${GREEN}# Monitoring${NC}
    $0 status                   # Check container status
    $0 logs -f                  # Follow logs
    $0 ccache-stats             # Check build cache

    ${GREEN}# Cleanup${NC}
    $0 stop                     # Stop container
    $0 clean                    # Remove everything

${YELLOW}QUICK START:${NC}
    1. $0 build
    2. $0 start
    3. $0 setup-vscode
    4. code ~/my-project
    5. Click "Reopen in Container" in VSCode

${YELLOW}CONTAINER INFO:${NC}
    Name:           $CONTAINER_NAME
    Project Dir:    $PROJECT_DIR
    Mount Point:    /workspace

${GREEN}═══════════════════════════════════════════════════════════${NC}

EOF
}

# 主函数
main() {
    # 检查依赖
    check_podman
    
    # 解析命令
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
        vscode)
            vscode
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

# 执行主函数
main "$@"
