import {carros, retrato, ArenaRender} from './render.js';
const $=id=>document.getElementById(id);
const renderer=new ArenaRender($('arena'));
let socket, player_id=null, estado_partida=null, dentro=false, seleccionado='rayo', audio_on=false, audio_ctx=null, anterior_fase=null, ultimo_tick_sonido=-100, toast_timeout;
const teclas=new Set();let direccion_touch='quieto', fuego_touch=false;
const query=new URLSearchParams(location.search);
$('codigo').value=(query.get('sala')||Math.random().toString(36).slice(2,7)).toUpperCase().replace(/[^A-Z0-9]/g,'').slice(0,8);
try{$('nombre').value=localStorage.getItem('arena_nombre')||''}catch{}

for(const [id,carro] of Object.entries(carros)){
  const btn=document.createElement('button');btn.type='button';btn.className='vehicle-btn';btn.dataset.carro=id;btn.style.setProperty('--car-color',carro.color);btn.setAttribute('aria-pressed',String(id===seleccionado));btn.setAttribute('aria-label',`Elegir ${carro.nombre}, ${carro.tipo}`);
  const dibujo=document.createElement('canvas');dibujo.width=100;dibujo.height=64;dibujo.setAttribute('aria-hidden','true');btn.append(dibujo);retrato(dibujo,id);
  const nombre=document.createElement('strong');nombre.textContent=carro.nombre;btn.append(nombre);btn.addEventListener('click',()=>elegir(id));$('vehicle-grid').append(btn);
  const card=document.createElement('div');card.className='hud-card empty';card.dataset.hud=id;card.style.setProperty('--car-color',carro.color);
  card.innerHTML='<canvas class="hud-car" width="70" height="60" aria-hidden="true"></canvas><div class="hud-info"><div class="hud-top"><span class="hud-name"></span><span class="hp-text"></span></div><div class="hp-track"><div class="hp-fill"></div></div><span class="driver-name">Esperando piloto</span></div>';
  card.querySelector('.hud-name').textContent=carro.nombre.toUpperCase();card.querySelector('.hp-text').textContent=carro.vida+' / '+carro.vida;retrato(card.querySelector('canvas'),id);$('hud').append(card);
}
function elegir(id){
  if(dentro){enviar({tipo:'elegir',personaje:id});return}
  seleccionado=id;mostrarSeleccion();
}
function mostrarSeleccion(){
  const carro=carros[seleccionado];document.documentElement.style.setProperty('--player',carro.color);
  for(const btn of document.querySelectorAll('[data-carro]'))btn.setAttribute('aria-pressed',String(btn.dataset.carro===seleccionado));
  $('carro-name').textContent=carro.nombre;$('carro-type').textContent=carro.tipo;$('carro-detail').textContent=carro.detalle;
  $('stats').replaceChildren();
  for(const [nombre,valor,max,texto] of [['Vida',carro.vida,145,carro.vida],['Velocidad',carro.velocidad,4.2,carro.velocidad.toFixed(1)],['Daño',carro.dano,34,carro.dano]]){
    const stat=document.createElement('div');stat.innerHTML='<div class="stat-line"><span></span><b></b></div><div class="stat-meter"><i></i></div>';stat.querySelector('span').textContent=nombre;stat.querySelector('b').textContent=texto;stat.querySelector('i').style.width=(valor/max*100)+'%';$('stats').append(stat);
  }
}
mostrarSeleccion();
function conectar(){
  $('conexion').textContent='Conectando…';$('status-dot').classList.remove('online');$('join-btn').disabled=true;$('practice-btn').disabled=true;
  socket=new WebSocket(`${location.protocol==='https:'?'wss':'ws'}://${location.host}/ws`);
  socket.addEventListener('open',()=>{$('conexion').textContent='Conectado';$('status-dot').classList.add('online');$('join-btn').disabled=false;$('practice-btn').disabled=false});
  socket.addEventListener('message',e=>{
    let mensaje;try{mensaje=JSON.parse(e.data)}catch{return}
    if(mensaje.tipo==='hola'){player_id=mensaje.player_id;renderer.prepararMapa(mensaje.mapa,mensaje.ancho,mensaje.alto);if(query.get('practica')==='1')iniciarPractica()}
    if(mensaje.tipo==='dentro'){
      dentro=true;player_id=mensaje.player_id;$('sala-label').textContent=mensaje.sala;$('join-form').hidden=true;$('waiting-panel').hidden=false;
      const url=new URL(location.href);url.searchParams.set('sala',mensaje.sala);history.replaceState({},'',url);sonido('join');
    }
    if(mensaje.tipo==='estado'){estado_partida=mensaje.estado;renderer.recibir(estado_partida,player_id);actualizar()}
    if(mensaje.tipo==='error'){notificar(mensaje.mensaje);$('join-btn').disabled=false;$('practice-btn').disabled=false}
  });
  socket.addEventListener('close',()=>{
    $('conexion').textContent='Desconectado';$('status-dot').classList.remove('online');$('join-btn').disabled=true;limpiarControles();
    if(!$('disconnect-dialog').open)$('disconnect-dialog').showModal();
  });
  socket.addEventListener('error',()=>{$('conexion').textContent='Sin conexión'});
}
conectar();
function enviar(mensaje){if(socket?.readyState===WebSocket.OPEN)socket.send(JSON.stringify(mensaje))}
function notificar(texto){$('toast').textContent=texto;$('toast').hidden=false;clearTimeout(toast_timeout);toast_timeout=setTimeout(()=>$('toast').hidden=true,4500)}
$('join-form').addEventListener('submit',e=>{
  e.preventDefault();const nombre=$('nombre').value.trim(),sala=$('codigo').value.trim().toUpperCase();
  if(!nombre){$('nombre').focus();return}
  if(!/^[A-Z0-9]{3,8}$/.test(sala)){notificar('El código debe tener de 3 a 8 letras o números.');return}
  try{localStorage.setItem('arena_nombre',nombre)}catch{}
  $('join-btn').disabled=true;enviar({tipo:'entrar',nombre,sala,personaje:seleccionado});
});
function iniciarPractica(){
  const nombre=$('nombre').value.trim()||'Piloto';
  $('join-btn').disabled=true;$('practice-btn').disabled=true;
  enviar({tipo:'practica',nombre,personaje:seleccionado});
}
$('practice-btn').addEventListener('click',iniciarPractica);
$('practice-waiting-btn').addEventListener('click',()=>location.assign('/?practica=1'));
function colocarMina(){if(estado_partida?.fase==='jugando'){enviar({tipo:'mina'})}}
$('mine-btn').addEventListener('click',colocarMina);
$('touch-mine').addEventListener('click',colocarMina);
$('ready-btn').addEventListener('click',()=>{const yo=estado_partida?.jugadores.find(p=>p.id===player_id);enviar({tipo:'listo',valor:!yo?.listo});sonido('ready')});
$('leave-btn').addEventListener('click',()=>location.assign('/'));
$('exit-practice-btn').addEventListener('click',()=>location.assign('/'));
$('rematch-btn').addEventListener('click',()=>{limpiarControles();enviar({tipo:'revancha'})});
$('reconnect-btn').addEventListener('click',()=>location.reload());
$('copy-btn').addEventListener('click',async()=>{
  if(estado_partida?.modo==='practica'){notificar('La prueba es individual. Para invitar amigos, vuelve al inicio y entra a una sala.');return}
  const url=new URL(location.href);url.searchParams.set('sala',dentro?new URL(location.href).searchParams.get('sala'):$('codigo').value.toUpperCase());
  try{await navigator.clipboard.writeText(url.toString());notificar('Enlace copiado. Compártelo con otros tres pilotos.')}catch{notificar('Comparte esta dirección: '+url.toString())}
});
$('fullscreen-btn').addEventListener('click',async()=>{try{if(document.fullscreenElement)await document.exitFullscreen();else await document.documentElement.requestFullscreen()}catch{notificar('Tu navegador no permite pantalla completa.')}});
$('sound-btn').addEventListener('click',()=>{
  audio_on=!audio_on;$('sound-btn').setAttribute('aria-pressed',String(audio_on));$('sound-btn').querySelector('span').textContent=audio_on?'ON':'OFF';
  if(audio_on){audio_ctx ||= new (window.AudioContext||window.webkitAudioContext)();audio_ctx.resume();sonido('ready')}
});
function sonido(tipo){
  if(!audio_on||!audio_ctx)return;
  const tonos={join:[440,.12,'sine'],ready:[660,.08,'square'],shot:[130,.045,'sawtooth'],hit:[75,.08,'triangle'],start:[880,.18,'square'],end:[330,.35,'triangle']};
  const [frecuencia,duracion,onda]=tonos[tipo]||tonos.ready;
  const osc=audio_ctx.createOscillator(), gain=audio_ctx.createGain();osc.type=onda;osc.frequency.setValueAtTime(frecuencia,audio_ctx.currentTime);osc.frequency.exponentialRampToValueAtTime(frecuencia*.5,audio_ctx.currentTime+duracion);gain.gain.setValueAtTime(.035,audio_ctx.currentTime);gain.gain.exponentialRampToValueAtTime(.001,audio_ctx.currentTime+duracion);osc.connect(gain);gain.connect(audio_ctx.destination);osc.start();osc.stop(audio_ctx.currentTime+duracion);
}
function actualizar(){
  const e=estado_partida, yo=e.jugadores.find(p=>p.id===player_id);
  if(yo&&seleccionado!==yo.personaje){seleccionado=yo.personaje;mostrarSeleccion()}
  const fase=e.fase;
  $('fase-label').textContent={lobby:'Preparando partida',cuenta:'Cuenta atrás',jugando:'En combate',final:'Ronda terminada'}[fase];
  $('practice-waiting-btn').hidden=e.modo==='practica';
  $('exit-practice-btn').hidden=e.modo!=='practica';
  if(e.modo==='practica'){$('sala-label').textContent='PRUEBA';$('fase-label').textContent='Prueba de movimiento'}
  const segundos=Math.ceil(e.restantes/30);$('timer').textContent=e.modo==='practica'?'Libre':String(Math.floor(segundos/60)).padStart(2,'0')+':'+String(segundos%60).padStart(2,'0');
  $('lobby-panel').hidden=fase!=='lobby';$('countdown-panel').hidden=fase!=='cuenta';$('result-panel').hidden=fase!=='final';$('eliminado').hidden=!(fase==='jugando'&&yo?.vida<=0);
  $('touch-controls').classList.toggle('active',fase==='jugando'&&yo?.vida>0);
  $('effect-bar').hidden=fase!=='jugando';
  const efectos=[];
  if(yo?.escudo)efectos.push('Escudo activo');
  if(yo?.turbo_hasta>e.tick)efectos.push('Turbo '+Math.ceil((yo.turbo_hasta-e.tick)/30)+' s');
  if(yo?.potentes>0)efectos.push('Potente: '+yo.potentes+' disparos');
  $('effect-status').textContent=efectos.join(' · ')||'Sin mejoras activas';
  $('mine-count').textContent=yo?.minas_carga??0;
  const mina_bloqueada=!yo||yo.vida<=0||yo.minas_carga<1||e.minas?.some(m=>m.owner===player_id);
  $('mine-btn').disabled=mina_bloqueada;$('touch-mine').disabled=mina_bloqueada;
  if(fase==='cuenta')$('count-number').textContent=Math.ceil(e.cuenta/30);
  $('ocupacion').textContent=e.jugadores.length+' / 4 pilotos';
  $('mi-piloto').textContent=yo?'Tu vehículo: '+carros[yo.personaje].nombre:'Sin piloto';
  for(const [id,carro] of Object.entries(carros)){
    const p=e.jugadores.find(q=>q.personaje===id), card=document.querySelector(`[data-hud="${id}"]`);
    card.classList.toggle('empty',!p);card.classList.toggle('dead',!!p&&p.vida<=0);card.classList.toggle('mine',p?.id===player_id);
    card.querySelector('.hp-text').textContent=p?`${p.vida} / ${p.max_vida}`:`${carro.vida} / ${carro.vida}`;card.querySelector('.hp-fill').style.width=(p?p.vida/p.max_vida*100:100)+'%';card.querySelector('.driver-name').textContent=p?(p.conectado?p.nombre:'Desconectado'):'Esperando piloto';
    const btn=document.querySelector(`[data-carro="${id}"]`);btn.disabled=!!p&&p.id!==player_id;
    const label=btn.querySelector('.ocupado-label');if(btn.disabled&&!label){const t=document.createElement('span');t.className='ocupado-label';t.textContent='Ocupado';btn.append(t)}else if(!btn.disabled&&label)label.remove();
  }
  if(fase==='lobby'){
    $('roster').replaceChildren();
    for(let i=0;i<4;i++){
      const p=e.jugadores.find(q=>q.slot===i),linea=document.createElement('div');linea.className='roster-slot';linea.innerHTML='<i></i><span></span><b></b>';linea.querySelector('span').textContent=p?p.nombre:'Esperando…';linea.querySelector('i').style.background=p?carros[p.personaje].color:'#546071';linea.querySelector('b').textContent=p?.listo?'✓':'';$('roster').append(linea);
    }
    $('ready-btn').firstChild.textContent=yo?.listo?'Cancelar preparado ':'Estoy listo ';$('ready-btn').setAttribute('aria-pressed',String(!!yo?.listo));
  }
  if(fase==='final'){
    const ganador=e.jugadores.find(p=>p.id===e.resultado),gane=e.resultado===player_id;
    $('result-title').textContent=e.resultado==='empate'?'Empate':gane?'¡Victoria!':'Ronda terminada';
    $('result-detail').textContent=ganador?`${ganador.nombre} sobrevivió con ${carros[ganador.personaje].nombre}.`:'No hubo un único superviviente. La arena pide revancha.';
    retrato($('winner-car'),ganador?.personaje||seleccionado,true);
  }
  if(fase!==anterior_fase){limpiarControles();if(fase==='jugando'){$('arena').focus({preventScroll:true});sonido('start')};if(fase==='final')sonido('end');anterior_fase=fase}
  if(e.tick-ultimo_tick_sonido>3){if(e.impactos.some(i=>i.tipo==='carro'&&i.ttl>=8))sonido('hit');else if(e.proyectiles.some(b=>b.owner===player_id&&b.ttl>=99))sonido('shot');ultimo_tick_sonido=e.tick}
}
$('arena').addEventListener('pointerdown',()=>$('arena').focus({preventScroll:true}));
const mapeo={ArrowUp:'arriba',KeyW:'arriba',ArrowDown:'abajo',KeyS:'abajo',ArrowLeft:'izquierda',KeyA:'izquierda',ArrowRight:'derecha',KeyD:'derecha'};
function codigoTecla(e){return e.code || ({w:'KeyW',a:'KeyA',s:'KeyS',d:'KeyD',e:'KeyE',' ':'Space'}[e.key?.toLowerCase()] || e.key)}
function esCampo(){return ['INPUT','TEXTAREA'].includes(document.activeElement?.tagName) || document.activeElement?.isContentEditable}
window.addEventListener('keydown',e=>{
  if(estado_partida?.fase!=='jugando'||esCampo())return;
  const codigo=codigoTecla(e);
  if(codigo==='KeyE'){e.preventDefault();if(!e.repeat)colocarMina();return}
  if(mapeo[codigo]||codigo==='Space'){e.preventDefault();if(!teclas.has(codigo)){teclas.add(codigo);mandarInput()}}
});
window.addEventListener('keyup',e=>{const codigo=codigoTecla(e);if(teclas.has(codigo)){e.preventDefault();teclas.delete(codigo);mandarInput()}});
function limpiarControles(){teclas.clear();direccion_touch='quieto';fuego_touch=false;if(dentro)enviar({tipo:'input',direccion:'quieto',disparar:false});if(document.activeElement?.tagName==='BUTTON')document.activeElement.blur()}
window.addEventListener('blur',limpiarControles);document.addEventListener('visibilitychange',()=>{if(document.hidden)limpiarControles()});
function mandarInput(){
  if(!dentro||estado_partida?.fase!=='jugando')return;
  const ultima=[...teclas].reverse().find(k=>mapeo[k]);
  enviar({tipo:'input',direccion:direccion_touch!=='quieto'?direccion_touch:ultima?mapeo[ultima]:'quieto',disparar:fuego_touch||teclas.has('Space')});
}
setInterval(mandarInput,33);setInterval(()=>enviar({tipo:'ping'}),15000);
for(const btn of document.querySelectorAll('[data-dir]')){
  btn.addEventListener('pointerdown',e=>{e.preventDefault();btn.setPointerCapture(e.pointerId);direccion_touch=btn.dataset.dir;mandarInput()});
  const soltar=e=>{e.preventDefault();direccion_touch='quieto';mandarInput()};btn.addEventListener('pointerup',soltar);btn.addEventListener('pointercancel',soltar);
}
$('touch-fire').addEventListener('pointerdown',e=>{e.preventDefault();$('touch-fire').setPointerCapture(e.pointerId);fuego_touch=true;mandarInput()});
for(const evento of ['pointerup','pointercancel'])$('touch-fire').addEventListener(evento,e=>{e.preventDefault();fuego_touch=false;mandarInput()});
