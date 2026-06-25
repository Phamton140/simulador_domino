document.addEventListener('DOMContentLoaded', () => {
    const tableContainer = document.getElementById('table-container');
    const btnRestart = document.getElementById('btn-restart');
    const controls = document.getElementById('controls');

    // Constantes de dimensiones
    const TABLE_W = 800;
    const TABLE_H = 600;
    const PIECE_L = 60; // Largo
    const PIECE_W = 30; // Ancho
    const MARGIN = 100; // Margen para girar

    let gameSequence = [];
    let animationInterval = null;

    btnRestart.addEventListener('click', () => {
        startSimulation();
    });

    // Helper para generar el HTML de los puntos
    function getDotsHTML(val) {
        let dots = '';
        for(let i=1; i<=9; i++) {
            dots += `<div class="dot-pos p-${i}"><div class="dot"></div></div>`;
        }
        return `<div class="dots-container d-${val}">${dots}</div>`;
    }

    function generateGameSequence() {
        let adj = Array.from({length: 7}, () => []);
        for (let i = 0; i <= 6; i++) {
            for (let j = i; j <= 6; j++) {
                if (i === 6 && j === 6) continue;
                adj[i].push(j);
                if (i !== j) adj[j].push(i);
            }
        }
        
        // Barajar listas de adyacencia para camino aleatorio
        for (let i=0; i<=6; i++) {
            adj[i].sort(() => Math.random() - 0.5);
        }
        
        // Algoritmo de Hierholzer para encontrar un circuito Euleriano
        let path = [];
        let stack = [6];
        
        while(stack.length > 0) {
            let u = stack[stack.length - 1];
            if (adj[u].length > 0) {
                let v = adj[u].pop();
                if (u !== v) {
                    let idx = adj[v].indexOf(u);
                    adj[v].splice(idx, 1);
                }
                stack.push(v);
            } else {
                path.push(stack.pop());
            }
        }
        path.reverse();
        
        // path tiene 28 vértices (27 aristas). Comienza y termina en 6.
        let sequence = [];
        let left = 0;
        let right = path.length - 1;
        
        // Consumir el camino desde ambos extremos aleatoriamente para simular el juego
        while (left < right) {
            let side = Math.random() < 0.5 ? 1 : 2;
            
            if (side === 1) {
                sequence.push({
                    end: 1, 
                    val1: path[left], 
                    val2: path[left+1]
                });
                left++;
            } else {
                sequence.push({
                    end: 2, 
                    val1: path[right], 
                    val2: path[right-1]
                });
                right--;
            }
        }
        
        return sequence;
    }

    // Gira el extremo 90 grados en sentido antihorario
    function turnCounterClockwise(end) {
        const box = end.lastBox;
        if (!box) return;

        if (end.dir.y === -1) { // Iba hacia el Norte -> Gira al Oeste (Izquierda)
            end.dir = {x: -1, y: 0};
            end.x = box.px;
            end.y = box.py + 15;
        } else if (end.dir.x === -1) { // Iba al Oeste -> Gira al Sur (Abajo)
            end.dir = {x: 0, y: 1};
            end.x = box.px + 15;
            end.y = box.py + box.ph;
        } else if (end.dir.y === 1) { // Iba al Sur -> Gira al Este (Derecha)
            end.dir = {x: 1, y: 0};
            end.x = box.px + box.pw;
            end.y = box.py + box.ph - 15;
        } else if (end.dir.x === 1) { // Iba al Este -> Gira al Norte (Arriba)
            end.dir = {x: 0, y: -1};
            end.x = box.px + box.pw - 15;
            end.y = box.py;
        }
    }

    function renderPiece(x, y, w, h, val1, val2, flexDir, zIndex) {
        const domino = document.createElement('div');
        domino.className = `domino dir-${flexDir}`;
        domino.style.left = `${x}px`;
        domino.style.top = `${y}px`;
        domino.style.width = `${w}px`;
        domino.style.height = `${h}px`;
        domino.style.flexDirection = flexDir;
        domino.style.zIndex = zIndex;

        const half1 = document.createElement('div');
        half1.className = 'domino-half';
        half1.innerHTML = getDotsHTML(val1);

        const half2 = document.createElement('div');
        half2.className = 'domino-half';
        half2.innerHTML = getDotsHTML(val2);

        domino.appendChild(half1);
        domino.appendChild(half2);

        tableContainer.appendChild(domino);
    }

    function renderHand(sequence) {
        const handContainer = document.getElementById('north-hand');
        handContainer.innerHTML = '';
        let handPieces = [];

        // Norte juega en: inicio (6|6), y los pasos 3, 7, 11, 15, 19, 23.
        let northIndices = [-1, 3, 7, 11, 15, 19, 23];

        for (let i of northIndices) {
            let val1, val2;
            if (i === -1) {
                val1 = 6; val2 = 6;
            } else {
                val1 = sequence[i].val1;
                val2 = sequence[i].val2;
            }

            const handPiece = document.createElement('div');
            handPiece.className = 'hand-piece';
            handPiece.innerHTML = `
                <div class="domino-half" style="border-bottom: 2px solid #ccc; padding: 2px; box-sizing: border-box;">${getDotsHTML(val1)}</div>
                <div class="domino-half" style="padding: 2px; box-sizing: border-box;">${getDotsHTML(val2)}</div>
            `;
            handContainer.appendChild(handPiece);
            handPieces.push({ index: i, el: handPiece });
        }
        return handPieces;
    }

    function startSimulation() {
        if (animationInterval) clearInterval(animationInterval);
        tableContainer.innerHTML = '';
        controls.classList.add('hidden');

        gameSequence = generateGameSequence();
        let handElements = renderHand(gameSequence);
        
        let cx = TABLE_W / 2;
        let cy = TABLE_H / 2;

        // Colocar Doble 6 inicial (Horizontal)
        let d6_w = PIECE_L;
        let d6_h = PIECE_W;
        let d6_x = cx - d6_w / 2;
        let d6_y = cy - d6_h / 2;
        
        renderPiece(d6_x, d6_y, d6_w, d6_h, 6, 6, 'row', 10);
        
        // El Norte juega el D6
        setTimeout(() => {
            handElements[0].el.classList.add('played');
        }, 50);

        // Estado de los extremos
        let state = {
            1: { // Extremo 1 (Norte)
                x: cx, 
                y: cy - d6_h / 2, // Centro superior del Doble 6
                dir: {x: 0, y: -1}, // Crece hacia arriba
                lastBox: {px: d6_x, py: d6_y, pw: d6_w, ph: d6_h}
            },
            2: { // Extremo 2 (Sur)
                x: cx, 
                y: cy + d6_h / 2, // Centro inferior del Doble 6
                dir: {x: 0, y: 1}, // Crece hacia abajo
                lastBox: {px: d6_x, py: d6_y, pw: d6_w, ph: d6_h}
            }
        };

        let step = 0;
        let zIndexCounter = 11;

        animationInterval = setInterval(() => {
            if (step >= gameSequence.length) {
                clearInterval(animationInterval);
                controls.classList.remove('hidden');
                return;
            }

            const move = gameSequence[step];
            const end = state[move.end];
            let isDouble = move.val1 === move.val2;

            // Comprobar si hay que girar antes de colocar (sentido antihorario)
            let needTurn = false;
            
            // Si la ficha es un doble, evitamos que gire en la esquina. 
            // Se colocará recta y la SIGUIENTE ficha será la que efectúe el giro.
            if (!isDouble) {
                if (end.dir.y === -1 && end.y < MARGIN) needTurn = true;
                if (end.dir.y === 1 && end.y > TABLE_H - MARGIN) needTurn = true;
                if (end.dir.x === -1 && end.x < MARGIN) needTurn = true;
                if (end.dir.x === 1 && end.x > TABLE_W - MARGIN) needTurn = true;
            }

            if (needTurn) {
                turnCounterClockwise(end);
            }

            // Si es el turno de Norte (el índice coincide con uno de su mano), animar salida
            let handPiece = handElements.find(he => he.index === step);
            if (handPiece) {
                handPiece.el.classList.add('played');
            }

            let dir = end.dir;

            // Determinar dimensiones
            let w, h;
            if (dir.y !== 0) { // UP o DOWN
                w = isDouble ? PIECE_L : PIECE_W;
                h = isDouble ? PIECE_W : PIECE_L;
            } else { // LEFT o RIGHT
                w = isDouble ? PIECE_W : PIECE_L;
                h = isDouble ? PIECE_L : PIECE_W;
            }

            let px, py;
            let flexDir = w > h ? 'row' : 'column';
            let renderVal1, renderVal2;

            if (dir.y === -1) { // UP
                px = end.x - w / 2;
                py = end.y - h;
                end.x = px + w / 2;
                end.y = py;
                renderVal1 = move.val2; // Top
                renderVal2 = move.val1; // Bottom (toca el final)
            } 
            else if (dir.y === 1) { // DOWN
                px = end.x - w / 2;
                py = end.y;
                end.x = px + w / 2;
                end.y = py + h;
                renderVal1 = move.val1; // Top (toca el final)
                renderVal2 = move.val2; // Bottom
            }
            else if (dir.x === -1) { // LEFT
                px = end.x - w;
                py = end.y - h / 2;
                end.x = px;
                end.y = py + h / 2;
                renderVal1 = move.val2; // Left
                renderVal2 = move.val1; // Right (toca el final)
            }
            else if (dir.x === 1) { // RIGHT
                px = end.x;
                py = end.y - h / 2;
                end.x = px + w;
                end.y = py + h / 2;
                renderVal1 = move.val1; // Left (toca el final)
                renderVal2 = move.val2; // Right
            }

            renderPiece(px, py, w, h, renderVal1, renderVal2, flexDir, zIndexCounter++);
            end.lastBox = {px, py, pw: w, ph: h};

            step++;
        }, 500); // 500ms entre fichas
    }

    // Iniciar automáticamente al cargar
    setTimeout(() => {
        startSimulation();
    }, 500);
});
