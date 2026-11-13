#version 300 es
precision highp float;
out vec4 outColor;
uniform sampler2D uC;
uniform vec2 uRes;
uniform float uZoom, uT;
float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx)*0.1031); p3 += dot(p3, p3.yzx+33.33); return fract((p3.x+p3.y)*p3.z); }
void main(){
  vec2 fc = gl_FragCoord.xy;
  vec3 c;
  if(uZoom > 0.0005){
    // radial zoom blur around the frame centre (applied after depth of field, so it fades in smoothly)
    vec2 ctr = 0.5*uRes; vec2 d = fc - ctr;
    float j = hash12(fc + fract(uT*3.1)*97.);
    int N = int(clamp(length(d)*uZoom*0.6 + 4., 4., 48.));
    vec3 acc = vec3(0.);
    for(int i=0;i<48;i++){ if(i>=N) break; float u = (float(i)+j)/float(N) - 0.5; acc += texture(uC, (ctr + d*(1. + u*uZoom))/uRes).rgb; }
    c = acc/float(N);
  } else c = texture(uC, fc/uRes).rgb;
  c += (hash12(fc + fract(uT*7.13)*311.) - 0.5)*0.022;
  outColor = vec4(c, 1.);
}
