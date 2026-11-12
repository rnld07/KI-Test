#version 300 es
precision highp float;
out vec4 outColor;
uniform vec2 uRes;
uniform vec3 uCamPos, uCamFw, uCamRt, uCamUp;
uniform float uFocal, uFocus, uAper;
uniform vec3 uTip, uD1, uD2, uD3;
uniform sampler2D uUI;
uniform float uT, uDim;

const vec2 PH = vec2(3.53, 7.33);
const float PT = 0.825;
const vec2 SC = vec2(3.33, 7.08);
const float L1 = 2.3, L2 = 2.5, L3 = 9.0;
const vec3 LK = vec3(0.45, 0.80, -0.40);
const vec3 LF = vec3(-0.70, 0.35, 0.60);

vec3 J1, J2, U1, U2, U3;

float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx)*0.1031); p3 += dot(p3, p3.yzx+33.33); return fract((p3.x+p3.y)*p3.z); }
float vnoise(vec2 p){ vec2 i=floor(p), f=fract(p); vec2 u=f*f*(3.-2.*f);
  return mix(mix(hash12(i),hash12(i+vec2(1,0)),u.x), mix(hash12(i+vec2(0,1)),hash12(i+vec2(1,1)),u.x), u.y)*2.-1.; }
float vnoise3(vec3 p){ return vnoise(p.xz + p.y*1.7) * 0.6 + vnoise(p.xy*1.3 + 5.1)*0.4; }

float smin(float a, float b, float k){ float h = clamp(0.5+0.5*(b-a)/k, 0., 1.); return mix(b, a, h) - k*h*(1.-h); }
float sdRR(vec2 p, vec2 b, float r){ vec2 q=abs(p)-b+r; return min(max(q.x,q.y),0.)+length(max(q,0.))-r; }
float sdPhone(vec3 p){
  float r2 = 0.20;
  float d2 = sdRR(p.xz, PH - r2, 1.10 - r2);
  float dy = abs(p.y + PT*0.5) - (PT*0.5 - r2);
  vec2 w = vec2(d2, dy);
  return min(max(w.x,w.y),0.) + length(max(w,0.)) - r2;
}
float sdSeg(vec3 p, vec3 a, vec3 d, float L, float r0, float r1, vec3 U, out float h){
  vec3 v = p - a; h = clamp(dot(v,d), 0., L);
  vec3 c = v - d*h;
  float cu = dot(c, U);
  vec3 e = c + U*cu*0.13;
  return (length(e) - mix(r0, r1, h/L))*0.88;
}
float sdFinger(vec3 p){
  float h;
  float d1 = sdSeg(p, uTip, uD1, L1, 0.66, 0.78, U1, h);
  float d2 = sdSeg(p, J1, uD2, L2, 0.78, 0.84, U2, h);
  float d3 = sdSeg(p, J2, uD3, L3, 0.84, 0.96, U3, h);
  return smin(smin(d1, d2, 0.22), d3, 0.28);
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
vec3 calcN(vec3 p, float e){
  const vec2 k = vec2(1.,-1.); int i;
  return normalize(k.xyy*mapS(p+k.xyy*e,i) + k.yyx*mapS(p+k.yyx*e,i) + k.yxy*mapS(p+k.yxy*e,i) + k.xxx*mapS(p+k.xxx*e,i));
}
vec3 calcNF(vec3 p, float e){
  const vec2 k = vec2(1.,-1.);
  return normalize(k.xyy*sdFinger(p+k.xyy*e) + k.yyx*sdFinger(p+k.yyx*e) + k.yxy*sdFinger(p+k.yxy*e) + k.xxx*sdFinger(p+k.xxx*e));
}
float fingerShadow(vec3 ro, vec3 rd){
  float res = 1., t = 0.04;
  for(int i=0;i<32;i++){
    float h = sdFinger(ro + rd*t);
    res = min(res, 8.*h/t);
    t += clamp(h, 0.04, 1.0);
    if(res < 0.005 || t > 30.) break;
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
vec3 envRefl(vec3 r){
  vec3 c = vec3(0.012,0.013,0.016) + vec3(0.035,0.038,0.045)*smoothstep(-0.1,0.9,r.y);
  c += vec3(1.0,0.95,0.88)*pow(max(dot(r, normalize(vec3(0.35,0.75,-0.55))),0.), 40.)*0.55;
  return c;
}

// local finger coordinates: a = arc length from tip, cu = dorsal coord (-1..1), cs = side coord
void fingerLocal(vec3 p, out float a, out float cu, out float cs, out int seg){
  float h1, h2, h3;
  float d1 = sdSeg(p, uTip, uD1, L1, 0.66, 0.78, U1, h1);
  float d2 = sdSeg(p, J1, uD2, L2, 0.78, 0.84, U2, h2);
  float d3 = sdSeg(p, J2, uD3, L3, 0.84, 0.96, U3, h3);
  vec3 c; vec3 U; vec3 D;
  if(d1 <= d2 && d1 <= d3){ seg = 1; a = dot(p-uTip,uD1); c = p - uTip - uD1*h1; U = U1; D = uD1; }
  else if(d2 <= d3){ seg = 2; a = L1 + h2; c = p - J1 - uD2*h2; U = U2; D = uD2; }
  else { seg = 3; a = L1 + L2 + h3; c = p - J2 - uD3*h3; U = U3; D = uD3; }
  vec3 S = normalize(cross(D, U));
  float l = max(length(c), 1e-4);
  cu = dot(c, U)/l; cs = dot(c, S)/l;
}

vec3 skin(vec3 p, vec3 n, vec3 rd, bool cheap){
  float a, cu, cs; int seg;
  fingerLocal(p, a, cu, cs, seg);
  // ---- micro normal detail
  vec3 nn = n;
  if(!cheap){
    // fingerprint ridges on the pad
    float pad = smoothstep(-0.15, -0.45, cu)*smoothstep(2.1, 1.4, a);
    vec2 pc = vec2(a - 0.75, cs*0.75);
    float ph = length(pc*vec2(1.0,1.25))/0.048;
    float rid = sin(ph*6.2832);
    vec3 grad = normalize(cross(n, cross(uD1, n)) + 1e-4);
    nn = normalize(n + grad*rid*0.06*pad);
    // pores / skin noise
    float sn = vnoise3(p*42.)*0.5 + vnoise3(p*13.)*0.5;
    nn = normalize(nn + vec3(sn, -sn*0.5, sn*0.7)*0.035);
  }
  // ---- albedo (linear)
  vec3 alb = vec3(0.56, 0.28, 0.18);
  alb *= 0.94 + 0.06*vnoise3(p*7.);
  alb = mix(alb, vec3(0.60, 0.24, 0.16), smoothstep(1.6, 0.0, a)*0.35);
  // joints: redder + creases
  float kn1 = exp(-pow((a-2.32)/0.30,2.)), kn2 = exp(-pow((a-4.85)/0.38,2.));
  alb = mix(alb, vec3(0.55,0.24,0.17), (kn1*0.4+kn2*0.5)*smoothstep(0.0,0.6,cu));
  float wr = (kn1*0.8 + kn2)*smoothstep(0.15,0.7,cu)*(0.5+0.5*sin(a*48. + cs*3.));
  alb *= 1. - 0.22*wr;
  float crease = exp(-pow((a-2.2)/0.035,2.))*smoothstep(-0.2,-0.6,cu);
  alb *= 1. - 0.45*crease;
  // ---- nail
  float lat = abs(cs)/0.64;
  float aprox = 1.42 - 0.22*lat*lat;
  float nail = smoothstep(0.38, 0.52, cu) * smoothstep(1.0, 0.92, lat) * smoothstep(aprox, aprox-0.06, a) * step(float(seg), 1.5);
  nail *= smoothstep(-0.45, -0.25, a);
  float freeEdge = smoothstep(0.30, 0.18, a);
  vec3 nailC = mix(vec3(0.66, 0.36, 0.32), vec3(0.80, 0.70, 0.64), freeEdge);
  float cut = exp(-pow((a-aprox+0.03)/0.03,2.))*smoothstep(0.3,0.5,cu)*step(lat,1.0);
  alb = mix(alb, nailC, nail);
  alb *= 1. - 0.3*cut;
  // ---- lighting
  vec3 L = normalize(LK);
  float ndl = dot(nn, L);
  vec3 wrapc = vec3(0.50, 0.28, 0.22);
  vec3 dif = clamp((vec3(ndl)+wrapc)/(1.+wrapc), 0., 1.);
  float sh = cheap ? 1. : fingerShadow(p + n*0.02, L);
  vec3 keyC = vec3(1.0,0.93,0.84)*2.2;
  vec3 col = alb*keyC*dif*mix(vec3(0.25,0.12,0.10), vec3(1.), sh);
  vec3 F = normalize(LF);
  col += alb*vec3(0.30,0.36,0.50)*0.35*clamp((dot(nn,F)+0.3)/1.3,0.,1.);
  col += alb*vec3(0.05,0.05,0.06);
  // screen glow from below
  vec3 glow = uiBlur(p.xz) * clamp(-nn.y*0.8+0.25, 0., 1.) * exp(-max(p.y,0.)*0.5) * 1.6;
  col += alb*glow;
  // specular (skin sheen + nail gloss)
  vec3 H = normalize(L - rd);
  float rough = mix(22., 90., nail);
  float spec = pow(max(dot(nn,H),0.), rough)*mix(0.06, 0.35, nail)*(rough+2.)/24.;
  col += keyC*spec*sh;
  // rim / back light
  float rim = pow(1.-max(dot(nn,-rd),0.), 3.5);
  col += rim*vec3(0.45,0.38,0.36)*0.22;
  return col;
}

void main(){
  vec2 fc = gl_FragCoord.xy;
  vec2 q = (fc - 0.5*uRes)/(0.5*uRes.y);
  vec3 ro = uCamPos;
  vec3 rd = normalize(uCamFw*uFocal + uCamRt*q.x + uCamUp*q.y);
  const vec3 UP = vec3(0.,1.,0.);
  U1 = normalize(UP - uD1*dot(UP,uD1)); U2 = normalize(UP - uD2*dot(UP,uD2)); U3 = normalize(UP - uD3*dot(UP,uD3));
  J1 = uTip + uD1*L1; J2 = J1 + uD2*L2;

  float t = 0.05; int id = -1; bool hit = false;
  for(int i=0;i<180;i++){
    int k; float d = mapS(ro + rd*t, k);
    if(d < 0.0004*t + 0.0002){ hit = true; id = k; break; }
    t += d*0.92;
    if(t > 150.) break;
  }
  vec3 col = vec3(0.010,0.011,0.014);
  float depth = 150.;
  if(hit){
    depth = t;
    vec3 p = ro + rd*t;
    float ne = 0.0008 + 0.0004*t;
    vec3 n = calcN(p, ne);
    vec3 L = normalize(LK);
    if(id == 0){
      col = skin(p, n, rd, false);
    } else if(id == 1){
      float ds = sdRR(p.xz, SC, 0.92);
      bool face = n.y > 0.985;
      if(face){
        vec3 r = reflect(rd, n);
        float fr = 0.04 + 0.96*pow(1.-max(dot(n,-rd),0.), 5.);
        vec3 refl = envRefl(r);
        float tt = 0.03; bool fh = false;
        for(int i=0;i<60;i++){ float d = sdFinger(p + r*tt); if(d<0.002){fh=true;break;} tt += d; if(tt>30.) break; }
        if(fh){ vec3 pp = p + r*tt; refl = skin(pp, calcNF(pp, 0.003), r, true); }
        vec3 emis = vec3(0.);
        if(ds < 0.){ emis = uiTex(p.xz)*1.35; }
        float edgeA = smoothstep(-0.003, 0.003, ds);
        col = mix(emis*(1.-fr) + refl*fr, refl*fr + vec3(0.002), edgeA);
        col += vec3(0.006,0.007,0.009)*(1.-edgeA);
      } else {
        vec3 alb = vec3(0.42,0.40,0.37);
        float ndl = max(dot(n,L),0.);
        float sh = fingerShadow(p + n*0.02, L);
        vec3 H = normalize(L - rd);
        vec3 r = reflect(rd,n);
        col = alb*(0.05 + 1.6*ndl*sh) + pow(max(dot(n,H),0.),50.)*0.9*sh + envRefl(r)*alb*1.4;
        col += alb*0.08*clamp(dot(n,normalize(LF)),0.,1.);
      }
    } else {
      vec3 alb = vec3(0.030,0.030,0.034)*(0.88+0.12*vnoise(p.xz*1.7))*(0.95+0.05*vnoise(p.xz*40.));
      float ndl = max(dot(n,L),0.);
      float sh = fingerShadow(p + n*0.02, L);
      float ao = clamp(sdPhone(p)/1.0, 0., 1.);
      ao = 0.25 + 0.75*sqrt(ao);
      float pool = exp(-dot(p.xz-vec2(0.,1.),p.xz-vec2(0.,1.))*0.006);
      vec3 H = normalize(L - rd);
      col = alb*(0.4 + 3.0*ndl*sh*pool)*ao + pow(max(dot(n,H),0.),16.)*0.02*sh*ao*pool;
      // faint screen spill around the phone
      col += vec3(0.010,0.010,0.013)*exp(-max(sdPhone(p),0.)*1.5);
    }
  }
  col *= uDim;
  col = clamp((col*(2.51*col+0.03))/(col*(2.43*col+0.59)+0.14),0.,1.);
  col = pow(col, vec3(1./2.2));
  float coc = uAper*abs(depth - uFocus)/depth;
  outColor = vec4(col, clamp(coc/24., 0., 1.));
}
