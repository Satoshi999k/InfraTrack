import { gsap } from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import {
  Activity,
  AlertTriangle,
  ArrowRight,
  BarChart3,
  Bell,
  Bridge,
  Building2,
  Camera,
  Check,
  CheckCircle2,
  ChevronLeft,
  ClipboardList,
  Construction,
  Crosshair,
  Droplet,
  House,
  LayoutDashboard,
  Lightbulb,
  Map,
  MapPin,
  Megaphone,
  Menu,
  MessageCircle,
  Newspaper,
  Plus,
  Search,
  User,
  Video,
  Waves,
  X,
} from "lucide-react";

export function initializeSite(root = document) {
const $ = (selector, scope = root) => scope.querySelector(selector);
const $$ = (selector, scope = root) => Array.from(scope.querySelectorAll(selector));
const cleanups = [];
const listen = (target, event, handler, options) => {
  target.addEventListener(event, handler, options);
  cleanups.push(() => target.removeEventListener(event, handler, options));
};
const originalOverflow = document.body.style.overflow;
let mm;
let animationContext;
const cleanup = () => {
  if (mm) mm.revert();
  if (animationContext) animationContext.revert();
  cleanups.splice(0).forEach((removeListener) => removeListener());
  document.body.style.overflow = originalOverflow;
  document.documentElement.classList.remove('rm-on');
};

/* Icons are rendered from Lucide so the phone, dashboard, and navigation stay consistent. */
const ICONS={
 'chevron-left':ChevronLeft,plus:Plus,check:Check,bell:Bell,'map-pin':MapPin,
 activity:Activity,'alert-triangle':AlertTriangle,'check-circle':CheckCircle2,
 house:House,map:Map,user:User,camera:Camera,video:Video,search:Search,
 'message-circle':MessageCircle,'layout-dashboard':LayoutDashboard,
 'clipboard-list':ClipboardList,'bar-chart':BarChart3,megaphone:Megaphone,
 'arrow-right':ArrowRight,menu:Menu,x:X,crosshair:Crosshair,
 construction:Construction,newspaper:Newspaper,lightbulb:Lightbulb,waves:Waves,
 droplet:Droplet,building:Building2,bridge:Bridge
};
const I=(name,size=16,strokeWidth=1.8)=>renderToStaticMarkup(
  createElement(ICONS[name],{
    className:'ic',
    width:size,
    height:size,
    strokeWidth,
    'aria-hidden':true
  })
);
const MARK=(s=18,color='#EE4B7B')=>`<svg width="${s}" height="${s}" viewBox="0 0 32 32" fill="none" aria-hidden="true"><circle cx="16" cy="12" r="6" fill="${color}"/><path d="M16 18v8M8 26h16" stroke="currentColor" stroke-width="2.8" stroke-linecap="round"/></svg>`;

/* OpenStreetMap tiles show Mati City; glowing markers are illustrative sample reports. */
const MAP_ZOOM=14;
const MAP_TILE_SIZE=256;
const MAP_CENTRE=[6.9530,126.2280];
function mercatorPixel(lat,lon){
  const scale=MAP_TILE_SIZE*2**MAP_ZOOM;
  const boundedLat=Math.max(-85.05112878,Math.min(85.05112878,lat));
  const sin=Math.sin(boundedLat*Math.PI/180);
  return{
    x:(lon+180)/360*scale,
    y:(.5-Math.log((1+sin)/(1-sin))/(4*Math.PI))*scale
  };
}
const MAP_ORIGIN=mercatorPixel(...MAP_CENTRE);
function mapPoint(lat,lon){
  const point=mercatorPixel(lat,lon);
  return [800+point.x-MAP_ORIGIN.x,450+point.y-MAP_ORIGIN.y];
}
const MAP_TILE_X=Math.floor((MAP_ORIGIN.x-800)/MAP_TILE_SIZE);
const MAP_TILE_Y=Math.floor((MAP_ORIGIN.y-450)/MAP_TILE_SIZE);
function mapTiles(){
  let images='';
  for(let row=0;row<5;row++)for(let col=0;col<7;col++){
    const x=MAP_TILE_X+col,y=MAP_TILE_Y+row;
    const left=x*MAP_TILE_SIZE-MAP_ORIGIN.x+800;
    const top=y*MAP_TILE_SIZE-MAP_ORIGIN.y+450;
    images+=`<image href="https://tile.openstreetmap.org/${MAP_ZOOM}/${x}/${y}.png" x="${left.toFixed(2)}" y="${top.toFixed(2)}" width="${MAP_TILE_SIZE}" height="${MAP_TILE_SIZE}" preserveAspectRatio="none"/>`;
  }
  return images;
}
const TILES=mapTiles();
function rng(seed){return()=>((seed=(seed*16807)%2147483647)/2147483647)}
function smooth(points){
  const n=points.length;
  let path=`M${points[0][0].toFixed(1)},${points[0][1].toFixed(1)}`;
  for(let i=0;i<n;i++){
    const p0=points[(i-1+n)%n],p1=points[i],p2=points[(i+1)%n],p3=points[(i+2)%n];
    const c1=[p1[0]+(p2[0]-p0[0])/6,p1[1]+(p2[1]-p0[1])/6];
    const c2=[p2[0]-(p3[0]-p1[0])/6,p2[1]-(p3[1]-p1[1])/6];
    path+=`C${c1[0].toFixed(1)},${c1[1].toFixed(1)} ${c2[0].toFixed(1)},${c2[1].toFixed(1)} ${p2[0].toFixed(1)},${p2[1].toFixed(1)}`;
  }
  return path+'Z';
}
function contour(cx,cy,r,seed,amplitude){
  const random=rng(seed),phases=[random()*6.28,random()*6.28,random()*6.28],points=[];
  for(let i=0;i<40;i++){
    const angle=i/40*Math.PI*2;
    const variation=1+amplitude*(.6*Math.sin(2*angle+phases[0])+.3*Math.sin(3*angle+phases[1])+.15*Math.sin(5*angle+phases[2]));
    points.push([cx+Math.cos(angle)*r*variation*1.3,cy+Math.sin(angle)*r*variation*.8]);
  }
  return smooth(points);
}
const CONTOURS=(()=>{
  let paths='';
  for(let i=0;i<12;i++)paths+=`<path class="cn" d="${contour(430,330,36+i*38,7,.2)}"/>`;
  for(let i=0;i<8;i++)paths+=`<path class="cn" d="${contour(1060,160,34+i*38,11,.22)}"/>`;
  return paths;
})();
/* [latitude, longitude, status (r=Reported, p=In Progress, d=Resolved)] */
const MK=[
 [6.9530,126.2280,'r'],[6.9612515,126.2069944,'p'],[6.9450796,126.2323952,'r'],
 [6.9588636,126.2201871,'d'],[6.9506,126.2450,'r'],[6.9475,126.2135,'p'],
 [6.9650,126.2260,'r'],[6.9400,126.2100,'d'],[6.9510,126.2170,'p'],
 [6.9540,126.2390,'r']
];
const MK2=[
 [6.9530,126.2280,'d'],...MK.slice(1),
 [6.9490,126.2220,'d'],[6.9560,126.2350,'r'],[6.9480,126.2290,'p'],
 [6.9630,126.2160,'d'],[6.9460,126.2400,'r'],[6.9550,126.2130,'d'],
 [6.9500,126.2320,'p'],[6.9600,126.2290,'r'],[6.9420,126.2250,'r'],
 [6.9570,126.2430,'p'],[6.9440,126.2170,'d'],[6.9520,126.2040,'r'],
 [6.9660,126.2350,'d'],[6.9380,126.2330,'r'],[6.9480,126.2040,'p'],
 [6.9610,126.2390,'r'],[6.9500,126.2500,'d']
];
let uidN=0;
function buildMap({view='0 0 1600 900',mk=[],ms=1,labels=true}={}){
  const u='u'+(uidN++);
  const marks=mk.map(([lat,lon,s],i)=>{
    const [x,y]=mapPoint(lat,lon);
    return `<g transform="translate(${x.toFixed(2)} ${y.toFixed(2)}) scale(${ms})"><g class="mk mk-${s}${i===0?' mk-f':''}"><circle class="ring" r="24"/>${i===0?'<circle class="pulse" r="24"/>':''}<circle class="dot" r="9.5"/><circle class="core" r="3.4"/></g></g>`;
  }).join('');
  const [, ,width,height]=view.split(' ').map(Number);
  const creditX=Number(view.split(' ')[0])+width-10;
  const creditY=Number(view.split(' ')[1])+height-8;
  const creditSize=Math.max(4,Math.min(11,width*.007));
  return `<svg class="map-svg" viewBox="${view}" preserveAspectRatio="xMidYMid slice" aria-hidden="true" focusable="false"><g class="map-raster">${TILES}</g><g class="g-markers">${marks}</g>${labels?`<text class="map-sample-label" x="${Number(view.split(' ')[0])+16}" y="${creditY}" font-size="${creditSize}">Illustrative sample markers</text>`:''}<a class="map-attribution" href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener noreferrer"><text x="${creditX}" y="${creditY}" text-anchor="end" font-size="${creditSize}">© OpenStreetMap contributors</text></a></svg>`;
}
const DECO=`<svg class="deco" viewBox="0 0 1600 900" preserveAspectRatio="xMidYMid slice" aria-hidden="true" focusable="false">${CONTOURS}</svg>`;

/* sample "photo" of a road defect (drawn, not a real photo) */
const PHOTO=`<svg class="ph" viewBox="0 0 160 110" preserveAspectRatio="xMidYMid slice" aria-hidden="true"><rect width="160" height="110" fill="#9AA6A8"/><rect width="160" height="40" fill="#BFC9C8"/><path d="M0 40q12-11 24-3t28-2 30 2 36-5 42 8V40Z" fill="#6A7E72"/><path d="M0 40h160v70H0Z" fill="#4C5356"/><path d="M0 40h160v4H0Z" fill="#3B4245"/><path d="M80 44 76 110" stroke="#C9CFC9" stroke-width="2.4" stroke-dasharray="9 8" opacity=".7"/><path d="M26 98 50 84l7 6 22-19 7 7 26-17" stroke="#1B2124" stroke-width="2.6" fill="none" stroke-linejoin="round"/><ellipse cx="86" cy="82" rx="22" ry="8.5" fill="#6B7377"/><ellipse cx="86" cy="81" rx="18" ry="6.4" fill="#15191C"/></svg>`;

/* =========================================================================
   <PhoneMockup/>  shell + screen templates (final-state HTML; GSAP sets the starting states)
   ========================================================================= */
const phoneShell=(inner,extra='')=>`<div class="phone ${extra}" aria-hidden="true"><div class="phone-shell"><i class="pb pb1"></i><i class="pb pb2"></i><i class="pb pb3"></i><div class="phone-screen"><div class="island"></div><div class="statusbar"><span>9:41</span><span class="sb-r"><i class="sg"></i><i class="batt"></i></span></div>${inner}<div class="tap"></div><div class="phone-glare"></div></div></div></div>`;
const CH={r:'Reported',p:'In Progress',d:'Resolved'};
const chip=s=>`<span class="chip chip-${s}">${CH[s]}</span>`;
const tabbar=a=>{const t=[['house','home','Home'],['map','map','Map'],['newspaper','news','News'],['user','profile','Profile']];return `<div class="tabbar">${t.slice(0,2).map(([ic,k,l])=>`<div class="tab ${k===a?'on':''}">${I(ic,18)}<span>${l}</span></div>`).join('')}<div class="tab tab-add ${a==='report'?'on':''}"><span class="plus">${I('map-pin',19)}<i>+</i></span><span>Report</span></div>${t.slice(2).map(([ic,k,l])=>`<div class="tab ${k===a?'on':''}">${I(ic,18)}<span>${l}</span></div>`).join('')}</div>`};
const rowI=(ic,t,s,st)=>`<div class="rw"><div class="rw-i">${I(ic,15)}</div><div class="rw-t"><b>${t}</b><span>${s}</span></div>${chip(st)}</div>`;
const hdr=(t,n)=>`<div class="hdr">${I('chevron-left',17,2)}<b>${t}</b><span>${n}</span></div>`;
const TYPED='Cracked and sunken pavement. Water pools here after rain.';
const CATS=[['construction','Road'],['droplet','Water'],['waves','Drainage'],['lightbulb','Lighting']];
const PHONE_MAP_VIEW='540 150 380 780';

const SCREENS={
 home:()=>`<div class="scr scr-home"><div class="hm-top"><div class="app-heading"><span>MATI CITY · DAVAO ORIENTAL</span><b>Welcome, neighbor</b></div><div class="ic-btn">${I('bell',15)}<i class="dn"></i></div></div>
<div class="home-feature"><div class="feature-map map-dark">${buildMap({view:'600 330 320 200',mk:MK.slice(0,5),ms:.9,labels:false})}</div><div class="feature-copy"><span>COMMUNITY INFRASTRUCTURE UPDATE</span><b>Road improvement update</b><small>${I('check',11)} Reported · Mati City</small></div><em>Sample data</em></div>
<div class="home-stats"><div class="home-stat dark"><b>04</b><span>Your open reports</span></div><div class="home-stat"><b>12</b><span>Resolved reports</span></div></div>
<div class="sec-t">Nearby reports <em>See map →</em></div><div class="home-filters"><b>All</b><span>Roads</span><span>Water</span></div>
${rowI('construction','Road damage','Brgy. Central, Mati City','r')}${rowI('lightbulb','Streetlight','Mati City','p')}${tabbar('home')}</div>`,
 map:()=>`<div class="scr scr-map nop"><div class="map-full map-dark">${buildMap({view:PHONE_MAP_VIEW,mk:[MK[0],MK[1],MK[2],MK[3],MK[6],MK[7]],ms:1.4,labels:false})}</div>
<div class="map-top"><div class="pill">${I('search',14)}Search a place</div><div class="fcs"><span class="fc on">All</span><span class="fc">Reported</span><span class="fc">In Progress</span></div></div>
<div class="map-sheet"><div class="ms-ph">${PHOTO}</div><div><b>Cracked road surface</b><span class="l">Sample report</span></div></div>${tabbar('map')}</div>`,
r1:()=>`<div class="scr scr-r1"><div class="report-intro"><span>NEW SUBMISSION</span><b>Report an issue</b></div>
<div class="media-card"><span>${I('camera',20)}</span><b>Add photo or video</b><small>Use your camera to capture evidence</small></div>
<div class="lab">CATEGORY</div><div class="tiles">${CATS.map(([ic,l],i)=>`<div class="tile ${i===0?'sel':''}">${I(ic,20)}<span>${l}</span></div>`).join('')}</div>
<div class="lab">LOCATION</div><div class="location-preview"><div><span>DETECTED COORDINATES</span><b>6.9530° N, 126.2280° E</b></div>${I('crosshair',17)}</div>
<div class="field-preview"><span>DESCRIPTION</span><i>Describe what you saw — size, severity, and any safety risk...</i></div>
<div class="btn-next btn-sub"><i class="sub-fill"></i><span class="l1">Submit report</span><span class="l2">Sending</span></div></div>`,
 r2:()=>`<div class="scr scr-r2">${hdr('New report','2 of 4')}<div class="pbar"><i style="width:50%"></i></div><span class="selchip">${I('construction',13)}Road damage</span>
<div class="lab">Describe the issue</div><div class="ta"><span class="typed">${TYPED}</span><i class="caret"></i></div>
<div class="lab">Add evidence</div><div class="ev"><div class="ev-slot photo-slot"><div class="photo-empty">${I('camera',19)}<span>Add photo</span></div><div class="photo-img">${PHOTO}</div></div><div class="ev-slot">${I('video',19)}<span>Add video</span></div></div>
<div class="btn-next">Continue${I('arrow-right',15,2.2)}</div></div>`,
 r3:()=>`<div class="scr scr-r3">${hdr('New report','3 of 4')}<div class="pbar"><i style="width:75%"></i></div><div class="lab" style="margin-top:2px">Confirm the location</div>
<div class="loc-map map-dark">${buildMap({view:'640 360 240 180',mk:[],labels:false})}<div class="acc"></div><div class="pin"><svg viewBox="0 0 36 46" width="36" height="46"><path d="M18 45C18 45 3 29 3 17a15 15 0 0 1 30 0c0 12-15 28-15 28Z" fill="var(--phone-clay)" stroke="var(--phone-navy)" stroke-width="2.5"/><circle cx="18" cy="17" r="5.5" fill="var(--phone-navy)"/></svg></div><div class="gps">${I('crosshair',12,2.2)}GPS tagged</div></div>
<div class="loc-card">${I('map-pin',17)}<div><b>Brgy. Central, Mati City</b><span>Sample location. Drag the pin to adjust.</span></div></div>
<div class="btn-next">Continue${I('arrow-right',15,2.2)}</div></div>`,
 r4:()=>`<div class="scr scr-r4">${hdr('Review','4 of 4')}<div class="pbar"><i style="width:100%"></i></div>
<div class="rvcard"><div class="rv-ph">${PHOTO}</div><div class="rv-t"><b>Road damage</b><span>${TYPED}</span></div></div>
<ul class="chk"><li><span class="ck">${I('check',11,3)}</span>Photo attached</li><li><span class="ck">${I('check',11,3)}</span>Location tagged with GPS</li><li><span class="ck">${I('check',11,3)}</span>Ready for LGU review</li></ul>
<div class="btn-next btn-sub"><i class="sub-fill"></i><span class="l1">Submit report</span><span class="l2">Sending</span></div></div>`,
 r5:()=>`<div class="scr scr-r5"><svg class="ok" viewBox="0 0 80 80" aria-hidden="true"><circle class="ok-c" cx="40" cy="40" r="34"/><path class="ok-p" d="M25 41l10 10 21-22"/></svg>
<div class="big">Report<br>submitted</div><p>Sent to LGU personnel for review. You can follow its progress here.</p>
<div class="idrow"><span>Sample ID</span><b>IT-0001</b>${chip('r')}</div><div class="btn-next alt">Track progress${I('arrow-right',15,2.2)}</div></div>`,
 st:(state=3)=>`<div class="scr scr-st">${hdr('Report IT-0001','Sample')}
<div class="st-sum"><div class="st-ph">${PHOTO}</div><div><b>Road damage</b><span>Brgy. Central, Mati City</span></div></div>
<div class="st-chips"><span class="chip chip-r c1" style="opacity:${state===1?1:0}">Reported</span><span class="chip chip-p c2" style="opacity:${state===2?1:0}">In Progress</span><span class="chip chip-d c3" style="opacity:${state===3?1:0}">Resolved</span></div>
<div class="tl"><div class="tl-line"><i class="tl-fill" style="transform:scaleY(${(state-1)/2})"></i></div>
${[['Reported','Report received and logged.','r'],['In Progress','Marked for action by LGU personnel.','p'],['Resolved','Marked resolved by LGU personnel.','d']].map((x,i)=>`<div class="tl-n tl-n${i+1}"><span class="tl-d"><i class="tl-on" style="background:var(--st-${x[2]});opacity:${state>=i+1?1:0}"></i></span><div class="tl-t" style="opacity:${state>=i+1?1:.35}"><b>${x[0]}</b><span>${x[1]}</span></div></div>`).join('')}</div>
<div class="cm" style="opacity:${state===3?1:0}">${I('message-circle',14)}<div><b>Neighbor <em>sample comment</em></b>Thanks for the update.</div></div>
<div class="toast">${I('bell',14)}<span>Status updated: ${state===3?'Resolved':state===2?'In Progress':'Reported'}</span></div></div>`
};

/* =========================================================================
   preview card (scene 2) + dashboard (scene 5)
   ========================================================================= */
const cardHTML=()=>`<div class="cp-in"><div class="cp-ph">${PHOTO}<span class="cp-tag">Sample report</span></div><div class="cp-b"><div class="cp-top">${chip('r')}<span style="font-size:.85rem;opacity:.65">IT-0001</span></div><b>Cracked road surface</b><div class="cp-m"><span>${I('map-pin',15)}Brgy. Central</span><span>${I('camera',15)}1 photo</span><span>${I('message-circle',15)}Comments open</span></div></div></div>`;
const DASH_VIEW='570 326 380 248';
const dashHTML=()=>`<div class="dash-bg"></div><div class="dash-in">
<aside class="dash-side">
 <div class="dash-brand"><span class="dash-brand-mark">${I('building',19)}</span><span><b>InfraTrack</b><small>ADMIN PORTAL · MATI</small></span></div>
 <div class="dash-nav-group"><span class="dash-nav-label">Operations</span>
  <span class="dsi on">${I('layout-dashboard',16)}<b>Overview</b></span>
  <span class="dsi">${I('clipboard-list',16)}<b>Issue Queue</b></span>
  <span class="dsi">${I('map',16)}<b>Infrastructure Map</b></span>
  <span class="dsi">${I('bar-chart',16)}<b>Analytics &amp; Reports</b></span>
 </div>
 <div class="dash-nav-group dash-admin-group"><span class="dash-nav-label">Administration</span>
  <span class="dsi">${I('user',16)}<b>User Management</b></span>
  <span class="dsi">${I('megaphone',16)}<b>Public Advisory</b></span>
 </div>
 <div class="dash-account"><span class="dash-avatar">AD</span><span><b>Admin</b><small>LGU personnel</small></span></div>
</aside>
<div class="dash-main">
 <header class="dash-top"><div><small>LOCAL GOVERNMENT UNIT</small><b>Overview</b></div><span class="dash-search">${I('search',13)}Search infrastructure ID, street, or barangay</span><span class="dash-walkin">${I('plus',12)}Log walk-in report</span><span class="dash-notice">${I('bell',15)}</span><span class="dash-admin-user">${MARK(19)}<b>Admin</b></span></header>
 <div class="dash-content">
  <div class="dash-kpis">
   <div class="dash-kpi">${I('clipboard-list',15)}<small>Total reports</small><b>128</b><em>All database reports · sample</em></div>
   <div class="dash-kpi clay">${I('alert-triangle',15)}<small>Pending tasks</small><b>04</b><em>Needs review · sample</em></div>
   <div class="dash-kpi green">${I('activity',15)}<small>Avg. resolution time</small><b>3.2 <i>days</i></b><em>Resolved reports · sample</em></div>
   <div class="dash-kpi amber">${I('check-circle',15)}<small>Completion rate</small><b>67%</b><em>Resolved issues · sample</em></div>
  </div>
  <div class="dash-grid">
   <div class="panel dash-map map-light"><div class="dash-card-head"><b>Active infrastructure issues</b><span>Sample data</span></div>${buildMap({view:DASH_VIEW,mk:MK2,ms:1,labels:false})}<div class="dm-call">MT-2026-860 · Road damage</div><div class="dm-leg"><span style="--c:var(--st-r)"><i></i>Reported</span><span style="--c:var(--st-p)"><i></i>In Progress</span><span style="--c:var(--st-d)"><i></i>Resolved</span></div></div>
   <div class="panel dash-activity"><div class="dash-card-head"><b>Recent activity</b><span>View all ${I('arrow-right',11)}</span></div>
    <div class="dash-activity-item"><i class="activity-dot clay"></i><div><b>Road damage reported</b><p>Reported · Road damage · Brgy. Central</p><small>Sample record · MT-2026-879</small></div></div>
    <div class="dash-activity-item"><i class="activity-dot teal"></i><div><b>Streetlight issue updated</b><p>In Progress · Streetlight · Mati City</p><small>Sample record · MT-2026-861</small></div></div>
    <div class="dash-activity-item"><i class="activity-dot green"></i><div><b>Drainage concern resolved</b><p>Resolved · Drainage · Brgy. Dawan</p><small>Sample record · MT-2026-860</small></div></div>
   </div>
  </div>
  <div class="dash-lower">
   <div class="panel dash-category"><div class="dash-card-head"><b>Reports by category</b><span>Last 30 days · sample</span></div><div class="cbar"><span>Road damage</span><div><i style="width:92%"></i></div><b>12</b><span>Drainage</span><div><i style="width:64%"></i></div><b>08</b><span>Streetlight</span><div><i style="width:46%"></i></div><b>05</b></div></div>
   <div class="panel dash-team"><div class="dash-card-head"><b>Team workload</b><span>Active assignments</span></div><div class="dash-team-row"><i class="team-avatar clay">TA</i><span><b>Team Alpha</b><small>Central · sample assignment</small></span><em>04 active</em></div><div class="dash-team-row"><i class="team-avatar teal">MW</i><span><b>Mati Water District</b><small>Mati City · sample assignment</small></span><em>02 active</em></div></div>
  </div>
  <div class="dash-reports"><div class="dash-reports-head"><b>Recent reports</b><span>View issue queue ${I('arrow-right',11)}</span></div>
   <div class="dash-table-head"><span>Issue</span><span>Severity</span><span>Status</span><span>Reported by</span><span>Filed</span><span>Assigned to</span></div>
   <div class="dash-table-row feat-row"><b>MT-2026-860 · Road damage</b><span class="dash-severity high">High</span><span class="dash-status resolved">Resolved</span><span>Sample resident</span><span>Oct 10</span><span>Team Alpha</span></div>
   <div class="dash-table-row"><b>MT-2026-879 · Streetlight</b><span class="dash-severity medium">Medium</span><span class="dash-status progress">In Progress</span><span>Sample resident</span><span>Oct 09</span><span>Mati Water District</span></div>
  </div>
 </div>
</div></div>`;

/* =========================================================================
   helpers
   ========================================================================= */
function offsetTL(el,root){let x=0,y=0,n=el;while(n&&n!==root){x+=n.offsetLeft;y+=n.offsetTop;n=n.offsetParent}return{x,y}}
function offsetC(el,root){const o=offsetTL(el,root);return{x:o.x+el.offsetWidth/2,y:o.y+el.offsetHeight/2}}
function splitWords(el){const words=el.textContent.trim().split(/\s+/);el.setAttribute('aria-label',el.textContent.trim());el.innerHTML=words.map(w=>`<span class="wm" aria-hidden="true"><span class="wi">${w}</span></span>`).join(' ')}

/* =========================================================================
   MOUNT (shared by animated and reduced-motion layouts)
   ========================================================================= */
const prefersRM=window.matchMedia('(prefers-reduced-motion: reduce)');
const canAnimate=!prefersRM.matches;
if(!canAnimate)document.documentElement.classList.add('rm-on');
listen(prefersRM,'change',()=>location.reload());

$('#menuBtn').innerHTML=I('menu',24,2);
$('#bgHero').innerHTML=DECO;
$('#finalDeco').innerHTML=DECO;
$('#finalDeco').style.cssText='position:absolute;inset:0;opacity:.8;pointer-events:none';
$('#mapDark .pan').innerHTML=buildMap({mk:MK});
$('#mapLight .pan').innerHTML=buildMap({mk:MK2});
$('#dash').innerHTML=dashHTML();
$('#card').innerHTML=cardHTML();
$('#phoneRig').innerHTML=phoneShell(['home','map','r1','r2','r3','r4','r5'].map(k=>SCREENS[k]()).join('')+SCREENS.st(3),'');
$('#finalPhone').innerHTML=phoneShell(SCREENS.home());
$('#sysCols').innerHTML=[['camera','Residents report','Choose the issue, add a description with photo or video, and tag the location with GPS.'],['layout-dashboard','LGU personnel review','Reports appear on an administrative dashboard with a map, details and status controls.'],['bell','Everyone follows progress','Status moves from Reported to In Progress to Resolved, with community comments and advisories.']].map(([ic,t,p])=>`<div><h3>${I(ic,24)}${t}</h3><p>${p}</p></div>`).join('');
$$('[data-words]').forEach(splitWords);

/* =========================================================================
   <ReducedMotionLayout/>  every scene, readable, no scrolljacking
   ========================================================================= */
function buildRM(){
  const fit=(inner,cap)=>`<figure class="rm-ph" style="margin:0"><div class="rm-fit">${phoneShell(inner)}</div><figcaption>${cap}</figcaption></figure>`;
  const sec=(id,dark,h,p,vis)=>`<section class="rm-s ${dark?'dark':''}" id="${id}"><div class="rm-in"><h2 class="h-lg">${h}</h2><p class="sub" style="max-width:52ch">${p}</p></div><div class="rm-vis">${vis}</div></section>`;
  $('#rm').innerHTML=
   `<section class="rm-s" id="top"><div class="rm-in"><h1 class="h-xl">A Better Mati Starts With Being Heard.</h1><p class="sub">Report infrastructure issues, follow progress, and help create a better-informed community.</p></div><div class="rm-vis">${fit(SCREENS.home(),'The InfraTrack home screen')}</div></section>`+
   sec('map',true,'Every Issue Has a Place.','A real OpenStreetMap view of Mati City provides geographic context. The glowing report markers and report details are illustrative sample data.',`<div class="rm-map map-dark">${buildMap({mk:MK})}<div class="card-prev">${cardHTML()}</div></div>`)+
   sec('reporting',false,'See It. Report It. Track It.','Reporting is five short steps.',[['r1','1. Choose the issue'],['r2','2. Add a description and photo'],['r3','3. Check the GPS location'],['r4','4. Submit the report'],['r5','5. Get the confirmation']].map(([k,c])=>fit(SCREENS[k](),c)).join(''))+
   sec('status',true,'From Reported to Resolved.','A report moves through three states. These are illustrative workflow states, not repair timelines or guarantees.',[1,2,3].map(s=>fit(SCREENS.st(s),CH[['','r','p','d'][s]])).join(''))+
   sec('dashboard',false,'A Clearer View of Community Concerns.','LGU personnel see the same report on a dashboard, with its map, details, status and summary views. All data shown is sample data.',`<div class="rm-dash"><div class="dash">${dashHTML()}</div></div>`)+
   `<section class="rm-s" id="community" style="padding-bottom:clamp(60px,10vh,110px)"><div class="rm-in"><h2 class="h-lg">Better Visibility. More Informed Action.</h2><p class="sub" style="max-width:52ch">Reports can be reviewed against a real map of Mati City. Every glowing marker and report shown here is illustrative sample data, not a real complaint or result.</p></div><div class="rm-vis"><div class="rm-light map-light">${buildMap({mk:MK2})}</div></div></section>`;
}
if(!canAnimate)buildRM();

/* =========================================================================
   NAV + deep links (work with the pinned timeline)
   ========================================================================= */
const SCENE_T={top:0,map:3.45,reporting:4.5,status:8.95,dashboard:12.95,community:14.95};
const SCENE_NAMES=['Hero','Location','Report','Status','Monitoring','Community'];
const SCENE_START=[0,1.4,3.6,8.2,10.8,13.4];
const TOTAL=15.4;
let stageST=null;
const menu=$('#menu'),menuBtn=$('#menuBtn');
function setMenu(open){menu.classList.toggle('open',open);menuBtn.setAttribute('aria-expanded',String(open));menuBtn.setAttribute('aria-label',open?'Close menu':'Open menu');menuBtn.innerHTML=I(open?'x':'menu',24,2);document.body.style.overflow=open?'hidden':''}
listen(menuBtn,'click',()=>setMenu(!menu.classList.contains('open')));
listen(window,'keydown',e=>{if(e.key==='Escape'&&menu.classList.contains('open')){setMenu(false);menuBtn.focus()}});
function goTo(key,instant){
  if(!stageST||!(key in SCENE_T))return false;
  const y=stageST.start+(SCENE_T[key]/TOTAL)*(stageST.end-stageST.start);
  scrollTo({top:Math.round(y),behavior:instant?'instant':'smooth'});return true;
}
listen(document,'click',e=>{
  const a=e.target.closest('a[href^="#"]');if(!a)return;
  const key=a.dataset.go||a.getAttribute('href').slice(1);
  if(menu.classList.contains('open'))setMenu(false);
  if(stageST&&key in SCENE_T){e.preventDefault();history.pushState(null,'','#'+(key==='top'?'':key));goTo(key)}
});
listen(window,'popstate',()=>{const k=location.hash.slice(1)||'top';if(!goTo(k,true)&&k==='top')scrollTo(0,0)});

if(!canAnimate){
  /* nothing else to run: the page is fully readable without GSAP */
  return cleanup;
}

/* =========================================================================
   GSAP SETUP
   ========================================================================= */
gsap.registerPlugin(ScrollTrigger);
ScrollTrigger.config({ignoreMobileResize:true});
const hudN=$('.hud-n'),hudName=$('.hud-name'),hudBar=$('.hud-bar b'),navLinks=$$('.nav-links a');
function updateHud(p){
  const t=p*TOTAL;let i=0;SCENE_START.forEach((s,k)=>{if(t>=s-.0001)i=k});
  if(t>=4&&t<10.8){
    const phone=$('#phoneRig');
    // Scrubbed scroll jumps can skip the phone's fade-in update.
    if(phone&&Number(gsap.getProperty(phone,'autoAlpha'))<1)gsap.set(phone,{autoAlpha:1});
  }
  hudN.textContent=i+1;hudName.textContent=SCENE_NAMES[i];
  hudBar.style.transform=`scaleX(${p})`;
  navLinks.forEach(a=>a.classList.toggle('on',Number(a.dataset.i)===i));
}

/* =========================================================================
   <HeroScene/>  the one master timeline for scenes 1 to 6
   ========================================================================= */
function buildStage(desk){
  const stage=$('#stage'),phone=$('#phoneRig'),card=$('#card'),dash=$('#dash'),mapDark=$('#mapDark'),mapLight=$('#mapLight'),veil=$('#veil'),wash=$('#wash'),conn=$('#conn');
  const panD=$('.pan',mapDark),panL=$('.pan',mapLight),screen=$('.phone-screen',phone),tap=$('.tap',phone);
  const vw=()=>innerWidth,vh=()=>stage.clientHeight||innerHeight;
  const sc=k=>()=>Math.min(vh()*(desk?.72:vh()<740?.54:.64)/620,vw()*(desk?.42:vh()<740?.74:.8)/300)*k;
  const pxu=()=>Math.max(vw()/1600,vh()/900);
  const focal=()=>({x:vw()/2-40*pxu(),y:vh()/2});
  const org=()=>{const f=focal();return f.x+'px '+f.y+'px'};
  const ox=desk?72:50,oy=desk?50:67;
  /* phone anchor points per scene */
  const PXh=desk?()=>vw()*.22:()=>vw()>vh()?vw()*.19:0, PYh=desk?()=>0:()=>vw()>vh()?0:vh()*(vh()<740?.21:.17);
  const PYc=desk?()=>0:()=>vh()*.12;
  const PX3=desk?()=>vw()*.17:()=>vw()>vh()?vw()*.19:0, PY3=desk?()=>0:()=>vw()>vh()?0:vh()*.15;
  const PX5=desk?()=>-vw()*.27:()=>0, PY5=desk?()=>vh()*.14:()=>vh()*.95;
  const DX=desk?()=>vw()*.12:()=>0, DY=desk?()=>vh()*.03:()=>vh()*(vw()>vh()?.2:.06);
  const CW=320;

  /* elements */
  const scr=n=>$('.scr-'+n,phone);
  const sHome=scr('home'),sMap=scr('map'),r1=scr('r1'),r2=scr('r2'),r3=scr('r3'),r4=scr('r4'),r5=scr('r5'),st=scr('st');
  const tHero=$('#tHero'),heroLns=$$('.ln>span',tHero),heroSub=$('#heroSub'),cue=$('#cue');
  const tS2=$('#tS2'),s2Words=$$('.wi',tS2),tS3=$('#tS3'),h3=$('#h3'),stepsLi=$$('#steps li'),tS4=$('#tS4'),s4Words=$$('.wi',tS4);
  const tS5=$('#tS5'),s5Words=$$('.wi',tS5),tS6=$('#tS6'),tVeil=$('#tVeil');
  const mkDark=$$('.mk',mapDark),mkF=mkDark[0],mkOthers=mkDark.slice(1),phoneMk=$$('.mk',sMap);
  const swWrap=$('#swWrap'),hline=$('#hline'),hf=$('.hf',hline),tks=$$('.tk',hline),sw=[$('.sw1',tS4),$('.sw2',tS4),$('.sw3',tS4)],s4note=$('#s4note');

  /* ---------- initial states (static, non-measured) ---------- */
  gsap.set([sMap,r1,r2,r3,r4,r5,st],{autoAlpha:0});
  gsap.set($$('.txt',stage).filter(e=>e!==tHero),{autoAlpha:0});
  gsap.set(tVeil,{autoAlpha:0});
  gsap.set(card,{autoAlpha:0,yPercent:-50});
  gsap.set([dash,conn],{autoAlpha:0});
  gsap.set(s2Words,{yPercent:115});
  gsap.set(s4Words,{yPercent:115,skewY:7});
  gsap.set(s5Words,{xPercent:60});
  gsap.set(stepsLi,{opacity:.3});
  gsap.set([swWrap,hline,s4note],{autoAlpha:0});
  gsap.set(sw[0],{yPercent:0});gsap.set([sw[1],sw[2]],{yPercent:110});
  gsap.set(mkDark,{scale:0,autoAlpha:0});
  gsap.set(phoneMk,{scale:0});
  /* r1 */
  const tiles=$$('.tile',r1),tile0=tiles[0];
  gsap.set(tile0,{backgroundColor:'rgba(193,89,43,.10)',color:'#0E3A4C',borderColor:'#C1592B'});
  const tp0=offsetC(tile0,screen);
  /* r2 */
  const typed=$('.typed',r2);typed.textContent='';
  const photoEmpty=$('.photo-empty',r2),photoImg=$('.photo-img',r2),photoSlot=$('.photo-slot',r2),pp=offsetC(photoSlot,screen);
  gsap.set(photoImg,{autoAlpha:0,scale:.8});
  /* r3 */
  const pin=$('.pin',r3),acc=$('.acc',r3),locCard=$('.loc-card',r3);
  gsap.set([pin,acc,locCard],{autoAlpha:0});
  /* r4 */
  const chkLis=$$('.chk li',r4),subFill=$('.sub-fill',r4),l1=$('.l1',r4),l2=$('.l2',r4),subBtn=$('.btn-sub',r4),sp=offsetC(subBtn,screen);
  gsap.set(chkLis,{autoAlpha:0});
  /* r5 */
  const okC=$('.ok-c',r5),okP=$('.ok-p',r5),r5Kids=[$('.big',r5),$('p',r5),$('.idrow',r5),$('.btn-next',r5)];
  gsap.set(okC,{strokeDashoffset:214});gsap.set(okP,{strokeDashoffset:64});gsap.set(r5Kids,{autoAlpha:0,y:14});
  /* status screen: render state 3, then rewind to state 1 */
  const tlFill=$('.tl-fill',st),tlOn=[1,2,3].map(i=>$('.tl-n'+i+' .tl-on',st)),tlT=[1,2,3].map(i=>$('.tl-n'+i+' .tl-t',st)),chips=[1,2,3].map(i=>$('.c'+i,st)),cm=$('.cm',st),toast=$('.toast',st);
  gsap.set(tlFill,{scaleY:0});gsap.set([tlOn[1],tlOn[2]],{opacity:0,scale:.4});gsap.set([tlT[1],tlT[2]],{opacity:.35});
  gsap.set([chips[1],chips[2]],{opacity:0});gsap.set(chips[0],{opacity:1});gsap.set([cm,toast],{autoAlpha:0});
  /* dashboard */
  const dashPanels=$$('.dash-top,.dash-kpi,.dash-map,.dash-activity,.dash-lower .panel,.dash-reports',dash),dashMap=$('.dash-map',dash),dashChrome=$$('.dash-side,.dash-top,.dash-kpis,.dash-activity,.dash-lower,.dash-reports,.dash-bg',dash);
  const dashMk=$$('.mk',dash),sbars=$$('.cbar i',dash),featRow=$('.feat-row',dash);
  gsap.set(dashPanels,{autoAlpha:0});gsap.set(sbars,{scaleX:0});gsap.set(featRow,{backgroundColor:'rgba(27,138,131,0)'});
  gsap.set(wash,{opacity:0});

  /* connector (phone -> same report row in the dashboard), measured not guessed */
  function layoutConn(){
    if(!desk)return;
    const s=sc(.74)(),cx=vw()/2+PX5(),cy=vh()/2+PY5();
    const x1=cx+138*s,y1=cy-40*s;
    const o=offsetTL(featRow,dash),dcx=vw()/2+DX(),dcy=vh()/2+DY();
    const x2=dcx-dash.offsetWidth/2+o.x,y2=dcy-dash.offsetHeight/2+o.y+featRow.offsetHeight/2,mx=(x1+x2)/2;
    $('path',conn).setAttribute('d',`M${x1},${y1} C${mx},${y1} ${mx},${y2} ${x2},${y2}`);
  }
  ScrollTrigger.addEventListener('refresh',layoutConn);

  /* geometry for the scene-6 map reveal (no reliance on mid-animation DOM rects) */
  const panelRect=()=>{const o=offsetTL(dashMap,dash),l=vw()/2+DX()-dash.offsetWidth/2+o.x,t=vh()/2+DY()-dash.offsetHeight/2+o.y;return{l,t,w:dashMap.offsetWidth,h:dashMap.offsetHeight}};
  const clipFrom=()=>{const r=panelRect();return`inset(${r.t}px ${vw()-r.l-r.w}px ${vh()-r.t-r.h}px ${r.l}px round 14px)`};
  const zoomFrom=()=>{const r=panelRect(),dpx=Math.max(r.w/380,r.h/248);return dpx/pxu()};
  const shiftFrom=()=>{const r=panelRect(),f=focal();return{x:r.l+r.w/2-f.x,y:r.t+r.h/2-f.y}};
  gsap.set(panL,{transformOrigin:org});

  /* ---------- the master timeline ---------- */
  const unit=desk?.44:.24;
  const tl=gsap.timeline({
    defaults:{ease:'none',immediateRender:false},
    scrollTrigger:{trigger:stage,start:'top top',end:()=>'+='+Math.round(vh()*unit*TOTAL),pin:true,scrub:desk?.7:.18,anticipatePin:1,invalidateOnRefresh:true,fastScrollEnd:true,onUpdate:s=>updateHud(s.progress),onRefresh:s=>updateHud(s.progress)}
  });
  stageST=tl.scrollTrigger;
  const first={immediateRender:true};
  const swap=(a,b,t)=>tl.to(a,{autoAlpha:0,x:-18,duration:.2,ease:'power2.in'},t).fromTo(b,{autoAlpha:0,x:18},{autoAlpha:1,x:0,duration:.25,ease:'power2.out'},t+.05);

  /* ===== SCENE 1: hero, phone and map become one object (0 to 1.4) ===== */
  tl.fromTo(phone,{x:PXh,y:PYh,scale:sc(1),rotationY:desk?-18:0,rotationX:desk?5:0,rotation:desk?-3:0,transformPerspective:1400,autoAlpha:1},
                  {x:0,y:PYc,scale:sc(1.14),rotationY:0,rotationX:0,rotation:0,duration:1.05,ease:'power2.inOut',...first},0)
    .to(heroLns,{yPercent:-120,duration:.45,stagger:.07,ease:'power3.in'},.08)
    .to([heroSub,cue],{autoAlpha:0,y:-18,duration:.3},0)
    .fromTo(mapDark,{clipPath:`circle(0% at ${ox}% ${oy}%)`},{clipPath:`circle(145% at ${ox}% ${oy}%)`,duration:1.35,ease:'power2.in',...first},0)
    .fromTo(bgHeroEl(),{opacity:1},{opacity:0,duration:.8},.6)
    .fromTo(panD,{scale:1.2,transformOrigin:org},{scale:1,transformOrigin:org,duration:3,ease:'none',...first},0)
    .to(sHome,{autoAlpha:0,duration:.25},.85).to(sMap,{autoAlpha:1,duration:.25},.85)
    .to(phoneMk,{scale:1,duration:.3,stagger:.05,ease:'back.out(2)'},1.0);

  /* ===== SCENE 2: the map expands, markers arrive, one report becomes the focus (1.4 to 3.6) ===== */
  tl.to(tS2,{autoAlpha:1,duration:.15},1.2)
    .to(s2Words,{yPercent:0,duration:.55,stagger:.08,ease:'power3.out'},1.2)
    .to(phone,{y:()=>vh()*.95,scale:sc(.8),rotation:8,autoAlpha:0,duration:.9,ease:'power2.in'},1.55)
    .to(mkDark,{scale:1,autoAlpha:1,duration:.4,stagger:{each:.08,from:'end'},ease:'back.out(2.2)'},1.95)
    .to(mkOthers,{opacity:.28,duration:.4},3.05)
    .to(mkF,{scale:1.7,duration:.5,ease:'back.out(1.6)'},3.05)
    .to(panD,{scale:1.1,duration:.9,ease:'power2.inOut'},3.05)
    .fromTo(card,{autoAlpha:0,scale:.94,x:()=>desk?focal().x+54:(vw()-CW)/2,y:()=>desk?focal().y:vh()*.66},
                 {autoAlpha:1,scale:1,x:()=>desk?focal().x+54:(vw()-CW)/2,y:()=>desk?focal().y:vh()*.66,duration:.45,ease:'power3.out'},3.12);

  /* ===== SCENE 3: pinned reporting demo, five readable steps (3.6 to 8.2) ===== */
  tl.to(s2Words,{yPercent:-120,duration:.4,stagger:.04,ease:'power3.in'},3.6).to(tS2,{autoAlpha:0,duration:.05},4.05)
    .to(veil,{opacity:.6,duration:.6},3.6)
    /* the preview card morphs into the phone */
    .to(card,{x:()=>vw()/2+PX3()-sc(1)()*150,y:()=>vh()/2+PY3(),width:()=>300*sc(1)(),height:()=>620*sc(1)(),borderRadius:()=>(48*sc(1)())+'px',duration:.6,ease:'power3.inOut'},3.65)
    .to($('.cp-in',card),{autoAlpha:0,duration:.25},3.65)
    .set(sMap,{autoAlpha:0},3.95).set(r1,{autoAlpha:1},3.95)
    .fromTo(phone,{x:PX3,y:PY3,scale:sc(1),rotation:0,rotationY:0,rotationX:0,autoAlpha:0},{autoAlpha:1,duration:.3},4.0)
    .to(card,{autoAlpha:0,duration:.25},4.15)
    .to(tS3,{autoAlpha:1,duration:.2},3.85)
    .fromTo(h3,{clipPath:'inset(0 100% 0 0)'},{clipPath:'inset(0 0% 0 0)',duration:.6,ease:'power2.out'},3.85);
  const ts=[4.3,5.08,5.86,6.64,7.42];
  stepsLi.forEach((li,k)=>{tl.to(li,{opacity:1,duration:.2},ts[k]);if(k>0)tl.to(stepsLi[k-1],{opacity:.3,duration:.2},ts[k]);li.classList.toggle('on',false)});
  /* mobile shows only the active step: toggle the class on a tiny scrubbed callback */
  stepsLi.forEach((li,k)=>tl.call(()=>{stepsLi.forEach((l,j)=>l.classList.toggle('on',j===k))},null,ts[k]+.01));
  tl.call(()=>stepsLi.forEach((l,j)=>l.classList.toggle('on',j===0)),null,.001);
  /* step 1: choose the issue */
  tl.fromTo(tap,{autoAlpha:0,x:tp0.x+30,y:tp0.y+50,scale:1},{autoAlpha:1,x:tp0.x,y:tp0.y,duration:.18,ease:'power2.out'},4.32)
    .to(tap,{scale:.78,duration:.06},4.52)
    .to(tile0,{backgroundColor:'rgba(193,89,43,.10)',color:'#0E3A4C',borderColor:'#C1592B',duration:.12},4.56)
    .to(tap,{scale:1,autoAlpha:0,duration:.14},4.66);
  /* step 2: describe + photo */
  swap(r1,r2,5.08);
  const typeObj={n:0};
  tl.fromTo(typeObj,{n:0},{n:TYPED.length,duration:.32,ease:'none',onUpdate:()=>{typed.textContent=TYPED.slice(0,Math.round(typeObj.n))}},5.22)
    .fromTo(tap,{autoAlpha:0,x:pp.x+24,y:pp.y+40,scale:1},{autoAlpha:1,x:pp.x,y:pp.y,duration:.14},5.55)
    .to(tap,{scale:.78,duration:.05},5.69)
    .to(photoEmpty,{autoAlpha:0,duration:.1},5.72)
    .to(photoImg,{autoAlpha:1,scale:1,duration:.2,ease:'back.out(1.6)'},5.72)
    .to(tap,{scale:1,autoAlpha:0,duration:.1},5.78);
  /* step 3: GPS location */
  swap(r2,r3,5.86);
  tl.fromTo(pin,{y:-46,autoAlpha:0},{y:0,autoAlpha:1,duration:.25,ease:'bounce.out'},6.05)
    .fromTo(acc,{scale:.2,autoAlpha:0},{scale:1,autoAlpha:1,duration:.3},6.2)
    .fromTo(locCard,{y:30,autoAlpha:0},{y:0,autoAlpha:1,duration:.25},6.3);
  /* step 4: review + submit */
  swap(r3,r4,6.64);
  tl.to(chkLis,{autoAlpha:1,x:0,duration:.15,stagger:.06},6.78)
    .fromTo(tap,{autoAlpha:0,x:sp.x+26,y:sp.y+40,scale:1},{autoAlpha:1,x:sp.x,y:sp.y,duration:.14},6.98)
    .to(tap,{scale:.78,duration:.05},7.1)
    .fromTo(subFill,{scaleX:0},{scaleX:1,duration:.2,ease:'none'},7.14)
    .to(l1,{autoAlpha:0,duration:.08},7.14).to(l2,{autoAlpha:1,duration:.1},7.16)
    .to(tap,{autoAlpha:0,duration:.08},7.2);
  /* step 5: confirmation */
  swap(r4,r5,7.42);
  tl.to(okC,{strokeDashoffset:0,duration:.28},7.55).to(okP,{strokeDashoffset:0,duration:.18},7.78)
    .to(r5Kids,{autoAlpha:1,y:0,duration:.2,stagger:.05},7.7);
  gsap.set(l2,{autoAlpha:0});

  /* ===== SCENE 4: the submitted report becomes a status journey (8.2 to 10.8) ===== */
  tl.to(tS3,{autoAlpha:0,x:-30,duration:.35,ease:'power2.in'},8.2).to(veil,{opacity:.72,duration:.5},8.2)
    .to(tS4,{autoAlpha:1,duration:.15},8.3)
    .to(s4Words,{yPercent:0,skewY:0,duration:.55,stagger:.07,ease:'power3.out'},8.3)
    .to([swWrap,hline,s4note],{autoAlpha:1,y:0,duration:.4,stagger:.08},8.5);
  swap(r5,st,8.3);
  tl.to(tks[0],{backgroundColor:'#F2C230',borderColor:'#F2C230',duration:.2},8.5)
    /* Reported -> In Progress */
    .to(tlFill,{scaleY:.5,duration:.5,ease:'power1.inOut'},9.0)
    .to(tlOn[1],{opacity:1,scale:1,duration:.2},9.3).to(tlT[1],{opacity:1,duration:.2},9.3)
    .to(chips[0],{opacity:0,duration:.12},9.2).to(chips[1],{opacity:1,duration:.12},9.25)
    .to(sw[0],{yPercent:-110,duration:.4,ease:'power3.inOut'},9.1).fromTo(sw[1],{yPercent:110},{yPercent:0,duration:.4,ease:'power3.inOut'},9.12)
    .to(hf,{scaleX:.5,duration:.5,ease:'power1.inOut'},9.0).to(tks[1],{backgroundColor:'#F2C230',borderColor:'#F2C230',duration:.2},9.35)
    .fromTo(toast,{y:-30,autoAlpha:0},{y:0,autoAlpha:1,duration:.25,ease:'power2.out'},9.35).to(toast,{y:-30,autoAlpha:0,duration:.2},9.9)
    /* In Progress -> Resolved */
    .to(tlFill,{scaleY:1,duration:.5,ease:'power1.inOut'},9.9)
    .to(tlOn[2],{opacity:1,scale:1,duration:.2},10.2).to(tlT[2],{opacity:1,duration:.2},10.2)
    .to(chips[1],{opacity:0,duration:.12},10.1).to(chips[2],{opacity:1,duration:.12},10.15)
    .to(sw[1],{yPercent:-110,duration:.4,ease:'power3.inOut'},10.0).fromTo(sw[2],{yPercent:110},{yPercent:0,duration:.4,ease:'power3.inOut'},10.02)
    .to(hf,{scaleX:1,duration:.5,ease:'power1.inOut',backgroundColor:'#3DBE8B'},9.9).to(tks[2],{backgroundColor:'#3DBE8B',borderColor:'#3DBE8B',duration:.2},10.3)
    .to(cm,{autoAlpha:1,duration:.3},10.3);

  /* ===== SCENE 5: the resident's report becomes the LGU's dashboard (10.8 to 13.4) ===== */
  tl.to(tS4,{autoAlpha:0,y:-24,duration:.35,ease:'power2.in'},10.8)
    .to(tS5,{autoAlpha:1,duration:.15},11.0)
    .to(s5Words,{xPercent:0,duration:.5,stagger:.06,ease:'power3.out'},11.0)
    .to(phone,{x:PX5,y:PY5,scale:sc(.74),rotationY:desk?16:0,autoAlpha:desk?1:0,duration:1.0,ease:'power2.inOut'},10.85)
    .to(veil,{opacity:.84,duration:.8},10.9)
    .fromTo(dash,{autoAlpha:0,x:()=>DX()+vw()*.22,y:()=>DY()+30,rotationY:desk?-28:0,scale:.9,transformPerspective:1800,transformOrigin:'0% 50%'},
                 {autoAlpha:1,x:DX,y:DY,rotationY:desk?-7:0,scale:1,duration:1.0,ease:'power3.out'},11.1)
    .to(dash,{rotationY:0,duration:.8,ease:'power2.inOut'},12.2)
    .to(dashPanels,{autoAlpha:1,duration:.35,stagger:.06},11.5)
    .fromTo(dashMk,{scale:.2},{scale:1,duration:.3,stagger:.03,ease:'back.out(2)'},11.9)
    .to(sbars,{scaleX:1,duration:.4,stagger:.05},12.3);
  if(desk)tl.to(conn,{autoAlpha:1,duration:.05},12.3).fromTo(conn.querySelector('path'),{strokeDashoffset:1},{strokeDashoffset:0,duration:.6,ease:'power2.out'},12.3)
    .to(featRow,{backgroundColor:'rgba(27,138,131,.12)',duration:.3},12.8).to(conn,{autoAlpha:0,duration:.2},13.4);

  /* ===== SCENE 6: the dashboard map opens into a wider, lighter view of the community (13.4 to 15.4) ===== */
  tl.to(tS5,{autoAlpha:0,duration:.3},13.4)
    .to(phone,{autoAlpha:0,x:'-=60',duration:.4},13.4)
    .to(dashChrome,{autoAlpha:0,duration:.4},13.4)
    .fromTo(mapLight,{clipPath:clipFrom},{clipPath:'inset(0px 0px 0px 0px round 0px)',duration:1.1,ease:'power3.inOut'},13.55)
    .fromTo(panL,{scale:zoomFrom,x:()=>shiftFrom().x,y:()=>shiftFrom().y},{scale:1,x:0,y:0,duration:1.4,ease:'power3.inOut'},13.55)
    .set(dash,{autoAlpha:0},14.8)
    .to([tVeil,tS6],{autoAlpha:1,duration:.7,ease:'power2.out'},14.25)
    .fromTo(tS6,{y:24},{y:0,duration:.8,ease:'power2.out'},14.25)
    .to(wash,{opacity:.35,duration:.35},15.0);
  tl.to({},{duration:.001},TOTAL-.001);

  const hash=()=>{const k=location.hash.slice(1);if(k&&k in SCENE_T)goTo(k,true)};
  const hashTimer=window.setTimeout(hash,60);
  cleanups.push(()=>window.clearTimeout(hashTimer));
  return()=>{ScrollTrigger.removeEventListener('refresh',layoutConn);stageST=null};
}
function bgHeroEl(){return $('#bgHero')}

/* =========================================================================
   <FinalCTA/>  scene 7: echo of the hero, calmer
   ========================================================================= */
function buildFinal(desk){
  const fin=$('#final'),ph=$('#finalPhone'),slot=$('#phoneSlot');
  const lns=$$('.f-ln>span',fin),fades=$$('.f-fade',fin);
  gsap.set(lns,{yPercent:115});gsap.set(fades,{autoAlpha:0,y:20});
  const fs=()=>Math.min(slot.clientHeight*.94/620,slot.clientWidth*.9/300);
  const tl=gsap.timeline({defaults:{ease:'none',immediateRender:false},scrollTrigger:{trigger:fin,start:'top 74%',end:'top 10%',scrub:.6,invalidateOnRefresh:true}});
  tl.fromTo(ph,{y:170,scale:()=>fs()*.86,rotationY:26,rotationX:8,rotation:-6,transformPerspective:1400,autoAlpha:0},
               {y:0,scale:fs,rotationY:desk?-12:-6,rotationX:3,rotation:-2,autoAlpha:1,duration:1,ease:'power2.out',immediateRender:true},0)
    .to(lns,{yPercent:0,stagger:.14,duration:.5,ease:'power3.out'},.05)
    .to(fades,{autoAlpha:1,y:0,stagger:.12,duration:.4,ease:'power2.out'},.5);
}

/* =========================================================================
   responsive wiring: one matchMedia, two layouts, everything reverts on change
   ========================================================================= */
animationContext=gsap.context(()=>{
  mm=gsap.matchMedia();
  mm.add('(min-width: 1024px)',()=>{const c=buildStage(true);buildFinal(true);return c});
  mm.add('(max-width: 1023px)',()=>{const c=buildStage(false);buildFinal(false);return c});
},root);
const refreshPage=()=>{ScrollTrigger.refresh();if(location.hash)goTo(location.hash.slice(1),true)};
if(document.readyState==='complete')refreshPage();
else listen(window,'load',refreshPage);
return cleanup;
}
