#!/usr/bin/env perl
use strict;
use warnings;
use Mojolicious::Lite -signatures;
use Mojo::JSON qw(decode_json encode_json);

# ============================================================
#   SmashAPI — Backend Principal (Perl + Mojolicious)
# ============================================================

# Configuración
my $SECRET = $ENV{JWT_SECRET} // 'smashapi_secret_cambiar_en_produccion';
app->config(
    hypnotoad => {
        listen  => ['http://*:3000'],
        workers => 4,
    }
);

# Middleware: CORS
hook before_dispatch => sub ($c) {
    $c->res->headers->header('Access-Control-Allow-Origin'  => '*');
    $c->res->headers->header('Access-Control-Allow-Methods' => 'GET, POST, PUT, DELETE, OPTIONS');
    $c->res->headers->header('Access-Control-Allow-Headers' => 'Content-Type, Authorization');
    return if $c->req->method ne 'OPTIONS';
    $c->render(text => '', status => 200);
    $c->reply->rendered(200);
};

# ============================================================
#   Inicializar DB
# ============================================================
use DBI;
my $dbh;

sub get_db {
    unless ($dbh && $dbh->ping) {
        my $db_path = $ENV{DB_PATH} // "smash.db";
        $dbh = DBI->connect(
            "dbi:SQLite:dbname=$db_path",
            '', '',
            { RaiseError => 1, AutoCommit => 1, sqlite_unicode => 1 }
        ) or die "No se puede conectar a la DB: $DBI::errstr";
        _init_db($dbh);
    }
    return $dbh;
}

sub _init_db {
    my ($db) = @_;
    $db->do(q{
        CREATE TABLE IF NOT EXISTS players (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            username      TEXT NOT NULL UNIQUE,
            email         TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            elo           INTEGER DEFAULT 1000,
            wins          INTEGER DEFAULT 0,
            losses        INTEGER DEFAULT 0,
            created_at    DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    });
    $db->do(q{
        CREATE TABLE IF NOT EXISTS matches (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            room_id    TEXT NOT NULL,
            winner_id  INTEGER NOT NULL,
            loser_id   INTEGER NOT NULL,
            played_at  DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    });
    $db->do(q{
        CREATE TABLE IF NOT EXISTS queue (
            player_id  INTEGER PRIMARY KEY,
            username   TEXT NOT NULL,
            joined_at  INTEGER NOT NULL
        )
    });
    $db->do(q{
        CREATE TABLE IF NOT EXISTS rooms (
            room_id    TEXT PRIMARY KEY,
            p1_id      INTEGER NOT NULL,
            p2_id      INTEGER NOT NULL,
            created_at INTEGER NOT NULL
        )
    });
}

# ============================================================
#   Helpers: JWT simple
# ============================================================
use MIME::Base64 qw(encode_base64url decode_base64url);
use Digest::SHA qw(hmac_sha256);

sub create_token {
    my ($payload) = @_;
    my $header  = encode_base64url('{"alg":"HS256","typ":"JWT"}');
    my $body    = encode_base64url(encode_json($payload));
    my $sig     = encode_base64url(hmac_sha256("$header.$body", $SECRET));
    return "$header.$body.$sig";
}

sub verify_token {
    my ($token) = @_;
    return undef unless $token;
    my ($header, $body, $sig) = split /\./, $token;
    return undef unless $header && $body && $sig;
    my $expected = encode_base64url(hmac_sha256("$header.$body", $SECRET));
    return undef unless $sig eq $expected;
    return decode_json(decode_base64url($body));
}

helper auth_required => sub ($c) {
    my $auth  = $c->req->headers->authorization // '';
    my $token = $auth =~ s/^Bearer //r;
    my $data  = verify_token($token);
    unless ($data) {
        $c->render(json => { error => 'No autorizado' }, status => 401);
        return undef;
    }
    return $data;
};

# ============================================================
#   RUTAS: Autenticación
# ============================================================

# POST /api/auth/register
post '/api/auth/register' => sub ($c) {
    my $params   = $c->req->json;
    my $username = $params->{username} // '';
    my $password = $params->{password} // '';
    my $email    = $params->{email}    // '';

    unless ($username && $password && $email) {
        return $c->render(json => { error => 'Faltan campos requeridos' }, status => 400);
    }

    my $db = get_db();

    # Verificar si ya existe
    my $exists = $db->selectrow_hashref(
        "SELECT id FROM players WHERE username = ? OR email = ?",
        undef, $username, $email
    );
    if ($exists) {
        return $c->render(json => { error => 'Usuario o email ya existe' }, status => 409);
    }

    # Hash de contraseña (simple para ejemplo — usar bcrypt en producción)
    use Digest::SHA qw(sha256_hex);
    my $pass_hash = sha256_hex($password . $SECRET);

    $db->do(
        "INSERT INTO players (username, email, password_hash, created_at) VALUES (?, ?, ?, datetime('now'))",
        undef, $username, $email, $pass_hash
    );
    my $player_id = $db->last_insert_id('', '', 'players', 'id');

    my $token = create_token({ player_id => $player_id, username => $username });

    $c->render(json => {
        message   => 'Cuenta creada exitosamente',
        token     => $token,
        player_id => $player_id,
        username  => $username,
    }, status => 201);
};

# POST /api/auth/login
post '/api/auth/login' => sub ($c) {
    my $params   = $c->req->json;
    my $username = $params->{username} // '';
    my $password = $params->{password} // '';

    use Digest::SHA qw(sha256_hex);
    my $pass_hash = sha256_hex($password . $SECRET);

    my $db     = get_db();
    my $player = $db->selectrow_hashref(
        "SELECT id, username, email, elo FROM players WHERE username = ? AND password_hash = ?",
        undef, $username, $pass_hash
    );

    unless ($player) {
        return $c->render(json => { error => 'Credenciales incorrectas' }, status => 401);
    }

    my $token = create_token({ player_id => $player->{id}, username => $player->{username} });

    $c->render(json => {
        token     => $token,
        player_id => $player->{id},
        username  => $player->{username},
        elo       => $player->{elo},
    });
};

# GET /api/auth/me
get '/api/auth/me' => sub ($c) {
    my $auth = $c->auth_required;
    return unless $auth;

    my $db     = get_db();
    my $player = $db->selectrow_hashref(
        "SELECT id, username, email, elo, wins, losses, created_at FROM players WHERE id = ?",
        undef, $auth->{player_id}
    );

    $c->render(json => $player);
};

# ============================================================
#   RUTAS: Jugadores
# ============================================================

# GET /api/players/ranking — Top 100
get '/api/players/ranking' => sub ($c) {
    my $db = get_db();
    my $players = $db->selectall_arrayref(
        "SELECT id, username, elo, wins, losses FROM players ORDER BY elo DESC LIMIT 100",
        { Slice => {} }
    );
    $c->render(json => { ranking => $players });
};

# GET /api/players/:id — Perfil
get '/api/players/:id' => sub ($c) {
    my $db     = get_db();
    my $player = $db->selectrow_hashref(
        "SELECT id, username, elo, wins, losses, created_at FROM players WHERE id = ?",
        undef, $c->param('id')
    );
    return $c->render(json => { error => 'Jugador no encontrado' }, status => 404) unless $player;
    $c->render(json => $player);
};

# ============================================================
#   RUTAS: Matchmaking
# ============================================================
# URL base del servidor
my $SERVER_URL = $ENV{RAILWAY_PUBLIC_DOMAIN}
    ? "wss://$ENV{RAILWAY_PUBLIC_DOMAIN}"
    : "ws://localhost:3000";

# POST /api/matchmaking/queue — Unirse a la cola
post '/api/matchmaking/queue' => sub ($c) {
    my $auth = $c->auth_required;
    return unless $auth;

    my $player_id = $auth->{player_id};
    my $db        = get_db();

    # Verificar si ya tiene un room asignado
    my $room = $db->selectrow_hashref(
        "SELECT room_id, p1_id, p2_id FROM rooms WHERE p1_id = ? OR p2_id = ? ORDER BY created_at DESC LIMIT 1",
        undef, $player_id, $player_id
    );
    if ($room) {
        my $opponent_id = $room->{p1_id} == $player_id ? $room->{p2_id} : $room->{p1_id};
        return $c->render(json => {
            status      => 'match_found',
            room_id     => $room->{room_id},
            opponent_id => $opponent_id,
            ws_url      => "$SERVER_URL/game/$room->{room_id}",
        });
    }

    # Buscar si hay alguien esperando en la cola
    my $opponent = $db->selectrow_hashref(
        "SELECT player_id FROM queue WHERE player_id != ? ORDER BY joined_at ASC LIMIT 1",
        undef, $player_id
    );

    if ($opponent) {
        # Hay alguien esperando — el que llega segundo crea el room
        my $opponent_id = $opponent->{player_id};

        # El que llego primero es p1, el segundo es p2
        my $p1_id   = $opponent_id;
        my $p2_id   = $player_id;
        my $room_id = sprintf("%d_%d_%d", $p1_id, $p2_id, time());

        # Guardar room y limpiar cola
        $db->do(
            "INSERT INTO rooms (room_id, p1_id, p2_id, created_at) VALUES (?, ?, ?, ?)",
            undef, $room_id, $p1_id, $p2_id, time()
        );
        $db->do("DELETE FROM queue WHERE player_id IN (?, ?)", undef, $player_id, $opponent_id);

        return $c->render(json => {
            status      => 'match_found',
            room_id     => $room_id,
            opponent_id => $opponent_id,
            ws_url      => "$SERVER_URL/game/$room_id",
        });
    }

    # No hay nadie — agregar a la cola y esperar
    $db->do(
        "INSERT OR REPLACE INTO queue (player_id, username, joined_at) VALUES (?, ?, ?)",
        undef, $player_id, $auth->{username}, time()
    );

    $c->render(json => {
        status  => 'waiting',
        message => 'Buscando oponente...',
    });
};

# DELETE /api/matchmaking/queue — Salir de la cola
del '/api/matchmaking/queue' => sub ($c) {
    my $auth = $c->auth_required;
    return unless $auth;
    delete $queue{$auth->{player_id}};
    $c->render(json => { message => 'Saliste de la cola' });
};

# ============================================================
#   RUTAS: Partidas
# ============================================================

# POST /api/match/result — Reportar resultado
post '/api/match/result' => sub ($c) {
    my $auth   = $c->auth_required;
    return unless $auth;

    my $params    = $c->req->json;
    my $winner_id = $params->{winner_id};
    my $loser_id  = $params->{loser_id};
    my $room_id   = $params->{room_id};

    my $db = get_db();
    $db->do(
        "INSERT INTO matches (room_id, winner_id, loser_id, played_at) VALUES (?, ?, ?, datetime('now'))",
        undef, $room_id, $winner_id, $loser_id
    );

    # Actualizar stats
    $db->do("UPDATE players SET wins = wins + 1, elo = elo + 25 WHERE id = ?",  undef, $winner_id);
    $db->do("UPDATE players SET losses = losses + 1, elo = MAX(0, elo - 15) WHERE id = ?", undef, $loser_id);

    $c->render(json => { message => 'Resultado guardado', elo_change => { winner => '+25', loser => '-15' } });
};

# GET /api/match/history/:player_id — Historial
get '/api/match/history/:player_id' => sub ($c) {
    my $db      = get_db();
    my $matches = $db->selectall_arrayref(
        "SELECT m.room_id, m.winner_id, m.loser_id, m.played_at,
                pw.username as winner_name, pl.username as loser_name
         FROM matches m
         JOIN players pw ON pw.id = m.winner_id
         JOIN players pl ON pl.id = m.loser_id
         WHERE m.winner_id = ? OR m.loser_id = ?
         ORDER BY m.played_at DESC LIMIT 20",
        { Slice => {} }, $c->param('player_id'), $c->param('player_id')
    );
    $c->render(json => { matches => $matches });
};

# ============================================================
#   WebSocket — Sincronización en tiempo real
# ============================================================
my %rooms;  # room_id => [ connection1, connection2 ]

websocket '/game/:room_id' => sub ($c) {
    my $room_id = $c->param('room_id');
    $c->inactivity_timeout(0);

    # Unir al room
    push @{$rooms{$room_id}}, $c->tx;
    my $player_num = scalar @{$rooms{$room_id}};
    app->log->info("Jugador $player_num se unió al room $room_id");

    # Notificar si ya hay 2 jugadores
    if ($player_num == 2) {
        for my $tx (@{$rooms{$room_id}}) {
            $tx->send({ json => { type => 'game_start', message => '¡La batalla comienza!' } });
        }
    }

    $c->on(message => sub ($c, $msg) {
        my $data = decode_json($msg);

        # Broadcast a todos en el room (excepto el remitente)
        for my $tx (@{$rooms{$room_id}}) {
            next if $tx == $c->tx;
            $tx->send({ json => $data });
        }
    });

    $c->on(finish => sub ($c, $code, $reason) {
        # Limpiar conexión del room
        $rooms{$room_id} = [grep { $_ != $c->tx } @{$rooms{$room_id} // []}];
        delete $rooms{$room_id} unless @{$rooms{$room_id}};
        app->log->info("Jugador salió del room $room_id");
    });
};

# ============================================================
#   Iniciar servidor
# ============================================================
app->start;