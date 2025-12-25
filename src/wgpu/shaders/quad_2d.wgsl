// 2D Screen-space quad/circle shader
// Converts screen coordinates (Y-down, 0,0 = top-left) to clip space

struct ScreenUniforms {
    screen_size: vec2<f32>,
    _padding: vec2<f32>,
}

@group(0) @binding(0) var<uniform> screen: ScreenUniforms;

struct VertexInput {
    @location(0) position: vec2<f32>,
    @location(1) color: vec4<f32>,
}

struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) color: vec4<f32>,
}

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    
    // Convert screen coords to NDC
    // X: 0 -> -1, width -> 1
    // Y: 0 -> 1, height -> -1 (flip for clip space)
    let ndc_x = (in.position.x / screen.screen_size.x) * 2.0 - 1.0;
    let ndc_y = 1.0 - (in.position.y / screen.screen_size.y) * 2.0;
    
    out.clip_position = vec4<f32>(ndc_x, ndc_y, 0.0, 1.0);
    out.color = in.color;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    return in.color;
}
