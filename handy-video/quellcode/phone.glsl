#version 300 es
precision highp float;
out vec4 outColor;
uniform vec2 uRes;
uniform vec3 uCamPos, uCamFw, uCamRt, uCamUp;
uniform float uFocal;
uniform vec3 uTip;
uniform vec3 uFD;
uniform sampler2D uUI;
uniform float uT;
uniform float uDim;

const vec2 PH = vec2(3.58, 7.33);
const float PT = 0.82;
const vec2 SC = vec2(3.33, 7.08);
const float FR = 0.78;
const vec3 LK = vec3(-0.45, 0.85, 0.28);

vec3 FU, FS;

float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx)*0.1031); p3 += dot(p3, p3.yzx+33.33); return fract((p3.x+p3.y)*p3.z); }
float vnoise(vec2 p){ vec2 i=floor(p), f=fract(p); vec2 u=f*f*(3.-2.*f);
  return mix(mix(hash12(i),hash12(i+vec2(1,0)),u.x), mix(hash12(i+vec2(0,1)),hash12(i+vec2(1,1)),u.x), u.y)*2.-1.; }

float sdRR(vec2 p, vec2 b, float r){ vec2 q=abs(p)-b+r; return min(max(q.x,q.y),0.)+length(max(q,0.))-r; }
float sdPhone(vec3 p){
  float r2 = 0.22;
  float d2 = sdRR(p.xz, PH - r2, 1.05 - r2);
  float dy = abs(p.y + PT*0.5) - (PT*0.5 - r2);
  vec2 w = vec2(d2, dy);
  return min(max(w.x,w.y),0.) + length(max(w,0.)) - r2;
}
float fingerR(float h){ return FR + 0.09*smoothstep(0.,3.5,h); }
float sdFinger(vec3 p){
  vec3 v = p - uTip;
  float a = dot(v, uFD);
  float h = clamp(a, 0., 11.);
  vec3 c = v - uFD*h;
  float r = fingerR(h);
  return length(c) - r;
}
float mapS(vec3 p, out int id){
  float df = sdFinger(p);
  float dp = sdPhone(p);
  float dt = p.y + PT;
  id = 0; float d = df;
  if(dp < d){ d = dp; id = 1; }
  if(dt < d){ d = dt; id = 2; }
  return d;
}
vec3 calcN(vec3 p){
  const vec2 k = vec2(1.,-1.); const float e = 0.0015; int i;
  return normalize(k.xyy*mapS(p+k.xyy*e,i) + k.yyx*mapS(p+k.yyx*e,i) + k.yxy*mapS(p+k.yxy*e,i) + k.xxx*mapS(p+k.xxx*e,i));
}
float fingerShadow(vec3 ro, vec3 rd){
  float res = 1., t = 0.05;
  for(int i=0;i<28;i++){
    float h = sdFinger(ro + rd*t);
    res = min(res, 10.*h/t);
    t += clamp(h, 0.05, 1.0);
    if(res < 0.01 || t > 25.) break;
  }
  return clamp(res, 0., 1.);
}
vec3 uiTex(vec2 xz){
  vec2 uv = vec2((xz.x + SC.x)/(2.*SC.x), (xz.y + SC.y)/(2.*SC.y));
  return pow(texture(uUI, uv).rgb, vec3(2.2));
}
vec3 uiBlur(vec2 xz){
  vec2 uv = clamp(vec2((xz.x + SC.x)/(2.*SC.x), (xz.y + SC.y)/(2.*SC.y)), 0., 1.);
  return pow(textureLod(uUI, uv, 6.5).rgb, vec3(2.2));
}
vec3 skin(vec3 p, vec3 n, vec3 rd){
  vec3 v = p - uTip;
  float a = dot(v, uFD);
  vec3 c = v - uFD*clamp(a,0.,11.);
  float cu = dot(normalize(c), FU);
  vec3 alb = vec3(0.88,0.52,0.38);
  alb *= 0.93 + 0.07*vnoise(p.xz*9. + p.y*5.);
  alb = mix(alb, vec3(0.90,0.46,0.38), smoothstep(2.0,0.0,a)*0.3);
  // knuckle wrinkles (dorsal)
  float kn = exp(-pow((a-3.0)/0.35,2.))*smoothstep(0.1,0.6,cu);
  alb *= 1. - 0.18*kn*(0.5+0.5*sin(a*55.));
  float kn2 = exp(-pow((a-2.55)/0.12,2.))*smoothstep(-0.2,-0.7,cu);
  alb *= 1. - 0.25*kn2;
  // nail
  float nail = smoothstep(0.62,0.80,cu)*smoothstep(1.40,1.15,a)*smoothstep(-0.35,-0.05,a)*0.85;
  vec3 nailC = mix(vec3(0.90,0.62,0.56), vec3(0.95,0.82,0.76), smoothstep(0.0,-0.25,a));
  alb = mix(alb, nailC, nail);
  vec3 L = normalize(LK);
  float ndl = dot(n,L);
  float dif = max(ndl,0.);
  float wrap = max((ndl+0.3)/1.3, 0.);
  float sh = fingerShadow(p + n*0.02, L);
  vec3 keyC = vec3(1.0,0.94,0.86)*1.45;
  vec3 col = alb*(vec3(0.06,0.065,0.08) + keyC*wrap*mix(0.35,1.,sh));
  col += vec3(0.55,0.12,0.05)*(wrap-dif)*0.35;
  vec3 glow = uiBlur(p.xz) * max(0., -n.y*0.8+0.2) * exp(-max(p.y,0.)*0.45) * 1.3;
  col += alb*glow;
  vec3 H = normalize(L - rd);
  col += pow(max(dot(n,H),0.), mix(18., 60., nail))*mix(0.08, 0.25, nail)*keyC*sh;
  float rim = pow(1.-max(dot(n,-rd),0.), 3.);
  col += rim*vec3(0.25,0.22,0.24)*0.35;
  return col;
}
vec3 envRefl(vec3 r){
  vec3 c = vec3(0.025,0.028,0.035) + vec3(0.06,0.065,0.08)*smoothstep(-0.1,0.9,r.y);
  c += vec3(1.0,0.96,0.9)*pow(max(dot(r, normalize(vec3(-0.35,0.75,-0.55))),0.), 30.)*0.7;
  return c;
}

void main(){
  vec2 fc = gl_FragCoord.xy;
  vec2 q = (fc - 0.5*uRes)/(0.5*uRes.y);
  vec3 ro = uCamPos;
  vec3 rd = normalize(uCamFw*uFocal + uCamRt*q.x + uCamUp*q.y);
  vec3 palm = normalize(vec3(0.,-1.,0.) - uFD*dot(vec3(0.,-1.,0.), uFD));
  FU = -palm; FS = normalize(cross(uFD, FU));

  float t = 0.2; int id = -1; bool hit = false;
  for(int i=0;i<140;i++){
    int k; float d = mapS(ro + rd*t, k);
    if(d < 0.0008*t){ hit = true; id = k; break; }
    t += d*0.9;
    if(t > 120.) break;
  }
  vec3 col = vec3(0.012,0.013,0.017) + vec3(0.02,0.022,0.03)*(q.y*0.5+0.5);
  if(hit){
    vec3 p = ro + rd*t;
    vec3 n = calcN(p);
    vec3 L = normalize(LK);
    if(id == 0){
      col = skin(p, n, rd);
    } else if(id == 1){
      float ds = sdRR(p.xz, SC, 0.82);
      bool face = n.y > 0.97;
      if(face){
        vec3 r = reflect(rd, n);
        float fr = 0.04 + 0.96*pow(1.-max(dot(n,-rd),0.), 5.);
        vec3 refl = envRefl(r);
        // reflection of finger
        float tt = 0.05; bool fh = false;
        for(int i=0;i<48;i++){ float d = sdFinger(p + r*tt); if(d<0.004){fh=true;break;} tt += d; if(tt>30.) break; }
        if(fh){ vec3 pp = p + r*tt; vec3 nn = normalize(pp - uTip - uFD*clamp(dot(pp-uTip,uFD),0.,11.)); refl = skin(pp, nn, r)*0.9; }
        vec3 emis = vec3(0.);
        if(ds < 0.){ emis = uiTex(p.xz)*1.25; }
        float sh = fingerShadow(p + n*0.01, L);
        col = emis*(1.-fr*0.6) + refl*fr*(0.6+0.4*sh) + vec3(0.004);
        col = mix(col, vec3(0.006)+refl*fr, smoothstep(-0.002, 0.004, ds));
      } else {
        // titanium frame
        vec3 alb = vec3(0.50,0.49,0.47);
        float ndl = max(dot(n,L),0.);
        float sh = fingerShadow(p + n*0.02, L);
        vec3 H = normalize(L - rd);
        col = alb*(0.08 + 0.9*ndl*sh) + pow(max(dot(n,H),0.),40.)*0.6*sh + envRefl(reflect(rd,n))*alb*0.6;
      }
    } else {
      // table
      vec3 alb = vec3(0.045,0.045,0.05)*(0.85+0.15*vnoise(p.xz*1.3));
      float ndl = max(dot(n,L),0.);
      float sh = fingerShadow(p + n*0.02, L);
      float ao = clamp(sdPhone(p)/1.2, 0., 1.);
      ao = 0.35 + 0.65*ao;
      vec3 H = normalize(L - rd);
      col = alb*(0.25 + 1.3*ndl*sh)*ao + pow(max(dot(n,H),0.),20.)*0.04*sh*ao;
      col *= exp(-max(t-25.,0.)*0.05);
    }
  }
  col *= uDim;
  col = clamp((col*(2.51*col+0.03))/(col*(2.43*col+0.59)+0.14),0.,1.);
  col = pow(col, vec3(1./2.2));
  col += (hash12(fc + fract(uT)*100.)-0.5)*0.02;
  outColor = vec4(col, 1.);
}
