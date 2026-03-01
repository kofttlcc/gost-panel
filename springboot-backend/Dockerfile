# 构建阶段
FROM maven:3.9.6-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# 运行阶段
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
ENV JAVA_OPTS="-Xmx128m -Xms64m -Xss256k -XX:ReservedCodeCacheSize=64m -XX:CompressedClassSpaceSize=32m -XX:MaxDirectMemorySize=64m -XX:MaxMetaspaceSize=128m -XX:+UseSerialGC -Dfile.encoding=UTF-8 -Duser.timezone=Asia/Shanghai"
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV MALLOC_ARENA_MAX=2

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories \
    && apk update \
    && apk upgrade \
    && apk add --no-cache fontconfig ttf-dejavu

COPY --from=build /app/target/*.jar app.jar
EXPOSE 6365

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]
