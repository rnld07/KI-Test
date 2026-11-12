#version 300 es
precision highp float;
out vec4 outColor;
uniform vec2 uRes;
uniform float uN;       // view scale (halvings of 2.4 cm)
uniform float uGap;     // real gap / view gap (1 = gap fills the frame)
uniform float uT, uYaw, uAz, uRipple, uRippleR;
uniform vec2 uDrift;
uniform sampler2D uUI;
uniform vec2 uKeyUV;
uniform float uRt, uHt, uZt, uLneg, uLpos, uCCl, uYsT, uYsL, uTsT, uTsL, uWc, uFocusT;
uniform vec3 uDirT;
uniform float uTopGain, uEmisGain, uRidgeK, uFlat;
uniform vec3 uFU, uCen;

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

float gEps;
float Sc(float lf){ return exp2(-6.3808 - uN - lf); }
float Ws(float s, bool first, bool last){ float ls = log2(s); return (first?1.:smoothstep(4.0,2.8,ls))*(last?1.:smoothstep(-1.9,-0.8,ls)); }
float AA(float s){ return smoothstep(2.0, 5.0, (1./s)/gEps); }

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
  float h = crest*2.-1. - pore*1.8 + 0.08*vnoise(q*7.);
  vec3 a = mix(vec3(0.68,0.34,0.25), vec3(0.90,0.53,0.38), crest);
  a *= 1.-0.5*pore;
  return vec4(h, a);
}
vec4 cells(vec2 q){
  vec2 rel; vec4 v = voro(q, 0.85, rel);
  float edge = v.y - v.x;
  float crack = 1.-smoothstep(0.015,0.08,edge);
  float ang = v.z*6.2832;
  float tilt = dot(-rel, vec2(cos(ang),sin(ang)));
  float lip = smoothstep(0.10,0.03,edge)*smoothstep(0.0,0.4,tilt);
  float h = 0.3*(v.z*2.-1.) + 0.5*tilt - 1.1*crack + 0.35*lip + 0.10*fbm(q*5.,3);
  vec3 a = vec3(0.94,0.61,0.44)*(0.86+0.18*v.z);
  a = mix(a, vec3(0.48,0.22,0.17), crack*0.8);
  return vec4(h,a);
}
vec4 wrinkles(vec2 q){
  vec2 w = q + 0.6*vec2(fbm(q*0.35,2), fbm(q*0.35+7.7,2));
  float r = 1.-abs(fbm(w,3));
  r = r*r*r;
  float bump = 0.15*fbm(q*3.,2);
  return vec4(r*2.-1.+bump, mix(vec3(0.70,0.40,0.30), vec3(0.96,0.69,0.53), r));
}
vec4 fibers(vec2 q){
  vec2 w = q + 0.6*vec2(fbm(q*0.25,3), fbm(q*0.25+3.3,3));
  float id = floor(w.y);
  float l = fract(w.y)*2.-1.;
  float tube = sqrt(max(0.,1.-l*l));
  float strand = 0.5+0.5*sin(l*9.42 + w.x*0.9 + hash12(vec2(id,2.))*6.28);
  float seg = 0.5+0.5*sin(w.x*1.4 + hash12(vec2(id,1.))*6.28);
  float h = tube*(0.70+0.18*seg+0.12*strand)*2.-1.;
  return vec4(h, mix(vec3(0.60,0.34,0.27), vec3(0.97,0.75,0.59), tube*(0.85+0.15*strand)));
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
  vec3 c = a1>a2 ? vec3(0.97,0.79,0.63) : vec3(0.92,0.54,0.54);
  c *= 0.45 + 0.55*max(t1,t2);
  return vec4(max(a1,a2)*2.-1., c);
}
// CPK colours: C grey, H white, O red, N blue, S yellow ; coating: F green, C grey, O red
vec3 elemTop(float id){ return id<0.42? vec3(0.30,0.32,0.37) : id<0.68? vec3(0.94,0.94,0.96) : id<0.82? vec3(0.92,0.20,0.22) : id<0.95? vec3(0.22,0.38,0.95) : vec3(0.98,0.80,0.18); }
vec3 elemBot(float id){ return id<0.58? vec3(0.45,0.88,0.40) : id<0.86? vec3(0.30,0.32,0.37) : vec3(0.92,0.20,0.22); }
vec3 glowTop(float id){ return id<0.42? vec3(0.60,0.35,1.00) : id<0.68? vec3(1.00,0.55,0.85) : id<0.82? vec3(1.00,0.42,0.20) : id<0.95? vec3(0.45,0.40,1.00) : vec3(1.00,0.80,0.30); }
vec3 glowBot(float id){ return id<0.58? vec3(0.15,1.00,0.70) : id<0.86? vec3(0.25,0.50,1.00) : vec3(0.15,0.85,1.00); }
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
    float ang = float(j)*2.1 + 0.4 + 0.3*vnoise(q*0.02+float(j));
    vec2 d = vec2(cos(ang), sin(ang));
    vec2 rq = vec2(dot(q,d), dot(q, vec2(-d.y,d.x)));
    float row = floor(rq.y/3.);
    float hh = hash12(vec2(row, float(j)*13.));
    if(hh>0.72){
      float y0 = row*3. + 3.*hash12(vec2(row,float(j)*7.+1.));
      float w = 0.05 + 0.1*hh;
      float along = smoothstep(0.2,0.6, 0.5+0.5*sin(rq.x*0.12 + hh*20.));
      float x = abs(rq.y-y0)/w;
      g = max(g, exp(-x*x*2.)*along);
    }
  }
  return vec4(-g + 0.10*fbm(q*2.,3), 0.,0.,0.);
}
vec4 polish(vec2 q){ return vec4(fbm(q*0.8,3)*0.9,0.,0.,0.); }
vec4 coating(vec2 q){ vec2 rel; vec4 v=voro(q,0.9,rel); float rad=0.42+0.12*v.z; float b = sqrt(max(0.,rad*rad-v.x*v.x))/rad; return vec4(b*1.6-0.6 + 0.1*vnoise(q*3.), 0.,0.,0.); }
vec4 chains(vec2 q){ vec2 w = q + 0.9*vec2(fbm(q*0.3,3), fbm(q*0.3+5.,3)); float id=floor(w.y); float l=fract(w.y)*2.-1.; float tube=sqrt(max(0.,1.-l*l*1.5)); float bead = 0.75+0.25*sin(w.x*3.1+hash12(vec2(id,2.))*6.28); return vec4(tube*bead*2.-1., tube, 0.,0.); }

void evalTop(vec2 P, out float h, out vec3 alb, out float hr){
  h = 0.; hr = 0.; alb = vec3(0.); float ws = 0.;
  vec4 r; float k;
  if(wR>0.001){ k=AA(sR)*uRidgeK; r = k>0.01? ridges(P*sR) : vec4(0.); h += wR*k*r.x*0.30/sR; hr += wR*k*r.x; alb += wR*mix(vec3(0.80,0.43,0.31), r.yzw, k); ws += wR; }
  if(wC>0.001){ k=AA(sC); r = k>0.01? cells(P*sC+1.7) : vec4(0.); h += wC*k*r.x*0.30/sC; hr += wC*k*r.x; alb += wC*mix(vec3(0.86,0.56,0.40), r.yzw, k); ws += wC; }
  if(wW>0.001){ k=AA(sW); r = k>0.01? wrinkles(P*sW+5.3) : vec4(0.); h += wW*k*r.x*0.22/sW; hr += wW*k*r.x; alb += wW*mix(vec3(0.82,0.54,0.41), r.yzw, k); ws += wW; }
  if(wF>0.001){ k=AA(sF); r = k>0.01? fibers(P*sF+2.2) : vec4(0.); h += wF*k*r.x*0.25/sF; hr += wF*k*r.x; alb += wF*mix(vec3(0.82,0.58,0.46), r.yzw, k); ws += wF; }
  if(wM>0.001){ k=AA(sM); r = k>0.01? molecules(P*sM+8.8) : vec4(0.); h += wM*k*r.x*0.30/sM; hr += wM*k*r.x; alb += wM*mix(vec3(0.70,0.52,0.45), r.yzw, k); ws += wM; }
  if(wA>0.001){ k=AA(sA); r = k>0.01? atoms(P*sA+4.4, true) : vec4(0.); h += wA*k*r.x*0.35/sA; hr += wA*k*r.x; alb += wA*mix(vec3(0.55,0.52,0.58), r.yzw, k); ws += wA; }
  alb /= max(ws, 1e-3); hr /= max(ws, 1e-3);
}
void evalBot(vec2 P, out float h, out float oil, out vec3 alb, out float hr){
  h = 0.; oil = 0.; hr = 0.; alb = vec3(0.); float ws = 0.;
  vec4 r; float k;
  if(lS>0.001){ k=AA(tS); r = k>0.01? smudge(P*tS+9.1) : vec4(0.); h += lS*k*r.x*0.25/tS; oil += lS*k*r.y; }
  if(lK>0.001){ k=AA(tK); r = k>0.01? scratches(P*tK+3.3) : vec4(0.); h += lK*k*r.x*0.12/tK; hr += lK*k*r.x; alb += lK*vec3(0.46,0.53,0.65); ws += lK; }
  if(lP>0.001){ k=AA(tP); r = k>0.01? polish(P*tP+1.1) : vec4(0.); h += lP*k*r.x*0.12/tP; hr += lP*k*r.x; alb += lP*vec3(0.48,0.55,0.67); ws += lP; }
  if(lC>0.001){ k=AA(tC); r = k>0.01? coating(P*tC+6.6) : vec4(0.); h += lC*k*r.x*0.22/tC; hr += lC*k*r.x; alb += lC*vec3(0.50,0.57,0.70); ws += lC; }
  if(lL>0.001){ k=AA(tL); r = k>0.01? chains(P*tL+2.9) : vec4(0.,0.5,0.,0.); h += lL*k*r.x*0.28/tL; hr += lL*k*r.x; alb += lL*mix(vec3(0.30,0.36,0.46), vec3(0.56,0.86,0.62), r.y); ws += lL; }
  if(lA>0.001){ k=AA(tA); r = k>0.01? atoms(P*tA+7.7, false) : vec4(0.); h += lA*k*r.x*0.35/tA; hr += lA*k*r.x; alb += lA*mix(vec3(0.42,0.62,0.42), r.yzw, k); ws += lA; }
  alb = ws>1e-3 ? alb/ws : vec3(0.46,0.53,0.65);
  hr = ws>1e-3 ? hr/ws : 0.;
}
// electron clouds at the same positions as the atom layer
vec3 eCloud(vec2 qa, bool top){
  vec2 i0 = floor(qa), f0 = fract(qa); vec3 acc = vec3(0.);
  for(int y=-2;y<=2;y++) for(int x=-2;x<=2;x++){
    vec2 g = vec2(float(x),float(y));
    vec2 o = hash22(i0+g)*0.35 + 0.325;
    vec2 r = g + o - f0;
    float id = hash12(i0+g+17.3);
    acc += (top? glowTop(id) : glowBot(id)) * exp(-dot(r,r)*4.5);
  }
  return acc;
}

vec3 uiAt(vec2 Pw, float Uv){
  vec2 rel = Pw - vec2(0., 3.0);
  float ca = cos(uAz), sa = sin(uAz);
  vec2 w = vec2(rel.x*ca - rel.y*sa, -rel.x*sa - rel.y*ca)*Uv;   // cm on the phone (x right, z toward the bottom edge)
  return pow(texture(uUI, uKeyUV + vec2(w.x/6.66, w.y/14.16)).rgb, vec3(2.2));
}
vec2 phoneCm(vec2 Pw, float Uv){
  vec2 rel = Pw - vec2(0., 3.0);
  float ca = cos(uAz), sa = sin(uAz);
  return vec2(rel.x*ca - rel.y*sa, -rel.x*sa - rel.y*ca)*Uv;
}
vec3 uiCm(vec2 cm){ return pow(texture(uUI, uKeyUV + vec2(cm.x/6.66, cm.y/14.16)).rgb, vec3(2.2)); }

vec3 aces(vec3 x){ return clamp((x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14),0.,1.); }

float capIntersect(vec3 ro, vec3 rd, vec3 pa, vec3 pb, float r){
  vec3 ba = pb - pa; vec3 oa = ro - pa;
  float baba = dot(ba,ba), bard = dot(ba,rd), baoa = dot(ba,oa), rdoa = dot(rd,oa), oaoa = dot(oa,oa);
  float a = baba - bard*bard; float b = baba*rdoa - baoa*bard; float c = baba*oaoa - baoa*baoa - r*r*baba;
  float h = b*b - a*c;
  if(h >= 0.){
    float t = (-b - sqrt(h))/a; float y = baoa + t*bard;
    if(y > 0. && y < baba) return t;
    vec3 oc = (y <= 0.) ? oa : ro - pb; b = dot(rd,oc); c = dot(oc,oc) - r*r; h = b*b - c;
    if(h > 0.) return -b - sqrt(h);
  }
  return -1.;
}
vec3 capNormal(vec3 pos, vec3 a, vec3 b, float r){ vec3 ba=b-a, pa=pos-a; float h=clamp(dot(pa,ba)/dot(ba,ba),0.,1.); return (pa-h*ba)/r; }
vec3 Mf(vec3 p){ return p + uFU*(dot(p,uFU)*uFlat); }
// flattened fingertip capsule: intersect in the space where it is round
float fingerHit(vec3 ro, vec3 rd, vec3 pa, vec3 pb, float r, out vec3 nrm){
  vec3 ro2 = Mf(ro), rd2 = Mf(rd); float l = length(rd2); rd2 /= l;
  vec3 pa2 = Mf(pa), pb2 = Mf(pb);
  float t2 = capIntersect(ro2, rd2, pa2, pb2, r);
  nrm = vec3(0.,-1.,0.);
  if(t2 < 0.) return -1.;
  vec3 n2 = capNormal(ro2 + rd2*t2, pa2, pb2, r);
  nrm = normalize(Mf(n2));
  return t2/l;
}

void main(){
  vec2 fc = gl_FragCoord.xy;
  vec2 q = (fc - 0.5*uRes)/(FS*uRes.y);
  float ay = abs(q.y);
  float px = 1.0/(FS*uRes.y);

  sR = Sc(log2(4.7e-4)); sC = Sc(log2(3.5e-5)); sW = Sc(log2(2.5e-6)); sF = Sc(log2(1.6e-7)); sM = Sc(log2(8.0e-9)); sA = Sc(log2(4.0e-10));
  tS = Sc(log2(1.6e-5)); tK = Sc(log2(3.0e-6)); tP = Sc(log2(6.0e-7)); tC = Sc(log2(4.0e-8)); tL = Sc(log2(3.5e-9)); tA = Sc(log2(4.0e-10));
  wR = Ws(sR,true,false); wC = Ws(sC,false,false); wW = Ws(sW,false,false); wF = Ws(sF,false,false); wM = Ws(sM,false,false); wA = smoothstep(21.6,23.0,uN);
  lS = Ws(tS,false,false)*smoothstep(5.0,6.0,uN); lK = Ws(tK,false,false); lP = Ws(tP,false,false); lC = Ws(tC,false,false); lL = Ws(tL,false,false); lA = smoothstep(21.6,23.0,uN);

  vec3 I = normalize(vec3(q.x, q.y, 1.));
  vec3 V = -I;
  // ---- geometry: fingertip capsule (top) and glass (bottom), exact ray intersections
  vec3 cen = uCen;
  vec3 pa = cen - uDirT*uLneg, pb = cen + uDirT*uLpos;
  vec3 nT; float sT = fingerHit(vec3(0.), I, pa, pb, uRt, nT);
  float A2 = uCCl*I.z*I.z, B2 = I.y, C2 = 1.;
  float sL = -1.;
  if(A2 < 1e-7){ if(B2 < 0.) sL = -C2/B2; }
  else { float dd = B2*B2 - 4.*A2*C2; if(dd >= 0.) sL = (-B2 - sqrt(dd))/(2.*A2); }
  bool hitT = sT > 0., hitL = sL > 0.;
  bool top; bool miss = false; float s;
  if(hitT && (!hitL || sT < sL)){ top = true; s = sT; }
  else if(hitL){ top = false; s = sL; }
  else { miss = true; top = q.y > 0.; s = 0.; }

  float ys = top ? uYsT : uYsL;
  float ts = top ? uTsT : uTsL;
  float inGap = miss ? max(ys - ay, 0.) : 0.;
  vec3 X; vec3 N0;
  if(!miss){
    X = I*s;
    N0 = top ? nT : normalize(vec3(0., 1., 2.*uCCl*X.z));
  } else {
    X = vec3(q.x*ts, top ? ys*ts : -ys*ts, ts);
    N0 = top ? normalize(vec3(0., -1., ts/max(uRt,1.))) : normalize(vec3(0., 1., 2.*uCCl*ts));
  }
  if(miss && uWc < 0.001 && uN < 24.5){ outColor = vec4(vec3(0.), 0.); return; }
  float t = X.z;
  mat2 Ry = mat2(cos(uYaw), sin(uYaw), -sin(uYaw), cos(uYaw));
  vec2 Pl = vec2(X.x, X.z + inGap*25.);
  vec2 P = Ry*Pl + uDirT.xz*0. + uDrift;
  float dist = length(X);
  float cosi = max(abs(dot(N0, I)), 0.2);
  gEps = dist*px/cosi;
  float eps = dist*px;
  vec3 Tx = normalize(vec3(1.,0.,0.) - N0*N0.x);
  vec3 Tz = normalize(vec3(0.,0.,1.) - N0*N0.z);

  vec3 L = normalize(vec3(-0.45, top? -0.75 : 0.75, -0.5));
  vec3 L2 = normalize(vec3(0.7, top? -0.3 : 0.3, -0.2));

  vec3 col; float h0;
  float e = smoothstep(24.9, 25.95, uN);
  float Uv = 1.2*exp2(-uN);          // cm per view unit

  if(top){
    vec3 alb; float hr; evalTop(P, h0, alb, hr);
    float hx, hy, d2; vec3 d1; evalTop(P+Ry*vec2(eps,0.), hx, d1, d2); evalTop(P+Ry*vec2(0.,eps), hy, d1, d2);
    vec2 g = vec2(hx-h0, hy-h0)/eps;
    vec3 N = normalize(N0 - g.x*Tx - g.y*Tz);
    float ndl = dot(N,L);
    vec3 wrapc = mix(vec3(0.35,0.22,0.18), vec3(0.15), wA);
    vec3 dif = clamp((vec3(ndl)+wrapc)/(1.+wrapc), 0., 1.);
    vec3 H = normalize(L+V);
    float gl = 0.06 + 0.5*wA;
    float sp = pow(max(dot(N,H),0.), mix(30., 70., wA))*gl;
    float ao = 0.55 + 0.45*smoothstep(-1.0, 0.7, hr);
    col = alb*(0.05 + 1.05*dif)*ao + sp;
    col += alb*vec3(0.30,0.34,0.46)*0.12*clamp(dot(N,L2)+0.3,0.,1.);
    col += alb*alb*vec3(0.45,0.10,0.05)*0.25*(1.-wA)*(1.-dif.g);
    col *= uTopGain;
  } else {
    float oil; vec3 alb; float hr; evalBot(P, h0, oil, alb, hr);
    float hx, hy, o2, d2; vec3 d1; evalBot(P+Ry*vec2(eps,0.), hx, o2, d1, d2); evalBot(P+Ry*vec2(0.,eps), hy, o2, d1, d2);
    vec2 g = vec2(hx-h0, hy-h0)/eps;
    vec3 N = normalize(N0 - g.x*Tx - g.y*Tz);
    float ndl = dot(N,L);
    float wrap = clamp((ndl+0.2)/1.2, 0., 1.);
    vec3 H = normalize(L+V);
    float sp = pow(max(dot(N,H),0.), 60.);
    float glass = 1.-smoothstep(9.5, 13.5, uN);
    float ao = 0.6 + 0.4*smoothstep(-1.0, 0.7, hr);
    vec3 glassCol = vec3(0.);
    if(glass > 0.001){
      vec3 Xg = vec3(Pl.x, X.y, Pl.y);
      vec3 Rf = refract(I, N, 1./1.5);
      float delta = 0.07/Uv;
      vec2 off = Rf.xz*(delta/max(-dot(Rf,N0), 0.08));
      vec2 Pp = Ry*(Xg.xz + off) + uDrift;
      vec2 cm = phoneCm(Pp, Uv);
      vec3 uiS = uiCm(cm)*uEmisGain;
      const float CELL = 0.0078;     // diamond PenTile repeat: 2 pixels at 460 ppi
      vec2 pc = cm/CELL;
      vec2 cell = floor(pc), f = fract(pc);
      vec3 pcol = uiCm((cell+0.5)*CELL)*uEmisGain;
      float fpc = gEps*Uv/CELL;
      float sg = clamp(0.065*exp2(0.55*(uN-4.6)), 0.065, 0.6);
      sg = max(sg, fpc*0.6);
      float k = 1./(2.*sg*sg);
      vec2 o;
      o = fract(f - vec2(0.25,0.25) + 0.5) - 0.5; float G1 = exp(-dot(o*vec2(1.,1.4),o*vec2(1.,1.4))*k*1.6);
      o = fract(f - vec2(0.75,0.75) + 0.5) - 0.5; float G2 = exp(-dot(o*vec2(1.4,1.),o*vec2(1.4,1.))*k*1.6);
      o = fract(f - vec2(0.75,0.25) + 0.5) - 0.5; float R1 = exp(-dot(o,o)*k*1.15);
      o = fract(f - vec2(0.25,0.75) + 0.5) - 0.5; float B1 = exp(-dot(o,o)*k*0.8);
      float nrm = 1./(6.2832*sg*sg);
      vec3 sub = nrm*0.55*( R1*pcol.r*1.15*vec3(1.,0.06,0.03) + 0.5*(G1+G2)*pcol.g*2.24*vec3(0.10,1.,0.22) + B1*pcol.b*0.8*vec3(0.08,0.22,1.) );
      float pm = smoothstep(1.2, 0.5, fpc);
      vec3 emis = mix(uiS, mix(uiS, sub, pm), smoothstep(2.8, 4.4, uN));
      float trans = 1. - smoothstep(10.5, 13.5, uN);
      // mirror image of the fingertip in the glass
      vec3 Rr = reflect(I, N);
      vec3 refl = vec3(0.004);
      vec3 nR; float sr = fingerHit(X + N0*0.002, Rr, pa, pb, uRt, nR);
      if(sr > 0.){
        vec3 Y = X + N0*0.002 + sr*Rr;
        float hh, hr2; vec3 at; evalTop(Ry*Y.xz + uDrift, hh, at, hr2);
        refl = at*(0.10 + 0.5*clamp(-Rr.y,0.,1.))*(0.65+0.35*smoothstep(-1.,0.7,hr2));
        refl *= exp(-sr*0.08)*uTopGain;
      }
      float fr = 0.04 + 0.96*pow(1.-max(dot(N,V),0.), 5.);
      if(inGap > 0.) fr = min(fr, 0.45);
      glassCol = emis*trans*(1.-fr) + refl*fr + sp*vec3(1.0,0.96,0.92)*(0.35 + 0.9*oil);
      glassCol = mix(glassCol, glassCol*vec3(1.04,0.96,0.80) + vec3(0.04,0.03,0.01)*wrap, oil*0.5);
    }
    vec3 matCol = alb*(0.05 + 1.0*wrap)*ao + sp*mix(0.25, 0.55, lA);
    matCol += alb*vec3(0.25,0.28,0.38)*0.10*clamp(dot(N,L2)+0.3,0.,1.);
    col = mix(matCol, glassCol, glass);
  }

  // electron clouds (same centres as the atoms)
  float cloudGap = 0.;
  if(e > 0.001){
    vec2 Ps = P;
    if(inGap > 0.) Ps = Ry*vec2(q.x*ts, ts) + uDrift;
    vec3 cl = top ? eCloud(Ps*sA + 4.4, true) : eCloud(Ps*tA + 7.7, false);
    float fl = 0.85 + 0.15*fbm(Ps*3.0 + vec2(uT*0.3, 0.), 2);
    cl *= fl*1.15;
    if(inGap > 0.){ float vd = inGap*ts; cloudGap = exp(-vd*vd*3.0); cl *= cloudGap; }
    col = mix(col, cl, e);
  }

  float cov = 1.;
  if(miss){
    float jag = clamp(h0/max(ts,1.), -0.03, 0.03)*smoothstep(0.,0.3,uGap);
    float edge = ay - (ys*clamp(uGap,0.,1.) - jag);
    cov = uWc*smoothstep(-px*1.0, px*1.0, edge);
    cov = mix(cov, cloudGap, e);
  }
  float depthDark = mix(1.0, 0.70, smoothstep(2.5, max(ts,3.), t));
  col *= depthDark*cov;

  if(e > 0.001){
    vec2 cid = floor(fc/5.);
    float hs = hash12(cid + 3.7);
    if(hs > 0.986){
      vec2 cp = (cid+0.5)*5. + (hash22(cid)-0.5)*3.;
      float tw = 0.5+0.5*sin(uT*(2.+hs*5.)+hs*40.);
      float sdd = exp(-dot(fc-cp,fc-cp)*0.5);
      col += vec3(0.9,0.95,1.0)*sdd*tw*e*0.8;
    }
    float rr = length(vec2(q.x*0.16, q.y*2.4));
    float ring = exp(-pow((rr-uRippleR)*30.,2.))*uRipple;
    col += vec3(0.75,0.85,1.0)*ring*0.14;
  }

  col = aces(col*1.0);
  col = pow(col, vec3(1./2.2));
  float coc = 3.6*abs(dist - uFocusT)/max(dist,1e-3) + 3.*e;
  if(miss) coc = 3.*e;
  outColor = vec4(col, clamp(coc/24., 0., 1.));
}
