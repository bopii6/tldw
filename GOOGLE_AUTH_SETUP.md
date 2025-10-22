# Google OAuth 设置指南

## 🚨 问题诊断

如果您在使用Google注册时遇到问题，通常是因为以下原因之一：

1. **Supabase项目中的Google OAuth未配置**
2. **回调URL不匹配**
3. **环境变量缺失**

## 🔧 解决方案

### 1. 配置Supabase中的Google OAuth

1. 登录 [Supabase Dashboard](https://supabase.com/dashboard)
2. 选择您的项目: `smjjztidkzdcexytybbu`
3. 导航到 **Authentication** > **Providers**
4. 启用 **Google** 提供商
5. 配置以下设置：
   - **Enabled**: ✓
   - **Client ID**: 您的Google OAuth Client ID
   - **Client Secret**: 您的Google OAuth Client Secret

### 2. 设置正确的回调URL

在Google OAuth配置中，添加以下授权回调URL：
```
http://localhost:3008/auth/callback
```

**注意**: 端口号必须与您当前运行的端口一致（现在是3008）

### 3. 获取Google OAuth凭据

如果您还没有Google OAuth凭据：

1. 访问 [Google Cloud Console](https://console.cloud.google.com/)
2. 创建新项目或选择现有项目
3. 导航到 **APIs & Services** > **Credentials**
4. 点击 **Create Credentials** > **OAuth client ID**
5. 选择 **Web application**
6. 添加授权回调URL: `http://localhost:3008/auth/callback`
7. 记录 **Client ID** 和 **Client Secret**

### 4. 更新Supabase配置

将Google OAuth凭据添加到Supabase项目中：
- 将Client ID复制到Supabase的Google配置
- 将Client Secret复制到Supabase的Google配置

## 🐛 故障排除

### 检查服务器日志

在浏览器控制台中查看以下日志：
- `Google OAuth redirect URL` - 确认URL正确
- `Auth callback received` - 确认回调被接收
- `Session exchange error` - 查看具体错误信息

### 常见错误及解决方案

#### 错误: "provider is not enabled"
**原因**: Supabase中Google OAuth未启用
**解决**: 在Supabase Dashboard中启用Google提供商

#### 错误: "Invalid redirect_uri"
**原因**: 回调URL不匹配
**解决**: 确保回调URL与Google OAuth配置中的一致

#### 错误: "access_denied"
**原因**: 用户拒绝了授权请求
**解决**: 用户需要重新授权，或检查Google项目配置

#### 错误: "popup_blocked"
**原因**: 浏览器阻止了弹出窗口
**解决**: 允许站点的弹出窗口，或使用重定向方式

## 📋 测试步骤

1. 确保服务器在 `http://localhost:3008` 运行
2. 打开浏览器开发者工具查看控制台日志
3. 点击 "Sign in with Google" 按钮
4. 观察重定向和错误信息
5. 如果成功，应该重定向回应用并登录

## 🔍 调试信息

修复后的代码包含详细的日志记录：

### 前端日志 (`auth-modal.tsx`)
- Google OAuth重定向URL
- OAuth初始化成功/失败信息

### 后端日志 (`auth/callback/route.ts`)
- 接收到的认证回调详情
- 会话交换过程
- 成功登录的用户信息

## 📞 如果问题仍然存在

如果按照上述步骤后问题仍然存在：

1. **检查环境变量**: 确认 `NEXT_PUBLIC_APP_URL` 设置正确
2. **清除浏览器缓存**: 清除浏览器Cookie和缓存
3. **重新部署**: 如果是生产环境，确保环境变量正确设置
4. **联系支持**: 提供服务器日志中的具体错误信息

---

**注意**: 这些修复已经在代码中实现，现在只需要在Supabase中正确配置Google OAuth即可。