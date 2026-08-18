shader_type canvas_item;

// Full-screen TV static / white noise, used for the "Great Static" cinematic
// beat (the world shattering into the Void). Cheap hash noise, quantized in
// time so it reads as flickering broadcast static rather than a smooth
// dissolve — no textures needed.

uniform float intensity : hint_range(0.0, 1.0) = 0.4;
uniform float cells_x : hint_range(32.0, 640.0) = 320.0;
uniform float cells_y : hint_range(18.0, 360.0) = 180.0;
uniform float fps : hint_range(1.0, 60.0) = 20.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 cell = floor(UV * vec2(cells_x, cells_y));
	float frame = floor(TIME * fps);
	float n = hash(cell + frame * 17.13);
	COLOR = vec4(vec3(n), intensity);
}
