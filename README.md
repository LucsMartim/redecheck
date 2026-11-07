# RedeCheck

Ferramenta open source de diagnostico de conectividade para suporte de redes no Windows.
Versao inicial **0.1.0**, em PowerShell, sem dependencias externas.

## Problema que resolve

Padroniza os testes iniciais de um chamado: resolucao de nome, respostas ICMP e
conexao a portas TCP. Gera um relatorio HTML para abrir no navegador e um JSON
para analise e integracoes. Os testes rodam no computador onde o script e executado.

## Como executar

1. Extraia o ZIP.
2. Abra o Windows PowerShell na pasta `redecheck` (nao precisa ser administrador).
3. Execute o exemplo local:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\redecheck.ps1 -Target 127.0.0.1 -Port 443
```

O parametro Bypass vale somente para esse processo; nao altera a politica permanente.
Politicas corporativas podem impedir a execucao. Use os procedimentos aprovados pela sua empresa.

Para diagnosticar um equipamento da sua rede, substitua o IP e as portas pelos reais:

```powershell
.\redecheck.ps1 -Target 192.168.6.1 -Port 80,443 -Count 4 -TimeoutMs 1000
```

Para varios destinos, em uma sessao PowerShell que permita executar o script:

```powershell
.\redecheck.ps1 -Target '192.168.6.1','servidor.exemplo.local' -Port 443,445
```

Abra o arquivo `.html` gerado na pasta `reports`. O `.json` tem os detalhes.
Sem argumentos, o script testa somente `127.0.0.1:443`; essa porta pode estar fechada.

## O que os resultados significam

| Resultado | Interpretacao |
| --- | --- |
| ICMP recebido | O endereco respondeu ao ping |
| Sem resposta ICMP | Pode haver bloqueio, perda ou indisponibilidade |
| TCP acessivel | Pelo menos um endereco aceitou a conexao naquela porta |
| TCP nao acessivel | Nenhum dos enderecos testados aceitou a conexao no prazo |
| Nao testada DNS | Nao foi possivel resolver o destino |

ICMP usa o primeiro endereco resolvido. TCP tenta os enderecos em sequencia ate
obter uma conexao. O timeout e por tentativa; o tempo total cresce com o numero
de destinos, portas e enderecos. A resolucao DNS usa o timeout do Windows.
Uma falha TCP nao distingue, sozinha, firewall, porta fechada e falha de rede.
O teste TCP nao envia comandos de aplicacao e nao valida certificados.
Nao e um teste de throughput; para medir Mbps, use uma ferramenta como iperf.

## Privacidade

Nao existe telemetria nem envio automatico de relatorios. O script consulta o
resolvedor DNS configurado e envia os testes aos destinos informados. Os relatorios
podem conter nomes e IPs internos; revise antes de compartilhar publicamente.
Execute apenas em equipamentos que voce pode testar. A pasta `reports` e ignorada pelo Git.

## Publicar no GitHub

1. Crie um repositorio chamado `redecheck` no seu GitHub.
2. Envie os arquivos desta pasta, sem incluir relatorios reais.
3. Mantenha a licenca MIT e descreva o projeto como versao inicial.
4. Abra Issues com as melhorias do ROADMAP e convide colegas para testes reais.

Nao ha usuarios, downloads, contribuidores ou validacao ampla declarados nesta
versao. Publicar este projeto nao garante elegibilidade ou aprovacao em programas
de incentivo. Descreva apenas uso e contribuicoes que tenham ocorrido.

## Desenvolvimento

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\smoke.ps1
```

O teste cria um servidor TCP temporario no loopback, verifica conexao bem-sucedida,
porta fechada, resultados ICMP, relatorios e rejeicao de entrada invalida. Nao acessa
a Internet. Veja CONTRIBUTING.md e ROADMAP.md.

## Licenca

MIT. Veja LICENSE.
