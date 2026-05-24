# ZTNet SQLite 单容器版

本仓库是基于原作者 ZTNet 项目的改版，目标是把原来的 PostgreSQL + ZeroTier 独立容器部署方式，改成更适合个人服务器、小型 VPS 和轻量自托管场景的 SQLite 单容器部署。

原作者仓库：

```text
https://github.com/sinamics/ztnet
```

英文说明已保留在：

```text
README_EN.md
```

## 这个版本适合什么场景

- 个人或小团队自托管 ZeroTier 控制器管理界面。
- 不想额外维护 PostgreSQL 数据库。
- 希望一个容器同时运行 ZTNet Web、SQLite 数据库文件和 ZeroTier daemon。
- 使用 Nginx、Caddy 或其他反向代理对外提供 HTTPS。

不适合的场景：

- 已有 PostgreSQL 生产数据并要求自动迁移到 SQLite。
- 多实例横向扩展部署。
- 高并发、大团队、多节点数据库共享场景。

## 主要修改

- 数据库从 PostgreSQL 改为 SQLite。
- Docker Compose 从 PostgreSQL、ZeroTier、ZTNet 三容器改为单个 `ztnet` 容器。
- SQLite 数据持久化到 `/app/data/ztnet.sqlite`。
- ZeroTier 状态持久化到 `/var/lib/zerotier-one`。
- 容器启动时自动初始化 SQLite schema，并确保 `GlobalOptions` 默认配置存在。
- Prisma schema 调整为 SQLite 兼容。
- 移除了运行时代码中的 PostgreSQL 专用 raw SQL。
- 备份/恢复从 `pg_dump`、`psql` 改为 SQLite 文件备份/恢复。
- Docker 镜像通过 GitHub Container Registry 发布。

## 镜像地址

```text
ghcr.io/g2x-cmd/ztnet:ztnet-sqlte
```

拉取镜像：

```bash
docker pull ghcr.io/g2x-cmd/ztnet:ztnet-sqlte
```

## 推荐部署方式

Web 管理界面建议只映射到宿主机本地 `127.0.0.1:3000`，再通过 Nginx 反向代理到公网域名。

示例 `docker-compose.yml`：

```yaml
services:
  ztnet:
    image: ghcr.io/g2x-cmd/ztnet:ztnet-sqlte
    container_name: ztnet
    working_dir: /app
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    volumes:
      - /home/nexc/data/ztnet:/app/data
      - /home/nexc/data/config:/var/lib/zerotier-one
    ports:
      - 127.0.0.1:3000:3000
      - "9993:9993/udp"
    environment:
      DATABASE_URL: "file:/app/data/ztnet.sqlite"
      SQLITE_DIR: "/app/data"
      ZT_ADDR: "http://127.0.0.1:9993"
      ZT_SECRET_FILE: "/var/lib/zerotier-one/authtoken.secret"
      NEXTAUTH_URL: "https://ztnet.example.com"
      NEXTAUTH_SECRET: "replace_with_random_32_byte_secret"
```

启动：

```bash
docker compose pull
docker compose up -d
docker logs -f ztnet
```

## Nginx 反向代理

Nginx 上游地址指向：

```text
http://127.0.0.1:3000
```

`NEXTAUTH_URL` 必须设置成用户浏览器访问的公网地址，例如：

```yaml
NEXTAUTH_URL: "https://ztnet.example.com"
```

如果 `NEXTAUTH_URL` 仍是 `http://localhost:3000`，通过公网域名访问时会出现类似错误：

```text
Invalid origin: https://ztnet.example.com
```

## NEXTAUTH_SECRET

`NEXTAUTH_SECRET` 是认证系统密钥，用于保护登录 cookie、session 和认证 token。生产环境不要使用示例值。

生成随机密钥：

```bash
openssl rand -base64 32
```

然后填入：

```yaml
NEXTAUTH_SECRET: "生成出来的随机字符串"
```

上线后不要频繁更换该值，否则已登录用户需要重新登录。

## 首次注册

全新 SQLite 数据库启动后会自动创建默认全局配置：

```text
enableRegistration=true
firstUserRegistration=true
siteName=ZTNET
```

第一个注册的用户会自动成为管理员。

如果注册页显示异常，可以检查数据库初始化结果：

```bash
docker exec -it ztnet node -e 'const {PrismaClient}=require("@prisma/client"); const p=new PrismaClient(); p.globalOptions.findFirst({where:{id:1}, select:{id:true, enableRegistration:true, firstUserRegistration:true, siteName:true}}).then(console.log).finally(()=>p.$disconnect())'
```

正常应看到：

```js
{
  id: 1,
  enableRegistration: true,
  firstUserRegistration: true,
  siteName: 'ZTNET'
}
```

## 数据目录

建议持久化两个目录：

```text
/app/data
/var/lib/zerotier-one
```

对应宿主机示例：

```text
/home/nexc/data/ztnet
/home/nexc/data/config
```

其中：

- `/app/data` 保存 SQLite 数据库。
- `/var/lib/zerotier-one` 保存 ZeroTier identity、authtoken、planet 等状态。

## 更新镜像

```bash
docker compose pull
docker compose down
docker compose up -d
docker logs -f ztnet
```

如果本地缓存旧镜像，可以先删除：

```bash
docker rmi ghcr.io/g2x-cmd/ztnet:ztnet-sqlte
docker compose pull
docker compose up -d
```

## 本地开发测试

Windows PowerShell 示例：

```powershell
$env:DATABASE_URL="file:./data/ztnet.sqlite"
$env:NEXTAUTH_URL="http://localhost:3000"
$env:NEXTAUTH_SECRET="dummy_key_32_chars_minimum_value"
$env:NEXT_PUBLIC_APP_VERSION=""
$env:ZT_ADDR="http://127.0.0.1:9993"
$env:ZT_SECRET="dummy_secret"
npx prisma generate
npx prisma db push --accept-data-loss
npx prisma db seed
npx next dev
```

构建测试：

```powershell
$env:DATABASE_URL="file:./data/ztnet.sqlite"
$env:NEXTAUTH_URL="http://localhost:3000"
$env:NEXTAUTH_SECRET="dummy_key_32_chars_minimum_value"
$env:NEXT_PUBLIC_APP_VERSION=""
$env:ZT_ADDR="http://127.0.0.1:9993"
$env:ZT_SECRET="dummy_secret"
npm run build
```

## 注意事项

- 这个分支不提供 PostgreSQL 到 SQLite 的自动数据迁移。
- SQLite 数据库文件需要做好宿主机备份。
- `9993/udp` 建议对外开放给 ZeroTier 使用。
- Web 端口建议只绑定 `127.0.0.1`，由 Nginx 提供 HTTPS。
- 真实生产环境必须替换 `NEXTAUTH_SECRET`。

## 许可证和致谢

本项目基于原作者 ZTNet 修改：

```text
https://github.com/sinamics/ztnet
```

感谢原作者和相关贡献者提供 ZTNet 项目。本改版仅针对 SQLite 单容器部署场景做适配。
