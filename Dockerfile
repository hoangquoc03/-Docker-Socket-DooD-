FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /build
COPY src/main/java/com/quickbite/delivery/DeliveryService.java ./DeliveryService.java
RUN mkdir -p /out \
    && javac --add-modules jdk.httpserver -d /out DeliveryService.java

FROM eclipse-temurin:17-jre-alpine AS runtime
WORKDIR /app
RUN addgroup -S app && adduser -S -G app app
COPY --from=builder --chown=app:app /out/ ./
USER app
EXPOSE 8080
ENTRYPOINT ["java", "--add-modules", "jdk.httpserver", "-cp", "/app", "com.quickbite.delivery.DeliveryService"]