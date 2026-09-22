# Trucaralho

Primeira entrega: fundação de domínio e engine para Truco Paulista.

## Escopo

- Dart puro, sem dependência de Flutter no domínio.
- Engine genérica para ciclo de vida, ações, estado e serialização.
- Truco Paulista para 2 ou 4 jogadores, com duplas.
- Baralho de 40 cartas, vira e manilhas.
- Vazas, empates, mão, placar e negociação de Truco.
- Estado serializável e restaurável.
- Contador manual independente.
- IA aleatória e IA básica separadas do engine.
- Histórico de partida modelado separadamente do estado corrente.
- Persistência concreta local por arquivo, atrás da abstração `GameStateStore`.
- Criação de partidas 1v1 e 2v2 pela camada de aplicação, com configuração de jogadores, equipes e IA.
- Integração ponta a ponta entre factory, sessão, IA, histórico e persistência local.

## Validação

```bash
dart test
```

Nenhuma UI, Cubit/Bloc ou Blackjack faz parte desta entrega.
