import { test, expect } from '@playwright/test';
test('cuatro pilotos juegan, ven daño, reciben victoria y vuelven al lobby', async ({browser}) => {
  const sala = 'E' + Date.now().toString(36).slice(-6).toUpperCase();
  const contextos = await Promise.all(Array.from({length: 4}, () => browser.newContext()));
  const paginas = await Promise.all(contextos.map(c => c.newPage()));
  const errores = [];
  let ultimoEstado;
  paginas[0].on('websocket', ws => ws.on('framereceived', ({payload}) => {
    const m = JSON.parse(payload); if (m.tipo === 'estado') ultimoEstado = m.estado;
  }));
  try {
    for (const [i, p] of paginas.entries()) {
      p.on('pageerror', e => errores.push(e.message));
      await p.goto('/?sala=' + sala);
      await expect(p.locator('#conexion')).toHaveText('Conectado');
      await p.locator('#nombre').fill('Piloto ' + (i + 1));
      await p.locator(`[data-carro="${['rayo','muro','chispa','martillo'][i]}"]`).click();
      await p.getByRole('button', {name:'Entrar a la sala', exact: true}).click();
      await expect(p.locator('#ready-btn')).toBeVisible();
    }
    for (const p of paginas) await expect(p.locator('#ocupacion')).toHaveText('4 / 4 pilotos');
    await paginas[0].screenshot({path:'test-results/lobby.png', fullPage:true});
    for (const p of paginas) await p.locator('#ready-btn').click();
    for (const p of paginas) await expect(p.locator('#fase-label')).toHaveText('En combate', {timeout:7000});
    // Un botón de sonido enfocado no debe bloquear los controles del vehículo.
    await paginas[0].locator('#sound-btn').click();
    await paginas[0].keyboard.down('ArrowRight');
    await expect.poll(() => ultimoEstado?.jugadores.find(p=>p.nombre==='Piloto 1')?.x).toBeGreaterThan(100);
    await paginas[0].keyboard.up('ArrowRight');
    // Perder foco detiene el carro aunque el navegador no reciba keyup.
    await paginas[0].keyboard.down('ArrowRight');
    await paginas[0].evaluate(() => window.dispatchEvent(new Event('blur')));
    await paginas[0].waitForTimeout(120);
    const xDetenido = ultimoEstado.jugadores.find(p=>p.nombre==='Piloto 1').x;
    await paginas[0].waitForTimeout(150);
    expect(ultimoEstado.jugadores.find(p=>p.nombre==='Piloto 1').x).toBe(xDetenido);
    await paginas[0].keyboard.up('ArrowRight');
    await paginas[0].keyboard.down('Space');
    await expect(paginas[1].locator('[data-hud="muro"] .hp-text')).not.toHaveText('145 / 145', {timeout:10000});
    await paginas[0].keyboard.up('Space');
    await paginas[0].screenshot({path:'test-results/combate.png', fullPage:true});
    // Cerrar sockets de tres clientes es una derrota por desconexión, no un cambio artificial de estado.
    for (const c of contextos.slice(1)) await c.close();
    await expect(paginas[0].locator('#result-panel')).toBeVisible();
    await expect(paginas[0].locator('#result-title')).toHaveText('¡Victoria!');
    await paginas[0].getByRole('button',{name:'Volver al lobby'}).click();
    await expect(paginas[0].locator('#ready-btn')).toBeVisible();
    await expect(paginas[0].locator('#ocupacion')).toHaveText('1 / 4 pilotos');
    expect(errores).toEqual([]);
  } finally {await Promise.all(contextos.map(c=>c.close().catch(()=>{})));}
});
test('interfaz móvil y validación de nombre', async ({page}) => {
  await page.setViewportSize({width:390,height:844});
  await page.goto('/');
  await expect(page.locator('#conexion')).toHaveText('Conectado');
  await page.getByRole('button',{name:'Entrar a la sala',exact:true}).click();
  await expect(page.locator('#nombre')).toBeFocused();
  expect(await page.evaluate(()=>document.documentElement.scrollWidth <= window.innerWidth)).toBeTruthy();
  await page.screenshot({path:'test-results/movil.png',fullPage:true});
});

test('la arena completa cabe en una pantalla de escritorio', async ({page}) => {
  await page.setViewportSize({width:1440,height:900});
  await page.goto('/');
  const caja = await page.locator('.battle-stage').boundingBox();
  expect(caja.y + caja.height).toBeLessThanOrEqual(900);
});

test('prueba individual sin bots permite WASD y salir al menú', async ({page}) => {
  let estado;
  page.on('websocket', ws=>ws.on('framereceived',({payload})=>{const m=JSON.parse(payload);if(m.tipo==='estado')estado=m.estado}));
  await page.goto('/');
  await expect(page.locator('#conexion')).toHaveText('Conectado');
  await page.getByRole('button',{name:'Probar movimiento',exact:true}).click();
  await expect(page.locator('#fase-label')).toHaveText('Prueba de movimiento');
  await expect(page.locator('#arena')).toBeFocused();
  expect(estado.jugadores).toHaveLength(1);
  for(const [tecla,eje,signo] of [['d','x',1],['a','x',-1],['s','y',1],['w','y',-1]]){
    const antes=estado.jugadores[0][eje];
    await page.keyboard.down(tecla);
    await expect.poll(()=>signo*(estado.jugadores[0][eje]-antes)).toBeGreaterThan(0);
    await page.keyboard.up(tecla);
  }
  await expect(page.locator('#timer')).toHaveText('Libre');
  await page.screenshot({path:'test-results/practica.png',fullPage:true});
  await page.locator('#exit-practice-btn').click();
  await expect(page.locator('#join-form')).toBeVisible();
  await expect(page.locator('#fase-label')).toHaveText('Elige tu vehículo');
  await expect(page).not.toHaveURL(/practica=1/);
});
