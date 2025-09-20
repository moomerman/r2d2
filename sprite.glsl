@header package r2d2
@header import sg ".deps/github.com/floooh/sokol-odin/sokol/gfx"

@ctype mat4 Mat4

@vs vs
layout(binding=0) uniform uniforms {
    mat4 projection;
} uni;

in vec2 position;
in vec2 texcoord;
in vec4 color;

out vec2 frag_uv;
out vec4 frag_color;

void main() {
    gl_Position = uni.projection * vec4(position, 0.0, 1.0);
    frag_uv = texcoord;
    frag_color = color;
}
@end

@fs fs
layout(binding=0) uniform texture2D tex;
layout(binding=0) uniform sampler smp;

in vec2 frag_uv;
in vec4 frag_color;

out vec4 color;

void main() {
    color = texture(sampler2D(tex, smp), frag_uv) * frag_color;
}
@end

@program sprite vs fs
