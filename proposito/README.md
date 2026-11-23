# Propósito — Finanças, Foco e Fé

App pessoal (PWA) com duas partes:

- **⚔️ Jornada**: um "jogo" da vida real. Você ganha XP e sobe de nível completando missões diárias
  de **Fé** (oração, Bíblia, servir alguém, gratidão), **Força** (treino, sono), **Saúde** (água, comer limpo),
  **Sabedoria** (estudo, leitura), **Foco** (planejar o dia, timer de 25 min) e **Mordomia** (registrar gastos).
  Tem versículo do dia, sequência de dias (🔥), atributos, conquistas, plano de leitura da Bíblia inteira
  (1189 capítulos), contador de água, timer de foco e diário de gratidão/oração.
- **💰 Finanças**: renda (salário recorrente + extras), contas fixas com vencimento e "paga/atrasada",
  gastos do dia a dia por categoria, sobra do mês, meta de economia, quanto pode gastar por dia
  e dicas de sabedoria financeira.

## Visual

- **Jornada**: estilo azul com cartões de vidro e as suas fotos de treino (`img/`): tela de entrada, "Atributos da Semana", "Missão Ativa" e o "Bloco de Foco" com medidor.
- **Finanças**: estilo preto com verde-limão: visão geral, anéis de progresso, rosca por categoria, barras da semana, linha do saldo, próximas contas e sequência.
- Tela de entrada com nome e **PIN opcional** (o PIN é guardado como hash, mas protege só contra olhares curiosos: não é criptografia dos dados).

Em **⚙️ Ajustes** você coloca seu nome, liga/desliga missões, cria missões próprias e faz backup.

## Como usar

Os dados ficam salvos **só no seu aparelho** (navegador). Use *Exportar backup* de vez em quando.

Para usar no celular, o app precisa estar hospedado em algum endereço HTTPS. Opções gratuitas:

1. **Netlify Drop**: acesse app.netlify.com/drop e arraste a pasta `proposito`. Abra o link no celular.
2. **GitHub Pages** (repositório público): Settings → Pages → publicar a branch; o app fica em `/proposito/`.

Depois, no celular: **Android/Chrome** → menu ⋮ → *Instalar app*; **iPhone/Safari** → Compartilhar →
*Adicionar à Tela de Início*. Ele abre como um app e funciona sem internet.

Para testar no computador: `cd proposito && python3 -m http.server 8000` e abra http://localhost:8000.
