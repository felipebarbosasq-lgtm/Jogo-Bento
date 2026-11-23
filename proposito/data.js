// Conteúdo fixo do app: versículos, frases, plano bíblico, missões padrão, títulos e categorias.

const VERSES = [
  ["Tudo posso naquele que me fortalece.", "Filipenses 4:13"],
  ["Entrega o teu caminho ao Senhor, confia nele, e o mais ele fará.", "Salmos 37:5"],
  ["Buscai primeiro o Reino de Deus e a sua justiça, e todas essas coisas vos serão acrescentadas.", "Mateus 6:33"],
  ["Lâmpada para os meus pés é a tua palavra, e luz para o meu caminho.", "Salmos 119:105"],
  ["Não fui eu que lhe ordenei? Seja forte e corajoso! Não se apavore, nem desanime, pois o Senhor, o seu Deus, estará com você por onde você andar.", "Josué 1:9"],
  ["Tudo o que fizerem, façam de todo o coração, como para o Senhor, e não para os homens.", "Colossenses 3:23"],
  ["Porque sou eu que conheço os planos que tenho para vocês, planos de fazê-los prosperar e não de causar dano, planos de dar a vocês esperança e um futuro.", "Jeremias 29:11"],
  ["O Senhor é o meu pastor; de nada terei falta.", "Salmos 23:1"],
  ["Vinde a mim, todos os que estais cansados e sobrecarregados, e eu vos aliviarei.", "Mateus 11:28"],
  ["Não andem ansiosos por coisa alguma, mas em tudo, pela oração e súplicas, e com ação de graças, apresentem seus pedidos a Deus.", "Filipenses 4:6"],
  ["Mas os que esperam no Senhor renovam as suas forças. Voam alto como águias; correm e não ficam exaustos, andam e não se cansam.", "Isaías 40:31"],
  ["O exercício físico é de pouco proveito; a piedade, porém, para tudo é proveitosa.", "1 Timóteo 4:8"],
  ["Vocês não sabem que o corpo de vocês é santuário do Espírito Santo?", "1 Coríntios 6:19"],
  ["Assim, quer vocês comam, quer bebam, quer façam qualquer outra coisa, façam tudo para a glória de Deus.", "1 Coríntios 10:31"],
  ["Os planos do diligente tendem à fartura; mas a pressa excessiva, à pobreza.", "Provérbios 21:5"],
  ["Honre o Senhor com todos os seus recursos e com os primeiros frutos de todas as suas plantações.", "Provérbios 3:9"],
  ["Vá ter com a formiga, ó preguiçoso; observe os caminhos dela e seja sábio!", "Provérbios 6:6"],
  ["Nenhuma disciplina parece ser motivo de alegria no momento, mas sim de tristeza. Mais tarde, porém, produz fruto de justiça e paz.", "Hebreus 12:11"],
  ["Esqueço-me das coisas que ficaram para trás e avanço para as que estão adiante, prossigo para o alvo.", "Filipenses 3:13-14"],
  ["Não se amoldem ao padrão deste mundo, mas transformem-se pela renovação da sua mente.", "Romanos 12:2"],
  ["Sabemos que Deus age em todas as coisas para o bem daqueles que o amam.", "Romanos 8:28"],
  ["O choro pode durar uma noite, mas a alegria vem pela manhã.", "Salmos 30:5"],
  ["Pois Deus não nos deu espírito de covardia, mas de poder, de amor e de equilíbrio.", "2 Timóteo 1:7"],
  ["Confie no Senhor de todo o seu coração e não se apoie em seu próprio entendimento.", "Provérbios 3:5"],
  ["Ensina-nos a contar os nossos dias para que o nosso coração alcance sabedoria.", "Salmos 90:12"],
  ["Sejam praticantes da palavra, e não apenas ouvintes, enganando-se a si mesmos.", "Tiago 1:22"],
  ["Melhor é o pouco com o temor do Senhor do que um grande tesouro acompanhado de inquietação.", "Provérbios 15:16"],
  ["Não nos cansemos de fazer o bem, pois no tempo próprio colheremos, se não desanimarmos.", "Gálatas 6:9"],
  ["Deleite-se no Senhor, e ele atenderá aos desejos do seu coração.", "Salmos 37:4"],
  ["O Filho do homem não veio para ser servido, mas para servir.", "Marcos 10:45"],
  ["Sirvam uns aos outros mediante o amor.", "Gálatas 5:13"],
  ["Combati o bom combate, terminei a corrida, guardei a fé.", "2 Timóteo 4:7"],
];

const FIN_TIPS = [
  "“Os planos do diligente tendem à fartura.” (Pv 21:5) — Anote cada gasto: o que é medido pode ser melhorado.",
  "Pague-se primeiro: assim que o salário cair, separe a sua meta de economia antes de gastar.",
  "Regra 50/30/20: 50% necessidades, 30% desejos, 20% para guardar e investir. Ajuste à sua realidade.",
  "“O que toma emprestado é servo do que empresta.” (Pv 22:7) — Fuja de juros de cartão e cheque especial.",
  "Antes de comprar algo que não precisa, espere 48 horas. A vontade costuma passar.",
  "Monte uma reserva de emergência de 3 a 6 meses de custo de vida. Ela traz paz.",
  "Fidelidade no pouco: “Quem é fiel no pouco também é fiel no muito.” (Lc 16:10)",
  "Revise suas contas fixas: assinaturas que você não usa são vazamentos silenciosos.",
  "Generosidade também é mordomia: “Deus ama quem dá com alegria.” (2Co 9:7)",
  "Cozinhar em casa é ao mesmo tempo economia e saúde. Dois coelhos, uma panela.",
  "“Há tesouro desejável e azeite na casa do sábio, mas o tolo o desperdiça.” (Pv 21:20)",
  "Pequenos gastos diários somam muito: R$ 15 por dia são R$ 450 por mês.",
  "Defina um propósito para o dinheiro guardado: objetivo com nome é mais fácil de cumprir.",
  "Contentamento é riqueza: “Grande fonte de lucro é a piedade com o contentamento.” (1Tm 6:6)",
];

const MOTIVATION = {
  zero: ["Um passo de cada vez. Comece pelo mais simples.", "Hoje é um novo dia. As misericórdias do Senhor se renovam cada manhã.", "Disciplina é escolher o que você quer mais em vez do que quer agora."],
  some: ["Bom começo! Continue firme.", "Você está construindo quem quer ser.", "Constância vence talento. Siga em frente!"],
  most: ["Quase lá! Termine forte.", "Mais um pouco e o dia está vencido!", "Você está sendo fiel. Continue!"],
  all: ["Dia completo! “Muito bem, servo bom e fiel.” 🙌", "Missão cumprida! Descanse em paz, você honrou o dia.", "100%! Glória a Deus por mais um dia vencido."],
};

// Livros da Bíblia com número de capítulos (total 1189)
const BIBLE = [
  ["Gênesis",50],["Êxodo",40],["Levítico",27],["Números",36],["Deuteronômio",34],["Josué",24],["Juízes",21],["Rute",4],
  ["1 Samuel",31],["2 Samuel",24],["1 Reis",22],["2 Reis",25],["1 Crônicas",29],["2 Crônicas",36],["Esdras",10],["Neemias",13],
  ["Ester",10],["Jó",42],["Salmos",150],["Provérbios",31],["Eclesiastes",12],["Cantares",8],["Isaías",66],["Jeremias",52],
  ["Lamentações",5],["Ezequiel",48],["Daniel",12],["Oseias",14],["Joel",3],["Amós",9],["Obadias",1],["Jonas",4],["Miqueias",7],
  ["Naum",3],["Habacuque",3],["Sofonias",3],["Ageu",2],["Zacarias",14],["Malaquias",4],
  ["Mateus",28],["Marcos",16],["Lucas",24],["João",21],["Atos",28],["Romanos",16],["1 Coríntios",16],["2 Coríntios",13],
  ["Gálatas",6],["Efésios",6],["Filipenses",4],["Colossenses",4],["1 Tessalonicenses",5],["2 Tessalonicenses",3],["1 Timóteo",6],
  ["2 Timóteo",4],["Tito",3],["Filemom",1],["Hebreus",13],["Tiago",5],["1 Pedro",5],["2 Pedro",3],["1 João",5],["2 João",1],
  ["3 João",1],["Judas",1],["Apocalipse",22],
];

// Pilares (atributos do personagem)
const PILLARS = {
  fe:     { name: "Fé",        icon: "✝️", color: "#f4c95d" },
  corpo:  { name: "Força",     icon: "💪", color: "#ff7a59" },
  saude:  { name: "Saúde",     icon: "🥗", color: "#5fd38d" },
  mente:  { name: "Sabedoria", icon: "📚", color: "#6aa7ff" },
  foco:   { name: "Foco",      icon: "🎯", color: "#b18cff" },
  fin:    { name: "Mordomia",  icon: "💰", color: "#3fd0c9" },
};

// Missões diárias padrão. auto = marcada automaticamente pelo app.
const DEFAULT_MISSIONS = [
  { id: "fe_oracao",   p: "fe",    xp: 10, name: "Oração da manhã",               hint: "Comece o dia falando com Deus" },
  { id: "fe_biblia",   p: "fe",    xp: 15, name: "Ler a Bíblia",                  hint: "Pelo menos 1 capítulo", auto: "bible" },
  { id: "fe_servir",   p: "fe",    xp: 15, name: "Servir alguém",                 hint: "Um ato de bondade ou ajuda, como Jesus" },
  { id: "fe_gratidao", p: "fe",    xp: 5,  name: "Escrever gratidão",             hint: "No diário abaixo", auto: "gratitude" },
  { id: "corpo_treino",p: "corpo", xp: 20, name: "Treinar / academia",            hint: "Corpo é templo do Espírito" },
  { id: "corpo_sono",  p: "corpo", xp: 10, name: "Dormir 7h ou mais",             hint: "Descanso também é disciplina" },
  { id: "saude_agua",  p: "saude", xp: 10, name: "Beber 8 copos de água",         hint: "Use o contador de água", auto: "water" },
  { id: "saude_limpo", p: "saude", xp: 15, name: "Comer limpo o dia todo",        hint: "Sem fast food, refrigerante ou doce em excesso" },
  { id: "saude_verde", p: "saude", xp: 5,  name: "Comer fruta e verdura",         hint: "Cor no prato" },
  { id: "mente_estudo",p: "mente", xp: 15, name: "Estudar 30 minutos",            hint: "Invista em você" },
  { id: "mente_leitura",p:"mente", xp: 10, name: "Ler 10 páginas de um livro",    hint: "Líderes são leitores" },
  { id: "foco_plano",  p: "foco",  xp: 5,  name: "Planejar o dia",                hint: "Escreva as 3 prioridades do dia" },
  { id: "foco_bloco",  p: "foco",  xp: 15, name: "Bloco de foco (25 min)",        hint: "Use o timer abaixo, sem celular", auto: "focus" },
  { id: "fin_registro",p: "fin",   xp: 10, name: "Registrar os gastos do dia",    hint: "Ou marque se não gastou nada", auto: "expense" },
  { id: "fin_superfluo",p:"fin",   xp: 10, name: "Nenhum gasto supérfluo",        hint: "Só o necessário hoje" },
];

// Títulos por nível
const TITLES = [
  [1, "Discípulo Iniciante"], [3, "Aprendiz Fiel"], [5, "Servo Dedicado"], [8, "Guerreiro da Fé"],
  [12, "Atleta de Cristo"], [16, "Mordomo Sábio"], [20, "Soldado de Cristo"], [25, "Mestre da Disciplina"],
  [32, "Coluna da Igreja"], [40, "Vencedor em Cristo"], [50, "Lenda da Fidelidade"],
];

const EXPENSE_CATS = [
  { id: "alimentacao", name: "Alimentação", icon: "🍽️" },
  { id: "mercado",     name: "Mercado",     icon: "🛒" },
  { id: "transporte",  name: "Transporte",  icon: "🚗" },
  { id: "casa",        name: "Casa",        icon: "🏠" },
  { id: "saude",       name: "Saúde",       icon: "💊" },
  { id: "lazer",       name: "Lazer",       icon: "🎉" },
  { id: "compras",     name: "Compras",     icon: "🛍️" },
  { id: "educacao",    name: "Educação",    icon: "🎓" },
  { id: "oferta",      name: "Dízimo/Oferta", icon: "⛪" },
  { id: "outros",      name: "Outros",      icon: "📦" },
];
