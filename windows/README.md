# 只有 Windows 电脑和网线

适用于没有 OpenWrt 路由器、把校园网墙口直接连接到 Windows 电脑网口的情况。程序在电脑上持续运行，发现掉线后自动重新认证。

## 使用前须知

- 当前自动发布支持 64 位 Windows 10/11。
- 只有这台电脑获得网络；本方案不会自动给手机或其他设备共享网络。
- 电脑关机、休眠或拔掉网线后，程序无法继续认证。
- 安装和首次排查时建议关闭 Wi-Fi、VPN、代理和其他联网软件，避免探测流量走错网络接口。
- 本项目不是学校官方软件，请遵守校园网使用规定。

## 安装

1. 在项目 [Releases](https://github.com/APinkCube/hust-wired-auto-reconnect/releases) 中下载 `hust-network-login-x86_64-pc-windows-msvc.zip` 和同名 `.sha256` 文件。
2. 解压整个压缩包，不要只取出 `.exe`。
3. 将校园网网线插入电脑，并确认 Windows 的“以太网”显示已连接。
4. 右键开始菜单，打开“终端（管理员）”或“Windows PowerShell（管理员）”。
5. 进入解压目录并执行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

运行前可以核对下载文件：

```powershell
Get-FileHash .\hust-network-login-x86_64-pc-windows-msvc.zip -Algorithm SHA256
Get-Content .\hust-network-login-x86_64-pc-windows-msvc.zip.sha256
```

两处哈希值应完全一致。本项目是个人维护的开源软件，暂未购买 Windows 代码签名证书，因此 Windows Defender SmartScreen 可能显示“未知发布者”。请先确认下载地址是本仓库并完成哈希校验，再决定是否运行；不要关闭系统安全软件。

安装程序会询问学号和校园网密码。密码输入不会回显，配置会保存到：

```text
C:\ProgramData\hust-network-login\hust-network-login.conf
```

该目录只允许当前安装用户、Administrators 和 SYSTEM 访问。安装程序还会创建 `HUST Wired Auto Reconnect` 计划任务，在开机或登录后自动运行。

## 检查状态

在 PowerShell 中运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\hust-network-login\check.ps1"
```

输出会显示：

- 安装文件是否完整；
- 计划任务状态与上次运行结果；
- 登录程序是否正在运行；
- 当前活动的有线网卡；
- 最近的标准输出和错误日志。

## 修改账号或密码

使用管理员 PowerShell 运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\hust-network-login\install.ps1" -UpdateCredentials
```

## 手动启动或停止

```powershell
Start-ScheduledTask -TaskName "HUST Wired Auto Reconnect"
Stop-ScheduledTask -TaskName "HUST Wired Auto Reconnect"
```

## 卸载

默认会同时删除保存的校园网账号和密码：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\hust-network-login\uninstall.ps1"
```

如需保留凭据文件：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\hust-network-login\uninstall.ps1" -KeepCredentials
```

## 常见问题

- 没有活动的有线网卡：检查网线、墙口和网卡驱动，并确认没有使用 USB 网卡省电断开。
- 程序运行但没有触发认证：临时关闭 Wi-Fi、VPN 和代理后重启计划任务。
- 显示 `portal login was rejected`：重新录入账号密码，并确认账号状态正常。
- WAN/以太网拿不到有效 IPv4：通常属于 DHCP、墙口或其他前置认证问题，本程序无法替代这些环节。
- 提交 Issue 前，请删除日志中的学号、IP、MAC、Cookie 和完整认证地址。
