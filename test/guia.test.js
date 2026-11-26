const test = require("node:test");
const assert = require("node:assert/strict");
const { gerarGuia } = require("../src/guia");

test("gera a guia com prefixo G- a partir do requisicaoId", () => {
  const r = gerarGuia({ requisicaoId: "R-001", hospital: "H-Recife", bolsas: ["O-NEG-0142"] }, 1);
  assert.equal(r.status, 201);
  assert.deepEqual(r.corpo, {
    guia: "G-R-001",
    hospital: "H-Recife",
    bolsas: ["O-NEG-0142"],
    invocacaoNesteAmbiente: 1,
  });
});

test("sem requisicaoId devolve 400", () => {
  const r = gerarGuia({ hospital: "H-Recife" }, 1);
  assert.equal(r.status, 400);
  assert.equal(r.corpo.erro, "requisicaoId obrigatório");
});

test("sem bolsas devolve lista vazia e hospital nulo quando ausente", () => {
  const r = gerarGuia({ requisicaoId: "R-002" }, 3);
  assert.equal(r.status, 201);
  assert.deepEqual(r.corpo.bolsas, []);
  assert.equal(r.corpo.hospital, null);
  assert.equal(r.corpo.invocacaoNesteAmbiente, 3);
});
