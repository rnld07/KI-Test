#version 300 es
precision highp float;
out vec4 outColor;
uniform vec2 uRes;
uniform float uN;
uniform float uT;
uniform float uRipple;
uniform float uRippleR;
uniform vec2 uDrift;
uniform sampler2D uUI;
uniform vec2 uKeyUV;

const float YS = 0.253;
const float CC = 0.016;
const float FS = 0.546875;

float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx)*0.1031); p3 += dot(p3, p3.yzx+33.33); return fract((p3.x+p3.y)*p3.z); }
vec2 hash22(vec2 p){ vec3 p3 = fract(vec3(p.xyx)*vec3(.1031,.1030,.0973)); p3 += dot(p3, p3.yzx+33.33); return fract((p3.xx+p3.yz)*p3.zy); }
float vnoise(vec2 p){ vec2 i=floor(p), f=fract(p); vec2 u=f*f*(3.-2.*f);
  return mix(mix(hash12(i),hash12(i+vec2(1,0)),u.x), mix(hash12(i+vec2(0,1)),hash12(i+vec2(1,1)),u.x), u.y)*2.-1.; }
float fbm(vec2 p, int oct){ float s=0., a=0.5; for(int i=0;i<6;i++){ if(i>=oct) break; s+=a*vnoise(p); p=mat2(1.6,1.2,-1.2,1.6)*p+vec2(3.1,1.7); a*=0.5;} return s; }
vec4 voro(vec2 p, float jit, out vec2 rel){ vec2 i=floor(p), f=fract(p); float d1=8., d2=8.; float id=0.; rel=vec2(0);
  for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++){ vec2 g=vec2(float(x),float(y)); vec2 o=hash22(i+g)*jit + (1.-jit)*0.5; vec2 r=g+o-f; float d=dot(r,r);
    if(d<d1){ d2=d1; d1=d; id=hash12(i+g+17.3); rel=r;} else if(d<d2){ d2=d;} }
  return vec4(sqrt(d1), sqrt(d2), id, 0.); }

float Sc(float lf){ return exp2(-6.3808 - uN - lf); }
float Ws(float s, bool first, bool last){ float ls = log2(s); return (first?1.:smoothstep(4.9,3.4,ls))*(last?1.:smoothstep(-1.9,-0.8,ls)); }

float wR,wC,wW,wF,wM,wA, sR,sC,sW,sF,sM,sA;
float lS,lK,lP,lC,lL,lA, tS,tK,tP,tC,tL,tA;

// ---------------- upper (finger) layers ----------------
vec4 ridges(vec2 q){
  vec2 w = q + 1.3*vec2(fbm(q*0.06,3), fbm(q*0.06+11.,3));
  float ph = length(w - vec2(6.0, 150.0));
  float r = 0.5+0.5*sin(6.2832*ph);
  float crest = smoothstep(0.12,0.88,r);
  vec2 rel; vec4 v = voro(q*1.7+3.1, 1.0, rel);
  float pore = (1.-smoothstep(0.05,0.15,v.x))*step(0.5,v.z)*crest;
  float h = crest*2.-1. - pore*1.8 + 0.1*vnoise(q*7.);
  vec3 a = mix(vec3(0.60,0.26,0.20), vec3(0.95,0.57,0.41), crest);
  a *= 1.-0.5*pore;
  return vec4(h, a);
}
vec4 cells(vec2 q){
  vec2 rel; vec4 v = voro(q, 0.85, rel);
  float edge = v.y - v.x;
  float crack = 1.-smoothstep(0.015,0.08,edge);
  float ang = v.z*6.2832;
  float tilt = dot(-rel, vec2(cos(ang),sin(ang)));
  float h = 0.3*(v.z*2.-1.) + 0.5*tilt - 1.1*crack + 0.14*fbm(q*5.,3);
  vec3 a = vec3(0.95,0.62,0.45)*(0.86+0.18*v.z);
  a = mix(a, vec3(0.50,0.24,0.18), crack*0.8);
  return vec4(h,a);
}
vec4 wrinkles(vec2 q){
  vec2 w = q + 0.7*vec2(fbm(q*0.4,3), fbm(q*0.4+7.7,3));
  float r = 1.-abs(fbm(w,4));
  r = r*r*r;
  return vec4(r*2.-1., mix(vec3(0.72,0.42,0.32), vec3(0.97,0.70,0.54), r));
}
vec4 fibers(vec2 q){
  vec2 w = q + 0.6*vec2(fbm(q*0.25,3), fbm(q*0.25+3.3,3));
  float id = floor(w.y);
  float l = fract(w.y)*2.-1.;
  float tube = sqrt(max(0.,1.-l*l));
  float seg = 0.5+0.5*sin(w.x*1.4 + hash12(vec2(id,1.))*6.28);
  float h = tube*(0.65+0.35*seg)*2.-1. + 0.15*vnoise(vec2(w.x*0.5, w.y*4.));
  return vec4(h, mix(vec3(0.62,0.36,0.28), vec3(0.98,0.76,0.60), tube));
}
vec4 molecules(vec2 q){
  vec2 w = q + 0.5*vec2(fbm(q*0.2,2), fbm(q*0.2+9.1,2));
  float id = floor(w.y);
  float l = fract(w.y)*2.-1.;
  float ph = w.x*2.2 + hash12(vec2(id,4.))*6.28;
  float y1 = 0.38*sin(ph);
  float r = 0.36;
  float t1 = sqrt(max(0., r*r - (l-y1)*(l-y1)))/r;
  float t2 = sqrt(max(0., r*r - (l+y1)*(l+y1)))/r;
  float z1 = cos(ph)*0.25;
  float a1 = t1*(0.75+z1), a2 = t2*(0.75-z1);
  vec3 c = a1>a2 ? vec3(0.98,0.80,0.64) : vec3(0.93,0.55,0.55);
  c *= 0.45 + 0.55*max(t1,t2);
  return vec4(max(a1,a2)*2.-1., c);
}
vec3 elemTop(float id){ return id<0.42? vec3(0.30,0.32,0.38) : id<0.68? vec3(0.95,0.95,0.97) : id<0.82? vec3(0.95,0.25,0.32) : id<0.95? vec3(0.25,0.42,0.98) : vec3(1.0,0.82,0.22); }
vec3 elemBot(float id){ return id<0.5? vec3(0.35,0.92,0.72) : id<0.78? vec3(0.28,0.32,0.40) : id<0.9? vec3(0.95,0.35,0.42) : vec3(0.90,0.76,0.50); }
vec4 atoms(vec2 q, bool top){
  vec2 rel; vec4 v = voro(q, 0.35, rel);
  float r = 0.52;
  float s1 = sqrt(max(0., r*r - v.x*v.x))/r;
  vec2 rel2; vec4 v2 = voro(q+vec2(0.5,0.5)+3.7, 0.35, rel2);
  float s2 = sqrt(max(0., r*r - v2.x*v2.x))/r*0.55;
  if(s1 >= s2) return vec4(s1*2.-1., top? elemTop(v.z): elemBot(v.z));
  return vec4(s2*2.-1., (top? elemTop(v2.z): elemBot(v2.z))*0.55);
}
// ---------------- lower (glass) layers ----------------
vec4 smudge(vec2 q){
  vec2 rel; vec4 v = voro(q, 1.0, rel);
  float rad = 0.14 + 0.3*fract(v.z*7.3);
  float present = step(0.3, v.z);
  float dome = sqrt(max(0., rad*rad - v.x*v.x))/rad * present;
  return vec4(dome*1.2, dome, 0., 0.);
}
vec4 scratches(vec2 q){
  float g = 0.;
  for(int j=0;j<3;j++){
    float ang = float(j)*1.1 + 0.4;
    vec2 d = vec2(cos(ang), sin(ang));
    vec2 rq = vec2(dot(q,d), dot(q, vec2(-d.y,d.x)));
    float row = floor(rq.y/3.);
    float hh = hash12(vec2(row, float(j)*13.));
    if(hh>0.5){
      float y0 = row*3. + 3.*hash12(vec2(row,float(j)*7.+1.));
      float w = 0.05 + 0.1*hh;
      float along = smoothstep(0.2,0.6, 0.5+0.5*sin(rq.x*0.12 + hh*20.));
      g = max(g, (1.-smoothstep(0., w, abs(rq.y-y0)))*along);
    }
  }
  return vec4(-g*1.0 + 0.12*fbm(q*2.,3), 0.,0.,0.);
}
vec4 polish(vec2 q){ return vec4(fbm(q*0.8,3)*0.9,0.,0.,0.); }
vec4 coating(vec2 q){ vec2 rel; vec4 v=voro(q,0.9,rel); float rad=0.42+0.12*v.z; float b = sqrt(max(0.,rad*rad-v.x*v.x))/rad; return vec4(b*1.6-0.6 + 0.1*vnoise(q*3.), 0.,0.,0.); }
vec4 chains(vec2 q){ vec2 w = q + 0.9*vec2(fbm(q*0.3,3), fbm(q*0.3+5.,3)); float id=floor(w.y); float l=fract(w.y)*2.-1.; float tube=sqrt(max(0.,1.-l*l*1.5)); float bead = 0.75+0.25*sin(w.x*3.1+hash12(vec2(id,2.))*6.28); return vec4(tube*bead*2.-1., tube, 0.,0.); }

void evalTop(vec2 P, out float h, out vec3 alb){
  h = 0.; alb = vec3(0.); float ws = 0.;
  vec4 r;
  if(wR>0.001){ r = ridges(P*sR); h += wR*r.x*0.30/sR; alb += wR*r.yzw; ws += wR; }
  if(wC>0.001){ r = cells(P*sC+1.7); h += wC*r.x*0.30/sC; alb += wC*r.yzw; ws += wC; }
  if(wW>0.001){ r = wrinkles(P*sW+5.3); h += wW*r.x*0.22/sW; alb += wW*r.yzw; ws += wW; }
  if(wF>0.001){ r = fibers(P*sF+2.2); h += wF*r.x*0.25/sF; alb += wF*r.yzw; ws += wF; }
  if(wM>0.001){ r = molecules(P*sM+8.8); h += wM*r.x*0.30/sM; alb += wM*r.yzw; ws += wM; }
  if(wA>0.001){ r = atoms(P*sA+4.4, true); h += wA*r.x*0.35/sA; alb += wA*r.yzw; ws += wA; }
  alb /= max(ws, 1e-3);
}
void evalBot(vec2 P, out float h, out float oil, out vec3 alb){
  h = 0.; oil = 0.; alb = vec3(0.); float ws = 0.;
  vec4 r;
  if(lS>0.001){ r = smudge(P*tS+9.1); h += lS*r.x*0.25/tS; oil += lS*r.y; }
  if(lK>0.001){ r = scratches(P*tK+3.3); h += lK*r.x*0.12/tK; alb += lK*vec3(0.46,0.53,0.65); ws += lK; }
  if(lP>0.001){ r = polish(P*tP+1.1); h += lP*r.x*0.12/tP; alb += lP*vec3(0.48,0.55,0.67); ws += lP; }
  if(lC>0.001){ r = coating(P*tC+6.6); h += lC*r.x*0.22/tC; alb += lC*vec3(0.50,0.57,0.70); ws += lC; }
  if(lL>0.001){ r = chains(P*tL+2.9); h += lL*r.x*0.28/tL; alb += lL*mix(vec3(0.30,0.36,0.46), vec3(0.62,0.92,0.84), r.y); ws += lL; }
  if(lA>0.001){ r = atoms(P*tA+7.7, false); h += lA*r.x*0.35/tA; alb += lA*r.yzw; ws += lA; }
  alb = ws>1e-3 ? alb/ws : vec3(0.46,0.53,0.65);
}

vec3 uiCm(vec2 cm){
  vec2 uv = uKeyUV + vec2(cm.x/6.66, -cm.y/14.16);
  return pow(texture(uUI, uv).rgb, vec3(2.2));
}

vec3 aces(vec3 x){ return clamp((x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14),0.,1.); }

void main(){
  vec2 fc = gl_FragCoord.xy;
  vec2 q = (fc - 0.5*uRes)/(FS*uRes.y);
  bool top = q.y > 0.;
  float ay = abs(q.y);
  float px = 1.0/(FS*uRes.y);

  sR = Sc(log2(4.7e-4)); sC = Sc(log2(3.5e-5)); sW = Sc(log2(2.5e-6)); sF = Sc(log2(1.6e-7)); sM = Sc(log2(8.0e-9)); sA = Sc(log2(4.0e-10));
  tS = Sc(log2(1.6e-5)); tK = Sc(log2(3.0e-6)); tP = Sc(log2(6.0e-7)); tC = Sc(log2(4.0e-8)); tL = Sc(log2(3.5e-9)); tA = Sc(log2(4.0e-10));
  wR = Ws(sR,true,false); wC = Ws(sC,false,false); wW = Ws(sW,false,false); wF = Ws(sF,false,false); wM = Ws(sM,false,false); wA = Ws(sA,false,true);
  lS = Ws(tS,false,false)*smoothstep(5.0,6.0,uN); lK = Ws(tK,false,false); lP = Ws(tP,false,false); lC = Ws(tC,false,false); lL = Ws(tL,false,false); lA = Ws(tA,false,true);

  float dome = top ? 0.20*(1.-smoothstep(1.0,4.0,uN)) : 0.;
  float ysE = YS + dome*q.x*q.x;
  float ayc = max(ay, YS + 1e-4);
  float t = (ayc - sqrt(max(ayc*ayc - 4.*CC, 0.)))/(2.*CC);
  vec2 P = vec2(q.x*t, t + max(YS-ay,0.)*25.) + uDrift;
  float eps = max(t*1.3*px, 1e-5);

  vec3 V = -normalize(vec3(q.x, q.y, 1.));
  vec3 N0 = top ? normalize(vec3(0., -1., 2.*CC*t)) : normalize(vec3(0., 1., 2.*CC*t));
  vec3 Tz = normalize(vec3(0., top? 2.*CC*t : -2.*CC*t, 1.));
  vec3 L = normalize(vec3(-0.45, top? -0.75 : 0.75, -0.5));

  vec3 col; float h0;
  float e = smoothstep(24.6, 25.9, uN);

  if(top){
    vec3 alb; evalTop(P, h0, alb);
    float hx, hy; vec3 d1; evalTop(P+vec2(eps,0.), hx, d1); evalTop(P+vec2(0.,eps), hy, d1);
    vec2 g = vec2(hx-h0, hy-h0)/eps;
    vec3 N = normalize(N0 - g.x*vec3(1.,0.,0.) - g.y*Tz);
    float ndl = dot(N,L);
    float wrap = max((ndl+0.25)/1.25, 0.);
    float dif = max(ndl, 0.);
    vec3 H = normalize(L+V);
    float sp = pow(max(dot(N,H),0.), 36.);
    float gl = 0.10 + 0.55*wA;
    col = alb*(0.07 + 0.95*wrap) + vec3(0.55,0.10,0.04)*(wrap-dif)*0.6*(1.-wA) + sp*gl;
    col += alb*vec3(0.25,0.3,0.45)*0.06;
  } else {
    float oil; vec3 alb; evalBot(P, h0, oil, alb);
    float hx, hy, o2; vec3 d1; evalBot(P+vec2(eps,0.), hx, o2, d1); evalBot(P+vec2(0.,eps), hy, o2, d1);
    vec2 g = vec2(hx-h0, hy-h0)/eps;
    vec3 N = normalize(N0 - g.x*vec3(1.,0.,0.) - g.y*Tz);
    float ndl = dot(N,L);
    float wrap = max((ndl+0.25)/1.25, 0.);
    vec3 H = normalize(L+V);
    float sp = pow(max(dot(N,H),0.), 60.);
    float glass = 1.-smoothstep(9.5, 13.5, uN);
    float dcm = 2.4*exp2(-uN);
    vec2 Prel = P - uDrift - vec2(0., 3.0) + g*0.25*oil;
    vec2 cm = Prel*(dcm*0.5);
    vec3 uiS = uiCm(cm)*2.2;
    vec2 pc = cm/0.0055;
    vec2 cell = floor(pc), f = fract(pc);
    vec3 pcol = uiCm((cell+0.5)*0.0055)*2.2;
    float sg = mix(0.075, 0.33, smoothstep(5.5, 9.0, uN));
    float k = 1./(2.*sg*sg);
    vec2 o;
    o = fract(f - vec2(0.25,0.25) + 0.5) - 0.5; float G1 = exp(-dot(o,o)*k);
    o = fract(f - vec2(0.75,0.75) + 0.5) - 0.5; float G2 = exp(-dot(o,o)*k);
    o = fract(f - vec2(0.75,0.25) + 0.5) - 0.5; float R1 = exp(-dot(o,o)*k);
    o = fract(f - vec2(0.25,0.75) + 0.5) - 0.5; float B1 = exp(-dot(o,o)*k*0.8);
    float nrm = 1./(6.2832*sg*sg);
    vec3 sub = 0.6*nrm*( R1*pcol.r*vec3(1.,0.08,0.04) + 0.5*(G1+G2)*pcol.g*vec3(0.12,1.,0.25) + B1*pcol.b*vec3(0.1,0.25,1.)/0.8 );
    vec3 emis = mix(uiS, sub*0.75, smoothstep(2.8, 4.6, uN));
    vec2 bq = q*vec2(1.6,1.6) + vec2(uT*0.01, 0.);
    float b1 = smoothstep(0.1,0.9, 0.5+0.5*vnoise(bq*2.0+1.));
    float b2 = smoothstep(0.1,0.9, 0.5+0.5*vnoise(bq*2.0+7.));
    float b3 = smoothstep(0.1,0.9, 0.5+0.5*vnoise(bq*2.0+13.));
    vec3 bok = (uiS*0.5+0.05)*(vec3(1.,0.15,0.1)*b1 + vec3(0.15,1.,0.3)*b2 + vec3(0.15,0.3,1.)*b3)*1.4;
    emis = mix(emis, bok, smoothstep(8.5, 10.8, uN));
    float trans = mix(1.0, 0.0, smoothstep(10.5, 14.0, uN));
    float fr = 0.04 + 0.96*pow(1.-max(dot(N,V),0.), 5.);
    vec3 env = vec3(0.62,0.33,0.24)*0.30*(0.7+0.3*vnoise(q*3.));
    vec3 glassCol = emis*trans*(1.-fr) + env*fr + sp*vec3(1.0,0.95,0.9)*(0.6 + 0.9*oil);
    glassCol = mix(glassCol, glassCol*vec3(1.05,0.95,0.75) + vec3(0.05,0.035,0.01)*wrap, oil*0.6);
    vec3 matCol = alb*(0.06 + 0.95*wrap) + sp*0.45 + bok*0.10*(1.-smoothstep(-0.2,0.6,h0*tA));
    col = mix(matCol, glassCol, glass);
  }

  if(e > 0.001){
    float s = top ? sA : tA;
    vec2 qa = P*s*1.1 + (top? 4.4 : 7.7) + vec2(uT*0.05, 0.);
    vec2 i0 = floor(qa); vec2 f0 = fract(qa);
    vec3 acc = vec3(0.);
    for(int y=-2;y<=2;y++) for(int x=-2;x<=2;x++){
      vec2 gg = vec2(float(x),float(y));
      vec2 o = hash22(i0+gg)*0.6+0.2;
      vec2 r = gg + o - f0;
      float hh = hash12(i0+gg+5.1);
      float rad = 0.35 + 0.35*hh;
      float b = exp(-dot(r,r)/(rad*rad));
      vec3 pal = top ? (hh<0.33? vec3(1.0,0.25,0.65) : hh<0.66? vec3(1.0,0.50,0.18) : vec3(0.55,0.30,1.0))
                     : (hh<0.33? vec3(0.10,0.90,0.95) : hh<0.66? vec3(0.05,0.75,0.50) : vec3(0.25,0.40,1.0));
      acc += pal*b;
    }
    float fl = 0.75 + 0.25*fbm(qa*1.3 + vec2(0., uT*0.2), 3);
    vec3 cloud = acc*fl*0.9;
    cloud += cloud*cloud*0.25;
    col = mix(col, cloud, e);
  }

  float jag = clamp(h0/7.9, -0.03, 0.03);
  float edge = ay - (ysE - jag);
  float cov = smoothstep(-px*1.2, px*1.2, edge);
  float soft = exp(-max(-edge,0.)*14.);
  cov = mix(cov, max(cov, soft*0.9), e);
  float depthDark = mix(1.0, 0.62, smoothstep(2.5, 7.9, t));
  col *= depthDark;
  col *= cov;

  if(e > 0.001){
    vec2 cid = floor(fc/4.);
    float hs = hash12(cid + 3.7);
    if(hs > 0.985){
      vec2 cp = (cid+0.5)*4.;
      float tw = 0.5+0.5*sin(uT*(2.+hs*5.)+hs*40.);
      float sd = exp(-dot(fc-cp,fc-cp)*0.6);
      col += vec3(0.9,0.95,1.0)*sd*tw*e*(0.35+0.65*smoothstep(0.0,0.3,ay));
    }
    float rr = length(vec2(q.x*0.16, q.y*2.4));
    float ring = exp(-pow((rr-uRippleR)*30.,2.))*uRipple;
    col += vec3(0.75,0.85,1.0)*ring*0.30;
  }

  col = aces(col*0.95);
  col = pow(col, vec3(1./2.2));
  col += (hash12(fc + fract(uT)*100.)-0.5)*0.025;
  outColor = vec4(col, 1.);
}
