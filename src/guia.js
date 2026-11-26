// Regra de negócio pura: monta a guia de transporte a partir do pedido.
// Fica separada do handler HTTP para poder ser testada sem subir o runtime.

function gerarGuia(pedido, invocacaoNesteAmbiente) {
  if (!pedido || typeof pedido !== "object" || !pedido.requisicaoId) {
    return { status: 400, corpo: { erro: "requisicaoId obrigatório" } };
  }
  return {
    status: 201,
    corpo: {
      guia: "G-" + pedido.requisicaoId,
      hospital: pedido.hospital ?? null,
      bolsas: Array.isArray(pedido.bolsas) ? pedido.bolsas : [],
      invocacaoNesteAmbiente,
    },
  };
}

module.exports = { gerarGuia };
