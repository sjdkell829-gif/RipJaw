using System.ComponentModel.DataAnnotations;

namespace RipJawAPI.Models
{
    public class Player
    {
        public int Id { get; set; }
        [Required][MaxLength(50)]
        public string Username { get; set; } = string.Empty;
        [Required][MaxLength(100)]
        public string Email { get; set; } = string.Empty;
        [Required]
        public string PasswordHash { get; set; } = string.Empty;
        public int Elo { get; set; } = 1000;
        public int Wins { get; set; } = 0;
        public int Losses { get; set; } = 0;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }

    public class Match
    {
        public int Id { get; set; }
        public string RoomId { get; set; } = string.Empty;
        public int WinnerId { get; set; }
        public int LoserId { get; set; }
        public DateTime PlayedAt { get; set; } = DateTime.UtcNow;
    }
}