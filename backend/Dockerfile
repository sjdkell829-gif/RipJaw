FROM perl:5.38-slim

WORKDIR /app

# Dependencias del sistema
RUN apt-get update && apt-get install -y \
    libsqlite3-dev \
    sqlite3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Instalar módulos Perl necesarios
RUN cpanm --notest \
    Mojolicious \
    DBI \
    DBD::SQLite \
    Digest::SHA \
    MIME::Base64 \
    JSON::PP \
    IO::Socket::SSL \
    Mojo::WebSocket

# Copiar código del servidor
COPY . .

# Crear directorio de datos e inicializar la base de datos
RUN mkdir -p /data && \
    sqlite3 /data/smash.db < db/schema.sql

# Puerto REST (WebSocket también corre en el mismo puerto con Mojolicious)
EXPOSE 3000

# Variables de entorno con defaults
ENV JWT_SECRET=cambiar_en_produccion \
    DB_PATH=/data/smash.db \
    MOJO_MODE=production

CMD ["perl", "smashapi.pl", "daemon", "-l", "http://*:3000"]