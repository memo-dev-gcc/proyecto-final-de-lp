// Arte original por código: sprites y texturas locales, sin imágenes ni servicios externos.
export const carros = {
  rayo: {nombre:'Rayo', tipo:'Buggy ligero', color:'#f5c542', oscuro:'#957029', detalle:'Muévete rápido. Mantente fuera de la línea de fuego.', vida:85, velocidad:4.2, dano:20, recarga:14},
  muro: {nombre:'Muro', tipo:'Blindado pesado', color:'#5ba3ff', oscuro:'#2c5287', detalle:'Resiste más impactos. Usa las coberturas para avanzar.', vida:145, velocidad:2.6, dano:20, recarga:17},
  chispa: {nombre:'Chispa', tipo:'Auto de combate', color:'#76cf5b', oscuro:'#3b7330', detalle:'Presiona con disparos rápidos. Cada impacto cuenta.', vida:100, velocidad:3.5, dano:12, recarga:8},
  martillo: {nombre:'Martillo', tipo:'Camioneta artillera', color:'#ee5c55', oscuro:'#903d3d', detalle:'Golpea fuerte. Calcula el momento de cada disparo.', vida:110, velocidad:3, dano:34, recarga:26}
};
const angulos = {arriba:0,derecha:Math.PI/2,abajo:Math.PI,izquierda:-Math.PI/2};
export function dibujarCarro(ctx, personaje, x, y, direccion='arriba', escala=1, destruido=false) {
  const carro = carros[personaje] || carros.rayo;
  ctx.save();ctx.translate(Math.round(x),Math.round(y));ctx.rotate(angulos[direccion]||0);ctx.scale(escala,escala);
  const color = destruido?'#58504c':carro.color, oscuro=destruido?'#332e2c':carro.oscuro;
  const rect=(x,y,w,h,c)=>{ctx.fillStyle=c;ctx.fillRect(x,y,w,h)};
  const ancho = personaje==='muro'?25:personaje==='chispa'?19:22;
  const largo = personaje==='martillo'?36:personaje==='muro'?34:30;
  rect(-ancho/2+3,-largo/2+4,ancho,largo,'#0007');
  // Ruedas y banda metálica: silueta diferenciada por tamaño.
  for(const lado of [-1,1])for(const yy of [-10,9]) {
    rect(lado===-1?-ancho/2-4:ancho/2-1, yy-5,5,10,'#0c1015');
    rect(lado===-1?-ancho/2-4:ancho/2+1, yy-3,2,6,'#67727e');
  }
  rect(-ancho/2,-largo/2,ancho,largo,'#101820');rect(-ancho/2+2,-largo/2+2,ancho-4,largo-4,oscuro);
  rect(-ancho/2+2,-largo/2+2,ancho-5,7,color);rect(-ancho/2+2,-largo/2+2,ancho-5,2,'#ffffff55');
  rect(-ancho/2+2,0,ancho-4,largo/2-2,color);rect(ancho/2-4,1,2,largo/2-4,oscuro);
  if(personaje==='rayo') {
    rect(-7,-6,14,13,'#141c26');rect(-5,-5,10,5,'#70a9b8');rect(-3,0,6,6,'#615449');
    rect(-8,-5,2,13,'#d9c297');rect(6,-5,2,13,'#d9c297');rect(-7,11,14,2,'#b8bdba');
  } else if(personaje==='muro') {
    rect(-10,-4,20,17,oscuro);rect(-8,-4,16,14,color);rect(-7,-3,14,3,'#c2d8dc');
    rect(-6,2,12,5,'#18354a');rect(-5,10,10,2,'#2c3848');rect(-2,-20,4,19,'#adb5b7');rect(-1,-20,2,16,'#394653');
  } else if(personaje==='chispa') {
    rect(-7,-6,14,16,'#131e28');rect(-6,-5,12,5,'#84bec1');rect(-5,1,10,7,color);rect(-6,9,12,3,'#507b6c');
    rect(-ancho/2-2,12,ancho+4,3,'#18232b');rect(-2,-14,4,8,'#d4dfd4');
  } else {
    rect(-8,-6,16,12,color);rect(-7,-5,14,5,'#88b6bd');rect(-8,8,16,8,'#3c3030');
    rect(-6,9,12,5,'#18202b');rect(-3,-21,6,21,'#111821');rect(-2,-21,4,18,'#9ba4a7');rect(1,-21,2,18,'#5a656d');
  }
  rect(-ancho/2+2,-largo/2,4,2,destruido?'#5c4e37':'#fff1ad');rect(ancho/2-6,-largo/2,4,2,destruido?'#5c4e37':'#fff1ad');
  rect(-ancho/2+2,largo/2-3,3,2,'#bd4545');rect(ancho/2-5,largo/2-3,3,2,'#bd4545');
  if(destruido){rect(-5,-4,8,11,'#242425');rect(-2,1,7,5,'#8b5130')}
  ctx.restore();
}
export function retrato(canvas, personaje, grande=false) {
  const ctx=canvas.getContext('2d');ctx.clearRect(0,0,canvas.width,canvas.height);ctx.imageSmoothingEnabled=false;
  dibujarCarro(ctx,personaje,canvas.width/2,canvas.height/2,'derecha',grande?2.5:1.45);
}
export class ArenaRender {
  constructor(canvas) {
    this.canvas=canvas;this.ctx=canvas.getContext('2d');this.ctx.imageSmoothingEnabled=false;
    this.base=document.createElement('canvas');this.base.width=1120;this.base.height=640;
    this.mapa=[];this.estado=null;this.previous=null;this.player_id=null;this.recibido=0;this.carro_preview='rayo';
    this.animar=this.animar.bind(this);requestAnimationFrame(this.animar);
  }
  prepararMapa(mapa) {
    this.mapa=mapa;const c=this.base.getContext('2d');c.fillStyle='#2a2e36';c.fillRect(0,0,1120,640);
    let semilla=7264;const random=()=>{semilla=(semilla*1664525+1013904223)>>>0;return semilla/4294967296};
    for(let i=0;i<16500;i++){c.fillStyle=random()>.5?'#ffffff06':'#00000018';c.fillRect(Math.floor(random()*1120),Math.floor(random()*640),random()>.95?3:1,1)}
    c.strokeStyle='#b8b8a014';c.lineWidth=2;c.setLineDash([10,16]);c.strokeRect(80,80,960,480);c.setLineDash([]);
    for(const [x,y,n] of [[100,100,'01'],[1020,100,'02'],[100,540,'03'],[1020,540,'04']]) {
      c.strokeStyle='#b9bcc320';c.lineWidth=2;c.beginPath();c.arc(x,y,30,0,Math.PI*2);c.stroke();
      c.fillStyle='#c7cbd425';c.font='bold 12px monospace';c.textAlign='center';c.fillText(n,x,y+48);
    }
    // Juntas, remaches y sombras de bloques de concreto.
    for(const pared of mapa)for(let x=pared.x;x<pared.x+pared.w;x+=40)for(let y=pared.y;y<pared.y+pared.h;y+=40){
      c.fillStyle='#11151c88';c.fillRect(x+3,y+7,40,40);c.fillStyle='#666c73';c.fillRect(x,y,40,40);
      c.fillStyle='#c1beb1';c.fillRect(x+2,y+2,36,30);c.fillStyle='#dfdace';c.fillRect(x+2,y+2,36,3);
      c.fillStyle='#8b8d89';c.fillRect(x+2,y+31,36,7);c.fillStyle='#a6a499';c.fillRect(x+34,y+4,4,27);
      c.fillStyle='#696f74';for(const [dx,dy] of [[6,7],[31,7],[6,27],[31,27]])c.fillRect(x+dx,y+dy,2,2);
      for(let j=0;j<9;j++){c.fillStyle=random()>.5?'#202a3522':'#ffffff22';c.fillRect(x+4+Math.floor(random()*30),y+5+Math.floor(random()*23),2,1)}
    }
  }
  recibir(estado, player_id) {this.previous=this.estado;this.estado=estado;this.player_id=player_id;this.recibido=performance.now()}
  animar(ahora) {
    const c=this.ctx;c.clearRect(0,0,1120,640);c.drawImage(this.base,0,0);
    const estado=this.estado;
    if(estado){
      const alpha=Math.min(1,(ahora-this.recibido)/33);
      for(const p of estado.jugadores){
        const old=this.previous?.jugadores.find(q=>q.id===p.id);
        const x=old?old.x+(p.x-old.x)*alpha:p.x, y=old?old.y+(p.y-old.y)*alpha:p.y;
        this.dibujarJugador(p,x,y);
      }
      for(const b of estado.proyectiles){
        const color=carros[b.personaje]?.color||'#ffe8a1';c.fillStyle='#080e1580';c.fillRect(b.x-2,b.y+3,6,4);
        c.strokeStyle=color;c.lineWidth=3;c.beginPath();c.moveTo(b.x-b.dx*10,b.y-b.dy*10);c.lineTo(b.x,b.y);c.stroke();c.fillStyle='#fff5d6';c.fillRect(b.x-2,b.y-2,4,4);
      }
      for(const efecto of estado.impactos){
        c.save();c.translate(efecto.x,efecto.y);c.strokeStyle=efecto.tipo==='carro'?'#ff934b':'#f5d18b';c.lineWidth=2;
        const radio=(10-efecto.ttl)*2+3;c.globalAlpha=Math.min(1,efecto.ttl/5);
        for(let j=0;j<6;j++){const a=j*Math.PI/3;c.beginPath();c.moveTo(Math.cos(a)*3,Math.sin(a)*3);c.lineTo(Math.cos(a)*radio,Math.sin(a)*radio);c.stroke()}c.fillStyle='#fff2b6';c.fillRect(-3,-3,6,6);c.restore();
      }
    }else {
      [{personaje:'rayo',x:100,y:100,direccion:'derecha'},{personaje:'muro',x:1020,y:100,direccion:'abajo'},{personaje:'chispa',x:100,y:540,direccion:'arriba'},{personaje:'martillo',x:1020,y:540,direccion:'izquierda'}].forEach(p=>dibujarCarro(c,p.personaje,p.x,p.y,p.direccion,1.25));
    }
    requestAnimationFrame(this.animar);
  }
  dibujarJugador(p,x,y){
    const c=this.ctx, muerto=p.vida<=0;
    if(p.id===this.player_id&&!muerto){c.strokeStyle='#ffffffaa';c.lineWidth=1;c.setLineDash([5,4]);c.beginPath();c.arc(x,y,25,0,Math.PI*2);c.stroke();c.setLineDash([])}
    dibujarCarro(c,p.personaje,x,y,p.direccion,1.12,muerto);
    c.font='bold 11px Trebuchet MS, sans-serif';c.textAlign='center';c.lineWidth=3;c.strokeStyle='#131820';c.strokeText(p.nombre,x,y-35);c.fillStyle=muerto?'#9a9490':'#f0ecdf';c.fillText(p.nombre,x,y-35);
    c.fillStyle='#10151c';c.fillRect(x-22,y-30,44,5);c.fillStyle=carros[p.personaje].color;c.fillRect(x-21,y-29,42*Math.max(0,p.vida/p.max_vida),3);
  }
}
