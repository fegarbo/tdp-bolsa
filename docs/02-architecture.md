---
stepsCompleted: ['architecture-decisions']
inputDocuments: ['PRD.md', '01-conceptual-model.md']
workflowType: 'architecture'
project_name: 'Sistema de Gestão de Bolsa de Valores'
user_name: 'Fernando Garbo'
date: '2026-05-17'
sgbd: 'PostgreSQL 13+'
---

# Decisões Arquiteturais — Sistema de Gestão de Bolsa de Valores

**Autor:** Fernando Garbo
**Data:** 2026-05-17
**SGBD:** PostgreSQL 13+

---

## Visão Geral

Este documento registra as decisões de design que guiaram o desenvolvimento do modelo relacional para uma corretora de bolsa de valores. O schema suporta dois padrões de acesso simultâneos: **OLTP** (negociações em tempo real) e **OLAP** (análises históricas de carteira).

Cada decisão é apresentada com seu contexto, a alternativa considerada e a justificativa da escolha adotada.

---

## Decisões de Design

### 1. Surrogate Keys em todas as entidades

**Decisão:** Todas as entidades usam uma chave primária inteira gerada (`INTEGER GENERATED ALWAYS AS IDENTITY`). As chaves de negócio (CPF, CNPJ, ticker) são declaradas como `UNIQUE`, mas não são usadas como PK nem como FK.

**Alternativa considerada:** Usar a chave de negócio diretamente como PK (ex: `cpf_cnpj` como PK de INVESTIDOR).

**Justificativa:** Isola todas as relações de FK de mudanças no formato das chaves de negócio. Caso concreto: a IN RFB 2.229/2024 introduz CNPJ alfanumérico — com surrogate key, nenhuma FK em NEGOCIACAO, ACAO ou outras tabelas precisa ser alterada.

---

### 2. SCD Type 2 para dados mestres

**Decisão:** INVESTIDOR, EMPRESA e ACAO possuem tabelas auxiliares de histórico (`_historico`) com colunas `data_inicio` e `data_fim`. A tabela principal sempre contém a versão atual.

**Alternativa considerada:** Adicionar coluna `versao` ou `valido_ate` diretamente na tabela principal; ou usar uma única tabela com flag `ativo`.

**Justificativa:** O SCD Type 2 permite consultas point-in-time precisas ("qual era o setor da empresa X em tal data?") sem ambiguidade. A separação em tabela auxiliar mantém a tabela principal enxuta e o acesso OLTP rápido. O protocolo de atualização é atômico: INSERT no histórico seguido de UPDATE na tabela principal, dentro de uma transação.

**Protocolo:**

```sql
1. INSERT INTO <entidade>_historico
       SELECT ..., data_cadastro AS data_inicio, CURRENT_TIMESTAMP AS data_fim
       FROM <entidade> WHERE <entidade>_id = :id

2. UPDATE <entidade>
       SET <colunas alteradas>, data_atualizacao = CURRENT_TIMESTAMP
       WHERE <entidade>_id = :id
```

---

### 3. Imutabilidade de NEGOCIACAO e COTACAO

**Decisão:** As tabelas NEGOCIACAO e COTACAO aceitam apenas INSERT. Não há UPDATE nem DELETE.

**Alternativa considerada:** Permitir cancelamento/estorno via UPDATE com flag de status.

**Justificativa:** Registros imutáveis garantem trilha de auditoria completa — requisito regulatório em mercados financeiros. Um cancelamento, se necessário, é modelado como uma nova negociação com sinal inverso (estorno), não como modificação do registro original.

---

### 4. CPF e CNPJ em um único campo VARCHAR(14)

**Decisão:** O campo `cpf_cnpj` em INVESTIDOR armazena apenas dígitos (sem formatação) em um `VARCHAR(14)`. A constraint `CHECK` composta vincula o comprimento ao tipo do investidor:

```sql
CHECK (
    (tipo = 'PF' AND LENGTH(cpf_cnpj) = 11) OR
    (tipo = 'PJ' AND LENGTH(cpf_cnpj) = 14)
)
```

**Alternativa considerada:** Campos separados `cpf` e `cnpj`, ou um campo `VARCHAR(18)` com máscara de formatação.

**Justificativa:** Um único campo com dígitos simpifica consultas, indexação e integração com sistemas externos. A constraint garante coerência sem lógica de aplicação. Tamanho 14 acomoda tanto CPF (11) quanto CNPJ (14 dígitos).

---

### 5. CNPJ alfanumérico — surrogate key isola o impacto

**Decisão:** EMPRESA usa `empresa_id` (surrogate) como PK; o campo `cnpj VARCHAR(14)` é UNIQUE mas não é FK em nenhuma tabela.

**Contexto:** A Instrução Normativa RFB 2.229/2024 introduz CNPJ alfanumérico a partir de julho de 2026, alterando o formato para incluir letras além de dígitos.

**Justificativa:** Se `cnpj` fosse usado como FK em ACAO, NEGOCIACAO ou outra tabela, a migração para o novo formato exigiria atualização em cascata em múltiplas tabelas. Com surrogate key, apenas a coluna `cnpj` de EMPRESA precisa ser ajustada.

---

### 6. BIGINT para total_acoes

**Decisão:** A coluna `total_acoes` em ACAO e ACAO_HISTORICO usa o tipo `BIGINT`.

**Justificativa:** O limite de `INTEGER` no PostgreSQL é aproximadamente 2,1 bilhões. Grandes emissores da B3 superam esse valor: Petrobras PETR3 possui ~13 bilhões de ações ordinárias. `BIGINT` suporta até ~9,2 quintilhões, cobrindo qualquer emissão realista.

---

### 7. VARCHAR + CHECK em vez de ENUM

**Decisão:** Campos com domínio controlado (tipo_operacao, tipo de ação, tipo de contato) usam `VARCHAR(n)` com `CHECK IN (...)` em vez de tipos `ENUM` do PostgreSQL.

**Alternativa considerada:** `CREATE TYPE tipo_operacao AS ENUM ('C', 'V')`.

**Justificativa:** `ENUM` no PostgreSQL requer `ALTER TYPE` para adicionar novos valores — operação que pode ser bloqueante em tabelas grandes e não pode ser revertida em transações DDL. O padrão `VARCHAR + CHECK` é equivalente em integridade e significativamente mais simples de evoluir.

---

### 8. NUMERIC(15,2) para valores financeiros

**Decisão:** Colunas de valor monetário (`valor_unitario` em NEGOCIACAO e `valor` em COTACAO) usam `NUMERIC(15,2)`.

**Alternativa considerada:** `FLOAT` ou `DOUBLE PRECISION`.

**Justificativa:** Tipos de ponto flutuante introduzem erros de arredondamento binário — inaceitável em contexto financeiro. `NUMERIC` usa aritmética decimal exata. A precisão de 15 dígitos totais com 2 casas decimais suporta valores até R$ 9.999.999.999.999,99 — suficiente para qualquer ativo negociado.

---

### 9. Trigger para manutenção automática de SALDO_CARTEIRA

**Decisão:** A função `fn_atualiza_saldo_carteira()` é executada via trigger `AFTER INSERT ON negociacao FOR EACH ROW`.

**Lógica:**
- **Compra (C):** `INSERT ... ON CONFLICT DO UPDATE` (UPSERT) cria ou incrementa a posição.
- **Venda (V):** verifica se o saldo é suficiente; se não for, lança `RAISE EXCEPTION` (que reverte toda a transação, incluindo o INSERT em NEGOCIACAO); se for, decrementa.

**Alternativa considerada:** Calcular o saldo sempre via `SUM(negociacoes)` em consulta, sem tabela de saldo.

**Justificativa:** A tabela SALDO_CARTEIRA materializa a posição consolidada, tornando a leitura da carteira um acesso direto (O(1) por par investidor/ação) em vez de um agregado sobre toda a tabela de negociações. O trigger garante consistência automática — a aplicação não precisa manter o saldo manualmente.

---

### 10. ON DELETE RESTRICT explícito em todas as FKs

**Decisão:** Todas as 10 FKs declaram `ON DELETE RESTRICT` explicitamente.

**Alternativa considerada:** Omitir a cláusula (PostgreSQL usa RESTRICT como padrão) ou usar `ON DELETE CASCADE`.

**Justificativa:** A declaração explícita documenta a intenção — registros dependentes nunca são deletados silenciosamente. Cascade seria perigoso em contexto financeiro: deletar um investidor não deve remover seu histórico de negociações.

---

### 11. VIEW vw_valor_mercado para capitalização de mercado

**Decisão:** `valor_mercado` (total_acoes × cotação mais recente) não é armazenado. É calculado pela VIEW `vw_valor_mercado` sob demanda.

**Alternativa considerada:** Coluna `valor_mercado` materializada em EMPRESA, atualizada por trigger após cada INSERT em COTACAO.

**Justificativa:** `valor_mercado` é um atributo derivado — persistir viola a 3FN e cria risco de inconsistência entre `total_acoes`, `cotacao.valor` e o valor materializado. A VIEW recalcula sempre com os dados mais recentes. Para performance em alta frequência, uma VIEW materializada pode ser adotada futuramente sem alterar o schema.

---

### 12. Entidade CONTATO separada

**Decisão:** Dados de contato (telefone, email, WhatsApp) são uma entidade própria com os tipos controlados `TEL`, `EML`, `WHT`.

**Alternativa considerada:** Colunas `telefone` e `email` diretamente em INVESTIDOR.

**Justificativa:** Colunas fixas limitam a quantidade de contatos e criam valores nulos quando o investidor não possui um tipo específico. A entidade CONTATO suporta N contatos de qualquer tipo sem colunas nulas, com UNIQUE composta `(investidor_id, tipo, valor)` prevenindo duplicatas.

---

### 13. Índices de suporte às consultas analíticas

**Decisão:** 7 índices criados além dos implícitos nas constraints UNIQUE e PK:

| Índice | Tabela | Colunas | Caso de uso |
| --- | --- | --- | --- |
| idx_contato_investidor | CONTATO | (investidor_id) | Busca de contatos por investidor |
| idx_negociacao_investidor | NEGOCIACAO | (investidor_id) | Extrato por investidor |
| idx_negociacao_acao | NEGOCIACAO | (acao_id) | Histórico por ação |
| idx_negociacao_data | NEGOCIACAO | (data_hora_transacao) | Consultas por período |
| idx_inv_hist_lookup | INVESTIDOR_HISTORICO | (investidor_id, data_fim) | Queries point-in-time |
| idx_emp_hist_lookup | EMPRESA_HISTORICO | (empresa_id, data_fim) | Queries point-in-time |
| idx_acao_hist_lookup | ACAO_HISTORICO | (acao_id, data_fim) | Queries point-in-time |

Os índices nas tabelas de histórico usam `data_fim` como segunda coluna porque as queries point-in-time filtram por `data_fim > :target_date`.

---

## Resumo das Decisões

| Decisão | Padrão Adotado | Motivação Principal |
| --- | --- | --- |
| Identificadores | Surrogate keys (IDENTITY) | Isolamento de mudanças em chaves de negócio |
| Histórico de dados mestres | SCD Type 2 | Consultas point-in-time e auditoria |
| Operações financeiras | Imutabilidade (append-only) | Trilha de auditoria regulatória |
| Documento CPF/CNPJ | VARCHAR(14) + CHECK composto | Simplicidade e coerência por tipo |
| Domínios controlados | VARCHAR + CHECK IN | Extensibilidade sem ALTER TYPE |
| Valores monetários | NUMERIC(15,2) | Aritmética decimal exata |
| Saldo de carteira | Tabela materializada por trigger | Leitura O(1) por par investidor/ação |
| Exclusão em cascata | RESTRICT explícito | Proteção de histórico financeiro |
| Capitalização de mercado | VIEW derivada | 3FN e dados sempre atualizados |
| Contatos | Entidade separada | Múltiplos contatos sem colunas nulas |

---

**Status:** ✅ DECISÕES ARQUITETURAIS DOCUMENTADAS
