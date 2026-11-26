// Bu dosya, web sürümündeki satranç motorunun (engine.js) aynısını taşır.
// JavaScriptCore ile telefonda çalıştırılır. Elle düzenlemeyin; engine.js'den üretilir.
let engineJavaScript = #"""
// ================= MOTOR =================
var P=1,N=2,B=3,R=4,Q=5,K=6;
var VAL=[0,100,320,330,500,900,0];
var MATE=30000, INF=1e9;
function T(s){return s.split(/[\s,]+/).filter(Boolean).map(Number);}
var PST=[null,
T("0 0 0 0 0 0 0 0 50 50 50 50 50 50 50 50 10 10 20 30 30 20 10 10 5 5 10 25 25 10 5 5 0 0 0 20 20 0 0 0 5 -5 -10 0 0 -10 -5 5 5 10 10 -20 -20 10 10 5 0 0 0 0 0 0 0 0"),
T("-50 -40 -30 -30 -30 -30 -40 -50 -40 -20 0 0 0 0 -20 -40 -30 0 10 15 15 10 0 -30 -30 5 15 20 20 15 5 -30 -30 0 15 20 20 15 0 -30 -30 5 10 15 15 10 5 -30 -40 -20 0 5 5 0 -20 -40 -50 -40 -30 -30 -30 -30 -40 -50"),
T("-20 -10 -10 -10 -10 -10 -10 -20 -10 0 0 0 0 0 0 -10 -10 0 5 10 10 5 0 -10 -10 5 5 10 10 5 5 -10 -10 0 10 10 10 10 0 -10 -10 10 10 10 10 10 10 -10 -10 5 0 0 0 0 5 -10 -20 -10 -10 -10 -10 -10 -10 -20"),
T("0 0 0 0 0 0 0 0 5 10 10 10 10 10 10 5 -5 0 0 0 0 0 0 -5 -5 0 0 0 0 0 0 -5 -5 0 0 0 0 0 0 -5 -5 0 0 0 0 0 0 -5 -5 0 0 0 0 0 0 -5 0 0 0 5 5 0 0 0"),
T("-20 -10 -10 -5 -5 -10 -10 -20 -10 0 0 0 0 0 0 -10 -10 0 5 5 5 5 0 -10 -5 0 5 5 5 5 0 -5 0 0 5 5 5 5 0 -5 -10 5 5 5 5 5 0 -10 -10 0 5 0 0 0 0 -10 -20 -10 -10 -5 -5 -10 -10 -20")];
var KMG=T("-30 -40 -40 -50 -50 -40 -40 -30 -30 -40 -40 -50 -50 -40 -40 -30 -30 -40 -40 -50 -50 -40 -40 -30 -30 -40 -40 -50 -50 -40 -40 -30 -20 -30 -30 -40 -40 -30 -30 -20 -10 -20 -20 -20 -20 -20 -20 -10 20 20 0 0 0 0 20 20 20 30 10 0 0 10 30 20");
var KEG=T("-50 -40 -30 -20 -20 -30 -40 -50 -30 -20 -10 0 0 -10 -20 -30 -30 -10 20 30 30 20 -10 -30 -30 -10 30 40 40 30 -10 -30 -30 -10 30 40 40 30 -10 -30 -30 -10 20 30 30 20 -10 -30 -30 -30 0 0 0 0 -30 -30 -50 -30 -30 -30 -30 -30 -30 -50");
var KN_D=[[-2,-1],[-2,1],[-1,-2],[-1,2],[1,-2],[1,2],[2,-1],[2,1]];
var KG_D=[[-1,-1],[-1,0],[-1,1],[0,-1],[0,1],[1,-1],[1,0],[1,1]];
var DIAG=[[-1,-1],[-1,1],[1,-1],[1,1]], ORTH=[[-1,0],[1,0],[0,-1],[0,1]];

function parseFEN(f){
  var parts=f.trim().split(/\s+/), rows=parts[0].split('/');
  if(rows.length!==8) throw new Error('FEN geçersiz');
  var b=new Array(64).fill(0), map={p:1,n:2,b:3,r:4,q:5,k:6}, wk=0, bk=0;
  for(var r=0;r<8;r++){
    var c=0;
    for(var j=0;j<rows[r].length;j++){
      var ch=rows[r][j];
      if(/\d/.test(ch)) c+=+ch;
      else{
        var lo=ch.toLowerCase();
        if(!(lo in map)||c>7) throw new Error('FEN geçersiz');
        var v=(ch===lo?-1:1)*map[lo]; b[r*8+c]=v; if(v===K)wk++; if(v===-K)bk++; c++;
      }
    }
    if(c!==8) throw new Error('FEN geçersiz');
  }
  if(wk!==1||bk!==1) throw new Error('Her iki tarafın da bir şahı olmalı');
  var cs=parts[2]||'-', cast=0;
  if(cs.indexOf('K')>=0)cast|=1; if(cs.indexOf('Q')>=0)cast|=2; if(cs.indexOf('k')>=0)cast|=4; if(cs.indexOf('q')>=0)cast|=8;
  var ep=-1;
  if(parts[3]&&parts[3]!=='-'){ep=(8-parseInt(parts[3][1],10))*8+'abcdefgh'.indexOf(parts[3][0]); if(!(ep>=0&&ep<64)) ep=-1;}
  return {board:b,turn:(parts[1]==='b'?-1:1),cast:cast,ep:ep,half:parseInt(parts[4],10)||0,full:parseInt(parts[5],10)||1};
}
function toFEN(s){
  var out=[], L=' pnbrqk';
  for(var r=0;r<8;r++){
    var row='',e=0;
    for(var c=0;c<8;c++){
      var p=s.board[r*8+c];
      if(!p){e++;continue;}
      if(e){row+=e;e=0;}
      var ch=L[Math.abs(p)]; row+=p>0?ch.toUpperCase():ch;
    }
    if(e)row+=e; out.push(row);
  }
  var cs=(s.cast&1?'K':'')+(s.cast&2?'Q':'')+(s.cast&4?'k':'')+(s.cast&8?'q':'');
  var ep=s.ep>=0?'abcdefgh'[s.ep&7]+(8-(s.ep>>3)):'-';
  return out.join('/')+' '+(s.turn===1?'w':'b')+' '+(cs||'-')+' '+ep+' '+s.half+' '+s.full;
}
function startState(){return parseFEN('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');}

function attacked(b,sq,by){
  var r=sq>>3,c=sq&7,i,rr,cc,dr,dc,p;
  var pr=by===1?r+1:r-1;
  if(pr>=0&&pr<8){
    if(c>0&&b[pr*8+c-1]===by*P)return true;
    if(c<7&&b[pr*8+c+1]===by*P)return true;
  }
  for(i=0;i<8;i++){rr=r+KN_D[i][0];cc=c+KN_D[i][1]; if(rr>=0&&rr<8&&cc>=0&&cc<8&&b[rr*8+cc]===by*N)return true;}
  for(i=0;i<8;i++){rr=r+KG_D[i][0];cc=c+KG_D[i][1]; if(rr>=0&&rr<8&&cc>=0&&cc<8&&b[rr*8+cc]===by*K)return true;}
  for(i=0;i<4;i++){
    dr=DIAG[i][0];dc=DIAG[i][1];rr=r+dr;cc=c+dc;
    while(rr>=0&&rr<8&&cc>=0&&cc<8){p=b[rr*8+cc]; if(p){ if(p===by*B||p===by*Q)return true; break;} rr+=dr;cc+=dc;}
    dr=ORTH[i][0];dc=ORTH[i][1];rr=r+dr;cc=c+dc;
    while(rr>=0&&rr<8&&cc>=0&&cc<8){p=b[rr*8+cc]; if(p){ if(p===by*R||p===by*Q)return true; break;} rr+=dr;cc+=dc;}
  }
  return false;
}
function kingSq(b,t){for(var i=0;i<64;i++) if(b[i]===t*K) return i; return -1;}

// fl: 1 yakalama, 2 en passant, 4 kısa rok, 8 uzun rok, 16 çift adım
function gen(s,caps){
  var b=s.board,t=s.turn,out=[];
  function add(f,to,p,fl){out.push({f:f,t:to,p:p||0,fl:fl||0});}
  for(var i=0;i<64;i++){
    var pc=b[i]; if(pc*t<=0)continue;
    var pt=pc*t,r=i>>3,c=i&7,j,dr,dc,rr,cc,to,tg;
    if(pt===P){
      var dir=-t,r1=r+dir; if(r1<0||r1>7)continue;
      var promo=(t===1&&r1===0)||(t===-1&&r1===7);
      var push=function(to,fl){ if(promo){add(i,to,Q,fl);add(i,to,R,fl);add(i,to,B,fl);add(i,to,N,fl);} else add(i,to,0,fl); };
      if(b[r1*8+c]===0){
        if(!caps||promo) push(r1*8+c,0);
        if(!caps&&r===(t===1?6:1)&&b[(r+2*dir)*8+c]===0) add(i,(r+2*dir)*8+c,0,16);
      }
      for(j=-1;j<=1;j+=2){
        cc=c+j; if(cc<0||cc>7)continue;
        to=r1*8+cc; tg=b[to];
        if(tg*t<0) push(to,1); else if(tg===0&&to===s.ep) add(i,to,0,2);
      }
    }else if(pt===N||pt===K){
      var d=pt===N?KN_D:KG_D;
      for(j=0;j<8;j++){
        rr=r+d[j][0];cc=c+d[j][1]; if(rr<0||rr>7||cc<0||cc>7)continue;
        to=rr*8+cc; tg=b[to]; if(tg*t>0)continue;
        if(tg!==0)add(i,to,0,1); else if(!caps)add(i,to,0,0);
      }
      if(pt===K&&!caps&&i===(t===1?60:4)){
        var base=t===1?56:0,kb=t===1?1:4,qb=t===1?2:8;
        if((s.cast&kb)&&b[base+5]===0&&b[base+6]===0&&b[base+7]===t*R&&!attacked(b,base+4,-t)&&!attacked(b,base+5,-t)&&!attacked(b,base+6,-t)) add(i,base+6,0,4);
        if((s.cast&qb)&&b[base+1]===0&&b[base+2]===0&&b[base+3]===0&&b[base]===t*R&&!attacked(b,base+4,-t)&&!attacked(b,base+3,-t)&&!attacked(b,base+2,-t)) add(i,base+2,0,8);
      }
    }else{
      var dirs=pt===B?DIAG:(pt===R?ORTH:DIAG.concat(ORTH));
      for(j=0;j<dirs.length;j++){
        dr=dirs[j][0];dc=dirs[j][1];rr=r+dr;cc=c+dc;
        while(rr>=0&&rr<8&&cc>=0&&cc<8){
          to=rr*8+cc; tg=b[to];
          if(tg===0){ if(!caps)add(i,to,0,0); }
          else{ if(tg*t<0)add(i,to,0,1); break; }
          rr+=dr;cc+=dc;
        }
      }
    }
  }
  return out;
}
function make(s,m){
  var b=s.board.slice(),t=s.turn,p=b[m.f],cast=s.cast,ep=-1;
  b[m.t]=m.p?t*m.p:p; b[m.f]=0;
  if(m.fl&2) b[m.t+(t===1?8:-8)]=0;
  if(m.fl&4){ if(t===1){b[61]=b[63];b[63]=0;} else {b[5]=b[7];b[7]=0;} }
  if(m.fl&8){ if(t===1){b[59]=b[56];b[56]=0;} else {b[3]=b[0];b[0]=0;} }
  if(m.fl&16) ep=(m.f+m.t)/2;
  if(Math.abs(p)===K) cast&=(t===1?~3:~12);
  if(m.f===63||m.t===63)cast&=~1; if(m.f===56||m.t===56)cast&=~2;
  if(m.f===7||m.t===7)cast&=~4; if(m.f===0||m.t===0)cast&=~8;
  var reset=Math.abs(p)===P||(m.fl&3)!==0;
  return {board:b,turn:-t,cast:cast,ep:ep,half:reset?0:s.half+1,full:s.full+(t===-1?1:0)};
}
function legal(s){
  var t=s.turn,res=[],mv=gen(s,false);
  for(var i=0;i<mv.length;i++){
    var n=make(s,mv[i]);
    if(!attacked(n.board,kingSq(n.board,t),-t)) res.push(mv[i]);
  }
  return res;
}
function inCheck(s){return attacked(s.board,kingSq(s.board,s.turn),-s.turn);}

function evaluate(s){
  var b=s.board,score=0,np=0,i,p,pt;
  for(i=0;i<64;i++){p=b[i]; if(!p)continue; pt=Math.abs(p); if(pt!==P&&pt!==K)np+=VAL[pt];}
  var eg=np<2600;
  for(i=0;i<64;i++){
    p=b[i]; if(!p)continue; pt=Math.abs(p);
    var w=p>0, idx=w?i:(i^56);
    var v=VAL[pt]+(pt===K?(eg?KEG[idx]:KMG[idx]):PST[pt][idx]);
    score+=w?v:-v;
  }
  return score;
}
var nodes=0,deadline=0,aborted=false;
function orderMoves(s,moves,pv){
  for(var i=0;i<moves.length;i++){
    var m=moves[i],sc=0;
    if(pv&&m.f===pv.f&&m.t===pv.t&&m.p===pv.p) sc=1e6;
    else{
      if(m.fl&3){ var vic=(m.fl&2)?P:Math.abs(s.board[m.t]); sc=10000+VAL[vic]*10-VAL[Math.abs(s.board[m.f])]/10; }
      if(m.p) sc+=9000+VAL[m.p];
    }
    m.o=sc;
  }
  moves.sort(function(a,b){return b.o-a.o;});
}
function qsearch(s,alpha,beta,ply){
  nodes++; if((nodes&2047)===0&&Date.now()>deadline)aborted=true;
  if(aborted)return 0;
  var stand=s.turn*evaluate(s);
  if(ply>10)return stand;
  if(stand>=beta)return beta;
  if(stand>alpha)alpha=stand;
  var mv=gen(s,true); orderMoves(s,mv,null);
  for(var i=0;i<mv.length;i++){
    var n=make(s,mv[i]);
    if(attacked(n.board,kingSq(n.board,s.turn),-s.turn))continue;
    var sc=-qsearch(n,-beta,-alpha,ply+1);
    if(aborted)return 0;
    if(sc>=beta)return beta;
    if(sc>alpha)alpha=sc;
  }
  return alpha;
}
function negamax(s,depth,alpha,beta,ply){
  nodes++; if((nodes&2047)===0&&Date.now()>deadline)aborted=true;
  if(aborted)return 0;
  if(s.half>=100)return 0;
  var chk=inCheck(s);
  if(chk&&ply<20)depth++;
  if(depth<=0)return qsearch(s,alpha,beta,0);
  var mv=gen(s,false); orderMoves(s,mv,null);
  var best=-INF,any=false;
  for(var i=0;i<mv.length;i++){
    var n=make(s,mv[i]);
    if(attacked(n.board,kingSq(n.board,s.turn),-s.turn))continue;
    any=true;
    var sc=-negamax(n,depth-1,-beta,-alpha,ply+1);
    if(aborted)return 0;
    if(sc>best)best=sc;
    if(sc>alpha)alpha=sc;
    if(alpha>=beta)break;
  }
  if(!any)return chk?-MATE+ply:0;
  return best;
}
function search(s,ms,maxDepth){
  nodes=0;aborted=false;deadline=Date.now()+ms;
  var moves=legal(s); if(!moves.length)return null;
  var best=moves[0],bestScore=0,done=0;
  for(var d=1;d<=maxDepth;d++){
    orderMoves(s,moves,best);
    var alpha=-INF,lb=null,ls=-INF;
    for(var i=0;i<moves.length;i++){
      var n=make(s,moves[i]);
      var sc=-negamax(n,d-1,-INF,-alpha,1);
      if(aborted&&d>1)break;
      if(sc>ls){ls=sc;lb=moves[i];}
      if(sc>alpha)alpha=sc;
    }
    if(aborted&&d>1)break;
    best=lb;bestScore=ls;done=d;
    if(Math.abs(bestScore)>MATE-100)break;
    if(Date.now()>deadline)break;
  }
  return {move:{f:best.f,t:best.t,p:best.p,fl:best.fl},score:bestScore,depth:done,nodes:nodes};
}
function perft(s,d){
  if(d===0)return 1;
  var mv=legal(s),n=0;
  for(var i=0;i<mv.length;i++)n+=d===1?1:perft(make(s,mv[i]),d-1);
  return n;
}

// ================= TELEFON İÇİN YARDIMCILAR =================
var FILES_ = 'abcdefgh';
function sqName_(i){return FILES_[i&7]+(8-(i>>3));}
var LET_=['','','N','B','R','Q','K'];
var TRN_=['','Piyon','At','Fil','Kale','Vezir','Şah'];
var PL_={2:'n',3:'b',4:'r',5:'q'};
function sanOf_(s,m,lm){
  var b=s.board,pt=Math.abs(b[m.f]),str;
  if(m.fl&4)str='O-O';
  else if(m.fl&8)str='O-O-O';
  else{
    var cap=(m.fl&3)!==0; str='';
    if(pt===1){ if(cap)str+=FILES_[m.f&7]+'x'; str+=sqName_(m.t); if(m.p)str+='='+LET_[m.p]; }
    else{
      str+=LET_[pt];
      var o=lm.filter(function(x){return !(x.f===m.f&&x.t===m.t&&x.p===m.p)&&b[x.f]===b[m.f]&&x.t===m.t;});
      if(o.length){
        var sf=o.some(function(x){return (x.f&7)===(m.f&7);}), sr=o.some(function(x){return (x.f>>3)===(m.f>>3);});
        if(!sf)str+=FILES_[m.f&7]; else if(!sr)str+=(8-(m.f>>3)); else str+=sqName_(m.f);
      }
      if(cap)str+='x'; str+=sqName_(m.t);
    }
  }
  var n=make(s,m); if(inCheck(n))str+=legal(n).length?'+':'#';
  return str;
}
function trDesc_(s,m){
  if(m.fl&4)return 'Kısa rok';
  if(m.fl&8)return 'Uzun rok';
  var t=TRN_[Math.abs(s.board[m.f])]+' '+sqName_(m.f)+' → '+sqName_(m.t), tags=[];
  if(m.fl&2)tags.push('piyon alır (geçerken)');
  else if(m.fl&1)tags.push(TRN_[Math.abs(s.board[m.t])].toLowerCase()+' alır');
  if(m.p)tags.push(TRN_[m.p].toLowerCase()+' olur');
  var n=make(s,m); if(inCheck(n))tags.push(legal(n).length?'şah çeker':'MAT!');
  return t+(tags.length?' · '+tags.join(', '):'');
}
function analyze(fen,ms,depth){
  var s;
  try{ s=parseFEN(fen); }catch(e){ return JSON.stringify({error:e.message}); }
  if(attacked(s.board,kingSq(s.board,-s.turn),s.turn))
    return JSON.stringify({error:'sırası olmayan tarafın şahı tehdit altında (sıra/taraf yanlış olabilir)'});
  var lm=legal(s);
  if(!lm.length) return JSON.stringify({result:inCheck(s)?'Şah mat':'Pat'});
  var r=search(s,ms,depth), m=r.move;
  var full=lm.filter(function(x){return x.f===m.f&&x.t===m.t&&x.p===m.p;})[0]||m;
  var cp=r.score*s.turn, mate=null;
  if(Math.abs(cp)>=MATE-100) mate=(cp>0?1:-1)*Math.ceil((MATE-Math.abs(cp))/2);
  return JSON.stringify({san:sanOf_(s,full,lm),
    uci:sqName_(full.f)+sqName_(full.t)+(full.p?PL_[full.p]:''),
    desc:trDesc_(s,full), cp:cp, mate:mate, depth:r.depth});
}

"""#
