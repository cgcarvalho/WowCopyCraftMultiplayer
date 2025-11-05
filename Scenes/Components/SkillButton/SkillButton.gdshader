shader_type canvas_item;
uniform vec4 glow_color : source_color;
uniform float glow_power = 1.0;

void fragment() {
    COLOR = texture(TEXTURE, UV);
    COLOR.rgb += glow_color.rgb * glow_power * COLOR.a;
}