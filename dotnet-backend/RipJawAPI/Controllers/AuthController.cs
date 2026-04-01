using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using RipJawAPI.Data;
using RipJawAPI.Models;

namespace RipJawAPI.Controllers
{
    [ApiController]
    [Route("api/auth")]
    public class AuthController : ControllerBase
    {
        private readonly AppDbContext _db;
        private readonly IConfiguration _config;

        public AuthController(AppDbContext db, IConfiguration config)
        {
            _db = db;
            _config = config;
        }

        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] RegisterRequest req)
        {
            if (await _db.Players.AnyAsync(p => p.Username == req.Username || p.Email == req.Email))
                return Conflict(new { error = "Usuario o email ya existe" });

            var player = new Player
            {
                Username = req.Username,
                Email = req.Email,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.Password)
            };
            _db.Players.Add(player);
            await _db.SaveChangesAsync();

            var token = GenerateToken(player);
            return StatusCode(201, new { message = "Cuenta creada", token, player_id = player.Id, username = player.Username });
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginRequest req)
        {
            var player = await _db.Players.FirstOrDefaultAsync(p => p.Username == req.Username);
            if (player == null || !BCrypt.Net.BCrypt.Verify(req.Password, player.PasswordHash))
                return Unauthorized(new { error = "Credenciales incorrectas" });

            var token = GenerateToken(player);
            return Ok(new { token, player_id = player.Id, username = player.Username, elo = player.Elo });
        }

        private string GenerateToken(Player player)
        {
            var secret = _config["JWT_SECRET"] ?? "ripjaw_dev_secret_super_seguro_32chars!!";
            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
            var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
            var claims = new[] {
                new Claim("player_id", player.Id.ToString()),
                new Claim("username", player.Username)
            };
            var token = new JwtSecurityToken(claims: claims, expires: DateTime.UtcNow.AddDays(30), signingCredentials: creds);
            return new JwtSecurityTokenHandler().WriteToken(token);
        }
    }

    public record RegisterRequest(string Username, string Email, string Password);
    public record LoginRequest(string Username, string Password);
}