using Microsoft.AspNetCore.Mvc;
using RipJawAPI.Services;

namespace RipJawAPI.Controllers
{
    [ApiController]
    [Route("api/matchmaking")]
    public class MatchmakingController : ControllerBase
    {
        private readonly MatchmakingService _matchmaking;
        public MatchmakingController(MatchmakingService matchmaking) => _matchmaking = matchmaking;

        [HttpPost("queue")]
        public IActionResult JoinQueue()
        {
            var playerIdClaim = User.FindFirst("player_id")?.Value;
            if (playerIdClaim == null) return Unauthorized(new { error = "No autenticado" });
            var result = _matchmaking.JoinQueue(int.Parse(playerIdClaim));
            return Ok(result);
        }

        [HttpDelete("queue")]
        public IActionResult LeaveQueue()
        {
            var playerIdClaim = User.FindFirst("player_id")?.Value;
            if (playerIdClaim == null) return Unauthorized();
            _matchmaking.LeaveQueue(int.Parse(playerIdClaim));
            return Ok(new { message = "Saliste de la cola" });
        }
    }
}