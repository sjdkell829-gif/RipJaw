FROM perl:5.38

WORKDIR /app

# Build tools + dependencias del sistema para compilar módulos Perl
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    make \
    libsqlite3-dev \
    sqlite3 \
    curl \
    libssl-dev \
    zlib1g-dev \
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

EXPOSE 3000

ENV JWT_SECRET=cambiar_en_produccion \
    DB_PATH=/data/smash.db \
    MOJO_MODE=production

CMD ["perl", "smashapi.pl", "daemon", "-l", "http://*:3000"]