-- =============================================================================
-- DML — Sistema de Gestão de Bolsa de Valores
-- PostgreSQL 13+
-- Autor: Fernando Garbo | Data: 2026-05-17
-- =============================================================================
-- Conteúdo:
--   1. INSERT  — Dados de referência (investidores, empresas, contatos, ações)
--   2. INSERT  — Cotações (série temporal append-only)
--   3. INSERT  — Negociações (trigger mantém saldo_carteira automaticamente)
--   4. UPDATE  — SCD Type 2 em dados mestres
--   5. Exceções — venda com saldo insuficiente · DELETE com integridade referencial
-- =============================================================================


-- =============================================================================
-- 1. INVESTIDORES
-- PF: cpf_cnpj de 11 dígitos | PJ: cpf_cnpj de 14 dígitos
-- =============================================================================

BEGIN;

INSERT INTO investidor (cpf_cnpj, nome, tipo, data_cadastro, data_atualizacao) VALUES
    ('12345678901',    'Fernando Garbo',       'PF', '2026-01-10 09:00:00', '2026-01-10 09:00:00'),
    ('98765432100',    'Ana Lima',             'PF', '2026-01-15 10:30:00', '2026-01-15 10:30:00'),
    ('02332886000104', 'XP Investimentos SA',  'PJ', '2026-02-01 08:00:00', '2026-02-01 08:00:00');


-- =============================================================================
-- 2. EMPRESAS
-- =============================================================================

INSERT INTO empresa (cnpj, nome, setor, data_cadastro, data_atualizacao) VALUES
    ('33000167000101', 'Petróleo Brasileiro SA', 'Energia',    '2026-01-10 09:00:00', '2026-01-10 09:00:00'),
    ('90400888000142', 'Banco Santander Brasil',  'Financeiro', '2026-01-10 09:05:00', '2026-01-10 09:05:00'),
    ('33592510000154', 'Vale SA',                 'Mineração',  '2026-01-10 09:10:00', '2026-01-10 09:10:00');


-- =============================================================================
-- 3. CONTATOS
-- Múltiplos contatos por investidor; sem restrição de quantidade.
-- =============================================================================

INSERT INTO contato (investidor_id, tipo, valor) VALUES
    (1, 'EML', 'fernando@email.com'),
    (1, 'TEL', '21999990001'),
    (2, 'EML', 'ana.lima@email.com'),
    (2, 'WHT', '11988880002'),
    (3, 'EML', 'contato@xp.com.br'),
    (3, 'TEL', '1130030100');


-- =============================================================================
-- 4. AÇÕES
-- BIGINT em total_acoes: emissores de grande porte excedem limite de INTEGER.
-- =============================================================================

INSERT INTO acao (empresa_id, ticker, tipo, total_acoes, data_cadastro, data_atualizacao) VALUES
    (1, 'PETR3', 'ON', 13044496930, '2026-01-10 09:00:00', '2026-01-10 09:00:00'),
    (1, 'PETR4', 'PN',  9441019985, '2026-01-10 09:00:00', '2026-01-10 09:00:00'),
    (2, 'SANB4', 'PN',  4000000000, '2026-01-10 09:05:00', '2026-01-10 09:05:00'),
    (3, 'VALE3', 'ON',  4390590345, '2026-01-10 09:10:00', '2026-01-10 09:10:00');


-- =============================================================================
-- 5. COTAÇÕES — série temporal de 3 dias por ação (append-only)
-- =============================================================================

INSERT INTO cotacao (acao_id, valor, data_hora) VALUES
    -- PETR3
    (1, 36.50, '2026-05-13 10:00:00'),
    (1, 37.20, '2026-05-14 10:00:00'),
    (1, 38.50, '2026-05-15 10:00:00'),
    -- PETR4
    (2, 34.80, '2026-05-13 10:00:00'),
    (2, 35.60, '2026-05-14 10:00:00'),
    (2, 36.20, '2026-05-15 10:00:00'),
    -- SANB4
    (3, 27.10, '2026-05-13 10:00:00'),
    (3, 28.00, '2026-05-14 10:00:00'),
    (3, 28.90, '2026-05-15 10:00:00'),
    -- VALE3
    (4, 58.30, '2026-05-13 10:00:00'),
    (4, 59.10, '2026-05-14 10:00:00'),
    (4, 60.75, '2026-05-15 10:00:00');


-- =============================================================================
-- 6. NEGOCIAÇÕES — fn_atualiza_saldo_carteira() dispara após cada INSERT
-- =============================================================================

-- Compras: trigger faz UPSERT em saldo_carteira
INSERT INTO negociacao (investidor_id, acao_id, tipo_operacao, quantidade, valor_unitario, data_hora_transacao)
VALUES
    (1, 1, 'C', 100, 38.50, '2026-05-15 10:05:00'),  -- Fernando: +100 PETR3
    (1, 2, 'C', 200, 36.20, '2026-05-15 10:06:00'),  -- Fernando: +200 PETR4
    (2, 3, 'C',  50, 28.90, '2026-05-15 10:07:00'),  -- Ana:      + 50 SANB4
    (3, 4, 'C', 500, 60.75, '2026-05-15 10:08:00'),  -- XP:       +500 VALE3
    (1, 1, 'C',  50, 38.50, '2026-05-15 11:00:00');  -- Fernando: +50 PETR3 (total: 150)

-- Vendas válidas: trigger decrementa saldo
INSERT INTO negociacao (investidor_id, acao_id, tipo_operacao, quantidade, valor_unitario, data_hora_transacao)
VALUES
    (1, 1, 'V',  30, 39.00, '2026-05-15 14:00:00'),  -- Fernando: -30 PETR3 (saldo: 150 → 120)
    (2, 3, 'V',  20, 29.50, '2026-05-15 14:30:00');  -- Ana:      -20 SANB4 (saldo:  50 →  30)

COMMIT;


-- =============================================================================
-- 7. SCD TYPE 2 — Atualização de dados mestres com rastreamento histórico
-- Protocolo:
--   1. INSERT na tabela _historico com snapshot atual e data_fim = CURRENT_TIMESTAMP
--   2. UPDATE na tabela principal com os novos dados e data_atualizacao = CURRENT_TIMESTAMP
-- =============================================================================

-- 7a. EMPRESA — Petrobras reclassifica setor: 'Energia' → 'Petróleo e Gás'
BEGIN;

INSERT INTO empresa_historico (empresa_id, cnpj, nome, setor, data_inicio, data_fim)
SELECT empresa_id, cnpj, nome, setor, data_cadastro, CURRENT_TIMESTAMP
FROM   empresa
WHERE  cnpj = '33000167000101';

UPDATE empresa
SET    setor            = 'Petróleo e Gás',
       data_atualizacao = CURRENT_TIMESTAMP
WHERE  cnpj = '33000167000101';

COMMIT;


-- 7b. INVESTIDOR — Fernando atualiza nome (ex: casamento)
BEGIN;

INSERT INTO investidor_historico (investidor_id, cpf_cnpj, nome, tipo, data_inicio, data_fim)
SELECT investidor_id, cpf_cnpj, nome, tipo, data_cadastro, CURRENT_TIMESTAMP
FROM   investidor
WHERE  cpf_cnpj = '12345678901';

UPDATE investidor
SET    nome             = 'Fernando Garbo Pimentel',
       data_atualizacao = CURRENT_TIMESTAMP
WHERE  cpf_cnpj = '12345678901';

COMMIT;


-- 7c. ACAO — Petrobras emite novas ações ordinárias
BEGIN;

INSERT INTO acao_historico (acao_id, empresa_id, ticker, tipo, total_acoes, data_inicio, data_fim)
SELECT acao_id, empresa_id, ticker, tipo, total_acoes, data_cadastro, CURRENT_TIMESTAMP
FROM   acao
WHERE  ticker = 'PETR3';

UPDATE acao
SET    total_acoes      = 13500000000,
       data_atualizacao = CURRENT_TIMESTAMP
WHERE  ticker = 'PETR3';

COMMIT;


-- =============================================================================
-- 8. CASOS DE EXCEÇÃO — encapsulados em blocos anônimos; script não aborta
-- =============================================================================

-- 8a. Venda com saldo insuficiente → trigger lança RAISE EXCEPTION
--     Fernando possui 120 PETR3; tentativa de vender 9.999 deve ser bloqueada.
DO $$
BEGIN
    INSERT INTO negociacao (investidor_id, acao_id, tipo_operacao, quantidade, valor_unitario)
    VALUES (1, 1, 'V', 9999, 39.00);

    RAISE NOTICE 'FALHOU: exceção esperada não foi lançada';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'OK — venda bloqueada: %', SQLERRM;
END $$;


-- 8b. DELETE em pai com filhos → viola ON DELETE RESTRICT
--     Investidor 1 possui contatos, negociações e saldo associados.
DO $$
BEGIN
    DELETE FROM investidor WHERE cpf_cnpj = '12345678901';

    RAISE NOTICE 'FALHOU: deleção deveria ter sido bloqueada';
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'OK — DELETE bloqueado por integridade referencial: %', SQLERRM;
END $$;
