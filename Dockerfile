# Dockerfile
FROM ubuntu:24.04

# 设置时区避免交互
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

# 更新软件源并安装完整的C开发工具链
RUN apt-get update && apt-get install -y \
    # 核心编译工具
    build-essential \
    gcc \
    g++ \
    gdb \
    make \
    cmake \
    ninja-build \
    ccache \
    autoconf \
    automake \
    libtool \
    pkg-config \
    # 调试和分析工具
    valgrind \
    gdbserver \
    strace \
    ltrace \
    # 静态分析工具
    cppcheck \
    clang \
    clang-tools \
    # 版本控制
    git \
    # 编辑器
    vim \
    nano \
    # 文档和帮助
    man-db \
    manpages-dev \
    manpages-posix-dev \
    # 实用工具
    curl \
    wget \
    tree \
    htop \
    tmux \
    file \
    lsof \
    # 网络工具
    net-tools \
    iputils-ping \
    netcat-openbsd \
    # 其他常用库的开发包（根据需要添加）
    libssl-dev \
    zlib1g-dev \
    # 搜索工具（代码搜索）
    silversearcher-ag \
    ripgrep \
    # 清理缓存
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 配置ccache加速编译
ENV PATH="/usr/lib/ccache:${PATH}"
ENV CCACHE_DIR="/workspace/.ccache"

# 设置默认工作目录
WORKDIR /workspace

# 配置GDB
RUN echo "set auto-load safe-path /" > /root/.gdbinit && \
    echo "set debuginfod enabled on" >> /root/.gdbinit && \
    # 允许在容器内使用ptrace（GDB需要）
    echo "kernel.yama.ptrace_scope = 0" > /etc/sysctl.d/10-ptrace.conf

# 配置git（可选，避免容器内git警告）
RUN git config --global --add safe.directory /workspace

# 暴露gdbserver端口（用于远程调试）
EXPOSE 1234

# 保持容器运行
CMD ["tail", "-f", "/dev/null"]