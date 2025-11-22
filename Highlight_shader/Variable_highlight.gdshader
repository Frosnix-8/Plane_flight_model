shader_type spatial;
render_mode unshaded;

 instance uniform float opacity2 : hint_range(0.0, 1.0) = 0.0;
 instance uniform vec3 highlight_color : source_color = vec3(0.384, 0.694, 1.0);
 instance uniform vec3 click_color : source_color = vec3(0.);

void fragment() {
	if (opacity2 <= 0.0001) {
		discard;
	}
	ALBEDO = highlight_color;
	ALPHA = opacity2;
}
