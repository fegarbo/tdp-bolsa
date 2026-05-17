---
stepsCompleted: []
inputDocuments: ['PRD.md']
workflowType: 'architecture'
project_name: 'Sistema de Gestão de Bolsa de Valores'
user_name: 'Fernando Garbo'
date: '2026-04-21'
sgbd: 'PostgreSQL'
---

# Architecture Decision Document - Sistema de Gestão de Bolsa de Valores

_Modelo Conceitual, Lógico e Físico para Banco de Dados de Bolsa de Valores_

## Overview

Este documento captura as decisões arquitetônicas para o design de banco de dados de uma corretora de bolsa de valores, focando em:
- **Modelo Conceitual:** Entidades, atributos e relacionamentos
- **Modelo Lógico:** Schema normalizado (3NF) com SCD Type 2
- **Modelo Físico:** Scripts DDL, DML e DQL para PostgreSQL

**Padrão:** OLTP + OLAP com SCD Type 2 para histórico de dados mestres
**SGBD:** PostgreSQL
**Deadline:** 10/05/2026
