#version 300 es
precision highp float;
out vec4 outColor;
uniform sampler2D uA, uB;
uniform float uMix, uUseA, uUseB, uT;
uniform vec2 uRes;
uniform float uZoom;
const float MAXR = 24.;
float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx)*0.1031); p3 += dot(p3, p3.yzx+33.33); return fract((p3.x+p3.y)*p3.z); }
vec3 dof(sampler2D tx, vec2 fc){
  vec4 c0 = texture(tx, fc/uRes);
  float r0 = c0.a*MAXR;
  if(r0 < 0.7) return c0.rgb;
  vec3 acc = c0.rgb; float ws = 1.;
  int N = r0 < 4. ? 16 : (r0 < 10. ? 32 : 56);
  float rot = hash12(fc)*6.2832;
  for(int i=0;i<56;i++){
    if(i>=N) break;
    float fi = float(i)+0.5;
    float r = sqrt(fi/float(N))*r0;
    float th = fi*2.39996 + rot;
    vec2 p = fc + vec2(cos(th),sin(th))*r;
    vec4 c = texture(tx, p/uRes);
    float rs = c.a*MAXR;
    float w = smoothstep(r-1.5, r+0.5, rs);
    float lum = dot(c.rgb, vec3(0.3,0.5,0.2));
    w *= 1. + lum*lum*1.2;
    acc += c.rgb*w; ws += w;
  }
  return acc/ws;
}
vec3 zoomBlur(sampler2D tx, vec2 fc){
  vec2 c = 0.5*uRes; vec2 d = fc - c;
  vec3 acc = vec3(0.); float j = hash12(fc);
  for(int i=0;i<40;i++){ float u = (float(i)+j)/40. - 0.5; acc += texture(tx, (c + d*(1. + u*uZoom))/uRes).rgb; }
  return acc/40.;
}
void main(){
  vec2 fc = gl_FragCoord.xy;
  vec3 a = uUseA > 0.5 ? (uZoom > 0.004 ? zoomBlur(uA, fc) : dof(uA, fc)) : vec3(0.);
  vec3 b = uUseB > 0.5 ? (uZoom > 0.004 ? zoomBlur(uB, fc) : dof(uB, fc)) : vec3(0.);
  vec3 c = mix(a, b, uMix);
  c += (hash12(fc + fract(uT*7.13)*311.) - 0.5)*0.022;
  outColor = vec4(c, 1.);
}
