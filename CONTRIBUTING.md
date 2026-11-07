# Como contribuir

Abra uma Issue descrevendo o problema, o resultado esperado, a versao do Windows
e a versao do PowerShell (`$PSVersionTable.PSVersion`). Remova IPs, nomes de clientes,
credenciais e outros dados privados dos exemplos.

Para uma melhoria, explique primeiro o caso de uso. Envie um pull request pequeno,
atualize o README quando o comportamento mudar e execute `tests/smoke.ps1`.
Para problemas especificos de IPv6 ou idioma do Windows, inclua um exemplo anonimizado.

Os testes de conectividade devem ter timeout, liberar sockets e manter os dados
locais. Nao inclua relatorios reais no repositorio.
