#version 300 es

uniform mat4 u_Model;
uniform mat4 u_ModelInvTr;
uniform mat4 u_ViewProj;
uniform float u_Time;

in vec4 vs_Pos;
in vec4 vs_Nor;
in vec4 vs_Col;

out vec4 fs_Pos;      // object space, before displacement -- the noise input
out vec4 fs_Nor;
out vec4 fs_LightVec;
out vec4 fs_Col;

const vec4 lightPos = vec4(5, 5, 3, 1);

const float FREQ = 2.4;
const float AMP  = 0.18;
const float EPS  = 0.01;

// Different phase speed per axis so the three waves drift out of sync.
float ripple(vec3 p) {
    return sin(p.x * FREQ + u_Time)
         * cos(p.y * FREQ + u_Time * 0.7)
         * sin(p.z * FREQ + u_Time * 1.3);
}

vec3 displace(vec3 p, vec3 n) {
    return p + n * (AMP * ripple(p));
}

void main()
{
    fs_Col = vs_Col;
    fs_Pos = vs_Pos;

    vec3 pos = vs_Pos.xyz;
    vec3 nor = normalize(vs_Nor.xyz);

    // Rebuild the normal from the displaced surface, otherwise the lighting
    // keeps following the flat cube faces and the ripple only shows up in the
    // silhouette. Sample two nearby points along a tangent basis and cross them.
    vec3 helper = abs(nor.y) < 0.99 ? vec3(0, 1, 0) : vec3(1, 0, 0);
    vec3 tan1 = normalize(cross(helper, nor));
    vec3 tan2 = cross(nor, tan1);

    vec3 p0 = displace(pos, nor);
    vec3 p1 = displace(pos + tan1 * EPS, nor);
    vec3 p2 = displace(pos + tan2 * EPS, nor);

    fs_Nor = vec4(mat3(u_ModelInvTr) * normalize(cross(p1 - p0, p2 - p0)), 0);

    vec4 modelposition = u_Model * vec4(p0, 1.0);
    fs_LightVec = lightPos - modelposition;
    gl_Position = u_ViewProj * modelposition;
}
