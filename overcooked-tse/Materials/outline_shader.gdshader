// outline_shader.gdshader
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_front, unshaded; // Key render modes

// Uniforms (parameters you can control from the material or script)
uniform bool outline_enabled = false; // The switch to turn the outline on/off
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // White outline by default
uniform float outline_width : hint_range(0.0, 10.0) = 1.0; // Outline thickness

void vertex() {
    // Only modify the vertex position if the outline is enabled
    if (outline_enabled) {
        // Push the vertex outwards along its normal direction
        // The amount is controlled by outline_width (scaled slightly for view distance)
        VERTEX += NORMAL * outline_width * 0.01 * VIEW_MATRIX[3][3];
    } else {
        // If outline is disabled, make this pass invisible by pushing vertices far away
        // (Alternatively, could control visibility in fragment shader)
        VERTEX.z = 10000.0; // Push way back if outline is off
    }
}

void fragment() {
    // Only set the color if the outline is enabled
    if (outline_enabled) {
        // Set the fragment color to the specified outline color
        ALBEDO = outline_color.rgb;
        ALPHA = outline_color.a;
    } else {
        // Discard the fragment if the outline is disabled for this pass
        discard; // Or ALPHA = 0.0;
    }
}
