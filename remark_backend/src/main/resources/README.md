# 配置文件说明

本项目使用 Spring Boot 的 properties 格式配置文件，支持多环境配置。

## 配置文件结构

- `application.properties` - 基础配置，包含默认设置
- `application-dev.properties` - 开发环境配置（包含占位符，可修改）
- `application-pro.properties` - 生产环境配置（支持环境变量，推荐使用环境变量）

**注意**：
- 配置文件中的密码和密钥都是占位符，请根据实际情况修改
- 生产环境强烈建议使用环境变量而不是直接修改配置文件
- 如果需要在本地覆盖配置而不提交，可以直接修改对应的 `application-{profile}.properties` 文件，但注意不要提交包含真实密码的配置

## 环境切换

### 方式一：通过 application.properties 设置（默认）

在 `application.properties` 中设置：
```properties
spring.profiles.active=dev  # 开发环境
# 或
spring.profiles.active=pro  # 生产环境
```

### 方式二：通过启动参数设置

**Maven 启动：**
```bash
mvn spring-boot:run -Dspring-boot.run.arguments="--spring.profiles.active=pro"
```

**JAR 包启动：**
```bash
java -jar remark-backend.jar --spring.profiles.active=pro
```

**IDE 启动（IntelliJ IDEA / Eclipse）：**
在运行配置的 VM options 或 Program arguments 中添加：
```
-Dspring.profiles.active=pro
```
或
```
--spring.profiles.active=pro
```

### 方式三：通过环境变量设置

```bash
export SPRING_PROFILES_ACTIVE=pro
java -jar remark-backend.jar
```

## 环境配置说明

### 开发环境 (DEV)

- **端口**: 8080
- **数据库**: 本地 MySQL，SSL 关闭
- **日志级别**: DEBUG（详细日志）
- **JWT 密钥**: 开发用密钥（请勿在生产环境使用）

### 生产环境 (PRO)

- **端口**: 8080（可通过环境变量覆盖）
- **数据库**: 支持环境变量配置，默认启用 SSL
- **连接池**: 已优化连接池配置
- **日志级别**: INFO/WARN（减少日志输出）
- **JWT 密钥**: 支持环境变量配置（建议使用强密钥）

## 环境变量配置（生产环境推荐）

生产环境建议使用环境变量来管理敏感信息，避免将密码等敏感信息写入配置文件。

支持的环境变量：

```bash
# 数据库配置
export DB_URL=jdbc:mysql://your-db-host:3306/remark_money?useUnicode=true&characterEncoding=utf-8&useSSL=true&serverTimezone=UTC
export DB_USERNAME=your_db_username
export DB_PASSWORD=your_db_password

# JWT 配置
export JWT_SECRET=your_very_long_and_random_jwt_secret_key

# 微信配置
export WECHAT_APP_ID=your_wechat_appid
export WECHAT_APP_SECRET=your_wechat_appsecret
```

## 配置优先级

Spring Boot 配置加载优先级（从高到低）：
1. 命令行参数（`--key=value`）
2. 环境变量（`SPRING_DATASOURCE_PASSWORD` 或 `DB_PASSWORD`）
3. `application-{profile}.properties`（根据激活的 profile）
4. `application.properties`（基础配置）

**注意**：Spring Boot 会自动将环境变量转换为配置属性，例如：
- `DB_PASSWORD` → `spring.datasource.password`
- `JWT_SECRET` → `auth.jwt-secret`
- `WECHAT_APP_ID` → `weixin.app-id`

## 注意事项

1. **生产环境部署前**：
   - 修改 `application-pro.properties` 中的默认密码和密钥
   - 或使用环境变量覆盖敏感配置
   - 确保数据库连接使用 SSL

2. **开发环境**：
   - 可以直接修改 `application-dev.properties` 中的配置
   - 如果包含敏感信息，建议使用环境变量或本地配置文件（不会被提交）

3. **配置文件安全**：
   - 不要将包含真实密码的配置文件提交到版本控制系统
   - 生产环境敏感信息建议使用环境变量或配置中心管理

## 示例：Docker 部署

```dockerfile
# Dockerfile
FROM openjdk:8-jre-alpine
COPY target/remark-backend.jar app.jar
ENV SPRING_PROFILES_ACTIVE=pro
ENV DB_URL=jdbc:mysql://db:3306/remark_money
ENV DB_USERNAME=root
ENV DB_PASSWORD=your_password
ENV JWT_SECRET=your_jwt_secret
CMD ["java", "-jar", "app.jar"]
```

