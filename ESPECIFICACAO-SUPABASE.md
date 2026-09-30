# Especificação: ligar as telas ao Supabase

Substituir os dados de exemplo por dados reais. O esquema já está aplicado
(migrações 0001, 0002 e 0003) e a autenticação é por **e-mail e palavra-passe**.

Aplicam-se as convenções do `CLAUDE.md`: português, feita-first, nenhuma cor
ou dimensão nos ecrãs, regras nos controladores.

---

## 1. Regras que atravessam tudo

- **Nenhum widget chama o Supabase directamente.** A cadeia é sempre
  ecrã → controlador (Riverpod) → repositório → cliente Supabase.
- **Todo o ecrã que lê dados tem três estados**: a carregar, com erro (com
  botão de tentar de novo) e vazio. Nada de ecrã em branco enquanto espera.
- **Nada de `valorInicial` fixo nos campos.** Todos os formulários passam a ter
  `TextEditingController` e a ler o que o utilizador escreve.
- **Erros do servidor chegam ao ecrã traduzidos.** Um `AuthException` ou
  `PostgrestException` nunca aparece cru ao utilizador.
- **A app nunca escreve em**: `assinaturas`, `pagamentos`, `configuracoes`,
  `categorias`, `servicos`, `zonas`, `planos`, nem nas colunas de estatística
  de `prestadores`. Isso é do servidor ou do administrador.

## 2. Estrutura a criar

```
lib/nucleo/dados/cliente_supabase.dart      // acesso ao SupabaseClient
lib/nucleo/dados/excepcoes.dart             // tradução de erros
lib/funcionalidades/<nome>/dados/
    modelos/…_modelo.dart                   // fromJson / toJson
    repositorios/…_repositorio.dart
```

Cada repositório é exposto por um `Provider` e recebe o cliente por injecção,
para poder ser trocado em testes.

## 3. Autenticação (telas 01–03)

### Registo

```dart
await cliente.auth.signUp(
  email: email,
  password: palavraPasse,
  data: {
    'nome': nome,
    'telefone': telefone,     // só dígitos; o gatilho normaliza
    'municipio': municipio,
    'zona_id': zonaId,        // o id ('fomento'), não o nome ('Fomento')
  },
);
```

O perfil em `perfis` é criado pelo gatilho `trg_criar_perfil`, na mesma
transacção. **Não inserir em `perfis` a partir da app.**

O gatilho rejeita nome com menos de 5 caracteres e telefone fora de
`8[2-7]` + 7 dígitos, e nesse caso o registo inteiro é revertido. Essas
mensagens têm de ser mostradas no campo respectivo.

### Alterações necessárias aos ecrãs

**Tela 02 (Entrar):** remover o segmentado Telefone/Email. Com autenticação por
e-mail, a entrada por telefone não funciona, e deixar o separador lá é prometer
uma coisa que falha. O telefone continua a existir como campo do perfil.

**Tela 03 (Cadastro):** o `CaixaSeleccao` de município e bairro passa a ler as
`zonas` da base e a guardar o `id`, não o rótulo. Filtrar os bairros pelo
município escolhido.

"Recuperar senha" passa a `resetPasswordForEmail`, ou esconde-se enquanto não
estiver implementado. Hoje mostra um aviso de um SMS que nunca é enviado.

### Sessão

`Supabase.instance.client.auth.onAuthStateChange` alimenta um
`sessaoProvider`. O ecrã inicial passa a ser decidido por ele:

- sem sessão → boas-vindas
- com sessão e sem registo de prestador → painel do cliente
- com sessão e prestador `pendente` → ecrã de aguardo de aprovação
- com sessão e prestador `aprovado` → painel do prestador

Isto substitui o `home:` fixo no `main.dart`.

## 4. Catálogo e zonas

Só leitura, e já estão preenchidos. É por aqui que se deve começar, porque não
depende de nada e valida a ligação.

Tabelas: `categorias`, `servicos`, `zonas`. Carregar uma vez por sessão e
guardar em memória; são poucas linhas e não mudam durante o uso.

## 5. Cadastro do prestador

Insere em `prestadores` (o `perfil_id` é `auth.uid()`), em `prestador_zonas` e
carrega os documentos para o Storage.

Criar dois buckets:

- `documentos` — **privado**. BI e comprovativos. Caminho
  `{perfil_id}/{tipo}.jpg`.
- `publico` — leitura pública. Fotos de perfil, capa e portefólio.

Política do bucket privado: só o dono escreve e lê o seu prefixo.

Comprimir as imagens antes do envio (`flutter_image_compress`), com largura
máxima de 1600 px. A câmara devolve ficheiros de vários MB e os dados móveis
aqui são caros.

O campo `estado` fica `pendente` e a app não o altera: a aprovação é feita no
painel do Supabase.

## 6. Preços (tela 13)

`precos_prestador`, com `upsert` por serviço à medida que o utilizador edita.
`valor` nulo é válido e significa "sob orçamento".

Serviços fora do catálogo vão para `servicos_proprios`, máximo de 3, imposto
por gatilho: apanhar a excepção e mostrar a mensagem de limite.

## 7. Procura e perfil do prestador (telas 04–06)

A lista lê `prestadores` com `perfis`, `precos_prestador` e as estatísticas já
calculadas (`avaliacao_media`, `total_avaliacoes`, `servicos_feitos`,
`pct_recomenda`). Não calcular médias na app: vêm prontas da base.

A RLS já esconde prestadores sem assinatura válida, portanto **não filtrar
visibilidade na app**; se o fizeres nos dois sítios, um dia divergem.

Ordenar por reputação, nunca por preço mais baixo.

Distância: o filtro "até X km" usa `distancia_km` no servidor. Enquanto não
houver mapa, filtrar por `zona_id` e esconder o filtro de distância.

Favoritos: tabela `favoritos`.

## 8. Solicitação directa (telas 07, 08, 14)

Cliente insere em `pedidos`. Anexos vão para `anexos` mais o Storage.

O prestador aceita chamando a função do servidor:

```dart
await cliente.rpc('aceitar_pedido', params: {
  'p_pedido': pedidoId,
  'p_valor': valorAcordado,   // pode ser nulo
});
```

Isso cria a linha em `trabalhos`. **Não inserir em `trabalhos` a partir da
app.** Rejeitar é um `update` do estado para `rejeitado`.

O contacto do cliente só fica legível depois de existir o trabalho: antes
disso, a consulta a `perfis` devolve vazio por RLS, e o ecrã tem de tratar isso
como estado normal e não como erro.

## 9. Concursos (telas 16–20)

Cliente insere em `concursos` com `fecha_em = now() + 48h`.

A faixa de referência de preços vem de `vw_referencia_precos` por serviço e
município; se não vier linha, não mostrar faixa nenhuma. Com dois prestadores
na app, inventar um intervalo seria enganar o cliente.

Prestador insere em `propostas`, com `tipo` `aceita_orcamento` ou
`contraproposta`. A contraproposta exige justificação com pelo menos 15
caracteres, imposto por restrição: validar também no formulário, para o
utilizador não levar um erro do servidor.

O cliente escolhe chamando:

```dart
await cliente.rpc('adjudicar_concurso', params: {'p_proposta': propostaId});
```

Isso fecha as outras propostas e cria o trabalho, numa só transacção.

## 10. Trabalhos e avaliações (tela 09)

Concluir um trabalho é um `update` de `trabalhos.estado` para `concluido`, e
**só o cliente o pode fazer**. A RLS impede o prestador.

A avaliação insere em `avaliacoes` com `trabalho_id`, `estrelas`, `comentario`
e `recomenda`. A base só aceita se o trabalho estiver concluído e pertencer a
quem avalia. Uma avaliação por trabalho.

A média e a percentagem de recomendação actualizam-se sozinhas por gatilho: a
app só tem de reler o perfil.

## 11. Assinatura (tela 15)

Leitura apenas: `planos`, `assinaturas` do próprio, `pagamentos` do próprio, e
a vista `vw_estado_gratuito`, que dá dias restantes, trabalhos restantes e
trabalhos feitos.

O plano gratuito acaba aos 30 dias ou aos 3 trabalhos concluídos, o que vier
primeiro, e esses dois números vêm de `configuracoes`, não do código.

A confirmação de pagamento fica por ligar; manter o botão a simular, com o
`TODO` que já lá está.

## 12. Ordem de execução

Uma de cada vez, com `flutter analyze` e commit entre elas:

1. Cliente Supabase, tradução de erros, `sessaoProvider` e encaminhamento
   inicial.
2. Registo e entrada (telas 01–03).
3. Catálogo e zonas.
4. Cadastro do prestador e Storage.
5. Preços.
6. Procura e perfil do prestador.
7. Solicitação directa.
8. Concursos e propostas.
9. Trabalhos e avaliações.
10. Assinatura (leitura).

Os dados de exemplo saem à medida que cada passo fica ligado, não todos de uma
vez: enquanto uma funcionalidade não estiver ligada, continua a usar
`dados_exemplo.dart`.

## 13. Aceitação

1. Criar conta pela app faz aparecer a linha em `perfis`, com nome e telefone.
2. Nome com 3 letras é rejeitado com mensagem no campo, e não fica conta órfã
   em `auth.users`.
3. Fechar e reabrir a app mantém a sessão e leva ao ecrã certo.
4. O bairro guardado é o `id`, não o rótulo.
5. Um prestador `pendente` não aparece na procura feita por outra conta.
6. Um prestador aprovado aparece, com o preço e a avaliação vindos da base.
7. Antes de aceitar, o prestador não vê o telefone do cliente em lado nenhum.
8. Depois de `aceitar_pedido`, o contacto aparece e existe linha em
   `trabalhos`.
9. Avaliar um trabalho não concluído é recusado pelo servidor.
10. Com a rede desligada, cada ecrã mostra erro com "tentar de novo" e não
    fica em branco.
