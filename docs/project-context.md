# Project Context — Sistema de Gestão de Bolsa de Valores

**Projeto:** Stock Exchange Database — Relational Model
**Autor:** Fernando Garbo
**SGBD:** PostgreSQL 13+
**Deadline:** 10/05/2026 (meta interna) | 17/05/2026 (prazo oficial)
**Status atual:** Modelo Conceitual ✅ validado → Modelo Lógico ✅ concluído → Modelo Físico 🔄 em andamento

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
| CONTATO | Múltiplos telefones e emails por investidor | — |
| EMPRESA | Empresas listadas na bolsa | cnpj (surrogate isola FKs da mudança de formato IN RFB 2.229/2024) |
| ACAO | Ações emitidas por empresas; inclui total_acoes | ticker (ex: PETR3, PETR4) |
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
| Atributos derivados | valor_total (NEGOCIACAO), valor_atual (SALDO_CARTEIRA) e valor_mercado (EMPRESA) — calculados em consulta, não persistidos |
| Trigger | SALDO_CARTEIRA atualizado por trigger após INSERT em NEGOCIACAO |
| UNIQUE em COTACAO | Surrogate PK (cotacao_id) + UNIQUE (acao_id, data_hora) — protege contra duplicata no mesmo instante |
| Entidade CONTATO | Entidade separada para múltiplos contatos por investidor; email e telefone removidos de INVESTIDOR |
| valor_mercado derivado | Calculado como total_acoes × cotacao_atual; exposto via VIEW vw_valor_mercado no modelo físico |
| Cisão societária | SCD Type 2 em ACAO trata cisão: nova versão do registro com novo empresa_id preserva o histórico |

---

## Relacionamentos Validados

| # | Relacionamento | Entidades | Cardinalidade | Status |
| --- | --- | --- | --- | --- |
| 1 | emite | EMPRESA → ACAO | (0,n):(1,1) | ✅ validado |
| 2 | realiza | INVESTIDOR → NEGOCIACAO | (0,n):(1,1) | ✅ validado |
| 3 | negociada_em | ACAO → NEGOCIACAO | (0,n):(1,1) | ✅ validado |
| 4 | possui_cotacao | ACAO → COTACAO | (0,n):(1,1) | ✅ validado |
| 5 | possui | INVESTIDOR → SALDO_CARTEIRA | (0,n):(1,1) | ✅ validado |
| 6 | registrada_em | ACAO → SALDO_CARTEIRA | (0,n):(1,1) | ✅ validado |
| 7 | possui_contato | INVESTIDOR → CONTATO | (0,n):(1,1) | ✅ validado |

---

## Próximos Passos

1. ✅ Concluir validação dos relacionamentos (7 validados)
2. ✅ Resolver decisões pendentes (CONTATO, valor_mercado, cisão societária)
3. ✅ Produzir **Modelo Lógico** (schema 3NF + SCD Type 2) → `docs/03-logical-model.md`
4. 🔄 Produzir **Modelo Físico**: `sql/ddl.sql`, `sql/dml.sql`, `sql/dql.sql`
