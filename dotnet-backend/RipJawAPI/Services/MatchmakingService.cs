namespace RipJawAPI.Services
{
    public class MatchmakingService
    {
        private readonly Dictionary<int, DateTime> _queue = new();

        public object JoinQueue(int playerId)
        {
            _queue[playerId] = DateTime.UtcNow;
            var opponent = _queue.Keys.FirstOrDefault(id => id != playerId);
            if (opponent != 0)
            {
                _queue.Remove(playerId);
                _queue.Remove(opponent);
                var roomId = $"{playerId}_{opponent}_{DateTimeOffset.UtcNow.ToUnixTimeSeconds()}";
                return new { status = "match_found", room_id = roomId, opponent_id = opponent, ws_url = $"wss://ripjaw-production.up.railway.app/game/{roomId}" };
            }
            return new { status = "waiting", message = "Buscando oponente..." };
        }

        public void LeaveQueue(int playerId) => _queue.Remove(playerId);
    }
}