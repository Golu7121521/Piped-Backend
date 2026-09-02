FROM eclipse-temurin:21-jdk AS build

WORKDIR /app/

COPY . /app/

RUN --mount=type=cache,target=/root/.gradle/caches/ \
 ./gradlew shadowJar

FROM eclipse-temurin:21-jre

RUN --mount=type=cache,target=/var/cache/apt/ \
 apt-get update && \
 apt-get install -y --no-install-recommends \
  curl \
  && \
 apt-get clean && \
 rm -rf /var/lib/apt/lists/*

WORKDIR /app/

COPY hotspot-entrypoint.sh docker-healthcheck.sh /

COPY --from=build /app/build/libs/piped-1.0-all.jar /app/piped.jar

COPY VERSION .

# Create a secure startup script to handle environment variables
RUN echo '#!/bin/sh' > /app/start.sh && \
    echo 'echo "PORT=8080" > /app/config.properties' >> /app/start.sh && \
    echo 'echo "hibernate.connection.driver_class=org.postgresql.Driver" >> /app/config.properties' >> /app/start.sh && \
    echo 'echo "hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect" >> /app/config.properties' >> /app/start.sh && \
    echo 'echo "hibernate.connection.url=${SPRING_DATASOURCE_URL}" >> /app/config.properties' >> /app/start.sh && \
    echo 'echo "hibernate.connection.username=${SPRING_DATASOURCE_USERNAME}" >> /app/config.properties' >> /app/start.sh && \
    echo 'echo "hibernate.connection.password=${SPRING_DATASOURCE_PASSWORD}" >> /app/config.properties' >> /app/start.sh && \
    echo 'echo "--- Configuration Created ---"' >> /app/start.sh && \
    echo 'cat /app/config.properties | grep -v password' >> /app/start.sh && \
    echo 'exec /hotspot-entrypoint.sh' >> /app/start.sh && \
    chmod +x /app/start.sh

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 CMD /docker-healthcheck.sh

ENTRYPOINT ["/app/start.sh"]
