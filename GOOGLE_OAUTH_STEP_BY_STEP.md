# Google OAuth 回调URL设置详细步骤

## 🎯 目标
在Google Cloud Console中添加回调URL: `http://localhost:3008/auth/callback`

## 📋 详细步骤

### 第1步: 访问Google Cloud Console

1. 打开浏览器，访问: https://console.cloud.google.com/
2. 登录您的Google账号

### 第2步: 选择或创建项目

1. 在顶部导航栏点击项目选择器
2. 如果已有项目，选择一个项目
3. 如果没有项目，点击 **NEW PROJECT**
   - 项目名称: `TLDW Authentication` (或您喜欢的名称)
   - 点击 **CREATE**

### 第3步: 配置OAuth同意屏幕

1. 在左侧菜单中，点击 **APIs & Services** > **OAuth consent screen**
2. 选择 **External** (因为这是面向公众的应用)
3. 点击 **CREATE**

#### 填写OAuth同意屏幕信息:
- **App name**: `TLDW` (或您的应用名称)
- **User support email**: 选择您的邮箱
- **Developer contact information**: 填写您的邮箱
- 点击 **SAVE AND CONTINUE**

#### 范围 (Scopes):
1. 点击 **ADD OR REMOVE SCOPES**
2. 搜索并添加: `openid`, `email`, `profile`
3. 点击 **UPDATE**
4. 点击 **SAVE AND CONTINUE**

#### 测试用户:
1. 点击 **ADD USERS**
2. 添加您的测试邮箱地址
3. 点击 **SAVE AND CONTINUE**
4. 返回仪表板，点击 **BACK TO DASHBOARD**

### 第4步: 创建OAuth客户端ID

1. 在左侧菜单中，点击 **APIs & Services** > **Credentials**
2. 点击 **+ CREATE CREDENTIALS**
3. 选择 **OAuth client ID**

#### 配置OAuth客户端ID:
- **Application type**: **Web application**
- **Name**: `TLDW Web Client` (或您喜欢的名称)

#### 添加授权重定向URI (这是关键步骤!):

1. 在 **Authorized redirect URIs** 部分，点击 **+ ADD URI**
2. 在输入框中输入: `http://localhost:3008/auth/callback`
3. 点击 **ADD**
4. 再次点击 **+ ADD URI** 添加另一个:
   `http://localhost:3008/auth/callback`
5. 确认看到两个相同的回调URL

### 第5步: 获取凭据

1. 点击 **CREATE**
2. **保存您的凭据**:
   - **Client ID**: 复制这个ID (示例: `1234567890-abc123def456.apps.googleusercontent.com`)
   - **Client Secret**: 点击 **SHOW** 或下载JSON文件 (示例: `GOCSPX-abc123def456ghi789`)

### 第6步: 在Supabase中配置

1. 访问 [Supabase Dashboard](https://supabase.com/dashboard)
2. 选择您的项目: `smjjztidkzdcexytybbu`
3. 导航到 **Authentication** > **Providers**
4. 找到 **Google** 并点击它
5. 填写配置:
   - **Enabled**: ✅ (勾选)
   - **Client ID**: 粘贴您从Google获得的Client ID
   - **Client Secret**: 粘贴您从Google获得的Client Secret
6. 点击 **Save**

## 🎨 重要注意事项

### 端口号问题
- 如果您更改了运行端口，需要相应更新回调URL
- 当前使用的是 `http://localhost:3008/auth/callback`
- 如果使用其他端口，如3005，则更改为 `http://localhost:3005/auth/callback`

### 生产环境
- 部署到生产环境时，需要添加生产环境的URL
- 例如: `https://yourdomain.com/auth/callback`

## 🔍 验证配置

### 检查Google Cloud Console
1. 在 **Credentials** 页面看到您的OAuth客户端ID
2. 客户端ID配置中包含正确的回调URL

### 检查Supabase
1. 在 **Authentication** > **Providers** 中看到Google已启用
2. 配置状态显示 "Connected"

## 🐛 常见问题

### 问题1: "Invalid redirect_uri"
**原因**: 回调URL不匹配
**解决**:
- 检查Google Cloud Console中的回调URL是否完全正确
- 确保端口号与应用运行端口一致
- 确保没有多余的斜杠或参数

### 问题2: "unauthorized_client"
**原因**: Client ID或Secret不正确
**解决**:
- 重新复制Client ID和Secret
- 确保没有额外的空格或字符

### 问题3: "access_denied"
**原因**: 用户拒绝了授权
**解决**:
- 重新尝试授权
- 检查OAuth同意屏幕配置是否正确

## 📞 需要帮助？

如果在设置过程中遇到任何问题，请：
1. 截图错误信息
2. 提供您在Google Cloud Console中的配置截图
3. 告诉我当前运行的具体端口号

我会帮您进一步诊断和解决问题！