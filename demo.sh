#!/usr/bin/env bash
# Demonstração completa da atividade (usada na gravação do vídeo).
# Uso, no Git Bash, dentro da pasta do projeto:  bash demo.sh
URL=http://localhost:7071/api/guias
LOG="${TMPDIR:-/tmp}/func-demo.log"
CT='Content-Type: application/json'

titulo() { echo; echo "=================================================================="; echo ">>> $1"; echo "=================================================================="; sleep 2; }
mostra() { echo; echo "\$ $1"; sleep 1; }

sobe_host() {
  (npx func start --port 7071 > "$LOG" 2>&1 &)
  for i in $(seq 1 90); do grep -q "guias: \[POST\]" "$LOG" 2>/dev/null && break; sleep 1; done
  grep "guias: \[POST\]" "$LOG" | sed 's/^[[:space:]]*/    /'
  sleep 2
}
para_host() {
  powershell.exe -NoProfile -Command '$c=Get-NetTCPConnection -LocalPort 7071 -State Listen -ErrorAction SilentlyContinue; if($c){$p=$c.OwningProcess; Get-CimInstance Win32_Process -Filter "ParentProcessId=$p" | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }; Stop-Process -Id $p -Force}' >/dev/null 2>&1
  sleep 3
}

clear
echo "Rota Vital - funcao serverless que gera a guia de transporte"
echo "Azure Functions rodando localmente (Core Tools), sem Docker"
sleep 3

titulo "0) Limite de tempo da funcao (host.json)"
mostra "grep functionTimeout host.json"; grep functionTimeout host.json
sleep 3

titulo "1) Subindo a funcao (npx func start)"
para_host
sobe_host

titulo "2) Invocacao com o evento events/pedido.json - 2 vezes"
mostra "cat events/pedido.json"; cat events/pedido.json
for n in 1 2; do
  mostra "curl -X POST $URL -H '$CT' -d @events/pedido.json      # invocacao $n"
  curl -s -X POST "$URL" -H "$CT" -d @events/pedido.json -w "\n[HTTP %{http_code}] tempo: %{time_total}s\n"
  sleep 3
done
echo; echo "-> A 1a foi mais lenta (cold start / fase de Init). A 2a reaproveitou o ambiente."
sleep 4

titulo "3) Gatilho HTTP - 3 chamadas no MESMO ambiente"
for n in 1 2 3; do
  mostra "curl -X POST $URL -H '$CT' -d '{\"requisicaoId\":\"R-002\",\"hospital\":\"H-Caruaru\"}'"
  curl -s -X POST "$URL" -H "$CT" -d '{"requisicaoId":"R-002","hospital":"H-Caruaru"}' -w "\n[HTTP %{http_code}]\n"
  sleep 2
done
echo; echo "-> invocacaoNesteAmbiente subiu: a variavel global sobreviveu (mesmo processo)."
sleep 4

titulo "4) Reiniciando o host = ambiente NOVO"
para_host
sobe_host
mostra "curl -X POST $URL -H '$CT' -d '{\"requisicaoId\":\"R-002\",\"hospital\":\"H-Caruaru\"}'"
curl -s -X POST "$URL" -H "$CT" -d '{"requisicaoId":"R-002","hospital":"H-Caruaru"}' -w "\n[HTTP %{http_code}]\n"
echo; echo "-> O contador voltou para 1: variavel global nao guarda estado de forma confiavel."
sleep 4

titulo "5) Tempo limite: demorar=true (dorme 5 s, limite de 3 s)"
mostra "curl -X POST $URL -H '$CT' -d '{\"requisicaoId\":\"R-003\",\"demorar\":true}'"
curl -s -X POST "$URL" -H "$CT" -d '{"requisicaoId":"R-003","demorar":true}' -w "\n[HTTP %{http_code}]\n" --max-time 30
sleep 2
echo; echo "Log do host:"
grep -E "Timeout value of|Executed 'Functions.guias' \(Failed" "$LOG" | sed 's/, Id=[^,)]*//; s/ (Id: [^)]*)//' | tail -3
echo; echo "-> O host desistiu aos 3 s e devolveu erro 500."
sleep 5

para_host
titulo "Fim da demonstracao"
