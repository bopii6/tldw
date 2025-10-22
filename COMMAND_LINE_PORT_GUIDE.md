# 命令行指定端口启动服务器指南

## 🚀 推荐方法

### Windows PowerShell (推荐)
```powershell
# 设置端口3005并启动
$env:PORT=3005; npm run dev

# 设置端口3006并启动
$env:PORT=3006; npm run dev

# 设置端口3008并启动
$env:PORT=3008; npm run dev
```

### Windows CMD
```cmd
REM 设置端口3005并启动
set PORT=3005 && npm run dev

REM 设置端口3006并启动
set PORT=3006 && npm run dev

REM 设置端口3008并启动
set PORT=3008 && npm run dev
```

### Git Bash / WSL / Linux / macOS
```bash
# 设置端口3005并启动
PORT=3005 npm run dev

# 设置端口3006并启动
PORT=3006 npm run dev

# 设置端口3008并启动
PORT=3008 npm run dev
```

## 📝 使用步骤

### 1. 打开命令行工具
- **Windows**: 打开 PowerShell 或 CMD
- **macOS/Linux**: 打开 Terminal

### 2. 导航到项目目录
```bash
cd "c:\Users\wang\tldw"
```

### 3. 选择端口并启动
选择一个可用的端口（3005, 3006, 3008等）：
```powershell
# PowerShell示例
$env:PORT=3005; npm run dev
```

## 🔍 检查端口占用情况

### Windows
```cmd
netstat -ano | findstr :3005
netstat -ano | findstr :3006
netstat -ano | findstr :3008
```

### Linux/macOS
```bash
lsof -i :3005
lsof -i :3006
lsof -i :3008
```

## 🛠 常用端口

- **3000**: Next.js默认端口
- **3001-3010**: 常用开发端口
- **8080**: 常用测试端口

## ⚠ 注意事项

1. **避免端口冲突**: 选择未被占用的端口
2. **环境变量**: 确保设置了正确的 `NEXT_PUBLIC_APP_URL`
3. **防火墙**: 确保端口未被防火墙阻止
4. **权限**: 确保有足够的权限启动服务

## 🎯 快速启动脚本

### Windows (PowerShell)
创建文件 `start-dev.ps1`:
```powershell
param(
    [int]$Port = 3005
)

Write-Host "Starting development server on port $Port..."
$env:PORT = $Port
npm run dev
```

使用方法:
```powershell
.\start-dev.ps1 -Port 3005
```

### Linux/macOS
创建文件 `start-dev.sh`:
```bash
#!/bin/bash
PORT=${1:-3005}
echo "Starting development server on port $PORT..."
PORT=$PORT npm run dev
```

使用方法:
```bash
chmod +x start-dev.sh
./start-dev.sh 3005
```

## 🔧 故障排除

### 端口被占用
```bash
# 查找占用端口的进程
netstat -ano | findstr :3005

# 终止进程 (Windows)
taskkill /F /PID <进程ID>

# 终止进程 (Linux/macOS)
kill -9 <进程ID>
```

### 权限问题
```bash
# 以管理员身份运行 (Windows)
# 右键点击 PowerShell, 选择 "Run as Administrator"

# 使用sudo (Linux/macOS)
sudo PORT=3005 npm run dev
```

---

**提示**: 选择一个未被占用的端口，然后使用上述命令启动服务器！