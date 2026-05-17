# Project Context — Sistema de Gestão de Bolsa de Valores

**Projeto:** Stock Exchange Database — Relational Model
**Autor:** Fernando Garbo
**SGBD:** PostgreSQL 13+
**Deadline:** 10/05/2026 (meta interna) | 17/05/2026 (prazo oficial)
**Status atual:** Modelo Conceitual ✅ validado → Relacionamentos ✅ validados → Pronto para Modelo Lógico

---

## Objetivo

Banco de dados relacional completo para uma corretora de bolsa de valores.
Pipeline: **Conceitual → Lógico → Físico (DDL + DML + DQL)**.
Suporte simultâneo a **OLTP** (negociações em tempo real) e **OLAP** (relatórios históricos).

---

## Entidades do Modelo

| Entidade | Propósito | Chave de Negócio |
| --- | --- | --- |
| INVESTIDOR | Pessoas físicas (CPF) e jurídicas (CNPJ) | cpf_cnpj (VARCHAR 14, só dígitos) |
| EMPRESA | Empresas listadas na bolsa | cnpj (surrogate isola FKs da mudança de formato IN RFB 2.229/2024) |
| ACAO | Ações emitidas por empresas | ticker (ex: PETR3, PETR4) |
| NEGOCIACAO | Registro imutável de compra/venda (M:N entre INVESTIDOR e ACAO) | — |
| COTACAO | Histórico append-only de preços por ação | — |
| SALDO_CARTEIRA | Posição consolidada por par (investidor, acao) | — |

---

## Decisões Arquiteturais Confirmadas

| Decisão | Descrição |
| --- | --- |
| Surrogate keys | Todas as entidades usam PK inteira gerada; chaves de negócio como UNIQUE |
| SCD Type 2 | INVESTIDOR, EMPRESA, ACAO — histórico via tabelas auxiliares com data_inicio / data_fim |
| Imutabilidade | NEGOCIACAO e COTACAO — apenas INSERT, nunca UPDATE/DELETE |
| CPF/CNPJ | VARCHAR(14) apenas dígitos; CHECK composto vincula tipo (PF/PJ) ao comprimento |
| CNPJ alfanumérico | IN RFB 2.229/2024 muda formato; surrogate key isola todas as FKs do impacto |
| Tipo de ação | Campo controlado: ON (Ordinária), PN (Preferencial), UNT (Units) |
| Atributos derivados | valor_total (NEGOCIACAO) e valor_atual (SALDO_CARTEIRA) — calculados em consulta, não persistidos |
| Trigger | SALDO_CARTEIRA atualizado por trigger após INSERT em NEGOCIACAO |
| UNIQUE em COTACAO | Surrogate PK (cotacao_id) + UNIQUE (acao_id, data_hora) — protege contra duplicata no mesmo instante |

---

## Decisões Pendentes (para o Modelo Lógico)

| Decisão | Contexto |
| --- | --- |
| Entidade CONTATO | Avaliar entidade separada para múltiplos telefones/emails por investidor |
| valor_mercado | Definir se é persistido em EMPRESA ou derivado (preço × ações emitidas via JOIN com COTACAO) |
| Cisão societária | Vínculo empresa_id → acao pode ser mutável; definir se FK é imutável ou permite migração |

---

## Relacionamentos (em validação)

| # | Relacionamento | Entidades | Cardinalidade | Status |
| --- | --- | --- | --- | --- |
| 1 | emite | EMPRESA → ACAO | 1:N (0..* do lado ACAO) | ✅ validado |
| 2 | realiza | INVESTIDOR → NEGOCIACAO | 1:N | ✅ validado |
| 3 | negociada_em | ACAO → NEGOCIACAO | 1:N | ✅ validado |
| 4 | possui_cotacao | ACAO → COTACAO | 1:N | ✅ validado |
| 5 | possui | INVESTIDOR → SALDO_CARTEIRA | 1:N | ✅ validado |
| 6 | registrada_em | ACAO → SALDO_CARTEIRA | 1:N | ✅ validado |

---

## Próximos Passos

1. ✅ Concluir validação dos 6 relacionamentos
2. Avançar para **Modelo Lógico** (schema 3NF + SCD Type 2)
3. Resolver decisões pendentes no modelo lógico (CONTATO, valor_mercado, cisão societária)
4. Produzir **Modelo Físico**: `sql/ddl.sql`, `sql/dml.sql`, `sql/dql.sql`
