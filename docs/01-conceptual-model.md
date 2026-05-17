# Modelo Conceitual - Sistema de Gestão de Bolsa de Valores

**Data:** 2026-04-21
**Versão:** 1.2
**Status:** Validado

---

## Resumo Executivo

O modelo conceitual define as entidades de negócio e seus relacionamentos para um sistema de gestão de bolsa de valores. A estrutura suporta:

- **OLTP:** Negociações em tempo real
- **OLAP:** Relatórios e análises históricas
- **Integridade Referencial:** Relacionamentos fortes entre entidades

> **Nota de Design:** A necessidade de rastrear histórico de mudanças em dados mestres (Investidores, Empresas, Ações) é um requisito de negócio. O mecanismo de implementação desse histórico (padrão SCD Type 2) é uma decisão de design registrada no Modelo Lógico.

---

## Diagrama ER (Entidade-Relacionamento)

```mermaid
erDiagram
    INVESTIDOR ||--o{ NEGOCIACAO : realiza
    INVESTIDOR ||--o{ SALDO_CARTEIRA : possui

    EMPRESA ||--o{ ACAO : emite

    ACAO ||--o{ NEGOCIACAO : negociada_em
    ACAO ||--o{ COTACAO : possui_cotacao
    ACAO ||--o{ SALDO_CARTEIRA : registrada_em

    INVESTIDOR {
        int  investidor_id PK
        string cpf_cnpj UK
        string nome
        string tipo
        string email
        string telefone
    }

    EMPRESA {
        int    empresa_id PK
        string cnpj UK
        string nome
        string setor
        decimal valor_mercado
    }

    ACAO {
        int    acao_id PK
        string ticker UK
        string tipo
    }

    NEGOCIACAO {
        int     negociacao_id PK
        string  tipo_operacao
        int     quantidade
        decimal valor_unitario
        timestamp data_hora_transacao
    }

    COTACAO {
        int     cotacao_id PK
        decimal valor
        timestamp data_hora
    }

    SALDO_CARTEIRA {
        int saldo_id PK
        int quantidade
        timestamp data_atualizacao
    }
```

---

## Entidades Detalhadas

### 1. INVESTIDOR

**Propósito:** Armazenar informações de investidores (PF ou PJ)

| Atributo      | Tipo      | Descrição                     | Constraint              |
| ------------- | --------- | ----------------------------- | ----------------------- |
| investidor_id | Inteiro   | Identificador surrogate       | PK, gerado pelo banco   |
| cpf_cnpj      | String    | CPF (PF) ou CNPJ (PJ)         | UNIQUE, Obrigatório     |
| nome          | String    | Nome completo                 | Obrigatório             |
| tipo          | String    | PF ou PJ                      | Obrigatório             |
| email         | String    | Email de contato              | Obrigatório             |
| telefone      | String    | Telefone de contato           | Opcional                |

**Requisito de negócio:** Mudanças nos dados do investidor devem ser rastreadas com histórico completo.

---

### 2. EMPRESA

**Propósito:** Armazenar informações de empresas listadas na bolsa

| Atributo      | Tipo    | Descrição                      | Constraint            |
| ------------- | ------- | ------------------------------ | --------------------- |
| empresa_id    | Inteiro | Identificador surrogate        | PK, gerado pelo banco |
| cnpj          | String  | CNPJ da empresa                | UNIQUE, Obrigatório   |
| nome          | String  | Nome da empresa                | Obrigatório           |
| setor         | String  | Setor de atuação               | Obrigatório           |
| valor_mercado | Decimal | Valor de mercado (Market Cap)  | Opcional              |

**Requisito de negócio:** Mudanças nos dados da empresa devem ser rastreadas com histórico completo.

---

### 3. ACAO

**Propósito:** Armazenar ações emitidas por empresas, identificadas pelo ticker

| Atributo | Tipo    | Descrição                       | Constraint            |
| -------- | ------- | ------------------------------- | --------------------- |
| acao_id  | Inteiro | Identificador surrogate         | PK, gerado pelo banco |
| ticker   | String  | Código de negociação na bolsa   | UNIQUE, Obrigatório   |
| tipo     | String  | Tipo da ação: ON, PN ou UNT     | Obrigatório           |

**Requisito de negócio:** Mudanças nas características de uma ação devem ser rastreadas com histórico completo.

---

### 4. NEGOCIACAO

**Propósito:** Registrar todas as operações de compra e venda — entidade associativa entre INVESTIDOR e ACAO

| Atributo            | Tipo      | Descrição                         | Constraint            |
| ------------------- | --------- | --------------------------------- | --------------------- |
| negociacao_id       | Inteiro   | Identificador surrogate           | PK, gerado pelo banco |
| tipo_operacao       | String    | Compra (C) ou Venda (V)           | Obrigatório           |
| quantidade          | Inteiro   | Quantidade de ações               | Obrigatório, positivo |
| valor_unitario      | Decimal   | Preço por ação no momento         | Obrigatório, positivo |
| data_hora_transacao | Timestamp | Data e hora exata da negociação   | Obrigatório           |

> `valor_total` é atributo **derivado** (quantidade × valor_unitario) — não armazenado, calculado nas consultas.

**Regra de negócio:** Registros são imutáveis — apenas INSERT, nunca UPDATE ou DELETE.

---

### 5. COTACAO

**Propósito:** Manter histórico de preços das ações ao longo do tempo

| Atributo   | Tipo      | Descrição                    | Constraint            |
| ---------- | --------- | ---------------------------- | --------------------- |
| cotacao_id | Inteiro   | Identificador surrogate      | PK, gerado pelo banco |
| valor      | Decimal   | Preço da ação no momento     | Obrigatório, positivo |
| data_hora  | Timestamp | Data e hora da cotação       | Obrigatório           |

**Regra de negócio:** Append-only — apenas inserções, nunca atualizações ou remoções.

---

### 6. SALDO_CARTEIRA

**Propósito:** Registrar a posição atual de cada investidor por ação

| Atributo         | Tipo      | Descrição                          | Constraint                |
| ---------------- | --------- | ---------------------------------- | ------------------------- |
| saldo_id         | Inteiro   | Identificador surrogate            | PK, gerado pelo banco     |
| quantidade       | Inteiro   | Quantidade de ações em posição     | Obrigatório, não negativo |
| data_atualizacao | Timestamp | Data da última atualização         | Obrigatório               |

> `valor_atual` é atributo **derivado** (quantidade × cotação atual) — calculado sob demanda via JOIN com COTACAO.

**Regras de negócio:**
- Unicidade: um único registro por par `(investidor_id, acao_id)`
- Quantidade pode ser 0 — registro mantido para preservar histórico da posição
- Atualizado via **trigger** após cada INSERT em NEGOCIACAO

---

## Relacionamentos

| Relacionamento | Entidades | Cardinalidade | Descrição |
| --- | --- | --- | --- |
| emite | EMPRESA → ACAO | 1:N | Uma empresa pode ter zero ou mais ações (ex: pré-IPO ou ação retirada da bolsa) |
| realiza | INVESTIDOR → NEGOCIACAO | 1:N | Um investidor pode ter zero ou mais negociações; toda negociação pertence obrigatoriamente a um investidor |
| negociada_em | ACAO → NEGOCIACAO | 1:N | Uma ação pode ter zero ou mais negociações; toda negociação pertence obrigatoriamente a uma ação |
| possui_cotacao | ACAO → COTACAO | 1:N | Uma ação pode ter zero ou mais cotações; toda cotação pertence obrigatoriamente a uma ação |
| possui | INVESTIDOR → SALDO_CARTEIRA | 1:N | Um investidor pode ter zero ou mais registros de saldo; todo saldo pertence obrigatoriamente a um investidor |
| registrada_em | ACAO → SALDO_CARTEIRA | 1:N | Uma ação pode ter zero ou mais registros de saldo; todo saldo pertence obrigatoriamente a uma ação |

---

## Decisões de Design (para o Modelo Lógico)

| Decisão | Entidades afetadas | Descrição |
| --- | --- | --- |
| Surrogate keys | Todas | Todas as entidades usam surrogate PK (inteiro gerado); chaves de negócio como UNIQUE |
| SCD Type 2 | INVESTIDOR, EMPRESA, ACAO | Rastreamento de histórico via tabelas auxiliares com `data_inicio` e `data_fim` |
| Imutabilidade | NEGOCIACAO, COTACAO | Apenas INSERT — garantia de trilha de auditoria |
| Chave mista CPF/CNPJ | INVESTIDOR | Armazenar apenas dígitos (VARCHAR(14)); CHECK composto vinculando `tipo` ao comprimento |
| CNPJ alfanumérico | EMPRESA | IN RFB 2.229/2024 muda formato do CNPJ — surrogate key isola FKs do impacto |
| Tipo de ação | ACAO | Campo `tipo` controlado: ON (Ordinária), PN (Preferencial), UNT (Units) |
| Atributos derivados | NEGOCIACAO, SALDO_CARTEIRA | `valor_total` e `valor_atual` calculados nas consultas, não persistidos |
| Trigger | SALDO_CARTEIRA | Saldo atualizado via trigger após INSERT em NEGOCIACAO |
| Entidade CONTATO | INVESTIDOR | Avaliar entidade separada para múltiplos telefones e emails por investidor |
| valor_mercado | EMPRESA | Definir no modelo lógico: persistido ou derivado (preço x ações emitidas) |
| UNIQUE em COTACAO | COTACAO | Surrogate PK (cotacao_id) + UNIQUE (acao_id, data_hora) para evitar duas cotações no mesmo instante |
| Cisão societária | ACAO, EMPRESA | Vínculo empresa_id → acao pode ser mutável em caso de cisão; decisão adiada para modelo lógico |

---

**Status:** ✅ MODELO CONCEITUAL VALIDADO — Pronto para avançar ao Modelo Lógico
