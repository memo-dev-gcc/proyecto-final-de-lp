import {test} from 'node:test';
import assert from 'node:assert/strict';
const base=process.env.ARENA_URL||'http://127.0.0.1:4000';
const pausa=ms=>new Promise(r=>setTimeout(r,ms));
async function esperar(fn, descripcion, timeout=10000){const limite=Date.now()+timeout;while(Date.now()<limite){const valor=fn();if(valor)return valor;await pausa(15)}throw new Error('Timeout: '+descripcion)}
async function cliente(){
  const ws=new WebSocket(base.replace(/^http/,'ws')+'/ws'), mensajes=[];
  ws.addEventListener('message',e=>mensajes.push(JSON.parse(e.data)));
  ws.addEventListener('error',()=>{});
  await esperar(()=>mensajes.find(m=>m.tipo==='hola'),'bienvenida');
  return {ws,mensajes,enviar:m=>ws.send(JSON.stringify(m)),ultimo:()=>mensajes.findLast(m=>m.tipo==='estado')?.estado};
}
test('WebSockets reales: entradas inválidas, exclusividad, cuatro estados y desconexión',async()=>{
  const sala='N'+Date.now().toString(36).slice(-6).toUpperCase();
  const clientes=[];
  try {
    for(let i=0;i<5;i++)clientes.push(await cliente());
    const [a,b,c,d,extra]=clientes;
    a.ws.send('{malformado');await esperar(()=>a.mensajes.find(m=>m.tipo==='error'),'JSON inválido');
    a.enviar({tipo:'entrar',nombre:123,personaje:'rayo',sala});
    await esperar(()=>a.mensajes.filter(m=>m.tipo==='error').length===2,'nombre inválido');
    for(const [i,p] of clientes.slice(0,4).entries()){
      p.enviar({tipo:'entrar',nombre:'Piloto '+i,personaje:['rayo','muro','chispa','martillo'][i],sala});
      await esperar(()=>p.mensajes.some(m=>m.tipo==='dentro'),'entrada '+i);
    }
    extra.enviar({tipo:'entrar',nombre:'Quinto',personaje:'rayo',sala});
    await esperar(()=>extra.mensajes.some(m=>m.tipo==='error'),'quinto rechazado');
    for(const p of clientes.slice(0,4))assert.equal(p.ultimo().jugadores.length,4);
    for(const p of clientes.slice(0,4))p.enviar({tipo:'listo',valor:true});
    await esperar(()=>a.ultimo()?.fase==='jugando','inicio');
    const tick=a.ultimo().tick;
    await esperar(()=>clientes.slice(0,4).every(p=>p.mensajes.some(m=>m.tipo==='estado'&&m.estado.fase==='jugando'&&m.estado.tick===tick)),'mismo tick en cuatro sockets');
    const snapshots=clientes.slice(0,4).map(p=>p.mensajes.find(m=>m.tipo==='estado'&&m.estado.fase==='jugando'&&m.estado.tick===tick).estado);
    for(const s of snapshots)assert.deepEqual(s,snapshots[0]);
    const id=a.mensajes.find(m=>m.tipo==='hola').player_id;
    // El cliente no puede imponer posición, daño ni vida.
    a.enviar({tipo:'input',direccion:'quieto',disparar:false,x:999999,vida:999999,dano:999999});
    await esperar(()=>a.ultimo().tick>tick+2,'validación de estado');
    assert.equal(a.ultimo().jugadores.find(p=>p.id===id).x,100);
    assert.equal(a.ultimo().jugadores.find(p=>p.id===id).vida,85);
    a.enviar({tipo:'input',direccion:{mal:true},disparar:true});
    await pausa(100);assert.equal(a.ws.readyState,WebSocket.OPEN);
    for(const p of [b,c,d])p.ws.close();
    await esperar(()=>a.ultimo().fase==='final','victoria por desconexión');assert.equal(a.ultimo().resultado,id);
    a.enviar({tipo:'revancha'});await esperar(()=>a.ultimo().fase==='lobby','revancha');assert.equal(a.ultimo().jugadores.length,1);
    assert.equal(a.ultimo().jugadores[0].vida,85);
    assert.equal((await fetch(base+'/health')).status,200);
    assert.equal((await fetch(base+'/ws',{headers:{Origin:'http://otro-sitio.invalid'}})).status,403);
  }finally{clientes.forEach(p=>p.ws.close());}
});
