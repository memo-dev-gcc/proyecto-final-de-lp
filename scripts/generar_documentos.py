"""Genera los PDFs y sus fuentes Markdown. Solo requiere reportlab para documentación."""
from pathlib import Path
from html import escape
from PIL import Image as PILImage
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle, Image, Preformatted, Flowable
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4

RAIZ=Path(__file__).resolve().parents[1]
SALIDA=RAIZ/'docs/entrega'
FUENTES=Path('/System/Library/Fonts/Supplemental')
NORMAL,NEGRITA,MONO='Helvetica','Helvetica-Bold','Courier'
if (FUENTES/'Trebuchet MS.ttf').exists():
    for nombre,archivo in [('Trebuchet','Trebuchet MS.ttf'),('TrebuchetB','Trebuchet MS Bold.ttf')]:
        pdfmetrics.registerFont(TTFont(nombre,str(FUENTES/archivo)))
    NORMAL,NEGRITA='Trebuchet','TrebuchetB'
ANCHO=A4[0]-105
EST={
 'texto':ParagraphStyle('texto',fontName=NORMAL,fontSize=10.5,leading=14.7,spaceAfter=8),
 'titulo':ParagraphStyle('titulo',fontName=NEGRITA,fontSize=25,leading=29,spaceAfter=6),
 'subtitulo':ParagraphStyle('subtitulo',fontName=NORMAL,fontSize=11,leading=15,spaceAfter=13),
 'seccion':ParagraphStyle('seccion',fontName=NEGRITA,fontSize=12,leading=16,spaceBefore=8,spaceAfter=7,keepWithNext=True),
 'caption':ParagraphStyle('caption',fontName=NORMAL,fontSize=8.5,leading=11,spaceAfter=9),
 'tabla':ParagraphStyle('tabla',fontName=NORMAL,fontSize=9,leading=12),
 'tablahead':ParagraphStyle('tablahead',fontName=NEGRITA,fontSize=9,leading=12),
 'codigo':ParagraphStyle('codigo',fontName=MONO,fontSize=8.7,leading=12,spaceAfter=10,backColor=colors.HexColor('#f1f1f1'),borderPadding=9),
 'etiqueta':ParagraphStyle('etiqueta',fontName=NORMAL,fontSize=8.5,leading=11,spaceAfter=12),
}

def p(texto,tipo='texto'):return Paragraph(escape(texto).replace('\n','<br/>'),EST[tipo])
class Diagrama(Flowable):
    def __init__(self):super().__init__();self.width=ANCHO;self.height=216
    def draw(self):
        c=self.canv;c.setStrokeColor(colors.black);c.setFillColor(colors.black);c.setLineWidth(.6)
        def caja(x,y,w,h,a,b=None):
            c.roundRect(x,y,w,h,3,fill=0);c.setFont(NEGRITA,8);c.drawCentredString(x+w/2,y+h/2+(2 if b else -3),a)
            if b:c.setFont(NORMAL,7.3);c.drawCentredString(x+w/2,y+h/2-10,b)
        def flecha(x,y,x2,y2):
            c.line(x,y,x2,y2);c.line(x2,y2,x2-3,y2+5);c.line(x2,y2,x2+3,y2+5)
            c.line(x,y,x-3,y-5);c.line(x,y,x+3,y-5)
        w=104;gap=(ANCHO-4*w)/3
        for i in range(4):
            x=i*(w+gap);caja(x,165,w,28,f'Navegador {i+1}');flecha(x+w/2,163,x+w/2,129);caja(x,100,w,28,f'Socket {i+1}','Proceso del jugador')
            c.line(x+w/2,100,x+w/2,86)
        c.line(w/2,86,ANCHO-w/2,86);flecha(ANCHO/2,86,ANCHO/2,71)
        caja(ANCHO/2-120,37,240,33,'Arena.Partida','GenServer y estado autorizado')
        flecha(ANCHO/2,36,ANCHO/2,21);caja(ANCHO/2-120,-7,240,27,'Arena.Reglas  ·  Funciones puras')
        c.setFont(NORMAL,7.5);c.drawCentredString(ANCHO/2,204,'WebSockets: acciones y actualizaciones')

# Componentes: título, párrafo, sección, código, tabla, imagen y diagrama.
def construir(nombre,paginas):
    historia=[];md=[]
    for indice,pagina in enumerate(paginas):
        if indice:historia.append(PageBreak());md.append('\n---\n')
        for componente in pagina:
            tipo,*datos=componente
            if tipo in ['titulo','texto','seccion','subtitulo','caption','etiqueta']:
                historia.append(p(datos[0],tipo));pref={'titulo':'# ','seccion':'## '}.get(tipo,'');md.append(pref+datos[0]+'\n')
            elif tipo=='codigo':historia.extend([Spacer(1,4),Preformatted(datos[0],EST['codigo'])]);md.append('```elixir\n'+datos[0]+'\n```\n')
            elif tipo=='tabla':
                filas=datos[0];anchos=datos[1] if len(datos)>1 else [ANCHO/len(filas[0])]*len(filas[0])
                t=Table([[p(c,'tablahead' if i==0 else 'tabla') for c in fila] for i,fila in enumerate(filas)],colWidths=anchos,repeatRows=1,hAlign='LEFT')
                t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#eeeeee')),('VALIGN',(0,0),(-1,-1),'TOP'),('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),6),('LINEBELOW',(0,0),(-1,0),.5,colors.black),('LINEBELOW',(0,-1),(-1,-1),.4,colors.grey)]));historia.extend([t,Spacer(1,9)])
                md.append('| '+' | '.join(filas[0])+' |\n| '+' | '.join(['---']*len(filas[0]))+' |\n'+'\n'.join('| '+' | '.join(f)+' |' for f in filas[1:])+'\n')
            elif tipo=='imagen':
                ruta=RAIZ/datos[0]
                iw,ih=PILImage.open(ruta).size;factor=min(ANCHO/iw,datos[1]/ih if len(datos)>1 else ANCHO/iw);im=Image(str(ruta),width=iw*factor,height=ih*factor);historia.extend([im,Spacer(1,7)]);md.append(f'![Captura del juego](../capturas/{Path(datos[0]).name})\n')
            elif tipo=='diagrama':historia.extend([Diagrama(),Spacer(1,12)]);md.append('Navegadores ↔ WebSockets ↔ procesos Socket ↔ GenServer de partida ↔ reglas puras.\n')
    def pie(c,doc):
        c.saveState();c.setFont(NORMAL,9);c.setFillColor(colors.black);c.drawCentredString(A4[0]/2,28,str(doc.page));c.restoreState()
    doc=SimpleDocTemplate(str(SALIDA/(nombre+'.pdf')),pagesize=A4,leftMargin=52.5,rightMargin=52.5,topMargin=47,bottomMargin=48,title=nombre.replace('_',' '),author='')
    doc.build(historia,onFirstPage=pie,onLaterPages=pie)
    (SALIDA/(nombre+'.md')).write_text('\n'.join(md))

INFORME=[
[
('etiqueta','AVANCE II · LENGUAJES DE PROGRAMACIÓN'),
('titulo','Arena de acero'),('subtitulo','Prototipo multijugador en Elixir · Versión 0.2.0'),
('seccion','1  Presentación y objetivo'),
('texto','Arena de acero es un juego de combate vehicular 2D visto desde arriba. Cuatro jugadores conducen vehículos distintos dentro de una arena con paredes, se cubren y disparan en cuatro direcciones. Los impactos reducen la vida y gana el último vehículo activo. La ronda termina en empate si no queda un ganador único.'),
('texto','El objetivo de este avance es demostrar el núcleo funcional del proyecto: estado compartido, conexiones simultáneas, movimiento, paso de mensajes y reglas puras en Elixir. Se entrega como versión intermedia para el hito mínimo del 50 %, no como versión final terminada. El porcentaje es una referencia del enunciado, no una medición exacta de funciones completadas.'),
('seccion','2  Alcance implementado'),
('tabla',[
['Componente','Estado del avance'],
['Sala y jugadores','Código de sala, cuatro pilotos y selección exclusiva de vehículo.'],
['Juego básico','Movimiento, paredes, proyectiles, daño, eliminación y reinicio de ronda.'],
['Concurrencia','Proceso por conexión y GenServer coordinador por sala.'],
['Prueba individual','Un vehículo sin rivales para revisar controles; sin bots ni espera.'],
['Validación pendiente','Prueba presencial en cuatro computadoras y ajuste del balance.']],[120,ANCHO-120]),
('seccion','3  Vehículos y controles'),
('tabla',[
['Personaje','Vehículo','Diferencia principal'],['Rayo','Buggy','Rápido, con menor resistencia.'],['Muro','Blindado','Más vida y menor velocidad.'],['Chispa','Auto de combate','Disparo frecuente y menor daño por impacto.'],['Martillo','Camioneta','Más daño y mayor tiempo entre disparos.']],[85,110,ANCHO-195]),
('texto','WASD o flechas permiten moverse; Espacio dispara hacia la última dirección. El desplazamiento se actualiza en pasos de simulación, con cuatro orientaciones y sin giro libre. El navegador enfoca la arena al entrar; al perder el foco, los controles se detienen.')
],
[
('seccion','4  Estructura del juego'),('texto','El servidor concentra las decisiones de la partida. Cada navegador envía intenciones de movimiento y disparo, pero no posiciones, daño ni resultados. El coordinador aplica las reglas y distribuye un mismo estado a los clientes.'),
('diagrama',),('caption','Figura 1. Comunicación de cuatro jugadores con el coordinador de la partida.'),
('tabla',[
['Módulo','Responsabilidad'],['Arena.Application','Inicia supervisión, registro de salas y servidor HTTP.'],['Arena.Router y Arena.Socket','Sirven la interfaz y reciben mensajes WebSocket por jugador.'],['Arena.Salas','Localiza o crea la sala solicitada.'],['Arena.Partida','Coordina acciones, bucle de simulación y envío de estados.'],['Arena.Reglas','Calcula movimiento, colisiones, daño y final con funciones puras.']],[150,ANCHO-150]),
('seccion','5  Concurrencia y sincronización'),
('texto','Elixir se ejecuta sobre BEAM. Las conexiones se atienden en procesos ligeros y cada sala tiene un GenServer independiente. El coordinador procesa sus mensajes de forma secuencial, lo que evita que dos clientes modifiquen simultáneamente su estado autorizado. La simulación avanza aproximadamente cada 33 ms.'),
('texto','Un movimiento recorre esta secuencia: tecla en el navegador, mensaje WebSocket, proceso del jugador, coordinador, cálculo de un nuevo estado y difusión a las cuatro pantallas. Los monitores detectan desconexiones y las salas vacías terminan. Una desconexión durante combate elimina al vehículo; recargar no recupera automáticamente la sesión.'),
('texto','Los datos del juego se representan mediante mapas y listas inmutables. Las operaciones de red y temporización quedan en los procesos; las reglas reciben datos y devuelven nuevos datos. Esta separación permite verificar la lógica sin abrir navegadores.')
],
[
('seccion','6  Funciones principales'),
('tabla',[
['Función de Arena.Reglas','Propósito'],['nueva/0','Construye el estado inicial de la sala.'],['agregar/4','Valida y registra un jugador y su vehículo.'],['accion/3','Gestiona selección, preparado y revancha.'],['input/4','Registra una intención válida de movimiento y disparo.'],['tick/1','Avanza la simulación y calcula colisiones, daño y final.'],['quitar/2 y snapshot/1','Gestionan salida y preparan el estado enviado a clientes.']],[155,ANCHO-155]),
('seccion','7  Evidencia y verificación'),
('imagen','docs/capturas/practica.png'),
('caption','Figura 2. Prueba individual real: un solo vehículo, sin rivales y con tiempo libre. Utiliza el mismo servidor y las mismas reglas de movimiento que el multijugador.'),
('texto','La verificación automatizada pasó 14 pruebas ExUnit, una prueba de WebSockets reales y cuatro pruebas de navegador. Se comprobó movimiento con W, A, S y D, límites y paredes, daño y cadencia, selección exclusiva, quinto jugador rechazado, cuenta atrás, cuatro clientes con el mismo estado, desconexión, victoria, empate y revancha.'),
('texto','Las pruebas de cuatro clientes se ejecutaron en una computadora; no equivalen a haber validado cuatro equipos físicos en la red del aula. La revisión presencial debe completar esa comprobación. El código incluye las pruebas y las instrucciones para repetirlas.')
],
[
('seccion','8  Cómo conectarnos con los compañeros'),
('texto','Se necesitan cuatro navegadores y una red Wi-Fi o LAN que permita comunicación entre equipos. Solo la computadora anfitriona instala Elixir y Erlang/OTP. Las demás ejecutan el cliente en el navegador. GitHub almacena el proyecto; no ejecuta este servidor de juego.'),
('texto','Paso 1. El anfitrión abre una terminal en la carpeta del proyecto, instala las dependencias e inicia el servidor. Debe dejar la terminal abierta mientras juegan.'),
('codigo','mix local.hex --force   # solo al configurar Hex\nmix deps.get\nmix run --no-halt'),
('texto','Paso 2. Consultar la IP local del anfitrión: en macOS, ipconfig getifaddr en0 o los detalles de Wi-Fi; en Windows, ipconfig y Dirección IPv4; en Linux, hostname -I. Si el adaptador no es en0, se consulta la dirección desde la configuración de red.'),
('texto','Paso 3. Los cuatro abren la IP real y el puerto 4000. Ejemplo ilustrativo: http://192.168.1.25:4000. No se debe escribir localhost en las otras computadoras, porque apuntaría a ellas mismas. El anfitrión también usa su IP LAN antes de copiar una invitación.'),
('texto','Paso 4. Todos introducen el mismo código, por ejemplo AULA01, eligen vehículos distintos y pulsan Estoy listo. La ronda empieza cuando los cuatro están preparados. Para esta prueba se utiliza Entrar a la sala; Probar movimiento es solo para demostrar un vehículo.'),
('tabla',[
['Si ocurre esto','Comprobar'],['No abre la página','Servidor activo, misma red, IP correcta y puerto 4000.'],['El anfitrión entra y los demás no','Permisos entrantes de Erlang en firewall o aislamiento de clientes en Wi-Fi.'],['No responde el teclado','Hacer clic en la arena, comprobar foco y utilizar WASD o flechas.'],['Están en redes distintas','Se requiere despliegue en internet, fuera de esta entrega LAN.']],[160,ANCHO-160]),
('seccion','9  Trabajo para la entrega final'),
('texto','Se mantiene un alcance intermedio: una arena fija, paredes indestructibles y disparo básico. Quedan para una siguiente iteración la ampliación del mapa, objetos de recuperación de vida, armamento adicional y una revisión del balance. Antes de añadirlos se validará la experiencia con cuatro compañeros en equipos físicos.'),
('texto','La entrega se complementa con el Manual de Elixir y la guía de conexión en Markdown. El repositorio incluye código fuente, dependencias fijadas, instrucciones y pruebas reproducibles.'),
('caption','Repositorio: https://github.com/memo-dev-gcc/proyecto-final-de-lp\nReferencia técnica: documentación oficial de Elixir, GenServer y WebSock; enlaces completos en el manual.')
]
]

MANUAL=[
[
('etiqueta','MANUAL DEL LENGUAJE · AVANCE II'),('titulo','Elixir para Arena de acero'),('subtitulo','Fundamentos y uso en el proyecto'),
('seccion','1  Qué es Elixir y por qué se utiliza'),
('texto','Elixir es un lenguaje funcional que se ejecuta sobre la máquina virtual BEAM, también utilizada por Erlang. BEAM administra procesos ligeros y su comunicación mediante mensajes. En el proyecto permite coordinar jugadores conectados sin compartir memoria mutable entre sus procesos.'),
('texto','El lenguaje fue asignado al equipo y encaja con los requisitos de concurrencia e inmutabilidad. Su principal aporte es la coordinación del servidor. La interfaz HTML/Canvas dibuja el juego, mientras que las reglas permanecen en Elixir. WebSockets transporta mensajes; no sustituye la lógica que calcula movimiento y daño.'),
('seccion','2  Instalación y primeros comandos'),
('texto','El entorno probado utiliza Elixir 1.20.5 y Erlang/OTP 29. Para instalarlo se sigue la guía oficial del sistema operativo. En macOS con Homebrew se puede ejecutar brew install elixir. En Windows, IEx puede iniciarse con iex.bat para evitar el alias iex de PowerShell.'),
('codigo','elixir --version   # consultar versión\niex                # consola interactiva\n# Dentro de IEx:\n2 + 3\n"Arena" <> " de acero"\n# Salir: Ctrl+C dos veces'),
('seccion','3  Tipos y estructuras más utilizadas'),
('tabla',[
['Tipo','Ejemplo','Uso en el juego'],['Número','85, 4.2','Vida, posición y velocidad.'],['Booleano','true, false','Preparado y disparar.'],['String','"rayo"','Personaje e identificador recibido por JSON.'],['Átomo',':ok, :error','Etiquetas internas de resultados.'],['Tupla','{:ok, estado}','Respuesta con estado o error.'],['Lista','[bala_1, bala_2]','Proyectiles e impactos.'],['Mapa','%{vida: 85, x: 100}','Jugador y estado de la partida.']],[80,145,ANCHO-225]),
('texto','El código distingue claves átomo, como :vida, de claves string, como "tipo". Jason decodifica los objetos JSON con claves string. Los mensajes externos se validan y no se convierten libremente a átomos.')
],
[
('seccion','4  Módulos y funciones puras'),
('texto','Un módulo agrupa funciones. def define una función pública y defp una privada. nombre/aridad identifica cuántos argumentos recibe: tick/1 recibe uno. Una función pura depende de sus argumentos y no realiza efectos externos; para los mismos datos produce el mismo resultado.'),
('codigo','defmodule EjemploReglas do\n  def recibir_dano(jugador, dano) when dano >= 0 do\n    %{jugador | vida: max(0, jugador.vida - dano)}\n  end\nend\n\noriginal = %{vida: 85, x: 100}\nnuevo = EjemploReglas.recibir_dano(original, 20)\n# original.vida sigue siendo 85; nuevo.vida es 65'),
('texto','Este ejemplo es didáctico. En el juego, Arena.Reglas aplica cambios sobre mapas nuevos; las funciones de daño no modifican el mapa anterior. Reasignar el nombre de una variable no hace mutable el valor al que estaba asociado.'),
('seccion','5  Pattern matching y control de flujo'),
('texto','El operador = hace coincidir patrones. Permite extraer datos de una tupla y distinguir respuestas correctas de errores. case elige una rama según la estructura y los valores del resultado. Las guardas, como when dano >= 0, restringen las condiciones de una función.'),
('codigo','case Arena.Reglas.agregar(estado, "p1", "Ana", "rayo") do\n  {:ok, actualizado} -> actualizado\n  {:error, motivo} -> IO.puts(motivo)\nend'),
('texto','El ejemplo utiliza IO.puts para mostrar un error y, por ello, esa rama tiene un efecto externo. En el proyecto los callbacks de procesos manejan estos resultados; las reglas retornan datos en lugar de imprimir o enviar información por red.'),
('seccion','6  Enum y el operador pipe'),
('texto','Enum transforma colecciones sin un contador mutable. filter selecciona elementos, map transforma y reduce acumula un resultado nuevo. El pipe |> coloca el resultado anterior como primer argumento de la siguiente función.'),
('codigo','jugadores = [%{vida: 85}, %{vida: 0}, %{vida: 100}]\nvivos =\n  jugadores\n  |> Enum.filter(fn jugador -> jugador.vida > 0 end)\n  |> Enum.count()\n# vivos == 2'),
('texto','En Arena.Reglas.tick/1 se encadenan pasos de movimiento, disparo, colisiones y resolución del final. Separar estos cálculos facilita entender y probar una regla a la vez.')
],
[
('seccion','7  Procesos y paso de mensajes'),
('texto','Un proceso Elixir es una tarea ligera administrada por BEAM, no otra computadora ni un proceso completo del sistema operativo. Cada proceso tiene una identidad PID y un buzón. send envía mensajes; receive busca un mensaje que coincida con un patrón.'),
('codigo','principal = self()\nspawn(fn -> send(principal, {:piloto_listo, "Ana"}) end)\nreceive do\n  {:piloto_listo, nombre} -> nombre\nafter\n  1000 -> :sin_respuesta\nend'),
('texto','La concurrencia permite que varias conexiones estén activas a la vez. No significa que todos cambien el mismo mapa simultáneamente. En este juego el coordinador procesa sus mensajes de forma secuencial y conserva un único estado autorizado por sala.'),
('seccion','8  GenServer y supervisión'),
('texto','GenServer organiza un proceso que mantiene estado y responde a mensajes. init prepara el estado; handle_call recibe solicitudes con respuesta; handle_cast atiende envíos asíncronos; handle_info maneja otros mensajes, incluidos ticks y monitores. Call espera una respuesta; cast no la espera.'),
('codigo','# Ejemplo mínimo, independiente de Arena.Partida\ndefmodule ContadorDemo do\n  use GenServer\n  def start_link, do: GenServer.start_link(__MODULE__, 0)\n  def init(valor), do: {:ok, valor}\n  def handle_call(:leer, _origen, valor) do\n    {:reply, valor, valor}\n  end\n  def handle_cast(:sumar, valor) do\n    {:noreply, valor + 1}\n  end\nend\n{:ok, pid} = ContadorDemo.start_link()\nGenServer.cast(pid, :sumar)\nGenServer.call(pid, :leer)  # devuelve 1'),
('texto','El supervisor inicia y vigila procesos según su política. Arena.Application usa supervisión, Registry localiza salas y DynamicSupervisor crea coordinadores cuando se solicitan. Las salas son temporales: no se promete recuperar una partida perdida ni persistir datos después de reiniciar.'),
('texto','El proceso Arena.Socket representa la conexión de un jugador. Un monitor avisa al coordinador cuando esa conexión termina, permitiendo retirar o eliminar el vehículo. Los cálculos puros siguen separados de este manejo de mensajes.')
],
[
('seccion','9  Herramientas y ejecución del proyecto'),
('texto','Mix administra dependencias, compilación y tareas. Hex distribuye paquetes y mix.lock fija las versiones resueltas. El proyecto utiliza Bandit y Plug para HTTP, WebSockAdapter/WebSock para la conexión persistente y Jason para JSON. No necesita base de datos.'),
('codigo','mix local.hex --force\nmix deps.get\nmix run --no-halt\n# En otro terminal, o antes de iniciar el servidor:\nmix format --check-formatted\nmix compile --warnings-as-errors\nmix test'),
('texto','Para explorar el proyecto de forma interactiva, iniciar iex -S mix. La aplicación también inicia su servidor: cerrar antes otra instancia que use el mismo puerto. En IEx, h muestra ayuda y c permite compilar un archivo; para esta aplicación se recomienda compilar mediante Mix.'),
('seccion','10  Ejercicio reproducible y pruebas'),
('codigo','# Dentro de iex -S mix:\nestado = Arena.Reglas.nueva()\n{:ok, nuevo} = Arena.Reglas.agregar(estado, "demo", "Ana", "rayo")\nmap_size(estado.jugadores)  # 0\nmap_size(nuevo.jugadores)  # 1'),
('texto','El ejercicio demuestra que agregar devuelve un estado diferente sin cambiar el anterior. ExUnit verifica reglas con datos controlados y también el ciclo de vida de salas. Las pruebas de navegador comprueban teclado, interfaz y cuatro clientes reales; no sustituyen la revisión del comportamiento en la red del aula.'),
('seccion','11  Errores habituales'),
('tabla',[
['Problema','Acción recomendada'],['mix no se reconoce','Instalar Elixir y revisar PATH; abrir de nuevo la terminal.'],['Puerto ocupado','Cerrar la instancia anterior o usar PORT=4100 y abrir ese puerto.'],['MatchError','Revisar la forma del resultado y manejar {:error, motivo}.'],['Movimiento no responde','Enfocar la arena y comprobar conexión y modo de juego.']],[140,ANCHO-140]),
('seccion','12  Referencias oficiales'),
('caption','Elixir Core Team. Introducción e instalación. https://hexdocs.pm/elixir/introduction.html\nElixir Core Team. Pattern matching. https://hexdocs.pm/elixir/pattern-matching.html\nElixir Core Team. Processes. https://hexdocs.pm/elixir/processes.html\nElixir Core Team. GenServer. https://hexdocs.pm/elixir/GenServer.html\nBandit. https://hexdocs.pm/bandit/Bandit.html\nWebSock. https://hexdocs.pm/websock/WebSock.html\nWebSockAdapter. https://hexdocs.pm/websock_adapter/WebSockAdapter.html'),
('caption','Los ejemplos del manual son didácticos y se distinguen de las funciones reales del repositorio. El documento acompaña el Avance II de Arena de acero.')
]
]
if __name__=='__main__':
    SALIDA.mkdir(parents=True,exist_ok=True)
    construir('Avance_II_Arena_de_acero',INFORME)
    construir('Manual_Elixir_Arena_de_acero',MANUAL)
    print('Documentos generados en',SALIDA)
