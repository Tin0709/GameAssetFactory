// Independent parity: executes only inspected pure interpolation method bodies
// from pinned primary Blockbench and THREE sources; no app/server code runs.
const fs=require('fs'),path=require('path');const dir=__dirname;
function functionBody(text,marker){const start=text.indexOf(marker);if(start<0)throw Error(marker);let a=text.indexOf('{',start),depth=1,b=a+1;for(;depth;b++){if(text[b]==='{')depth++;if(text[b]==='}')depth--;}return text.slice(a+1,b-1);}
class Vector2{constructor(x=0,y=0){this.x=x;this.y=y;}set(x,y){this.x=x;this.y=y;return this;}}
const CatmullRom=new Function('t','p0','p1','p2','p3',functionBody(fs.readFileSync(path.join(dir,'three_Interpolations.js'),'utf8'),'function CatmullRom('));
class SplineCurve{constructor(points){this.points=points;}}
SplineCurve.prototype.getPoint=new Function('t','optionalTarget','Vector2','CatmullRom', 'optionalTarget=optionalTarget||new Vector2();'+functionBody(fs.readFileSync(path.join(dir,'three_SplineCurve.js'),'utf8'),'getPoint( t,'));
const primaryGetPoint=SplineCurve.prototype.getPoint;SplineCurve.prototype.getPoint=function(t){return primaryGetPoint.call(this,t,undefined,Vector2,CatmullRom)};
const bbFunction=new Function('before_plus','before','after','after_plus','axis','alpha','THREE',functionBody(fs.readFileSync(path.join(dir,'blockbench_keyframe.js'),'utf8'),'getCatmullromLerp('));
const requests=JSON.parse(fs.readFileSync(path.join(dir,'reference_requests.json')));
const result=requests.map(r=>{let keys=r.keys.map(([time,value])=>({time,data_points:[value],calc:(axis)=>value[axis]})),i=r.i;return bbFunction(keys[i-1],keys[i],keys[i+1],keys[i+2],r.axis,r.alpha,{Vector2,SplineCurve})});
fs.writeFileSync(path.join(dir,'reference_results.json'),JSON.stringify(result));
process.stdout.write(JSON.stringify({primary_reference_samples:result.length}));
