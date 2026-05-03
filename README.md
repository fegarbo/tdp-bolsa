# TDP Bolsa - Modelagem de Banco de Dados

## 🎓 Atividade Avaliativa

**Disciplina:** TDP - Transformando Dados em Percepção  
**Curso:** MBA Gen AI e LLM Master  
**Instituição:** PUC Rio  
**Professor:** Anderson Nascimento  

---

## 📋 Sobre o Projeto

**Projeto:** Sistema de Gestão de Bolsa de Valores  
**Autora:** Fernando Garbo  
**Data de Início:** 2026-04-18  
**Deadline:** 2026-05-03  
**SGBD:** PostgreSQL

---

## 📌 Enunciado da Atividade

### Case: Negociações na Bolsa de Valores

Uma corretora deseja criar um sistema para gerenciar **Investidores**, **Ações** e suas **Negociações** na bolsa de valores.

**Requisitos:**

1. **Investidores**
   - Identificado por CPF ou CNPJ (único)
   - Nome completo, tipo (Pessoa Física ou Jurídica)
   - Email e telefone

2. **Empresas e Ações**
   - Cada Ação pertence a uma Empresa listada na bolsa
   - Empresa identificada por ticker (código de negociação)
   - Atributos: nome da empresa, setor de atuação, valor de mercado

3. **Negociações**
   - Registro de compra ou venda de ações
   - Data e hora da transação
   - Tipo de operação (Compra ou Venda)
   - Quantidade de ações e valor unitário

4. **Histórico de Cotações**
   - Manter histórico de preços das ações
   - Data, hora e valor da cotação
   - Permitir análises de séries temporais e comportamento do mercado

5. **Saldo de Carteira**
   - Posição atual (quantidade de ações mantidas por investidor)
   - Atualizado a partir das negociações realizadas
   - Permitir análises retrospectivas usando histórico de cotações

**Objetivos da Modelagem:**
- ✅ Implementar o **Modelo Conceitual** com diagrama ER
- ✅ Implementar o **Modelo Lógico** com schema normalizado (3NF)
- ✅ Implementar o **Modelo Físico** com scripts DDL, DML e DQL para PostgreSQL

---

## 📋 Sobre o Projeto (Detalhes Técnicos)

Este projeto contém a modelagem completa de um banco de dados para gerenciar operações de uma corretora de bolsa de valores.

**Escopo:**
- Modelo Conceitual (Entidade-Relacionamento)
- Modelo Lógico (Schema normalizado 3NF)
- Modelo Físico (Scripts DDL, DML, DQL para PostgreSQL)

**Padrão de Design:**
- OLTP (transações de negociação) + OLAP (relatórios e análises)
- SCD Type 2 para histórico de dados mestres
- Integridade referencial forte

---

## 📁 Estrutura do Projeto

```
tdp-bolsa/
├── README.md                          # Este arquivo
├── .gitignore                         # Git ignore
├── docs/
│   ├── PRD.md                         # Product Requirements Document
│   ├── 01-conceptual-model.md         # Modelo Conceitual com diagrama ER
│   ├── 02-logical-model.md            # Modelo Lógico com tipos e constraints
│   └── 03-physical-model.md           # Modelo Físico com scripts SQL
├── sql/
│   ├── 01-ddl.sql                     # CREATE TABLE, FK, constraints
│   ├── 02-dml.sql                     # INSERT, UPDATE, DELETE (testes)
│   └── 03-dql.sql                     # SELECT (consultas e relatórios)
└── diagrams/
    ├── conceptual-model.mmd           # Diagrama ER em Mermaid
    └── logical-model.mmd              # Diagrama Lógico em Mermaid
```

---

## 🎯 Entidades Principais

| Entidade | Descrição | Histórico |
|----------|-----------|-----------|
| **INVESTIDOR** | Pessoa Física ou Jurídica que investe | SCD Type 2 |
| **EMPRESA** | Empresa listada na bolsa | SCD Type 2 |
| **ACAO** | Ação emitida por empresa | SCD Type 2 |
| **NEGOCIACAO** | Registro de compra/venda (imutável) | Type 1 (append-only) |
| **COTACAO** | Histórico de preços (append-only) | Type 1 (append-only) |
| **SALDO_CARTEIRA** | Posição consolidada do investidor | Type 2 (opcional) |

---

## 📊 Arquivos Entregáveis

### ✅ Documentação
- `docs/PRD.md` - Product Requirements Document completo
- `docs/01-conceptual-model.md` - Modelo Conceitual com diagrama ER
- `docs/02-logical-model.md` - Modelo Lógico com especificação de colunas
- `docs/03-physical-model.md` - Modelo Físico com scripts SQL

### ✅ Scripts SQL
- `sql/01-ddl.sql` - CREATE TABLE com constraints (PK, FK, UNIQUE, CHECK)
- `sql/02-dml.sql` - INSERT/UPDATE/DELETE com testes de integridade
- `sql/03-dql.sql` - SELECT para relatórios e validação de dados

### ✅ Diagramas
- `diagrams/conceptual-model.mmd` - ER em Mermaid (Crows-foot)
- `diagrams/logical-model.mmd` - Lógico em Mermaid

---

## 🚀 Como Usar Este Projeto

### 1. Revisar Modelos
```bash
# Ler o PRD
cat docs/PRD.md

# Revisar Modelo Conceitual
cat docs/01-conceptual-model.md

# Revisar Modelo Lógico
cat docs/02-logical-model.md

# Revisar Modelo Físico
cat docs/03-physical-model.md
```

### 2. Criar Banco de Dados em PostgreSQL
```bash
# Conectar ao PostgreSQL
psql -U postgres

# Executar DDL
\i sql/01-ddl.sql

# Executar DML (dados de teste)
\i sql/02-dml.sql

# Executar DQL (consultas)
\i sql/03-dql.sql
```

### 3. Validar Integridade
Os scripts DML e DQL incluem testes para:
- ✅ Foreign keys válidas
- ✅ Unicidade de CPF/CNPJ e Ticker
- ✅ SCD Type 2 funcionando corretamente
- ✅ Histórico de cotações completo
- ✅ Posições de carteira precisas

---

## 📅 Timeline

| Fase | Data | Status |
|------|------|--------|
| Modelo Conceitual | 2026-04-21 | ✅ Completo |
| Modelo Lógico | 2026-04-28 | ⏳ Em andamento |
| Modelo Físico (DDL/DML/DQL) | 2026-05-03 | ⏳ Pendente |
| Testes Finais | 2026-05-03 | ⏳ Pendente |

---

## 📝 Decisões de Design

### SCD Type 2 para Dados Mestres
- **Investidores, Empresas, Ações** têm tabelas de histórico
- Rastreia mudanças sem perder dados anteriores
- Permite análises retrospectivas ("qual era o setor em 2024?")

### OLTP + OLAP
- **OLTP (rápido):** Negociações e atualizações de saldos
- **OLAP (análises):** Relatórios históricos e tendências
- Schema normalizado suporta ambos sem redesign

### Integridade Referencial Forte
- Foreign keys obrigatórias
- Sem deletar, apenas marcar como inativo
- Relacionamentos N-para-N via tabelas de junção

---

## 📞 Contato

**Autor:** Fernando Garbo  

---

**Versão:** 1.0 | **Data:** 2026-04-21 | **Status:** Em Desenvolvimento
