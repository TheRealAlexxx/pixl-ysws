shader_type canvas_item;

// Discards anything outside a circle inscribed in the node's own rect. UV is
// well-defined 0..1 here because this only ever draws a single TextureRect
// (the minimap's SubViewport output), not a composite of several draw_*
// calls with their own local UV spaces.
void fragment() {
	COLOR = texture(TEXTURE, UV);
	if (length(UV - vec2(0.5)) > 0.5) {
		discard;
	}
}
