#version 300 es
precision highp float;
out vec4 outColor;
uniform vec2 uRes;
uniform float uN;       // view scale (halvings of 2.4 cm)
uniform float uT, uYaw, uAz, uRipple, uRippleR;
uniform sampler2D uUI;
uniform vec2 uKeyUV;
uniform float uRt, uHt, uHb, uZc, uLneg, uLpos, uCCl, uYsT, uYsL, uTsT, uTsL, uFocusT, uEdge;
uniform vec3 uDirT;
uniform float uTopGain, uEmisGain, uRidgeK, uFlat;
uniform vec3 uFU, uCen;
uniform vec2 uAnc;
uniform float uPix;      // zoom centre (z) on the top / bottom surface

const float FS = 0.546875;

float hash12(vec2 p){ vec3 p3 = fract(vec3(p.xyx)*0.1031); p3 += dot(p3, p3.yzx+33.33); return fract((p3.x+p3.y)*p3.z); }
vec2 hash22(vec2 p){ vec3 p3 = fract(vec3(p.xyx)*vec3(.1031,.1030,.0973)); p3 += dot(p3, p3.yzx+33.33); return fract((p3.xx+p3.yz)*p3.zy); }
float vnoise(vec2 p){ vec2 i=floor(p), f=fract(p); vec2 u=f*f*(3.-2.*f);
  return mix(mix(hash12(i),hash12(i+vec2(1,0)),u.x), mix(hash12(i+vec2(0,1)),hash12(i+vec2(1,1)),u.x), u.y)*2.-1.; }
float fbm(vec2 p, int oct){ float s=0., a=0.5; for(int i=0;i<5;i++){ if(i>=oct) break; s+=a*vnoise(p); p=mat2(1.6,1.2,-1.2,1.6)*p+vec2(3.1,1.7); a*=0.5;} return s; }
vec4 voro(vec2 p, float jit, out vec2 rel){ vec2 i=floor(p), f=fract(p); float d1=8., d2=8.; float id=0.; rel=vec2(0);
  for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++){ vec2 g=vec2(float(x),float(y)); vec2 o=hash22(i+g)*jit + (1.-jit)*0.5; vec2 r=g+o-f; float d=dot(r,r);
    if(d<d1){ d2=d1; d1=d; id=hash12(i+g+17.3); rel=r;} else if(d<d2){ d2=d;} }
  return vec4(sqrt(d1), sqrt(d2), id, 0.); }

// ------------------------------------------------------------------ layers
// every layer returns (height in [-1,1], albedo); physical relief = amp * feature size
vec4 ridges(vec2 q){                       // fingerprint ridges (period ~0.47 mm)
  vec2 w = q + 1.3*vec2(fbm(q*0.06,3), fbm(q*0.06+11.,3));
  float c = 0.5+0.5*cos(6.2832*length(w - vec2(6.0, 150.0)));
  float crest = pow(c, 0.55);
  vec2 rel; vec4 v = voro(q*1.6+3.1, 1.0, rel);
  float pore = (1.-smoothstep(0.07,0.17,v.x))*step(0.55,v.z)*smoothstep(0.45,0.9,c);
  float h = crest*2.-1. - pore*1.1 + 0.10*fbm(q*4.,2);
  vec3 a = mix(vec3(0.60,0.29,0.21), vec3(0.93,0.60,0.45), crest)*(1.-0.25*pore);
  return vec4(h, a);
}
vec4 cells(vec2 q){                        // corneocytes: overlapping flakes (~35 um)
  vec2 rel; vec4 v = voro(q, 0.85, rel);
  float edge = v.y - v.x;
  float ang = v.z*6.2832;
  float tilt = dot(-rel, vec2(cos(ang),sin(ang)));
  float curl = max(tilt, 0.); curl *= curl*2.2;
  float crack = 1.-smoothstep(0.0, 0.09, edge);
  float h = 0.45*(v.z*2.-1.) + 0.35*tilt + curl - 1.0*crack + 0.10*fbm(q*6.,2);
  vec3 a = vec3(0.95,0.64,0.47)*(0.84+0.20*v.z);
  a = mix(a, vec3(0.50,0.24,0.18), crack*0.75);
  return vec4(h, a);
}
vec4 csurf(vec2 q){                        // surface of one cell: villi + folds (~2.5 um)
  vec2 rel; vec4 v = voro(q, 0.9, rel);
  float rad = 0.40+0.16*v.z;
  float dome = sqrt(max(0., 1. - (v.x/rad)*(v.x/rad)));
  vec2 w = q*0.5 + 0.6*vec2(fbm(q*0.18,2), fbm(q*0.18+7.7,2));
  float rg = 1.-abs(fbm(w,3)); rg *= rg;
  float h = 1.15*dome + 0.55*rg - 0.9;
  vec3 a = mix(vec3(0.74,0.45,0.34), vec3(0.97,0.72,0.57), clamp(0.6*dome+0.4*rg,0.,1.));
  return vec4(h, a);
}
vec4 fibers(vec2 q){                       // keratin filament bundles (~160 nm)
  vec2 w = q + 0.6*vec2(fbm(q*0.25,3), fbm(q*0.25+3.3,3));
  float id = floor(w.y);
  float l = fract(w.y)*2.-1.;
  float tube = sqrt(max(0.,1.-l*l));
  float strand = 0.5+0.5*sin(l*9.42 + w.x*0.9 + hash12(vec2(id,2.))*6.28);
  float seg = 0.5+0.5*sin(w.x*1.4 + hash12(vec2(id,1.))*6.28);
  float h = tube*(0.72+0.16*seg+0.12*strand)*2.-1.;
  return vec4(h, mix(vec3(0.58,0.33,0.26), vec3(0.97,0.76,0.60), tube*(0.85+0.15*strand)));
}
vec4 molecules(vec2 q){                    // keratin coiled-coil dimers (~8 nm): two twisted bead strands per row
  vec2 w = q + 0.45*vec2(fbm(q*0.2,2), fbm(q*0.2+9.1,2));
  float id = floor(w.y*2.);
  float l = fract(w.y*2.)*0.5 - 0.25;
  float ph0 = hash12(vec2(id,4.))*6.28;
  float best = 0.; vec3 c = vec3(0.62,0.40,0.36);
  for(int s=0;s<2;s++){
    float sg = s==0 ? 1. : -1.;
    float x = w.x*3.0 + float(s)*0.5; float xi = floor(x);
    for(int j=-1;j<=1;j++){
      float xc = xi + float(j) + 0.5;
      float ph = xc*0.75 + ph0;
      float yc = sg*0.08*sin(ph);
      float zc = sg*cos(ph);
      vec2 d = vec2((x - xc)/3.0, l - yc);
      float r = 0.165;
      float e = 1. - dot(d,d)/(r*r);
      float hh = sqrt(max(0., e))*(0.8 + 0.2*zc);
      if(hh > best){ best = hh; c = (s==0 ? vec3(0.97,0.80,0.64) : vec3(0.93,0.60,0.56))*(0.65 + 0.35*sqrt(max(e,0.))); }
    }
  }
  return vec4(best*1.7-0.8, c);
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
// ---------------- glass ----------------
vec4 smudge(vec2 q){                       // skin-oil droplets (~16 um)
  vec2 rel; vec4 v = voro(q, 1.0, rel);
  float rad = 0.16 + 0.30*fract(v.z*7.3);
  float dome = sqrt(max(0., 1. - (v.x/rad)*(v.x/rad))) * step(0.3, v.z);
  return vec4(dome*2.-1., dome, 0., 0.);
}
vec4 scratches(vec2 q){                    // wiping micro-scratches (~3 um)
  float g = 0.;
  for(int j=0;j<3;j++){
    float ang = float(j)*2.1 + 0.4 + 0.3*vnoise(q*0.02+float(j));
    vec2 d = vec2(cos(ang), sin(ang));
    vec2 rq = vec2(dot(q,d), dot(q, vec2(-d.y,d.x)));
    float row = floor(rq.y/3.);
    float hh = hash12(vec2(row, float(j)*13.));
    if(hh>0.70){
      float y0 = row*3. + 3.*hash12(vec2(row,float(j)*7.+1.));
      float w = 0.10 + 0.14*hh;
      float along = smoothstep(0.2,0.6, 0.5+0.5*sin(rq.x*0.12 + hh*20.));
      float x = abs(rq.y-y0)/w;
      g = max(g, (exp(-x*x*2.) - 0.35*exp(-(x-1.3)*(x-1.3)*3.))*along);
    }
  }
  return vec4(-g*1.6 + 0.25*fbm(q*0.7,3), 0.,0.,0.);
}
vec4 polish(vec2 q){ float f = fbm(q*0.55,4); float g = 1.-abs(fbm(q*0.3+4.,3)); return vec4(f*1.3 + 0.6*g*g - 0.3, 0.,0.,0.); }
vec4 coating(vec2 q){ vec2 rel; vec4 v=voro(q,0.9,rel); float rad=0.42+0.12*v.z; float b = sqrt(max(0.,1.-(v.x/rad)*(v.x/rad))); return vec4(b*1.6-0.6 + 0.12*vnoise(q*3.), 0.,0.,0.); }
vec4 chains(vec2 q){                       // perfluoropolyether chains (~3.5 nm): bead strings
  vec2 w = q + 0.9*vec2(fbm(q*0.3,3), fbm(q*0.3+5.,3));
  float id = floor(w.y*2.); float l = (fract(w.y*2.)-0.5)*0.5;
  float x = w.x*2.6 + hash12(vec2(id,2.))*6.; float dx = (fract(x)-0.5)/2.6;
  float r = 0.20;
  float bead = sqrt(max(0., 1. - (dx*dx + l*l)/(r*r)));
  float tube = sqrt(max(0., 1. - l*l/(0.11*0.11)))*0.6;
  float h = max(bead, tube);
  return vec4(h*1.7-0.8, h, 0.,0.); }

// ------------------------------------------------------------------ layer bookkeeping
float gEpsT, gEpsB;
float sT[6], wT[6], aT[6], kT[6];
float sB[6], wB[6], aB[6], kB[6];
float AmpT, AmpB;
mat2 Ry;
float Sc(float lf){ return exp2(-6.3808 - uN - lf); }
float Win(float s, bool first, bool last){ float ls = log2(s); return (first?1.:smoothstep(5.2,3.2,ls))*(last?1.:smoothstep(-2.3,-0.9,ls)); }
float AAk(float s, float eps){ return smoothstep(1.6, 4.5, (1./s)/eps); }

vec4 layerTop(int i, vec2 q){
  if(i==0) return ridges(q+0.0);
  if(i==1) return cells(q+1.7);
  if(i==2) return csurf(q+5.3);
  if(i==3) return fibers(q+2.2);
  if(i==4) return molecules(q+8.8);
  return atoms(q+4.4, true);
}
vec4 layerBot(int i, vec2 q){
  if(i==0) return smudge(q+9.1);
  if(i==1) return scratches(q+3.3);
  if(i==2) return polish(q+1.1);
  if(i==3) return coating(q+6.6);
  if(i==4) return chains(q+2.9);
  return atoms(q+7.7, false);
}
float hTop(vec2 P){ float h=0.; for(int i=0;i<6;i++){ float w=wT[i]*kT[i]; if(w>0.002) h += w*aT[i]/sT[i]*clamp(layerTop(i, P*sT[i]).x,-1.,1.); } return h; }
float hBot(vec2 P){ float h=0.; for(int i=0;i<6;i++){ float w=wB[i]*kB[i]; if(w>0.002) h += w*aB[i]/sB[i]*clamp(layerBot(i, P*sB[i]).x,-1.,1.); } return h; }

// ------------------------------------------------------------------ base geometry
vec3 PA, PB, PA2, PB2;
vec3 Mf(vec3 p){ return p + uFU*(dot(p,uFU)*uFlat); }
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
float sdCap(vec3 p, vec3 a, vec3 b, float r){ vec3 pa=p-a, ba=b-a; float h=clamp(dot(pa,ba)/dot(ba,ba),0.,1.); return length(pa-ba*h)-r; }
vec3 capNormal(vec3 pos, vec3 a, vec3 b){ vec3 ba=b-a, pa=pos-a; float h=clamp(dot(pa,ba)/dot(ba,ba),0.,1.); return normalize(pa-h*ba); }
// flattened fingertip capsule: intersect in the space where it is round (t in real space)
float fingerHit(vec3 ro, vec3 rd, float r){
  vec3 ro2 = Mf(ro), rd2 = Mf(rd); float l = length(rd2); rd2 /= l;
  float t2 = capIntersect(ro2, rd2, PA2, PB2, r);
  return t2 < 0. ? -1. : t2/l;
}
float fingerFar(vec3 rd, float r){ const float BIG = 600.; float t = fingerHit(rd*BIG, -rd, r); return t < 0. ? -1. : BIG - t; }
float sdTopBase(vec3 p){ return sdCap(Mf(p), PA2, PB2, uRt); }
vec3 topNormal(vec3 p){ return normalize(Mf(capNormal(Mf(p), PA2, PB2))); }
float yBot(float z){ float d = z - uZc; return -uHb - uCCl*d*d; }
vec3 botNormal(vec3 p){ return normalize(vec3(0., 1., 2.*uCCl*(p.z-uZc))); }
// ray / shifted parabola: smallest & largest root of  ray.y - (yBot(z)+off) = 0
vec2 botRoots(vec3 rd, float off){
  float a = uCCl*rd.z*rd.z, b = rd.y - 2.*uCCl*uZc*rd.z, c = uHb - off + uCCl*uZc*uZc;
  if(a < 1e-8){ if(b < 0.) { float s = -c/b; return vec2(s, 1e5); } return vec2(-1.); }
  float d = b*b - 4.*a*c; if(d < 0.) return vec2(-1.);
  float q = sqrt(d); return vec2((-b - q)/(2.*a), (-b + q)/(2.*a));
}
vec2 PTop(vec3 p){ return Ry*vec2(p.x, p.z - uAnc.x); }
vec2 PBot(vec3 p){ return Ry*vec2(p.x, p.z - uAnc.y); }
float fTopP(vec3 p){ return sdTopBase(p) - hTop(PTop(p)); }
float fBotP(vec3 p){ return (p.y - yBot(p.z)) - hBot(PBot(p)); }

bool marchTop(vec3 rd, float t0, float t1, float minStep, out float th){
  float ta = t0; float t = t0;
  for(int i=0;i<64;i++){
    float f = fTopP(rd*t);
    if(f < 0.){
      if(i == 0){ th = t0; return true; }
      float tb = t;
      for(int k=0;k<5;k++){ float tm = 0.5*(ta+tb); if(fTopP(rd*tm) < 0.) tb = tm; else ta = tm; }
      th = 0.5*(ta+tb); return true;
    }
    if(t >= t1) break;
    ta = t; t = min(t + max(0.7*f, minStep), t1);
  }
  return false;
}
bool marchBot(vec3 rd, float t0, float t1, float minStep, out float th){
  float ta = t0; float t = t0;
  for(int i=0;i<64;i++){
    float f = fBotP(rd*t);
    if(f < 0.){
      if(i == 0){ th = t0; return true; }
      float tb = t;
      for(int k=0;k<5;k++){ float tm = 0.5*(ta+tb); if(fBotP(rd*tm) < 0.) tb = tm; else ta = tm; }
      th = 0.5*(ta+tb); return true;
    }
    if(t >= t1) break;
    ta = t; t = min(t + max(0.7*f, minStep), t1);
  }
  return false;
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
vec2 phoneCm(vec2 Pw, float Uv){
  vec2 rel = Pw - vec2(0., 3.0);
  float ca = cos(uAz), sa = sin(uAz);
  return vec2(rel.x*ca - rel.y*sa, -rel.x*sa - rel.y*ca)*Uv;
}
vec3 uiCm(vec2 cm){ return pow(texture(uUI, uKeyUV + vec2(cm.x/6.66, cm.y/14.16)).rgb, vec3(2.2)); }
vec3 aces(vec3 x){ return clamp((x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14),0.,1.); }

// soft self-shadow inside the relief shell
float shadowTop(vec3 p, vec3 L, float len){ float res = 1.; for(int k=1;k<=4;k++){ float u = float(k)/4.; float t = len*u*u; float f = fTopP(p + L*t); res = min(res, clamp(5.*f/t + 0.5, 0., 1.)); } return res; }
float shadowBot(vec3 p, vec3 L, float len){ float res = 1.; for(int k=1;k<=4;k++){ float u = float(k)/4.; float t = len*u*u; float f = fBotP(p + L*t); res = min(res, clamp(5.*f/t + 0.5, 0., 1.)); } return res; }

float gE;   // electron stage 0..1
float gPx;

// returns colour (linear, before tone map) and depth for the CoC; a = 1 if a surface was hit
vec4 shadeRay(vec2 q, out float dist, out bool topHit){
  vec3 I = normalize(vec3(q.x, q.y, 1.));
  vec3 V = -I;
  dist = 0.; topHit = q.y > 0.; gEpsT = 1.; gEpsB = 1.;
  // ---- shell intervals
  float tT0 = -1., tT1 = -1., tB0 = -1., tB1 = -1.;
  float AT = AmpT + 1e-4, AB = AmpB + 1e-4;
  if(sdTopBase(vec3(0.)) < AT) tT0 = 0.; else tT0 = fingerHit(vec3(0.), I, uRt + AT);
  if(tT0 >= 0.){ float ti = fingerHit(vec3(0.), I, max(uRt - AT, 0.01)); tT1 = ti > 0. ? ti : fingerFar(I, uRt + AT); if(tT1 < tT0) tT1 = tT0 + 4.*AT; }
  vec2 ro = botRoots(I, AB);
  if(uHb - AB + uCCl*uZc*uZc <= 0.) tB0 = 0.; else tB0 = ro.x;
  if(tB0 >= 0.){ vec2 ri = botRoots(I, -AB); tB1 = ri.x > 0. ? ri.x : min(ro.y, tB0 + 400.); if(tB1 < tB0) tB1 = tB0 + 4.*AB; }
  bool hT = false, hB = false; float th = 1e9, tb = 1e9;
  // footprint per surface (base distance)
  float cT = 1., cB = 1.;
  if(tT0 >= 0.){
    float tbase = fingerHit(vec3(0.), I, uRt); float tf = tbase > 0. ? tbase : 0.5*(tT0+tT1);
    vec3 n0 = topNormal(I*tf); cT = max(abs(dot(n0, I)), 0.12);
    gEpsT = tf*gPx/cT;
  }
  if(tB0 >= 0.){
    vec2 rb = botRoots(I, 0.); float tf = rb.x > 0. ? rb.x : 0.5*(tB0+tB1);
    vec3 n0 = botNormal(I*tf); cB = max(abs(dot(n0, I)), 0.12);
    gEpsB = tf*gPx/cB;
  }
  for(int i=0;i<6;i++){ kT[i] = AAk(sT[i], gEpsT); kB[i] = AAk(sB[i], gEpsB); }
  kT[0] *= uRidgeK;
  // effective shell amplitude after filtering
  float aT2 = 0., aB2 = 0., smT = 0.05, smB = 0.05;
  for(int i=0;i<6;i++){ float w = wT[i]*kT[i]; aT2 += w*aT[i]/sT[i]; if(w>0.01) smT = max(smT, sT[i]);
                        float v = wB[i]*kB[i]; aB2 += v*aB[i]/sB[i]; if(v>0.01) smB = max(smB, sB[i]); }
  if(tT0 >= 0.){
    if(aT2 < 1e-4){ float t = fingerHit(vec3(0.), I, uRt); if(t > 0.){ hT = true; th = t; } }
    else {
      float segP = length(I.xz)*(tT1 - tT0);
      float ms = max((tT1-tT0)/64., min((tT1-tT0)/8., 0.12/smT/max(length(I.xz),0.2)));
      hT = marchTop(I, tT0, tT1, ms, th);
    }
  }
  if(tB0 >= 0. && (!hT || tB0 < th)){
    if(aB2 < 1e-4){ vec2 r = botRoots(I, 0.); if(r.x > 0.){ hB = true; tb = r.x; } }
    else {
      float segP = length(I.xz)*(tB1 - tB0);
      float ms = max((tB1-tB0)/64., min((tB1-tB0)/8., 0.12/smB/max(length(I.xz),0.2)));
      hB = marchBot(I, tB0, tB1, ms, tb);
    }
  }
  if(hT && hB){ if(th < tb) hB = false; else hT = false; }
  if(!hT && !hB) return vec4(0.);

  float lm = smoothstep(2.4, 6.0, uN);
  vec3 col;
  if(hT){
    topHit = true; vec3 X = I*th; dist = th;
    vec2 P = PTop(X);
    vec3 N0 = topNormal(X);
    float eps = max(gEpsT*0.75, 1e-5);
    // albedo + cavity
    vec3 alb = vec3(0.); float ws = 0., cav = 0.; float h0 = 0.;
    for(int i=0;i<6;i++){ float w = wT[i]; if(w < 0.002) continue; float k = kT[i];
      vec4 r = k > 0.01 ? layerTop(i, P*sT[i]) : vec4(0.);
      vec3 base = i==0? vec3(0.80,0.45,0.33) : i==1? vec3(0.88,0.58,0.42) : i==2? vec3(0.86,0.58,0.45) : i==3? vec3(0.82,0.58,0.46) : i==4? vec3(0.72,0.54,0.47) : vec3(0.55,0.52,0.58);
      r.x = clamp(r.x,-1.,1.); alb += w*mix(base, r.yzw, k); ws += w; cav += w*k*r.x; h0 += w*k*aT[i]/sT[i]*r.x; }
    alb /= max(ws,1e-3); cav /= max(ws,1e-3);
    float hx = hTop(P + Ry*vec2(eps,0.)), hz = hTop(P + Ry*vec2(0.,eps));
    vec2 g = vec2(hx-h0, hz-h0)/eps;
    vec3 Tx = normalize(vec3(1.,0.,0.) - N0*N0.x), Tz = normalize(vec3(0.,0.,1.) - N0*N0.z);
    vec3 N = normalize(N0 - g.x*Tx - g.y*Tz);
    vec3 L = normalize(mix(vec3(-0.45,-0.75,-0.5), vec3(-0.50,-0.50,0.70), lm));
    float sh = aT2 > 1e-4 ? shadowTop(X + N0*0.0005*th, L, 3.5*aT2/max(abs(dot(L,N0)),0.25)) : 1.;
    float ndl = dot(N, L);
    float wA = wT[5];
    vec3 wrapc = mix(vec3(0.35,0.22,0.18), vec3(0.15), wA);
    vec3 dif = clamp((vec3(ndl)+wrapc)/(1.+wrapc), 0., 1.)*mix(1., sh, 0.85);
    vec3 H = normalize(L+V);
    float sp = pow(max(dot(N,H),0.), mix(30., 70., wA))*(0.07 + 0.5*wA)*sh;
    float ao = 0.55 + 0.45*smoothstep(-1.0, 0.7, cav);
    float fill = clamp(dot(N, V)*0.5+0.5, 0., 1.);
    col = alb*(0.05 + 1.05*dif)*ao + sp;
    col += alb*vec3(0.30,0.34,0.46)*0.14*fill*lm*ao;
    col += alb*alb*vec3(0.45,0.10,0.05)*0.25*(1.-wA)*(1.-dif.g);
    // rim sheen where the relief turns away (gives the edge a 3D lip)
    col += alb*vec3(1.0,0.75,0.6)*0.25*pow(1.-max(dot(N,V),0.),4.)*lm*sh;
    col *= uTopGain;
  } else {
    topHit = false; vec3 X = I*tb; dist = tb;
    vec2 P = PBot(X);
    vec3 N0 = botNormal(X);
    float eps = max(gEpsB*0.75, 1e-5);
    vec3 alb = vec3(0.); float ws = 0., cav = 0., oil = 0., h0 = 0.;
    for(int i=0;i<6;i++){ float w = wB[i]; if(w < 0.002) continue; float k = kB[i];
      vec4 r = k > 0.01 ? layerBot(i, P*sB[i]) : vec4(0.);
      r.x = clamp(r.x,-1.,1.); h0 += w*k*aB[i]/sB[i]*r.x;
      if(i==0){ oil += w*k*r.y; continue; }
      vec3 a = i==4 ? mix(vec3(0.30,0.36,0.46), vec3(0.56,0.86,0.62), r.y) : i==5 ? mix(vec3(0.42,0.62,0.42), r.yzw, k) : vec3(0.47,0.54,0.66);
      alb += w*a; ws += w; cav += w*k*r.x; }
    alb = ws > 1e-3 ? alb/ws : vec3(0.47,0.54,0.66);
    cav = ws > 1e-3 ? cav/ws : 0.;
    float hx = hBot(P + Ry*vec2(eps,0.)), hz = hBot(P + Ry*vec2(0.,eps));
    vec2 g = vec2(hx-h0, hz-h0)/eps;
    vec3 Tx = normalize(vec3(1.,0.,0.) - N0*N0.x), Tz = normalize(vec3(0.,0.,1.) - N0*N0.z);
    vec3 N = normalize(N0 - g.x*Tx - g.y*Tz);
    vec3 L = normalize(mix(vec3(-0.45,0.75,-0.5), vec3(-0.50,0.50,0.70), lm));
    float sh = aB2 > 1e-4 ? shadowBot(X + N0*0.0005*tb, L, 3.5*aB2/max(abs(dot(L,N0)),0.25)) : 1.;
    float ndl = dot(N,L);
    float wrap = clamp((ndl+0.2)/1.2, 0., 1.)*mix(1., sh, 0.85);
    vec3 H = normalize(L+V);
    float sp = pow(max(dot(N,H),0.), 60.)*sh;
    float glass = 1.-smoothstep(9.5, 13.5, uN);
    float ao = 0.6 + 0.4*smoothstep(-1.0, 0.7, cav);
    float Uv = 1.2*exp2(-uN);
    // mirror image of the fingertip (base shape, warm)
    vec3 Rr = reflect(I, N);
    vec3 refl = vec3(0.004);
    float sr = fingerHit(X + N0*0.002, Rr, uRt);
    if(sr > 0.){ refl = vec3(0.88,0.58,0.44)*(0.10 + 0.5*clamp(-Rr.y,0.,1.))*exp(-sr*0.08)*uTopGain; }
    float fr = 0.04 + 0.96*pow(1.-max(dot(N,V),0.), 5.);
    vec3 glassCol = vec3(0.);
    if(glass > 0.001){
      vec3 Rf = refract(I, N, 1./1.5);
      float delta = 0.07/Uv;
      vec2 off = Rf.xz*(delta/max(-dot(Rf,N0), 0.08));
      vec2 cm = phoneCm(X.xz + off, Uv);
      vec3 uiS = uiCm(cm)*uEmisGain;
      const float CELL = 0.0078;     // diamond PenTile repeat: 2 pixels at 460 ppi
      vec2 pc = cm/CELL;
      vec2 cell = floor(pc), f = fract(pc);
      vec3 pcol = uiCm((cell+0.5)*CELL)*uEmisGain;
      float fpc = gEpsB*Uv/CELL;
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
      float pm = smoothstep(1.2, 0.5, fpc)*uPix;
      vec3 emis = mix(uiS, mix(uiS, sub, pm), smoothstep(2.8, 4.4, uN));
      float trans = 1. - smoothstep(10.5, 13.5, uN);
      glassCol = emis*trans*(1.-fr) + refl*fr + sp*vec3(1.0,0.96,0.92)*(0.35 + 0.9*oil);
      glassCol = mix(glassCol, glassCol*vec3(1.04,0.96,0.80) + vec3(0.04,0.03,0.01)*wrap, oil*0.5);
    }
    float wA = wB[5];
    vec3 matCol = alb*(0.05 + 1.0*wrap)*ao + sp*mix(0.30, 0.55, wA) + refl*fr*0.6;
    matCol += alb*vec3(0.25,0.28,0.38)*0.16*clamp(dot(N,V)*0.5+0.5,0.,1.)*ao;
    col = mix(matCol, glassCol, glass);
  }
  // electron clouds (same centres as the atoms)
  if(gE > 0.001){
    vec3 X = I*dist;
    vec3 cl = topHit ? eCloud(PTop(X)*sT[5] + 4.4, true) : eCloud(PBot(X)*sB[5] + 7.7, false);
    float fl = 0.85 + 0.15*fbm(X.xz*3.0 + vec2(uT*0.3, 0.), 2);
    col = mix(col, cl*fl*1.15, gE);
  }
  float depthDark = mix(1.0, 0.72, smoothstep(2.5, 14., dist));
  return vec4(col*depthDark, 1.);
}

void main(){
  vec2 fc = gl_FragCoord.xy;
  vec2 q = (fc - 0.5*uRes)/(FS*uRes.y);
  float ay = abs(q.y);
  gPx = 1.0/(FS*uRes.y);
  Ry = mat2(cos(uYaw), sin(uYaw), -sin(uYaw), cos(uYaw));
  gE = smoothstep(24.9, 25.95, uN);

  sT[0] = Sc(log2(4.7e-4)); sT[1] = Sc(log2(3.5e-5)); sT[2] = Sc(log2(2.5e-6)); sT[3] = Sc(log2(1.6e-7)); sT[4] = Sc(log2(8.0e-9)); sT[5] = Sc(log2(4.0e-10));
  sB[0] = Sc(log2(1.6e-5)); sB[1] = Sc(log2(3.0e-6)); sB[2] = Sc(log2(6.0e-7)); sB[3] = Sc(log2(4.0e-8)); sB[4] = Sc(log2(3.5e-9)); sB[5] = Sc(log2(4.0e-10));
  aT[0] = 0.13; aT[1] = 0.055; aT[2] = 0.20; aT[3] = 0.24; aT[4] = 0.14; aT[5] = 0.27;
  aB[0] = 0.07; aB[1] = 0.12; aB[2] = 0.22; aB[3] = 0.24; aB[4] = 0.15; aB[5] = 0.27;
  for(int i=0;i<6;i++){ wT[i] = Win(sT[i], i==0, i==5); wB[i] = Win(sB[i], false, i==5); }
  wT[5] = smoothstep(21.6, 23.0, uN); wB[5] = wT[5];
  wB[0] *= smoothstep(5.0, 6.0, uN);
  AmpT = 0.; AmpB = 0.;
  for(int i=0;i<6;i++){ AmpT += wT[i]*aT[i]/sT[i]*(i==0? uRidgeK : 1.); AmpB += wB[i]*aB[i]/sB[i]; }
  AmpT *= 1.05; AmpB *= 1.05;

  vec3 cen = uCen;
  PA = cen - uDirT*uLneg; PB = cen + uDirT*uLpos;
  PA2 = Mf(PA); PB2 = Mf(PB);

  float dist; bool top;
  vec4 r = shadeRay(q, dist, top);
  vec3 col = r.rgb; float cov = r.a; float dsum = dist*r.a; float hc = r.a;
  // adaptive supersampling along the silhouettes of the two bands
  if(uEdge > 0.5){
    float bandT = AmpT/max(uTsT,0.5)*1.6 + 3.*gPx, bandB = AmpB/max(uTsL,0.5)*1.6 + 3.*gPx;
    if(abs(ay - (q.y > 0. ? uYsT : uYsL)) < (q.y > 0. ? bandT : bandB)){
      vec2 J[3] = vec2[3](vec2(0.33,-0.17), vec2(-0.17,-0.33), vec2(-0.33,0.25));
      for(int k=0;k<3;k++){ float d2; bool t2; vec4 r2 = shadeRay(q + J[k]*gPx, d2, t2); col += r2.rgb; hc += r2.a; dsum += d2*r2.a; }
      col /= 4.; cov = hc/4.;
    }
  }
  dist = hc > 0. ? dsum/hc : 0.;

  // gap glow in the electron stage
  if(gE > 0.001 && cov < 0.999){
    bool tp = q.y > 0.;
    float ys = tp ? uYsT : uYsL, ts = tp ? uTsT : uTsL;
    float inGap = max(ys - ay, 0.);
    vec2 Ps = Ry*vec2(q.x*ts, ts - (tp ? uAnc.x : uAnc.y));
    vec3 cl = tp ? eCloud(Ps*sT[5] + 4.4, true) : eCloud(Ps*sB[5] + 7.7, false);
    float vd = inGap*ts;
    col += (1.-cov)*cl*1.15*exp(-vd*vd*3.0)*gE;
  }

  if(gE > 0.001){
    vec2 cid = floor(fc/5.);
    float hs = hash12(cid + 3.7);
    if(hs > 0.986){
      vec2 cp = (cid+0.5)*5. + (hash22(cid)-0.5)*3.;
      float tw = 0.5+0.5*sin(uT*(2.+hs*5.)+hs*40.);
      float sdd = exp(-dot(fc-cp,fc-cp)*0.5);
      col += vec3(0.9,0.95,1.0)*sdd*tw*gE*0.8;
    }
    float rr = length(vec2(q.x*0.16, q.y*2.4));
    float ring = exp(-pow((rr-uRippleR)*30.,2.))*uRipple;
    col += vec3(0.75,0.85,1.0)*ring*0.14;
  }

  col = aces(col);
  col = pow(col, vec3(1./2.2));
  float coc = dist > 0. ? 3.6*abs(dist - uFocusT)/max(dist,1e-3) + 3.*gE : 3.*gE;
  outColor = vec4(col, clamp(coc/24., 0., 1.));
}
