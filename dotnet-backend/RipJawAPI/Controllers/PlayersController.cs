using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RipJawAPI.Data;

namespace RipJawAPI.Controllers
{
    [ApiController]
    [Route("api/players")]
    public class PlayersController : ControllerBase
    {
        private readonly AppDbContext _db;
        public PlayersController(AppDbContext db) => _db = db;

        [HttpGet("ranking")]
        public async Task<IActionResult> GetRanking()
        {
            var players = await _db.Players
                .OrderByDescending(p => p.Elo)
                .Take(100)
                .Select(p => new { p.Id, p.Username, p.Elo, p.Wins, p.Losses })
                .ToListAsync();
            return Ok(new { ranking = players });
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetPlayer(int id)
        {
            var player = await _db.Players
                .Where(p => p.Id == id)
                .Select(p => new { p.Id, p.Username, p.Elo, p.Wins, p.Losses, p.CreatedAt })
                .FirstOrDefaultAsync();
            if (player == null) return NotFound(new { error = "Jugador no encontrado" });
            return Ok(player);
        }
    }
}