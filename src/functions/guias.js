const { app } = require("@azure/functions");
const { gerarGuia } = require("../guia");

// Variável global: só sobrevive enquanto o mesmo processo (ambiente) for reaproveitado.
let contador = 0;

// Momento em que este ambiente foi inicializado (fase de Init).
const inicializadoEm = new Date().toISOString();

const dormir = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

app.http("guias", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "guias",
  handler: async (request, context) => {
    contador += 1;

    let pedido = {};
    try {
      const texto = await request.text();
      pedido = texto ? JSON.parse(texto) : {};
    } catch {
      return { status: 400, jsonBody: { erro: "corpo não é um JSON válido" } };
    }

    if (pedido.demorar) {
      context.log("demorar=true: dormindo 5 s (o functionTimeout do host.json é 3 s)");
      await dormir(5000);
    }

    const { status, corpo } = gerarGuia(pedido, contador);
    context.log(`invocação ${contador} neste ambiente (inicializado em ${inicializadoEm}) -> ${status}`);
    return { status, jsonBody: { ...corpo, ambienteInicializadoEm: inicializadoEm } };
  },
});
