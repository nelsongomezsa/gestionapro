# GestionAp PRO API · imagen de producción (perfil prod; todo por variables de entorno).
# Construir desde api/:   docker build -t gestionapro-api .
# Variables obligatorias: DB_URL, DB_USER, DB_PASS, JWT_SECRET. Opcionales: ANTHROPIC_API_KEY,
# MAIL_HOST/MAIL_USER/MAIL_PASS, GESTIONAP_ARCHIVOS_DIR (por defecto /data/archivos, en un volumen).

# 1) Compilación con Maven (las dependencias se cachean en su propia capa).
FROM maven:3.9-eclipse-temurin-21 AS compilacion
WORKDIR /src
COPY pom.xml .
RUN mvn -q -B dependency:go-offline
COPY src ./src
RUN mvn -q -B package -DskipTests

# 2) Ejecución: solo el JRE, usuario sin privilegios.
FROM eclipse-temurin:21-jre
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
RUN useradd --system --uid 10001 gestionap && mkdir -p /data/archivos && chown -R gestionap /data
WORKDIR /app
COPY --from=compilacion /src/target/gestionapro-api-*.jar app.jar
USER gestionap
ENV SPRING_PROFILES_ACTIVE=prod \
    JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError"
VOLUME /data/archivos
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -fsS http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
