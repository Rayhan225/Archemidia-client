shader_type canvas_item;

uniform vec4 water_color : source_color = vec4(0.2, 0.6, 0.8, 1.0);
uniform vec4 grid_color : source_color = vec4(1.0, 1.0, 1.0, 0.5); // Kept for compatibility, unused
uniform float tile_size = 64.0;
uniform vec2 rect_size = vec2(4000.0, 4000.0);
uniform float animation_speed = 3.0; 
uniform float bounce_height = 4.0; 

// Hardcoded offset 
const vec2 MANUAL_OFFSET = vec2(0.0, 16.0); 

void fragment() {
    // 1. Calculate 3-Frame Animation Offset
    float frame = floor(mod(TIME * animation_speed, 3.0));
    
    float y_shift = 0.0;
    if (frame == 1.0) y_shift = -bounce_height;
    if (frame == 2.0) y_shift = bounce_height;
    
    // 2. Just output the water color
    // We removed the grid line logic entirely.
    COLOR = water_color;
}