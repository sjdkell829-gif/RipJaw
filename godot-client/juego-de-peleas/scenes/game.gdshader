shader_type canvas_item;
void fragment() {
    vec4 col = texture(TEXTURE, UV);
    if (col.g > 0.5 && col.r < 0.5 && col.b < 0.5) {
        col.a = 0.0;
    }
    COLOR = col;
}