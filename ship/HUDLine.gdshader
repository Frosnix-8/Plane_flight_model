shader_type spatial;
render_mode unshaded, cull_back, vertex_lighting;

uniform vec3 linecolor : source_color = vec3(0.);
uniform float max_dist = 3.0;
varying float distance_to_cam;

void vertex() {
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX,1.0);
	distance_to_cam = length(view_pos.xyz);
}
void fragment() {
	if (distance_to_cam >= max_dist) {
		discard;
	}
	ALBEDO = linecolor;
}


//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
