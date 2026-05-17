---
stepsCompleted: ['step-01-init', 'step-02-discovery', 'step-02b-vision', 'step-02c-executive-summary', 'step-03-success']
inputDocuments: []
workflowType: 'prd'
project_name: 'Sistema de Gestão de Bolsa de Valores'
user_name: 'Fernando Garbo'
date: '2026-04-18'
classification:
  projectType: 'Design de Banco de Dados'
  domain: 'Fintech / Mercado de Capitais'
  complexity: 'Média-Alta'
  projectContext: 'greenfield'
  scope: 'Modelos Conceitual, Lógico e Físico'
vision:
  hybrid: 'OLTP (transações) + OLAP (relatórios)'
  keyPattern: 'SCD Type 2 para dados mestres com histórico'
  focus: 'Relacionamentos e integridade referencial bem construídos'
  stage: 'Modelagem Completa até 10/05'
  sgbd: 'PostgreSQL'
  deliverables: 'Modelo Conceitual + Modelo Lógico + Modelo Físico (DDL + DML + DQL)'
---

# Product Requirements Document - Sistema de Gestão de Bolsa de Valores

**Autor:** Fernando Garbo
**Data:** 2026-04-18

## Executive Summary

A corretora necessita de um modelo conceitual, lógico e físico bem estruturado para gerenciar operações de bolsa de valores. O sistema deve suportar **dois padrões de acesso simultâneos**: transações operacionais rápidas (OLTP) para execução de negociações em tempo real e acesso analítico (OLAP) para relatórios e análises de carteira. O design prioriza **integridade referencial forte, relacionamentos bem construídos, e capacidade de histórico** para suportar análises retrospectivas e auditoria regulatória.

### What Makes This Special

Este design diferencia-se por seu **equilíbrio pragmático entre integridade e flexibilidade**: utiliza **SCD Type 2** em tabelas mestres (Investidores, Empresas, Ações) para manter histórico completo sem sacrificar performance operacional. A arquitetura suporta casos de uso críticos (negociações, posições de carteira, cotações históricas) com um schema normalizado (3NF) no núcleo transacional, permitindo análises dimensional quando necessário. Isso habilita rastreamento completo de mudanças, auditoria de conformidade, e escalabilidade sem redesign futuro.

## Project Classification

| Atributo | Descrição |
|----------|-----------|
| **Tipo de Projeto** | Design de Banco de Dados (Modelos Conceitual, Lógico, Físico) |
| **Domínio** | Fintech / Mercado de Capitais |
| **Complexidade** | Média-Alta (múltiplas entidades, relacionamentos n-para-n, séries temporais) |
| **Contexto** | Greenfield (novo sistema) |
| **Foco de Implementação** | Modelagem Completa (Conceitual → Lógico → Físico) |
| **Padrão de Dados** | Híbrido OLTP + OLAP com SCD Type 2 |
| **SGBD** | PostgreSQL |
| **Deadline** | 03/05/2026 |

## Success Criteria

### User Success
- DBAs/Analistas conseguem executar negociações (INSERT/UPDATE) sem deadlocks ou conflitos de integridade referencial
- Conseguem gerar relatórios históricos (SELECT) que refletem com precisão o estado dos dados em qualquer ponto no tempo (SCD Type 2)
- Conseguem rastrear mudanças em dados mestres (Investidores, Empresas, Ações) via tabelas de histórico
- Conseguem realizar reconciliação: `SUM(movimentações) = saldo final` sem discrepâncias

### Business Success
- Modelo suporta **OLTP** (transações de negociação) e **OLAP** (relatórios/análises) sem redesign futuro
- Auditoria completa: toda operação é rastreável (quem fez, quando, o que mudou)
- Escalabilidade: schema preparado para crescimento de volume sem alterações estruturais
- Conformidade: histórico imutável garante conformidade regulatória

### Technical Success
- **Integridade Referencial Forte:** Zero orphaned records (FK constraints)
- **Atomicidade:** Operações multi-tabela garantem all-or-nothing (transações ACID)
- **Histórico (SCD Type 2):** Mudanças em dados mestres geram novo registro com timestamps (data_inicio, data_fim)
- **Relacionamentos N-para-N:** Implementados corretamente via tabelas de junção
- **Chaves Únicas:** CPF/CNPJ únicos para Investidores, Ticker único para Empresas

### Measurable Outcomes
- ✅ **Modelo Conceitual:** Diagrama ER completo com todas as entidades, atributos e relacionamentos (até 03/05)
- ✅ **Modelo Lógico:** Schema normalizado (3NF) documentado com tipos de dados (até 03/05)
- ✅ **Modelo Físico (Completo):** 
  - Scripts **DDL** (CREATE TABLE com constraints)
  - Scripts **DML** (INSERT/UPDATE/DELETE com casos de teste)
  - Scripts **DQL** (SELECT para relatórios e análises)
  - Todos executáveis e validáveis em PostgreSQL

## Product Scope

### MVP - Entrega Completa até 03/05

**Entidades Obrigatórias:**
- Investidores (com SCD Type 2 para mudanças de perfil)
- Empresas (com SCD Type 2 para mudanças de setor/mercado)
- Ações (com SCD Type 2 para mudanças de características)
- Cotações (histórico append-only de preços)
- Negociações (registro imutável de compra/venda)
- Saldo de Carteira (posição consolidada de investidor + ação)

**Modelos Entregáveis:**
1. **Modelo Conceitual:** Diagrama ER em notação clara (crows-foot ou similar)
2. **Modelo Lógico:** Especificação de tabelas, colunas, tipos, constraints, índices
3. **Modelo Físico (Completo para PostgreSQL):**
   - DDL: CREATE TABLE com PK, FK, UNIQUE, NOT NULL, CHECK constraints
   - DML: Scripts de teste (INSERT dados válidos, UPDATE para SCD Type 2, DELETE com validação)
   - DQL: Scripts de consultas (relatórios de carteira, cotações históricas, negociações, validação de integridade)

### Growth Features (Pós-MVP)
- Particionamento de tabelas por data (Cotações, Negociações)
- Índices avançados (covering indexes, partial indexes)
- Materialized Views para análises OLAP
- Procedures/Functions para cálculos complexos (PnL, risco)

### Vision (Futuro)
- Replicação para data warehouse (OLAP separado)
- Real-time streaming de cotações
- Machine learning para análises preditivas
