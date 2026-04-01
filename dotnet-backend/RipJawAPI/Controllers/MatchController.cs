using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RipJawAPI.Data;
using RipJawAPI.Models;

namespace RipJawAPI.Controllers
{
    [ApiController]
    [Route("api/match")]
    public class MatchController : ControllerBase
    {
        private readonly AppDbContext _db;
        public MatchController(AppDbContext db) => _db = db;

        [HttpPost("result")]
        public async Task<IActionResult> ReportResult([FromBody] MatchResultRequest req)
        {
            _db.Matches.Add(new Match { RoomId = req.RoomId, WinnerId = req.WinnerId, LoserId = req.LoserId });
            var winner = await _db.Players.FindAsync(req.WinnerId);
            var loser = await _db.Players.FindAsync(req.LoserId);
            if (winner != null) { winner.Wins++; winner.Elo += 25; }
            if (loser != null) { loser.Losses++; loser.Elo = Math.Max(0, loser.Elo - 15); }
            await _db.SaveChangesAsync();
            return Ok(new { message = "Resultado guardado", elo_change = new { winner = "+25", loser = "-15" } });
        }

        [HttpGet("history/{playerId}")]
        public async Task<IActionResult> GetHistory(int playerId)
        {
            var matches = await _db.Matches
                .Where(m => m.WinnerId == playerId || m.LoserId == playerId)
                .OrderByDescending(m => m.PlayedAt).Take(20).ToListAsync();
            return Ok(new { matches });
        }
    }

    public record MatchResultRequest(string RoomId, int WinnerId, int LoserId);
}