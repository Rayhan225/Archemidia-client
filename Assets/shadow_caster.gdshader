shader_type canvas_item;

// This shader is designed to render the shadow geometry as a solid,
// opaque mask. This allows us to use the Godot Light2D system's
// SHADOW_CASTING feature and handle shadow collapse via light logic.

// We use the vertex function to apply the skewing and scaling
// calculation from the GDScript, but calculated in the GPU.

uniform float skew_val = 0.0;
uniform float scale_y = -1.0;
uniform float scale_x = 1.0;

void vertex() {
    // 1. Apply the Skew (Shearing) in World Space
    // The position is already relative to the pivot (object's feet).
    // The skew operation shifts the X coordinate based on the Y coordinate.
    // The shadow sprite offset draws UP (negative Y in local space).
    // Positive skew_val (leaning right) is applied along the Y-axis.
    
    // We only apply skew, as rotation is 0.
    VERTEX.x += VERTEX.y * skew_val;

    // 2. Apply Scale (Flattening and Stretching)
    // Scale X is for width, Scale Y is for length (which is also negative for flipping the projection).
    VERTEX.x *= scale_x;
    VERTEX.y *= scale_y;
}

void fragment() {
    // 3. Render the shape as Opaque Black
    // This creates a clean mask for the Light2D node to use.
    COLOR = vec4(0.0, 0.0, 0.0, 1.0);
}