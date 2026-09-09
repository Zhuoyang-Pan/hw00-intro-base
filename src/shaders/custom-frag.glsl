#version 300 es
precision highp float;

uniform vec4 u_Color;
uniform float u_Time;

in vec4 fs_Pos;
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;

out vec4 out_Col;

vec3 random3(vec3 p) {
    return fract(sin(vec3(
        dot(p, vec3(127.1, 311.7,  74.7)),
        dot(p, vec3(269.5, 183.3, 246.1)),
        dot(p, vec3(113.5, 271.9, 124.6))
    )) * 43758.5453) * 2.0 - 1.0;
}

// One corner's contribution: gradient dotted with the offset, quintic falloff.
float surflet(vec3 p, vec3 gridPoint) {
    vec3 d = abs(p - gridPoint);
    vec3 t = vec3(1.0) - 6.0 * pow(d, vec3(5.0))
                       + 15.0 * pow(d, vec3(4.0))
                       - 10.0 * pow(d, vec3(3.0));
    float height = dot(p - gridPoint, random3(gridPoint));
    return height * t.x * t.y * t.z;
}

float perlin3(vec3 p) {
    float sum = 0.0;
    vec3 base = floor(p);
    for (int dx = 0; dx <= 1; ++dx) {
        for (int dy = 0; dy <= 1; ++dy) {
            for (int dz = 0; dz <= 1; ++dz) {
                sum += surflet(p, base + vec3(float(dx), float(dy), float(dz)));
            }
        }
    }
    return sum;
}

float fbm3(vec3 p, int octaves) {
    float sum = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    for (int i = 0; i < octaves; ++i) {
        sum += amp * perlin3(p * freq);
        freq *= 2.0;
        amp *= 0.5;
    }
    return sum;
}

// One feature point per cell, searched over the 3x3x3 neighbourhood.
// Returns the two nearest distances; F2 - F1 hits zero on the cell borders.
vec2 worley3(vec3 p) {
    vec3 base = floor(p);
    vec3 f = fract(p);
    float f1 = 100.0;
    float f2 = 100.0;
    for (int dx = -1; dx <= 1; ++dx) {
        for (int dy = -1; dy <= 1; ++dy) {
            for (int dz = -1; dz <= 1; ++dz) {
                vec3 neighbor = vec3(float(dx), float(dy), float(dz));
                vec3 point = random3(base + neighbor) * 0.5 + 0.5;
                float d = length(neighbor + point - f);
                if (d < f1) {
                    f2 = f1;
                    f1 = d;
                } else if (d < f2) {
                    f2 = d;
                }
            }
        }
    }
    return vec2(f1, f2);
}

void main()
{
    vec3 p = fs_Pos.xyz;
    vec3 q = p * 2.0 + vec3(0.0, 0.0, u_Time * 0.12);

    // Warping the sample point by another noise field is what stretches the
    // round FBM blobs into marbling.
    vec3 warp = vec3(
        fbm3(q + vec3(13.1, 47.3, 91.7), 3),
        fbm3(q + vec3(71.9, 23.5, 37.1), 3),
        fbm3(q + vec3(53.3, 89.1, 11.7), 3)
    );
    float marble = fbm3(q + 2.5 * warp, 5);
    float t = clamp(marble * 3.0 + 0.5, 0.0, 1.0);

    // Whole palette comes off u_Color so the picker retints the material.
    vec3 crust = u_Color.rgb * 0.10;
    vec3 mid   = u_Color.rgb * 0.75;
    vec3 hot   = mix(u_Color.rgb, vec3(1.0, 0.93, 0.70), 0.75);

    vec3 albedo = mix(crust, mid, smoothstep(0.0, 0.55, t));
    albedo = mix(albedo, hot, smoothstep(0.55, 1.0, t));

    // Same warp on the Worley lookup so the cracks follow the marbling.
    vec2 w = worley3(p * 2.2 + 0.6 * warp + vec3(u_Time * 0.05));
    float crack = 1.0 - smoothstep(0.0, 0.11, w.y - w.x);
    albedo = mix(albedo, hot, crack * 0.9);

    float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
    float lightIntensity = clamp(diffuseTerm, 0.0, 1.0) + 0.25;

    // Emissive, so the seams still glow on faces turned away from the light.
    vec3 emissive = hot * crack * crack * 0.45;

    out_Col = vec4(albedo * lightIntensity + emissive, u_Color.a);
}
