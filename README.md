# Rota Vital — Função serverless que gera a guia de transporte

**Atividade individual 1 · Serverless** · Infraestrutura de Software · ADS · CESAR School · 2026.2  
**Aluna:** Mirella Emily  
**Vídeo (até 3 min):** enviado como anexo na própria atividade do Google Classroom ("Atividade individual 1: Serverless").

Função HTTP que recebe uma requisição do Rota Vital e devolve a **guia de transporte**. Ela roda localmente no emulador oficial do **Azure Functions** (Azure Functions Core Tools), sem conta em nuvem e sem Docker. Todos os dados são sintéticos.

---

## 1. Caminho escolhido e por quê

O enunciado recomenda o Caminho A (AWS SAM CLI local), mas o `sam local` exige **Docker**, e a máquina usada não tem Docker nem WSL (instalar exigiria permissão de administrador e reinício). Por isso usei a **alternativa equivalente** citada no enunciado: **Azure Functions Core Tools** (`func start`), que roda o mesmo modelo de execução (host + processo da função) localmente, sem Docker.

| Atividade (SAM / Lambda) | Equivalente usado aqui (Azure Functions local) |
|---|---|
| `sam init` + `template.yaml` | `package.json` + `host.json` + `src/functions/guias.js` |
| Rota `POST /guias` no `template.yaml` | `app.http("guias", { methods: ["POST"], route: "guias" })` → `POST /api/guias` |
| `Timeout: 3` em `Globals` | `"functionTimeout": "00:00:03"` no `host.json` |
| `sam local invoke -e events/pedido.json` | `curl ... -d @events/pedido.json` (o mesmo evento, enviado ao gatilho HTTP) |
| `sam local start-api` | `npx func start` (escuta em `http://localhost:7071`) |
| Variável global `contador` | Variável global `contador` (mesma ideia) |
| Sem `--warm-containers` (contêiner novo por chamada) | Host **parado e iniciado de novo** = ambiente novo |
| `--warm-containers LAZY` (contêiner reaproveitado) | Host **continua rodando** = o mesmo processo atende as chamadas |

---

## 2. Como rodar

Pré-requisitos: **Node.js 22** e **Git Bash** (no Windows). Não precisa de Docker nem de conta na nuvem.

```bash
git clone <este repositório>
cd rota-vital-serverless
npm install            # instala @azure/functions e o Azure Functions Core Tools (func) no projeto
npm test               # 3 testes unitários da regra que monta a guia
npx func start         # sobe a função em http://localhost:7071/api/guias
```

Em outro terminal:

```bash
# 1) Invocação com o evento (rodar 2 vezes e comparar o tempo)
curl -X POST http://localhost:7071/api/guias -H "Content-Type: application/json" \
  -d @events/pedido.json -w "\ntempo: %{time_total}s\n"

# 2) Gatilho HTTP (rodar 3 vezes e observar invocacaoNesteAmbiente)
curl -X POST http://localhost:7071/api/guias -H "Content-Type: application/json" \
  -d '{"requisicaoId":"R-002","hospital":"H-Caruaru"}'

# 3) Limite de tempo (a função dorme 5 s; o limite é 3 s)
curl -X POST http://localhost:7071/api/guias -H "Content-Type: application/json" \
  -d '{"requisicaoId":"R-003","demorar":true}'
```

Para repetir o experimento 3 com limite maior: trocar `"functionTimeout"` no `host.json` para `"00:00:10"`, parar (`Ctrl+C`) e subir o `func start` de novo.

**Estrutura:**

```
src/functions/guias.js   ← handler HTTP (lê o body, contador global, demorar, timeout)
src/guia.js              ← regra que monta a guia (testável sem o runtime)
test/guia.test.js        ← testes unitários (node --test)
events/pedido.json       ← evento de exemplo (R-001, H-Recife, bolsa O-NEG-0142)
host.json                ← functionTimeout = 3 s
evidencias/              ← saídas reais dos comandos e logs do host
```

---

## 3. Resultados (evidências em `evidencias/`)

| # | Experimento | O que aconteceu | Arquivo |
|---|---|---|---|
| 0 | Ambiente e testes | Node 22.17.0, Core Tools 4.17.0; 3 testes passando | `00-ambiente.txt`, `00-testes-unitarios.txt` |
| 1 | Evento, 2 invocações (ambiente recém-criado) | 1ª: **237 ms** no host (0,68 s no curl) · 2ª: **7 ms** (0,22 s no curl) | `01-invocacao-com-evento.txt`, `04-resumo-duracoes-do-host.txt` |
| 2a | 3 chamadas HTTP no mesmo ambiente | `invocacaoNesteAmbiente` = 3, 4, 5 (o estado global sobreviveu) | `02a-http-ambiente-reaproveitado.txt` |
| 2b | Host reiniciado (ambiente novo) | contador **voltou para 1**, novo `ambienteInicializadoEm`, 1ª chamada lenta de novo (219 ms) | `02b-http-ambiente-novo.txt` |
| 3a | `demorar: true` com limite de 3 s | **HTTP 500** · log: *"Timeout value of 00:00:03 exceeded… Executed (Failed, Duration=3016ms)"* | `03a-timeout-3s.txt`, `func-host-fase1-timeout3s.log` |
| 3b | `demorar: true` com limite de 10 s | **HTTP 201** em 5,2 s | `03b-timeout-10s.txt` |

Observação do experimento 3a: o host cancelou a invocação e devolveu 500 aos 3 s, mas o código Node **continuou rodando** e terminou 2 s depois (aparece no log como "invocação 7 → 201"; essa resposta foi descartada). Em uma das rodadas, o host também reiniciou o processo da função depois do timeout. Ou seja: o timeout corta a resposta, mas não garante que o trabalho parou — mais um motivo para funções serem idempotentes.

---

## 4. Respostas

**1. Por que a primeira invocação demorou mais que a segunda? O que acontece na fase de Init?**  
Na primeira vez demorou bem mais porque o ambiente ainda estava "frio" (cold start). O servidor precisou criar o ambiente, iniciar o Node, carregar o código e rodar o que estava fora da função principal (as variáveis `contador` e `inicializadoEm`), que é justamente a fase de Init. Na segunda chamada, como o ambiente já estava pronto, rodou só o handler e foi bem rápido. Nos meus testes caiu de 237 ms para 7 ms (e depois que reiniciei o host, foi de 219 ms para 7 ms).

**2. O que o campo `invocacaoNesteAmbiente` mostrou com e sem reaproveitamento? O que isso diz sobre guardar estado numa variável global?**  
Com o ambiente sendo reaproveitado (host rodando), o contador foi subindo (1, 2, 3, 4, 5...) porque era o mesmo processo atendendo tudo. Quando reiniciei o host, o contador voltou para 1. No SAM sem o `--warm-containers`, cada chamada sobe um contêiner novo, então fica sempre em 1. Isso mostra que não dá pra confiar em variável global para salvar estado, porque se o ambiente reiniciar ou escalar, o valor se perde. Ela serve só como cache; dado importante tem que ir pro banco de dados.

**3. O que aconteceu com `demorar = true`? Qual é o tempo máximo no Lambda e o que fazer com um trabalho mais longo?**  
Com o limite em 3 segundos e a função demorando 5 segundos, o host parou de esperar aos 3 segundos, deu erro de timeout e retornou status 500 (o código ainda terminou depois, mas a resposta foi descartada). Quando mudei o limite para 10 segundos, rodou normal em uns 5,2 segundos e deu status 201. No AWS Lambda, o tempo máximo de uma execução é de 15 minutos (900 segundos). Se tiver uma tarefa que demore mais que isso, o jeito é quebrar ela em partes menores (usando filas ou Step Functions) ou rodar em um contêiner normal sem esse limite de tempo.

**4. Quanto custam 1 milhão de execuções com 128 MB e 100 ms?**

```
Memória:                128 MB / 1024 = 0,125 GB
Computação:             1.000.000 × 0,1 s × 0,125 GB = 12.500 GB-s
Custo de computação:    12.500 × US$ 0,0000166667 = US$ 0,2083
Custo das requisições:  US$ 0,20
Total:                  US$ 0,2083 + US$ 0,20 = US$ 0,4083 (cerca de US$ 0,41)
```

(Obs: com a camada gratuita de 1 milhão de requisições e 400 mil GB-s por mês, acaba saindo de graça.)

**5. Em que parte do Rota Vital uma função assim faria sentido, e em qual não faria?**  
No Rota Vital, faria sentido usar em tarefas rápidas e pontuais disparadas por algum evento, como emitir a guia de transporte quando a requisição é atendida, mandar e-mail/SMS de aviso ou processar as leituras de temperatura. Já na alocação FEFO das bolsas não faria sentido, porque ela precisa abrir transação direto com o PostgreSQL para salvar a requisição — abrir conexão com o banco a cada chamada pesaria muito, e o cold start atrasaria pedidos de emergência. Também não serve para as telas do sistema, que têm uso contínuo e funcionam melhor em um servidor rodando direto.

---

## 5. Uso de IA (PO-CESAR-021, permitido com declaração)

| Ferramenta | Finalidade | Como validei |
|---|---|---|
| Claude Code (Anthropic) | Apoio na escolha do caminho sem Docker, no código da função, no script dos experimentos e no rascunho deste README. | Rodei os testes unitários (3 passando) e os números do README saíram das saídas em `evidencias/`. Conferi a conta de custo. |

Fontes: enunciado da atividade (aula 007); documentação do Azure Functions Core Tools (learn.microsoft.com/azure/azure-functions/functions-run-local); cotas do Lambda (docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html).
