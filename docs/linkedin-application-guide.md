# LinkedIn Developer Portal 申请流程(Builder Plaza)

目标:拿到 "Sign In with LinkedIn using OpenID Connect" 的 Client ID / Secret,供 `LinkedInLive` 实现使用。配套决策见 `docs/adr/0003`。

## 前置产物

- `privacy.html` — 已生成的隐私政策页面(记得把联系邮箱改为团队真实邮箱)。

## 步骤

### 1. 用 S3 托管隐私政策(拿到表单必填的 online URL)

1. AWS 控制台 → S3 → Create bucket(如 `builderplaza-site`),区域任选。
2. 关闭该 bucket 的 Block Public Access,并添加公开读取的 bucket policy。
3. 上传 `privacy.html`。
4. Properties → Static website hosting → Enable,index document 填 `privacy.html`。
5. 记录 endpoint,形如 `http://builderplaza-site.s3-website-<region>.amazonaws.com/privacy.html` — 这就是 Privacy policy URL。

### 2. 创建免费 LinkedIn Page

1. 在 Create an app 表单点 "Create a new LinkedIn Page"。
2. 类型选 Company,名称 `Builder Plaza`,规模选最小档,logo 放一张方形图。
3. 不需要真实注册公司——这是个人开发者的标准做法。
4. 注意:Page 与 app 绑定后**不可更改**,不要用个人 profile 或临时名字。

### 3. 填写 Create an app 表单

- App name: `Builder Plaza`
- LinkedIn Page: 选刚建的页面
- Privacy policy URL: 步骤 1 的 S3 链接
- App logo: 方形、至少 100px
- 勾选 API Terms of Use → Create app

### 4. 添加 Sign In with LinkedIn 产品

- app 页面 → Products 标签 → "Sign In with LinkedIn using OpenID Connect" → Request access。
- 这是自助产品,通常几分钟到几天内自动批准(区别于需要人工审核的 Marketing API 等)。

### 5. 配置 OAuth 回调并保管凭证

- Auth 标签 → Redirect URLs:先填占位;App Runner 部署后改为
  `https://<app-runner-域名>/auth/linkedin/callback`
- Client ID / Client Secret 存入 AWS Secrets Manager(或 App Runner 环境变量),**严禁提交进 git**。

## Go / No-Go 规则(ADR-0003)

- 截止日:**2026-07-24**。届时未获批 → 环境变量切到 `LinkedInSimulated`,永久不回头。
- 无论批没批,`LinkedInSimulated` 都必须实现:自动化测试只跑在 Simulated 上。
- Simulated 路径在 UI、演示与报告中必须带 "Simulated for demo" 标注(学术诚信要求)。
