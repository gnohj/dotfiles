#language slang 2026
// Port of ghostty/shaders/cursor_smear_fade.glsl onto kitty's cursor_trail_* uniforms.

import kitty_custom_shader_types;

static const float3 TRAIL_COLOR = float3(0.3813, 0.6939, 0.5225);
static const float DURATION = 0.5;

float
sdf_rectangle(float2 p, float2 xy, float2 b) {
    float2 d = abs(p - xy) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float
seg(float2 p, float2 a, float2 b, inout float s, float d) {
    float2 e = b - a;
    float2 w = p - a;
    float2 proj = a + e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
    float segd = dot(p - proj, p - proj);
    d = min(d, segd);

    float c0 = step(0.0, p.y - a.y);
    float c1 = 1.0 - step(0.0, p.y - b.y);
    float c2 = 1.0 - step(0.0, e.x * w.y - e.y * w.x);
    float all_cond = c0 * c1 * c2;
    float none_cond = (1.0 - c0) * (1.0 - c1) * (1.0 - c2);
    s *= lerp(1.0, -1.0, step(0.5, all_cond + none_cond));
    return d;
}

float
sdf_parallelogram(float2 p, float2 v0, float2 v1, float2 v2, float2 v3) {
    float s = 1.0;
    float d = dot(p - v0, p - v0);
    d = seg(p, v0, v3, s, d);
    d = seg(p, v1, v0, s, d);
    d = seg(p, v2, v1, s, d);
    d = seg(p, v3, v2, s, d);
    return s * sqrt(d);
}

float2
to_aspect_space(float2 value, float is_position, float2 res) {
    return (value * 2.0 - res * is_position) / res.y;
}

float
antialias(float distance, float2 res) {
    return 1.0 - smoothstep(0.0, to_aspect_space(float2(2.0), 0.0, res).x, distance);
}

float
start_vertex_factor(float2 a, float2 b) {
    float condition1 = step(b.x, a.x) * step(a.y, b.y);
    float condition2 = step(a.x, b.x) * step(b.y, a.y);
    return 1.0 - max(condition1, condition2);
}

float2
rectangle_center(float4 r) {
    return float2(r.x + r.z / 2.0, r.y - r.w / 2.0);
}

float4
cursor_rect(float4 edge, float2 res) {
    float4 px = float4(edge.x * res.x, edge.z * res.y, (edge.y - edge.x) * res.x, (edge.z - edge.w) * res.y);
    return float4(to_aspect_space(px.xy, 1.0, res), to_aspect_space(px.zw, 0.0, res));
}

public float4
fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
    if (all(d.cursor_trail_prev_edge == float4(0.0))) return color;

    float2 res = float2(d.viewport_size_pixels);
    float2 vu = to_aspect_space(t.pos * res, 1.0, res);
    float2 offset_factor = float2(-0.5, 0.5);

    float4 current = cursor_rect(d.cursor_trail_edge, res);
    float4 previous = cursor_rect(d.cursor_trail_prev_edge, res);

    float vertex_factor = start_vertex_factor(current.xy, previous.xy);
    float inverted = 1.0 - vertex_factor;

    float2 v0 = float2(current.x + current.z * vertex_factor, current.y - current.w);
    float2 v1 = float2(current.x + current.z * inverted, current.y);
    float2 v2 = float2(previous.x + current.z * inverted, previous.y);
    float2 v3 = float2(previous.x + current.z * vertex_factor, previous.y - previous.w);

    float sdf_cursor = sdf_rectangle(vu, current.xy - current.zw * offset_factor, current.zw * 0.5);
    float sdf_trail = sdf_parallelogram(vu, v0, v1, v2, v3);

    float progress = clamp((d.timestamp - d.cursor_trail_change_time) / DURATION, 0.0, 1.0);
    float eased = pow(1.0 - progress, 3.0);
    float line_length = distance(rectangle_center(current), rectangle_center(previous));

    float fade = 1.0 - smoothstep(line_length, sdf_cursor, eased * line_length);
    float3 trail = TRAIL_COLOR * fade;

    float3 result = lerp(color.rgb, trail, antialias(sdf_trail, res));
    result = lerp(result, TRAIL_COLOR, antialias(sdf_cursor, res));
    result = lerp(result, color.rgb, step(sdf_cursor, 0.0));
    result = lerp(color.rgb, result, step(sdf_cursor, eased * line_length));
    return float4(result, color.a);
}
