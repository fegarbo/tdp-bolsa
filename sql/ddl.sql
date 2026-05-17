-- =============================================================================
-- DDL — Sistema de Gestão de Bolsa de Valores
-- PostgreSQL 13+
-- Autor: Fernando Garbo | Data: 2026-05-17
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Limpeza para re-execução (ordem inversa de dependência)
-- -----------------------------------------------------------------------------
DROP TRIGGER  IF EXISTS trg_atualiza_saldo_carteira ON negociacao;
DROP FUNCTION IF EXISTS fn_atualiza_saldo_carteira();
DROP VIEW     IF EXISTS vw_valor_mercado;
DROP TABLE    IF EXISTS saldo_carteira;
DROP TABLE    IF EXISTS negociacao;
DROP TABLE    IF EXISTS cotacao;
DROP TABLE    IF EXISTS acao_historico;
DROP TABLE    IF EXISTS acao;
DROP TABLE    IF EXISTS contato;
DROP TABLE    IF EXISTS empresa_historico;
DROP TABLE    IF EXISTS empresa;
DROP TABLE    IF EXISTS investidor_historico;
DROP TABLE    IF EXISTS investidor;


-- =============================================================================
-- TABELAS PRINCIPAIS
-- =============================================================================

-- 1. INVESTIDOR
-- Pessoas físicas (CPF, 11 dígitos) e jurídicas (CNPJ, 14 dígitos).
-- CHECK composto garante que o comprimento do documento é coerente com o tipo.
-- -----------------------------------------------------------------------------
CREATE TABLE investidor (
    investidor_id    INTEGER      GENERATED ALWAYS AS IDENTITY,
    cpf_cnpj         VARCHAR(14)  NOT NULL,
    nome             VARCHAR(255) NOT NULL,
    tipo             VARCHAR(2)   NOT NULL,
    data_cadastro    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_investidor            PRIMARY KEY (investidor_id),
    CONSTRAINT uq_investidor_cpf_cnpj   UNIQUE      (cpf_cnpj),
    CONSTRAINT ck_investidor_tipo       CHECK (tipo IN ('PF', 'PJ')),
    CONSTRAINT ck_investidor_documento  CHECK (
        (tipo = 'PF' AND LENGTH(cpf_cnpj) = 11) OR
        (tipo = 'PJ' AND LENGTH(cpf_cnpj) = 14)
    )
);

-- 2. EMPRESA
-- Surrogate key empresa_id isola todas as FKs de mudanças futuras no formato
-- do CNPJ (IN RFB 2.229/2024 introduz CNPJ alfanumérico).
-- -----------------------------------------------------------------------------
CREATE TABLE empresa (
    empresa_id       INTEGER      GENERATED ALWAYS AS IDENTITY,
    cnpj             VARCHAR(14)  NOT NULL,
    nome             VARCHAR(255) NOT NULL,
    setor            VARCHAR(100) NOT NULL,
    data_cadastro    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_empresa      PRIMARY KEY (empresa_id),
    CONSTRAINT uq_empresa_cnpj UNIQUE      (cnpj)
);


-- =============================================================================
-- TABELAS DE HISTÓRICO — SCD Type 2
-- Armazenam snapshots anteriores de dados mestres.
-- Protocolo de atualização:
--   1. INSERT na tabela _historico com os dados atuais e data_fim = NOW()
--   2. UPDATE na tabela principal com os novos dados e data_atualizacao = NOW()
-- =============================================================================

-- 3. INVESTIDOR_HISTORICO
-- -----------------------------------------------------------------------------
CREATE TABLE investidor_historico (
    historico_id  INTEGER      GENERATED ALWAYS AS IDENTITY,
    investidor_id INTEGER      NOT NULL,
    cpf_cnpj      VARCHAR(14)  NOT NULL,
    nome          VARCHAR(255) NOT NULL,
    tipo          VARCHAR(2)   NOT NULL,
    data_inicio   TIMESTAMP    NOT NULL,
    data_fim      TIMESTAMP    NOT NULL,

    CONSTRAINT pk_investidor_historico PRIMARY KEY (historico_id),
    CONSTRAINT fk_inv_hist_investidor  FOREIGN KEY (investidor_id)
        REFERENCES investidor (investidor_id) ON DELETE RESTRICT,
    CONSTRAINT ck_inv_hist_datas       CHECK (data_inicio < data_fim)
);

-- 4. EMPRESA_HISTORICO
-- -----------------------------------------------------------------------------
CREATE TABLE empresa_historico (
    historico_id INTEGER      GENERATED ALWAYS AS IDENTITY,
    empresa_id   INTEGER      NOT NULL,
    cnpj         VARCHAR(14)  NOT NULL,
    nome         VARCHAR(255) NOT NULL,
    setor        VARCHAR(100) NOT NULL,
    data_inicio  TIMESTAMP    NOT NULL,
    data_fim     TIMESTAMP    NOT NULL,

    CONSTRAINT pk_empresa_historico PRIMARY KEY (historico_id),
    CONSTRAINT fk_emp_hist_empresa  FOREIGN KEY (empresa_id)
        REFERENCES empresa (empresa_id) ON DELETE RESTRICT,
    CONSTRAINT ck_emp_hist_datas    CHECK (data_inicio < data_fim)
);

-- 5. CONTATO
-- Padrão tipo+valor suporta N contatos de qualquer tipo por investidor,
-- sem colunas nulas. UNIQUE composta evita duplicata do mesmo contato.
-- -----------------------------------------------------------------------------
CREATE TABLE contato (
    contato_id    INTEGER      GENERATED ALWAYS AS IDENTITY,
    investidor_id INTEGER      NOT NULL,
    tipo          VARCHAR(3)   NOT NULL,
    valor         VARCHAR(255) NOT NULL,

    CONSTRAINT pk_contato            PRIMARY KEY (contato_id),
    CONSTRAINT fk_contato_investidor FOREIGN KEY (investidor_id)
        REFERENCES investidor (investidor_id) ON DELETE RESTRICT,
    CONSTRAINT uq_contato            UNIQUE (investidor_id, tipo, valor),
    CONSTRAINT ck_contato_tipo       CHECK  (tipo IN ('TEL', 'EML', 'WHT'))
);

-- 6. ACAO
-- BIGINT em total_acoes: grandes emissores (ex: Petrobras ~13 bi ações)
-- excedem o limite de INTEGER (~2,1 bi).
-- -----------------------------------------------------------------------------
CREATE TABLE acao (
    acao_id          INTEGER      GENERATED ALWAYS AS IDENTITY,
    empresa_id       INTEGER      NOT NULL,
    ticker           VARCHAR(10)  NOT NULL,
    tipo             VARCHAR(3)   NOT NULL,
    total_acoes      BIGINT       NOT NULL,
    data_cadastro    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_acao             PRIMARY KEY (acao_id),
    CONSTRAINT uq_acao_ticker      UNIQUE      (ticker),
    CONSTRAINT fk_acao_empresa     FOREIGN KEY (empresa_id)
        REFERENCES empresa (empresa_id) ON DELETE RESTRICT,
    CONSTRAINT ck_acao_tipo        CHECK (tipo IN ('ON', 'PN', 'UNT')),
    CONSTRAINT ck_acao_total_acoes CHECK (total_acoes > 0)
);

-- 7. ACAO_HISTORICO
-- empresa_id armazenado como cópia (sem FK) para preservar integridade do
-- snapshot histórico independentemente de mudanças futuras em EMPRESA.
-- SCD Type 2 em ACAO trata cisões societárias: nova versão com novo empresa_id.
-- -----------------------------------------------------------------------------
CREATE TABLE acao_historico (
    historico_id INTEGER     GENERATED ALWAYS AS IDENTITY,
    acao_id      INTEGER     NOT NULL,
    empresa_id   INTEGER     NOT NULL,
    ticker       VARCHAR(10) NOT NULL,
    tipo         VARCHAR(3)  NOT NULL,
    total_acoes  BIGINT      NOT NULL,
    data_inicio  TIMESTAMP   NOT NULL,
    data_fim     TIMESTAMP   NOT NULL,

    CONSTRAINT pk_acao_historico PRIMARY KEY (historico_id),
    CONSTRAINT fk_acao_hist_acao FOREIGN KEY (acao_id)
        REFERENCES acao (acao_id) ON DELETE RESTRICT,
    CONSTRAINT ck_acao_hist_datas CHECK (data_inicio < data_fim)
);

-- 8. COTACAO
-- Append-only: apenas INSERT, nunca UPDATE ou DELETE.
-- UNIQUE (acao_id, data_hora) impede duas cotações no mesmo instante.
-- -----------------------------------------------------------------------------
CREATE TABLE cotacao (
    cotacao_id INTEGER        GENERATED ALWAYS AS IDENTITY,
    acao_id    INTEGER        NOT NULL,
    valor      NUMERIC(15, 2) NOT NULL,
    data_hora  TIMESTAMP      NOT NULL,

    CONSTRAINT pk_cotacao       PRIMARY KEY (cotacao_id),
    CONSTRAINT fk_cotacao_acao  FOREIGN KEY (acao_id)
        REFERENCES acao (acao_id) ON DELETE RESTRICT,
    CONSTRAINT uq_cotacao       UNIQUE (acao_id, data_hora),
    CONSTRAINT ck_cotacao_valor CHECK  (valor > 0)
);

-- 9. NEGOCIACAO
-- Registro imutável de compra/venda (entidade associativa INVESTIDOR × ACAO).
-- Apenas INSERT. valor_total é derivado (quantidade × valor_unitario).
-- -----------------------------------------------------------------------------
CREATE TABLE negociacao (
    negociacao_id       INTEGER        GENERATED ALWAYS AS IDENTITY,
    investidor_id       INTEGER        NOT NULL,
    acao_id             INTEGER        NOT NULL,
    tipo_operacao       VARCHAR(1)     NOT NULL,
    quantidade          INTEGER        NOT NULL,
    valor_unitario      NUMERIC(15, 2) NOT NULL,
    data_hora_transacao TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_negociacao            PRIMARY KEY (negociacao_id),
    CONSTRAINT fk_neg_investidor        FOREIGN KEY (investidor_id)
        REFERENCES investidor (investidor_id) ON DELETE RESTRICT,
    CONSTRAINT fk_neg_acao              FOREIGN KEY (acao_id)
        REFERENCES acao (acao_id) ON DELETE RESTRICT,
    CONSTRAINT ck_negociacao_tipo_op    CHECK (tipo_operacao IN ('C', 'V')),
    CONSTRAINT ck_negociacao_quantidade CHECK (quantidade > 0),
    CONSTRAINT ck_negociacao_valor      CHECK (valor_unitario > 0)
);

-- 10. SALDO_CARTEIRA
-- Posição consolidada por par (investidor, acao). Mantida automaticamente
-- por trigger após cada INSERT em NEGOCIACAO. quantidade = 0 é válido.
-- -----------------------------------------------------------------------------
CREATE TABLE saldo_carteira (
    saldo_id         INTEGER        GENERATED ALWAYS AS IDENTITY,
    investidor_id    INTEGER        NOT NULL,
    acao_id          INTEGER        NOT NULL,
    quantidade       INTEGER        NOT NULL DEFAULT 0,
    data_atualizacao TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_saldo_carteira   PRIMARY KEY (saldo_id),
    CONSTRAINT uq_saldo_carteira   UNIQUE      (investidor_id, acao_id),
    CONSTRAINT fk_saldo_investidor FOREIGN KEY (investidor_id)
        REFERENCES investidor (investidor_id) ON DELETE RESTRICT,
    CONSTRAINT fk_saldo_acao       FOREIGN KEY (acao_id)
        REFERENCES acao (acao_id) ON DELETE RESTRICT,
    CONSTRAINT ck_saldo_quantidade CHECK (quantidade >= 0)
);


-- =============================================================================
-- ÍNDICES
-- =============================================================================

-- CONTATO
CREATE INDEX idx_contato_investidor
    ON contato (investidor_id);

-- NEGOCIACAO
CREATE INDEX idx_negociacao_investidor
    ON negociacao (investidor_id);

CREATE INDEX idx_negociacao_acao
    ON negociacao (acao_id);

CREATE INDEX idx_negociacao_data
    ON negociacao (data_hora_transacao);

-- HISTÓRICO — otimiza recuperação de versões e consultas point-in-time
CREATE INDEX idx_inv_hist_lookup
    ON investidor_historico (investidor_id, data_fim);

CREATE INDEX idx_emp_hist_lookup
    ON empresa_historico (empresa_id, data_fim);

CREATE INDEX idx_acao_hist_lookup
    ON acao_historico (acao_id, data_fim);


-- =============================================================================
-- VIEW — Capitalização de Mercado
-- valor_mercado = total_acoes × cotação mais recente (derivado, não persistido)
-- =============================================================================

CREATE VIEW vw_valor_mercado AS
SELECT
    e.empresa_id,
    e.nome                      AS empresa,
    a.acao_id,
    a.ticker,
    a.total_acoes,
    c.valor                     AS cotacao_atual,
    a.total_acoes * c.valor     AS valor_mercado,
    c.data_hora                 AS data_cotacao
FROM  empresa  e
JOIN  acao     a ON a.empresa_id = e.empresa_id
JOIN  cotacao  c ON c.acao_id    = a.acao_id
WHERE c.data_hora = (
    SELECT MAX(c2.data_hora)
    FROM   cotacao c2
    WHERE  c2.acao_id = a.acao_id
);


-- =============================================================================
-- TRIGGER — Manutenção automática de SALDO_CARTEIRA
-- Disparado após cada INSERT em NEGOCIACAO.
-- Compra (C): UPSERT — cria ou incrementa posição.
-- Venda  (V): decrementa posição; lança exceção se saldo insuficiente.
-- =============================================================================

CREATE OR REPLACE FUNCTION fn_atualiza_saldo_carteira()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.tipo_operacao = 'C' THEN

        INSERT INTO saldo_carteira (investidor_id, acao_id, quantidade, data_atualizacao)
        VALUES (NEW.investidor_id, NEW.acao_id, NEW.quantidade, CURRENT_TIMESTAMP)
        ON CONFLICT (investidor_id, acao_id)
        DO UPDATE SET
            quantidade       = saldo_carteira.quantidade + EXCLUDED.quantidade,
            data_atualizacao = CURRENT_TIMESTAMP;

    ELSIF NEW.tipo_operacao = 'V' THEN

        IF NOT EXISTS (
            SELECT 1
            FROM   saldo_carteira
            WHERE  investidor_id = NEW.investidor_id
              AND  acao_id       = NEW.acao_id
              AND  quantidade   >= NEW.quantidade
        ) THEN
            RAISE EXCEPTION
                'Saldo insuficiente para venda: investidor_id=%, acao_id=%, quantidade solicitada=%',
                NEW.investidor_id, NEW.acao_id, NEW.quantidade;
        END IF;

        UPDATE saldo_carteira
        SET    quantidade       = quantidade - NEW.quantidade,
               data_atualizacao = CURRENT_TIMESTAMP
        WHERE  investidor_id    = NEW.investidor_id
          AND  acao_id          = NEW.acao_id;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_atualiza_saldo_carteira
    AFTER INSERT ON negociacao
    FOR EACH ROW
    EXECUTE FUNCTION fn_atualiza_saldo_carteira();
